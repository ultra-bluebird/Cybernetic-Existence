// Path: crates/psychcaps-core/src/psychosis_risk.rs
//
// Rust mirror of analysis/matlab/psychosis_risk_cybernetics_v1.m.
// All inputs are normalized or bounded to [0,1] as in your psych lattice. [file:3]

#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]

use core::fmt;

/// Canonical authority marker for Cybercore.
pub const ALN_MIGRATION_CYBERCORE_AUTHORITY_V1: &str =
    "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";

pub const HOST_DID: &str = "OrganicCPU";
pub const BOSTROM_ADDRESS: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

/// Normalized psych/physio inputs for psychosis risk.
///
/// These are all in [0,1], consistent with PsychCaps and NeurorightsMicroshield
/// patterns: 0 = fully safe / absent, 1 = maximal observed severity. [file:3]
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct PsychosisInputsNorm {
    pub pain: f64,          // normalized pain
    pub anxiety: f64,       // fear / anxiety
    pub cog_load: f64,      // cognitive load
    pub identity_disr: f64, // identity disruption / dissociation
    pub halluc: f64,        // hallucinations
    pub delusion: f64,      // delusions
    pub sleep_depr: f64,    // sleep deprivation
    pub stress: f64,        // stress / cortisol surrogate
    pub mania: f64,         // mania / agitation
}

impl PsychosisInputsNorm {
    pub fn new(
        pain: f64,
        anxiety: f64,
        cog_load: f64,
        identity_disr: f64,
        halluc: f64,
        delusion: f64,
        sleep_depr: f64,
        stress: f64,
        mania: f64,
    ) -> Option<Self> {
        let vals = [
            pain,
            anxiety,
            cog_load,
            identity_disr,
            halluc,
            delusion,
            sleep_depr,
            stress,
            mania,
        ];
        if vals.iter().all(|v| v.is_finite() && *v >= 0.0 && *v <= 1.0) {
            Some(Self {
                pain,
                anxiety,
                cog_load,
                identity_disr,
                halluc,
                delusion,
                sleep_depr,
                stress,
                mania,
            })
        } else {
            None
        }
    }
}

/// Risk components (all in [0,1]).
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct PsychosisComponents {
    pub r_positive: f64,
    pub r_identity: f64,
    pub r_affective: f64,
    pub r_sleep: f64,
    pub r_pain_cog: f64,
}

/// Scalar and 3-axis projection result.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct PsychosisRisk {
    pub r_psychosis: f64,          // scalar risk in [0,1]
    pub r_thought: f64,            // thought disorder axis
    pub r_affective: f64,          // affective axis
    pub r_identity_axis: f64,      // identity axis
}

/// Configuration parameters; keep simple and host-tunable. [file:3]
#[derive(Clone, Copy, Debug)]
pub struct PsychosisRiskParams {
    pub exp_positive: f64,
    pub exp_identity: f64,
    pub exp_affective: f64,
    pub exp_sleep: f64,
    // aggregation weights (must sum to 1.0)
    pub w_thought: f64,
    pub w_identity: f64,
    pub w_affective: f64,
    pub w_sleep: f64,
    pub w_pain_cog: f64,
    // projection weights to 3-axis vector
    pub w_thought_from_positive: f64,
    pub w_thought_from_cog: f64,
    pub w_aff_from_affective: f64,
    pub w_aff_from_sleep: f64,
    pub w_id_from_identity: f64,
}

impl PsychosisRiskParams {
    pub fn conservative_default() -> Self {
        Self {
            exp_positive: 2.0,
            exp_identity: 2.0,
            exp_affective: 2.0,
            exp_sleep: 2.0,
            // aggregation weights
            w_thought: 0.40,
            w_identity: 0.20,
            w_affective: 0.20,
            w_sleep: 0.10,
            w_pain_cog: 0.10,
            // projection weights
            w_thought_from_positive: 0.7,
            w_thought_from_cog: 0.3,
            w_aff_from_affective: 0.8,
            w_aff_from_sleep: 0.2,
            w_id_from_identity: 1.0,
        }
    }

    pub fn validate(&self) -> bool {
        let ws = [
            self.w_thought,
            self.w_identity,
            self.w_affective,
            self.w_sleep,
            self.w_pain_cog,
        ];
        if !ws.iter().all(|w| w.is_finite() && *w >= 0.0) {
            return false;
        }
        let sum = ws.iter().sum::<f64>();
        (sum - 1.0).abs() <= 1e-9
            && self.exp_positive >= 1.0
            && self.exp_identity >= 1.0
            && self.exp_affective >= 1.0
            && self.exp_sleep >= 1.0
    }
}

