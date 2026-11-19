// crates/nanorobotics-fp/src/lymphatic_clearance_envelope.rs

#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]

use serde::{Deserialize, Serialize};

pub const ALN_MIGRATION_CYBERCORE_AUTHORITY_V1: &str =
    "ALN.MIGRATION.CYBERCOREAUTHORITY.v1";
pub const HOST_DID: &str = "did.aln.bostrom-organic-host";
pub const BOSTROM_ADDRESS: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

/// Normalized lymphatic swarm state.
///
/// All scalars are in [0.0, 1.0] bands, mapped from physical units upstream.
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq)]
pub struct LymphaticSwarmState {
    /// Normalized swarm concentration in thoracic duct.
    pub c_thoracic: f32,
    /// Normalized swarm concentration in cervical lymph nodes.
    pub c_cervical: f32,
    /// Normalized lymphatic residence time.
    pub t_lymph_res: f32,
    /// Normalized lymph flow rate.
    pub q_lymph: f32,
}

impl LymphaticSwarmState {
    pub fn clamped(self) -> Self {
        Self {
            c_thoracic: self.c_thoracic.clamp(0.0, 1.0),
            c_cervical: self.c_cervical.clamp(0.0, 1.0),
            t_lymph_res: self.t_lymph_res.clamp(0.0, 1.0),
            q_lymph: self.q_lymph.clamp(0.0, 1.0),
        }
    }
}

/// Verdict for lymphatic clearance envelope.
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum LymphaticClearanceVerdict {
    Allow,
    ClampAndRetry,
    Deny,
}

/// Envelope configuration for lymphatic swarm clearance.
///
/// All thresholds are normalized 0.0–1.0 bands; mapping from physical
/// values (concentration, residence time, flow) into these bands
/// is performed by telemetry adapters.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct LymphaticClearanceEnvelope {
    pub c_thoracic_max: f32,
    pub c_cervical_max: f32,
    pub t_lymph_res_max: f32,
    pub q_lymph_min: f32,
    pub soft_c_thoracic_max: f32,
    pub soft_c_cervical_max: f32,
    pub soft_t_lymph_res_max: f32,
}

impl LymphaticClearanceEnvelope {
    /// Conservative default envelope for lymphatic clearance.
    pub fn conservative_default() -> Self {
        Self {
            c_thoracic_max: 0.30,
            c_cervical_max: 0.25,
            t_lymph_res_max: 0.40,
            q_lymph_min: 0.20,
            soft_c_thoracic_max: 0.20,
            soft_c_cervical_max: 0.15,
            soft_t_lymph_res_max: 0.30,
        }
    }

    pub fn clamped(self) -> Self {
        Self {
            c_thoracic_max: self.c_thoracic_max.clamp(0.0, 1.0),
            c_cervical_max: self.c_cervical_max.clamp(0.0, 1.0),
            t_lymph_res_max: self.t_lymph_res_max.clamp(0.0, 1.0),
            q_lymph_min: self.q_lymph_min.clamp(0.0, 1.0),
            soft_c_thoracic_max: self.soft_c_thoracic_max.clamp(0.0, 1.0),
            soft_c_cervical_max: self.soft_c_cervical_max.clamp(0.0, 1.0),
            soft_t_lymph_res_max: self.soft_t_lymph_res_max.clamp(0.0, 1.0),
        }
    }
}

