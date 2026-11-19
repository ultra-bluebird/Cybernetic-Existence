// File: crates/iss-thermal-lipschitz-guard/src/lib.rs
#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

pub const ALN_MIGRATION_CYBERCORE_AUTHORITY_V1: &str =
    "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";
pub const HOST_DID: &str = "OrganicCPU";
pub const BOSTROM_ADDRESS: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq)]
pub struct IssThermalLipschitzConfig {
    pub lipschitz_l_max_per_second: f32,
    pub margin_epsilon: f32,
    pub guard_dt_max_seconds: f32,
}

impl IssThermalLipschitzConfig {
    pub fn iss_default() -> Self {
        Self {
            lipschitz_l_max_per_second: 0.075,
            margin_epsilon: 0.01,
            guard_dt_max_seconds: 60.0,
        }
    }

    pub fn is_sane(&self) -> bool {
        self.lipschitz_l_max_per_second >= 0.0
            && self.margin_epsilon >= 0.0
            && self.guard_dt_max_seconds > 0.0
    }
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq)]
pub struct IssThermalSample {
    pub roh_thermal_scalar: f32,
    pub t_seconds: f32,
    pub margin_to_polytope: f32,
}

impl IssThermalSample {
    pub fn is_sane(&self) -> bool {
        self.roh_thermal_scalar >= 0.0
            && self.roh_thermal_scalar <= 0.3
            && self.t_seconds >= 0.0
            && self.margin_to_polytope >= 0.0
    }
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum IssThermalLipschitzVerdict {
    Allow,
    DenyTemporalAliasRisk,
    DenyConfigurationError,
}

fn compute_effective_lipschitz(prev: IssThermalSample, next: IssThermalSample) -> Option<f32> {
    let dt = next.t_seconds - prev.t_seconds;
    if dt <= 0.0 {
        return None;
    }
    let droh = (next.roh_thermal_scalar - prev.roh_thermal_scalar).abs();
    Some(droh / dt)
}

fn check_margin_condition(
    config: &IssThermalLipschitzConfig,
    prev: IssThermalSample,
    next: IssThermalSample,
) -> Option<bool> {
    let dt = next.t_seconds - prev.t_seconds;
    if dt <= 0.0 {
        return None;
    }

    if dt > config.guard_dt_max_seconds {
        return Some(false);
    }

    let required_margin = config.lipschitz_l_max_per_second * dt + config.margin_epsilon;
    let m = next.margin_to_polytope;
    Some(m >= required_margin)
}

pub fn evaluate_iss_thermal_lipschitz_step(
    config: &IssThermalLipschitzConfig,
    prev: IssThermalSample,
    next: IssThermalSample,
) -> IssThermalLipschitzVerdict {
    if !config.is_sane() || !prev.is_sane() || !next.is_sane() {
        return IssThermalLipschitzVerdict::DenyConfigurationError;
    }

    let leff_opt = compute_effective_lipschitz(prev, next);
    let leff = match leff_opt {
        Some(v) => v,
        None => return IssThermalLipschitzVerdict::DenyConfigurationError,
    };

    if leff > config.lipschitz_l_max_per_second + f32::EPSILON {
        return IssThermalLipschitzVerdict::DenyTemporalAliasRisk;
    }

    let margin_ok_opt = check_margin_condition(config, prev, next);
    let margin_ok = match margin_ok_opt {
        Some(v) => v,
        None => return IssThermalLipschitzVerdict::DenyConfigurationError,
    };

    if !margin_ok {
        return IssThermalLipschitzVerdict::DenyTemporalAliasRisk;
    }

    IssThermalLipschitzVerdict::Allow
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sane_default_config() {
        let cfg = IssThermalLipschitzConfig::iss_default();
        assert!(cfg.is_sane());
    }

    #[test]
    fn allow_small_change_with_large_margin() {
        let cfg = IssThermalLipschitzConfig::iss_default();

        let s1 = IssThermalSample {
            roh_thermal_scalar: 0.10,
            t_seconds: 0.0,
            margin_to_polytope: 0.20,
        };
        let s2 = IssThermalSample {
            roh_thermal_scalar: 0.11,
            t_seconds: 10.0,
            margin_to_polytope: 0.20,
        };

        let verdict = evaluate_iss_thermal_lipschitz_step(&cfg, s1, s2);
        assert_eq!(verdict, IssThermalLipschitzVerdict::Allow);
    }

    #[test]
    fn deny_if_effective_lipschitz_exceeds_bound() {
        let cfg = IssThermalLipschitzConfig::iss_default();

        let s1 = IssThermalSample {
            roh_thermal_scalar: 0.10,
            t_seconds: 0.0,
            margin_to_polytope: 0.20,
        };
        let s2 = IssThermalSample {
            roh_thermal_scalar: 0.20,
            t_seconds: 1.0,
            margin_to_polytope: 0.20,
        };

        let verdict = evaluate_iss_thermal_lipschitz_step(&cfg, s1, s2);
        assert_eq!(verdict, IssThermalLipschitzVerdict::DenyTemporalAliasRisk);
    }

    #[test]
    fn deny_if_margin_too_small_for_dt() {
        let cfg = IssThermalLipschitzConfig::iss_default();

        let s1 = IssThermalSample {
            roh_thermal_scalar: 0.10,
            t_seconds: 0.0,
            margin_to_polytope: 0.02,
        };
        let s2 = IssThermalSample {
            roh_thermal_scalar: 0.105,
            t_seconds: 10.0,
            margin_to_polytope: 0.02,
        };

        let verdict = evaluate_iss_thermal_lipschitz_step(&cfg, s1, s2);
        assert_eq!(verdict, IssThermalLipschitzVerdict::DenyTemporalAliasRisk);
    }
}

#[cfg(kani)]
mod kani_harnesses {
    use super::*;
    use kani::any;

