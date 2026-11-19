// crates/capillary-density-guard/src/polytope.rs

#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]

use serde::{Deserialize, Serialize};

/// Global authority and host binding constants for nanoswarm corridors.
pub const ALN_MIGRATION_CYBERCORE_AUTHORITY_V1: &str =
    "ALN.MIGRATION.CYBERCOREAUTHORITY.v1";
pub const HOST_DID: &str = "did.aln.bostrom-organic-host";
pub const BOSTROM_ADDRESS: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

/// Normalized capillary swarm density state.
///
/// - phi_tot: normalized total particulate volume fraction in the capillary bed (0.0–1.0).
/// - clogging_score: normalized topological clogging score (0.0–1.0).
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq)]
pub struct CapillaryDensityState {
    pub phi_tot: f32,
    pub clogging_score: f32,
}

impl CapillaryDensityState {
    pub fn clamped(self) -> Self {
        Self {
            phi_tot: self.phi_tot.clamp(0.0, 1.0),
            clogging_score: self.clogging_score.clamp(0.0, 1.0),
        }
    }
}

/// Guard verdict for the capillary density polytope.
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum CapillaryDensityVerdict {
    Allow,
    ClampAndRetry,
    Deny,
}

/// Configuration for the convex safe polytope in (phi_tot, clogging_score) space.
///
/// The inequalities encoded here must be conservative and tightening‑only over time.
/// All fields are normalized to [0.0, 1.0] bands; domain‑specific calibration
/// is handled upstream by mapping physical units into these normalized scalars.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct CapillaryPolytopeConfig {
    /// Maximum allowed phi_tot in the conservative safe band.
    pub phi_tot_max: f32,
    /// Maximum allowed clogging_score in the conservative safe band.
    pub clogging_score_max: f32,
    /// Oblique facet coefficients for y <= m1 * x + b1.
    pub facet_m1: f32,
    pub facet_b1: f32,
    /// Oblique facet coefficients for y <= m2 * x + b2.
    pub facet_m2: f32,
    pub facet_b2: f32,
    /// Oblique facet coefficients for y <= m3 * x + b3.
    pub facet_m3: f32,
    pub facet_b3: f32,
    /// Soft thresholds for ClampAndRetry band.
    pub soft_phi_tot_max: f32,
    pub soft_clogging_score_max: f32,
}

impl CapillaryPolytopeConfig {
    /// Conservative default polytope parameters.
    ///
    /// This configuration encodes a small convex polygon in (phi_tot, clogging_score)
    /// space that has been chosen to be safely inside the physiological corridor.
    pub fn conservative_default() -> Self {
        Self {
            phi_tot_max: 0.25,
            clogging_score_max: 0.20,
            facet_m1: 0.33,
            facet_b1: 0.0,
            facet_m2: 0.25,
            facet_b2: 0.01,
            facet_m3: -1.0,
            facet_b3: 0.35,
            soft_phi_tot_max: 0.20,
            soft_clogging_score_max: 0.15,
        }
    }

    pub fn clamped(self) -> Self {
        Self {
            phi_tot_max: self.phi_tot_max.clamp(0.0, 1.0),
            clogging_score_max: self.clogging_score_max.clamp(0.0, 1.0),
            facet_m1: self.facet_m1,
            facet_b1: self.facet_b1,
            facet_m2: self.facet_m2,
            facet_b2: self.facet_b2,
            facet_m3: self.facet_m3,
            facet_b3: self.facet_b3,
            soft_phi_tot_max: self.soft_phi_tot_max.clamp(0.0, 1.0),
            soft_clogging_score_max: self.soft_clogging_score_max.clamp(0.0, 1.0),
        }
    }
}