/// Evaluate the lymphatic clearance envelope for a given state.
///
/// Returns:
/// - Deny if any hard threshold is violated.
/// - ClampAndRetry if within hard bounds but outside soft bounds.
/// - Allow if comfortably inside soft bounds.
pub fn evaluate_lymphatic_clearance(
    env: &LymphaticClearanceEnvelope,
    state: LymphaticSwarmState,
) -> LymphaticClearanceVerdict {
    let env = env.clamped();
    let s = state.clamped();

    // Hard ceilings on concentrations.
    if s.c_thoracic > env.c_thoracic_max {
        return LymphaticClearanceVerdict::Deny;
    }
    if s.c_cervical > env.c_cervical_max {
        return LymphaticClearanceVerdict::Deny;
    }

    // Hard ceiling on residence time.
    if s.t_lymph_res > env.t_lymph_res_max {
        return LymphaticClearanceVerdict::Deny;
    }

    // Hard floor on lymph flow; too low flow implies stagnation.
    if s.q_lymph < env.q_lymph_min {
        return LymphaticClearanceVerdict::Deny;
    }

    // Soft band for ClampAndRetry.
    let soft_thoracic_ok = s.c_thoracic <= env.soft_c_thoracic_max;
    let soft_cervical_ok = s.c_cervical <= env.soft_c_cervical_max;
    let soft_res_ok = s.t_lymph_res <= env.soft_t_lymph_res_max;

    if soft_thoracic_ok && soft_cervical_ok && soft_res_ok {
        LymphaticClearanceVerdict::Allow
    } else {
        LymphaticClearanceVerdict::ClampAndRetry
    }
}

/// Map lymphatic clearance state into a normalized RoH axis contribution.
///
/// This scalar can be plugged into the global RoH kernel as a dedicated
/// lymphatic load axis.
///
/// The mapping is monotone: increasing concentrations or residence time
/// or decreasing flow cannot reduce risk.
pub fn lymphatic_risk_scalar(state: LymphaticSwarmState) -> f32 {
    let s = state.clamped();

    let c_th = s.c_thoracic;
    let c_ce = s.c_cervical;
    let t_res = s.t_lymph_res;
    let q = s.q_lymph;

    // Simple convex combination of normalized stressors.
    let load = 0.4_f32 * c_th + 0.3_f32 * c_ce + 0.3_f32 * t_res;
    let flow_penalty = (1.0_f32 - q).max(0.0);

    let raw = load + 0.5_f32 * flow_penalty;
    raw.clamp(0.0, 1.0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn conservative_default_allows_low_state() {
        let env = LymphaticClearanceEnvelope::conservative_default();
        let state = LymphaticSwarmState {
            c_thoracic: 0.10,
            c_cervical: 0.08,
            t_lymph_res: 0.20,
            q_lymph: 0.50,
        };
        let verdict = evaluate_lymphatic_clearance(&env, state);
        assert_eq!(verdict, LymphaticClearanceVerdict::Allow);
    }

    #[test]
    fn conservative_default_denies_high_concentration() {
        let env = LymphaticClearanceEnvelope::conservative_default();
        let state = LymphaticSwarmState {
            c_thoracic: 0.40,
            c_cervical: 0.10,
            t_lymph_res: 0.20,
            q_lymph: 0.50,
        };
        let verdict = evaluate_lymphatic_clearance(&env, state);
        assert_eq!(verdict, LymphaticClearanceVerdict::Deny);
    }

    #[test]
    fn lymphatic_risk_scalar_monotone_in_concentration() {
        let s1 = LymphaticSwarmState {
            c_thoracic: 0.10,
            c_cervical: 0.10,
            t_lymph_res: 0.20,
            q_lymph: 0.50,
        };
        let s2 = LymphaticSwarmState {
            c_thoracic: 0.30,
            c_cervical: 0.10,
            t_lymph_res: 0.20,
            q_lymph: 0.50,
        };
        let r1 = lymphatic_risk_scalar(s1);
        let r2 = lymphatic_risk_scalar(s2);
        assert!(r2 >= r1);
    }

    #[test]
    fn lymphatic_risk_scalar_monotone_in_flow_penalty() {
        let s1 = LymphaticSwarmState {
            c_thoracic: 0.10,
            c_cervical: 0.10,
            t_lymph_res: 0.20,
            q_lymph: 0.80,
        };
        let s2 = LymphaticSwarmState {
            c_thoracic: 0.10,
            c_cervical: 0.10,
            t_lymph_res: 0.20,
            q_lymph: 0.30,
        };
        let r1 = lymphatic_risk_scalar(s1);
        let r2 = lymphatic_risk_scalar(s2);
        assert!(r2 >= r1);
    }
}
