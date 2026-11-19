// crates/nanoswarm-execution-particles/src/dental_stimulation_guard.rs
//
// Dental-cranial stimulation guard skeleton.
// Wires DentalCranialEnvelope and psych envelopes into an execution-time guard
// for neuromodulation in the dental-cranial region.
//
// Edition and licensing are controlled at the crate root (Cargo.toml).
#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]

use core::fmt;

use nanorobotics_core::telemetry_dental::{DentalCranialEnvelope, DentalCranialTelemetry};
use nanorobotics_core::roh_state::{RohWeights, StateVectorBiohost, compute_roh};
use cybernano_physio::lifeforce::LifeforceInputs;

/// Canonical Cybercore migration authority clause.
pub const ALN_MIGRATION_CYBERCORE_AUTHORITY_V1: &str =
    "ALN.MIGRATION.CYBERCOREAUTHORITY.v1";

/// Host DID binding for OrganicCPU.
pub const HOSTDID: &str = "did.aln.bostrom-organic-host";

/// Primary Bostrom address for this host.
pub const BOSTROM_ADDRESS: &str =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

/// Stim duty window in milliseconds used for duty-cycle calculation.
pub type WindowMs = u32;

/// Normalized psych risk scalar in [0, 1], where 1.0 is worst band.
pub type PsychRiskNorm = f32;

/// Guard decision for dental-cranial stimulation.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum DentalStimVerdict {
    /// All guard conditions satisfied; stimulation may proceed.
    Allow,
    /// Guard conditions exceeded, but in a recoverable fashion; clamp and re-evaluate.
    ClampAndRetry,
    /// Hard violation of thermal, duty, psych, or RoH corridors; deny stimulation.
    Deny,
}

/// Error encountered while evaluating the guard.
#[derive(Debug)]
pub enum DentalStimGuardError {
    /// Dental envelope is invalid or inconsistent with its ALN calibration.
    InvalidDentalEnvelope,
    /// Psych risk input is out-of-range or not normalized.
    InvalidPsychRisk,
    /// Risk-of-Harm weights are invalid (do not sum to 1.0).
    InvalidRohWeights,
}

impl fmt::Display for DentalStimGuardError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            DentalStimGuardError::InvalidDentalEnvelope => {
                f.write_str("DentalCranialEnvelope is invalid or inconsistent")
            }
            DentalStimGuardError::InvalidPsychRisk => {
                f.write_str("Psych risk value is invalid or not normalized in [0, 1]")
            }
            DentalStimGuardError::InvalidRohWeights => {
                f.write_str("RoHWeights are invalid (weights must be finite and sum to 1.0)")
            }
        }
    }
}

/// Core configuration extracted from DentalCranialStimulationGuard.v1 ALN shard.
///
/// In a complete implementation this would be deserialized from
/// specs/aln/specs.aln.DentalCranialStimulationGuard.v1.aln.json.
/// For now, this struct provides the strongly-typed shape the runtime guard uses.
#[derive(Clone, Debug)]
pub struct DentalStimGuardConfig {
    pub guard_id: String,
    pub dental_envelope: DentalCranialEnvelope,
    pub roh_weights: RohWeights,
    pub roh_band_max: f64,
    pub thermal_delta_soft_max_c: f32,
    pub thermal_delta_hard_max_c: f32,
    pub dutycycle_soft_max: f32,
    pub dutycycle_hard_max: f32,
    pub window_ms: WindowMs,
    pub psychrisk_soft_max: PsychRiskNorm,
    pub psychrisk_hard_max: PsychRiskNorm,
}

impl DentalStimGuardConfig {
    /// Construct a conservative default guard config from existing ALN shards.
    ///
    /// This function is intentionally explicit and can later be replaced by an
    /// ALN-driven loader.
    pub fn default_conservative() -> Self {
        let dental_envelope = DentalCranialEnvelope::default();
        let roh_weights = RohWeights::default_conservative();
        Self {
            guard_id: "dental-cranial-stim.guard.default.v1".to_string(),
            dental_envelope,
            roh_weights,
            roh_band_max: 0.30,
            thermal_delta_soft_max_c: 0.25,
            thermal_delta_hard_max_c: 0.50,
            dutycycle_soft_max: 0.4,
            dutycycle_hard_max: 0.6,
            window_ms: 60_000,
            psychrisk_soft_max: 0.5,
            psychrisk_hard_max: 0.7,
        }
    }

    /// Validate internal invariants consistent with the ALN shard.
    pub fn validate(&self) -> bool {
        if !self.dental_envelope.validate() {
            return false;
        }
        if !self.roh_weights.validate() {
            return false;
        }
        if !(0.0 <= self.roh_band_max && self.roh_band_max <= 0.30) {
            return false;
        }
        if !(0.0 <= self.thermal_delta_soft_max_c
            && self.thermal_delta_soft_max_c <= self.thermal_delta_hard_max_c)
        {
            return false;
        }
        if !(0.0 <= self.thermal_delta_hard_max_c && self.thermal_delta_hard_max_c <= 2.0) {
            return false;
        }
        if !(0.0 <= self.dutycycle_soft_max
            && self.dutycycle_soft_max <= self.dutycycle_hard_max)
        {
            return false;
        }
        if !(0.0 <= self.dutycycle_hard_max && self.dutycycle_hard_max <= 1.0) {
            return false;
        }
        if !(0.0 <= self.psychrisk_soft_max
            && self.psychrisk_soft_max <= self.psychrisk_hard_max)
        {
            return false;
        }
        if !(0.0 <= self.psychrisk_hard_max && self.psychrisk_hard_max <= 1.0) {
            return false;
        }
        true
    }
}