/// Errors for psychosis risk evaluation.
#[derive(Debug)]
pub enum PsychosisRiskError {
    InvalidInputs,
    InvalidParams,
}

impl fmt::Display for PsychosisRiskError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            PsychosisRiskError::InvalidInputs => f.write_str("PsychosisInputsNorm invalid"),
            PsychosisRiskError::InvalidParams => f.write_str("PsychosisRiskParams invalid"),
        }
    }
}

fn pow_convex(x: f64, exp: f64) -> f64 {
    debug_assert!(x >= 0.0 && x <= 1.0);
    debug_assert!(exp >= 1.0);
    x.powf(exp)
}

/// Compute component risks. [file:3]
pub fn component_risks(
    inputs: PsychosisInputsNorm,
    params: PsychosisRiskParams,
) -> Result<PsychosisComponents, PsychosisRiskError> {
    if !params.validate() {
        return Err(PsychosisRiskError::InvalidParams);
    }

    let pos = 0.5 * (inputs.halluc + inputs.delusion);
    let r_positive = pow_convex(pos, params.exp_positive);

    let r_identity = pow_convex(inputs.identity_disr, params.exp_identity);

    let aff = (inputs.anxiety + inputs.stress + inputs.mania) / 3.0;
    let r_affective = pow_convex(aff, params.exp_affective);

    let r_sleep = pow_convex(inputs.sleep_depr, params.exp_sleep);

    let pain_cog = (inputs.pain + inputs.cog_load) / 2.0;
    let r_pain_cog = pow_convex(pain_cog, params.exp_positive);

    Ok(PsychosisComponents {
        r_positive,
        r_identity,
        r_affective,
        r_sleep,
        r_pain_cog,
    })
}

/// Aggregate into scalar R_psychosis and 3-axis projection. [file:3]
pub fn compute_psychosis_risk(
    inputs: PsychosisInputsNorm,
    params: PsychosisRiskParams,
) -> Result<PsychosisRisk, PsychosisRiskError> {
    if !params.validate() {
        return Err(PsychosisRiskError::InvalidParams);
    }

    let comps = component_risks(inputs, params)?;

    let w = &params;
    let mut r_psy = w.w_thought * comps.r_positive
        + w.w_identity * comps.r_identity
        + w.w_affective * comps.r_affective
        + w.w_sleep * comps.r_sleep
        + w.w_pain_cog * comps.r_pain_cog;

    if r_psy < 0.0 {
        r_psy = 0.0;
    } else if r_psy > 1.0 {
        r_psy = 1.0;
    }

    // Thought axis
    let mut r_thought = params.w_thought_from_positive * comps.r_positive
        + params.w_thought_from_cog * comps.r_pain_cog;

    // Affective axis
    let mut r_aff = params.w_aff_from_affective * comps.r_affective
        + params.w_aff_from_sleep * comps.r_sleep;

    // Identity axis
    let mut r_id = params.w_id_from_identity * comps.r_identity;

    for r in [&mut r_thought, &mut r_aff, &mut r_id] {
        if **r < 0.0 {
            **r = 0.0;
        } else if **r > 1.0 {
            **r = 1.0;
        }
    }

    Ok(PsychosisRisk {
        r_psychosis: r_psy,
        r_thought,
        r_affective: r_aff,
        r_identity_axis: r_id,
    })
}

/// Convenience wrapper using conservative defaults.
pub fn compute_psychosis_risk_default(
    inputs: PsychosisInputsNorm,
) -> Result<PsychosisRisk, PsychosisRiskError> {
    compute_psychosis_risk(inputs, PsychosisRiskParams::conservative_default())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn params_validate_and_weights_sum_to_one() {
        let p = PsychosisRiskParams::conservative_default();
        assert!(p.validate());
        let sum = p.w_thought + p.w_identity + p.w_affective + p.w_sleep + p.w_pain_cog;
        assert!((sum - 1.0).abs() < 1e-9);
    }

    #[test]
    fn zero_inputs_yield_low_risk() {
        let inputs = PsychosisInputsNorm::new(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0).unwrap();
        let r = compute_psychosis_risk_default(inputs).unwrap();
        assert!(r.r_psychosis >= 0.0 && r.r_psychosis <= 0.3);
    }

    #[test]
    fn max_inputs_yield_high_risk() {
        let inputs = PsychosisInputsNorm::new(1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0).unwrap();
        let r = compute_psychosis_risk_default(inputs).unwrap();
        assert!(r.r_psychosis > 0.7);
    }
}