/// Evaluate whether a normalized state lies inside the convex safe polytope.
///
/// Returns:
/// - Allow if all hard inequalities are satisfied.
/// - ClampAndRetry if hard inequalities are satisfied but soft thresholds are exceeded.
/// - Deny if any hard inequality is violated.
pub fn evaluate_capillary_polytope(
    cfg: &CapillaryPolytopeConfig,
    state: CapillaryDensityState,
) -> CapillaryDensityVerdict {
    let cfg = cfg.clamped();
    let s = state.clamped();

    // Hard box bounds.
    if s.phi_tot > cfg.phi_tot_max || s.clogging_score > cfg.clogging_score_max {
        return CapillaryDensityVerdict::Deny;
    }

    // Oblique facets: y <= m_i * x + b_i.
    let y = s.clogging_score;
    let x = s.phi_tot;

    let facet1_ok = y <= cfg.facet_m1 * x + cfg.facet_b1;
    let facet2_ok = y <= cfg.facet_m2 * x + cfg.facet_b2;
    let facet3_ok = y <= cfg.facet_m3 * x + cfg.facet_b3;

    if !(facet1_ok && facet2_ok && facet3_ok) {
        return CapillaryDensityVerdict::Deny;
    }

    // Soft thresholds for ClampAndRetry band.
    let soft_phi_ok = s.phi_tot <= cfg.soft_phi_tot_max;
    let soft_clog_ok = s.clogging_score <= cfg.soft_clogging_score_max;

    if soft_phi_ok && soft_clog_ok {
        CapillaryDensityVerdict::Allow
    } else {
        CapillaryDensityVerdict::ClampAndRetry
    }
}

/// Scalar capillary risk aggregator combining phi_tot and clogging_score
/// into a single normalized microvascular risk band.
///
/// This is a monotone scalar; increasing either input cannot reduce risk.
pub fn capillary_risk_scalar(phi_tot: f32, clogging_score: f32, wd: f32, wc: f32) -> f32 {
    let d = phi_tot.clamp(0.0, 1.0);
    let c = clogging_score.clamp(0.0, 1.0);

    let wd_raw = wd.max(0.0);
    let wc_raw = wc.max(0.0);
    let sum = wd_raw + wc_raw;
    let (alpha_d, alpha_c) = if sum > 0.0 {
        (wd_raw / sum, wc_raw / sum)
    } else {
        (0.5_f32, 0.5_f32)
    };

    let one_minus_d = (1.0_f32 - d).powf(alpha_d);
    let one_minus_c = (1.0_f32 - c).powf(alpha_c);
    1.0_f32 - (one_minus_d * one_minus_c)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn conservative_default_allows_origin() {
        let cfg = CapillaryPolytopeConfig::conservative_default();
        let s = CapillaryDensityState {
            phi_tot: 0.0,
            clogging_score: 0.0,
        };
        let verdict = evaluate_capillary_polytope(&cfg, s);
        assert_eq!(verdict, CapillaryDensityVerdict::Allow);
    }

    #[test]
    fn conservative_default_denies_high_density() {
        let cfg = CapillaryPolytopeConfig::conservative_default();
        let s = CapillaryDensityState {
            phi_tot: 0.3,
            clogging_score: 0.05,
        };
        let verdict = evaluate_capillary_polytope(&cfg, s);
        assert_eq!(verdict, CapillaryDensityVerdict::Deny);
    }

    #[test]
    fn risk_scalar_monotone_in_density() {
        let wd = 0.25_f32;
        let wc = 0.75_f32;
        let c = 0.4_f32;
        let r1 = capillary_risk_scalar(0.1, c, wd, wc);
        let r2 = capillary_risk_scalar(0.2, c, wd, wc);
        assert!(r2 >= r1);
    }

    #[test]
    fn risk_scalar_monotone_in_clogging() {
        let wd = 0.25_f32;
        let wc = 0.75_f32;
        let d = 0.2_f32;
        let r1 = capillary_risk_scalar(d, 0.3, wd, wc);
        let r2 = capillary_risk_scalar(d, 0.6, wd, wc);
        assert!(r2 >= r1);
    }
}