/// Inputs to the guard at execution time.
#[derive(Clone, Debug)]
pub struct DentalStimGuardInputs {
    /// Current dental-cranial telemetry slice.
    pub dental_telemetry: DentalCranialTelemetry,
    /// Current normalized psych risk in [0, 1], derived from psych envelopes.
    pub psych_risk_norm: PsychRiskNorm,
    /// Current LifeforceInputs to build a RoH state vector (may be shared).
    pub lifeforce_inputs: LifeforceInputs,
    /// Current motion-related normalized axis (e.g. nanoswarm dental motion).
    pub motion_norm: f32,
}

/// Evaluate the dental-cranial stimulation guard.
///
/// This function does not perform IO; it is pure and suitable for Kani verification.
pub fn evaluate_dental_stim_guard(
    cfg: &DentalStimGuardConfig,
    inputs: &DentalStimGuardInputs,
) -> Result<DentalStimVerdict, DentalStimGuardError> {
    if !cfg.dental_envelope.validate() {
        return Err(DentalStimGuardError::InvalidDentalEnvelope);
    }
    if !cfg.roh_weights.validate() {
        return Err(DentalStimGuardError::InvalidRohWeights);
    }
    if !(0.0_f32 <= inputs.psych_risk_norm && inputs.psych_risk_norm <= 1.0_f32) {
        return Err(DentalStimGuardError::InvalidPsychRisk);
    }

    // Thermal deltas and duty-cycle normalization via existing dental envelope helpers.
    let ttissue_c = inputs.dental_telemetry.ttissue_c;
    let delta_t_c = (ttissue_c - cfg.dental_envelope.tbaseline_c).max(0.0);

    // Hard thermal violation: immediate deny.
    if delta_t_c > cfg.thermal_delta_hard_max_c {
        return Ok(DentalStimVerdict::Deny);
    }

    // Duty-cycle hard violation: immediate deny.
    let duty = inputs.dental_telemetry.duty_cycle.clamp(0.0, 1.0);
    if duty > cfg.dutycycle_hard_max {
        return Ok(DentalStimVerdict::Deny);
    }

    // Psych hard violation: immediate deny.
    if inputs.psych_risk_norm > cfg.psychrisk_hard_max {
        return Ok(DentalStimVerdict::Deny);
    }

    // Build normalized dental hazard and map into global RoH state.
    let dental_norm = nanorobotics_core::telemetry_dental::dental_hazard_score(
        cfg.dental_envelope,
        inputs.dental_telemetry,
    )
    .unwrap_or(0.0_f32)
    .clamp(0.0, 1.0);

    // Lifeforce inputs are already in [0, 1] per axis.
    let lf = inputs.lifeforce_inputs;
    let sv = StateVectorBiohost {
        tnorm: lf.tempnorm as f64,          // Thermal axis driven by global core temp.
        atpnorm: lf.atpnorm as f64,        // ATP axis from metabolic power envelope.
        psychnorm: inputs.psych_risk_norm as f64,
        biofilmnorm: lf.biofilmnorm as f64,
        motionnorm: (inputs.motion_norm.max(dental_norm)) as f64,
    };

    let roh = compute_roh(sv, cfg.roh_weights);

    // RoH hard ceiling: deny.
    if roh > cfg.roh_band_max as f64 {
        return Ok(DentalStimVerdict::Deny);
    }

    // Soft clamp logic:
    // - If any soft threshold exceeded but hard not exceeded, return ClampAndRetry.
    let soft_thermal_violation = delta_t_c > cfg.thermal_delta_soft_max_c;
    let soft_duty_violation = duty > cfg.dutycycle_soft_max;
    let soft_psych_violation = inputs.psych_risk_norm > cfg.psychrisk_soft_max;

    if soft_thermal_violation || soft_duty_violation || soft_psych_violation {
        return Ok(DentalStimVerdict::ClampAndRetry);
    }

    Ok(DentalStimVerdict::Allow)
}

#[cfg(test)]
mod tests {
    use super::*;
    use nanorobotics_core::telemetry_dental::DentalCranialTelemetry;

    #[test]
    fn conservative_config_validates() {
        let cfg = DentalStimGuardConfig::default_conservative();
        assert!(cfg.validate());
    }

    #[test]
    fn safe_inputs_allow() {
        let cfg = DentalStimGuardConfig::default_conservative();
        let tel = DentalCranialTelemetry::new(37.05, 5.0, 0.2);
        let lf = LifeforceInputs {
            hrvnorm: 0.2,
            tempnorm: 0.1,
            perfusionnorm: 0.2,
            lactatenorm: 0.1,
            atpnorm: 0.1,
        };
        let inputs = DentalStimGuardInputs {
            dental_telemetry: tel,
            psych_risk_norm: 0.3,
            lifeforce_inputs: lf,
            motion_norm: 0.2,
        };
        let verdict = evaluate_dental_stim_guard(&cfg, &inputs).unwrap();
        assert_eq!(verdict, DentalStimVerdict::Allow);
    }

    #[test]
    fn hard_thermal_violation_denies() {
        let mut cfg = DentalStimGuardConfig::default_conservative();
        cfg.thermal_delta_hard_max_c = 0.5;
        let tel = DentalCranialTelemetry::new(37.8, 5.0, 0.2);
        let lf = LifeforceInputs {
            hrvnorm: 0.2,
            tempnorm: 0.1,
            perfusionnorm: 0.2,
            lactatenorm: 0.1,
            atpnorm: 0.1,
        };
        let inputs = DentalStimGuardInputs {
            dental_telemetry: tel,
            psych_risk_norm: 0.3,
            lifeforce_inputs: lf,
            motion_norm: 0.2,
        };
        let verdict = evaluate_dental_stim_guard(&cfg, &inputs).unwrap();
        assert_eq!(verdict, DentalStimVerdict::Deny);
    }
}