    #[kani::proof]
    fn lipschitz_never_allows_when_leff_above_bound() {
        let cfg = IssThermalLipschitzConfig::iss_default();
        kani::assume(cfg.is_sane());

        let prev: IssThermalSample = any();
        let next: IssThermalSample = any();

        kani::assume(prev.is_sane());
        kani::assume(next.is_sane());
        kani::assume(next.t_seconds > prev.t_seconds);

        let dt = next.t_seconds - prev.t_seconds;
        let droh = (next.roh_thermal_scalar - prev.roh_thermal_scalar).abs();
        let leff = droh / dt;

        kani::assume(leff > cfg.lipschitz_l_max_per_second + f32::EPSILON);

        let verdict = evaluate_iss_thermal_lipschitz_step(&cfg, prev, next);
        kani::assert!(
            verdict != IssThermalLipschitzVerdict::Allow,
            "Guard must not Allow when effective Lipschitz exceeds bound"
        );
    }

    #[kani::proof]
    fn margin_violation_never_allows() {
        let cfg = IssThermalLipschitzConfig::iss_default();
        kani::assume(cfg.is_sane());

        let prev: IssThermalSample = any();
        let next: IssThermalSample = any();

        kani::assume(prev.is_sane());
        kani::assume(next.is_sane());
        kani::assume(next.t_seconds > prev.t_seconds);

        let dt = next.t_seconds - prev.t_seconds;
        kani::assume(dt <= cfg.guard_dt_max_seconds);

        let required_margin = cfg.lipschitz_l_max_per_second * dt + cfg.margin_epsilon;
        kani::assume(next.margin_to_polytope < required_margin);

        let verdict = evaluate_iss_thermal_lipschitz_step(&cfg, prev, next);
        kani::assert!(
            verdict != IssThermalLipschitzVerdict::Allow,
            "Guard must not Allow when safety margin condition is violated"
        );
    }
}
