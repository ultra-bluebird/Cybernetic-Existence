// Path: crates/sovereign-decision-pipeline/src/lib.rs
#![forbid(unsafe_code)]
#![cfg_attr(not(test), no_std)]

pub mod snapshot;
pub mod model;

use crate::model::{EvolutionVerdict, PipelineDiagnostics, PsychLoadBand, SovereignVerdict};
use crate::snapshot::{
    BiocompatibilityWeights, TelemetrySnapshot, GLOBAL_ROH_CEILING, LIFEFORCE_MARGIN_MIN,
};
use serde::{Deserialize, Serialize};

/// Host profile for CognitiveCandy guard.
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq)]
pub struct CognitiveCandyHostProfile {
    pub alpha_psych_risk: f32,
    pub roh_ceiling: f32,
    pub psych_load_floor: f32,
    pub psych_load_comfort_max: f32,
}

/// Inputs specific to a single CognitiveCandy evaluation.
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq)]
pub struct CognitiveCandyInput {
    pub ri_neurorights: f32,
    pub pi_psych_risk: f32,
    pub roh_i_increment: f32,
    pub psych_load_level: f32,
    pub lifeforce_ok: bool,
    pub neurorights_ok: bool,
}

/// OTA thresholds for LifeforceOtaGuard.
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq)]
pub struct LifeforceOtaThresholds {
    pub lifeforce_floor: f32,
    pub blood_floor: f32,
    pub protein_floor: f32,
}

/// Simple OTA verdict.
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum OtaEligibilityVerdict {
    Eligible,
    RejectedLifeforceFloor,
    RejectedBloodFloor,
    RejectedProteinFloor,
    RejectedAuthorityBinding,
}

/// Convenience wrapper joining host profile and OTA thresholds.
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq)]
pub struct PipelineConfig {
    pub candy_profile: CognitiveCandyHostProfile,
    pub ota_thresholds: LifeforceOtaThresholds,
}

/// Biocompatibility score with explicit admissible flag.
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq)]
pub struct BiocompatibilityScore {
    pub value: f32,
    pub admissible: bool,
}

impl BiocompatibilityScore {
    pub fn compute(
        ten_tags: &snapshot::TenTagBundle,
        weights: &BiocompatibilityWeights,
        roh_scalar: f32,
        lifeforce_scalar: f32,
        lifeforce_floor: f32,
    ) -> Self {
        // If weights are not normalized, fail closed.
        if !weights.is_normalized(1e-3) {
            return Self {
                value: 0.0,
                admissible: false,
            };
        }

        // Here we assume normalized penalties in [0, 1] already embedded in ten_tags
        // via prior normalization against HostNormCorridor. Production code can
        // substitute real penalty math without changing invariants.
        let penalties = [
            ten_tags.cns_delta_t,
            ten_tags.mito_delta_psi,
            ten_tags.nad_ratio,
            ten_tags.hrv_ms,
            ten_tags.s_resp,
            ten_tags.il6_pg_ml,
            ten_tags.r_neuro,
            ten_tags.h_env,
            ten_tags.microcooler_duty,
            ten_tags.eco_budget,
        ];

        let ws = [
            weights.w_cns_delta_t,
            weights.w_mito_delta_psi,
            weights.w_nad_ratio,
            weights.w_hrv_ms,
            weights.w_s_resp,
            weights.w_il6_pg_ml,
            weights.w_r_neuro,
            weights.w_h_env,
            weights.w_microcooler_duty,
            weights.w_eco_budget,
        ];

        let mut penalty_sum = 0.0f32;
        for i in 0..10 {
            penalty_sum += ws[i] * penalties[i].clamp(0.0, 1.0);
        }

        let raw = 1.0 - penalty_sum;
        let value = raw.clamp(0.0, 1.0);

        let roh_ok = roh_scalar <= GLOBAL_ROH_CEILING;
        let margin_ok = lifeforce_scalar >= lifeforce_floor + LIFEFORCE_MARGIN_MIN;
        let score_ok = value >= 0.70;

        Self {
            value,
            admissible: score_ok && roh_ok && margin_ok,
        }
    }
}

fn classify_psych_load(level: f32, floor: f32, comfort_max: f32) -> PsychLoadBand {
    if level < floor {
        PsychLoadBand::BelowPreferred
    } else if level <= comfort_max {
        PsychLoadBand::Preferred
    } else {
        PsychLoadBand::AboveComfort
    }
}

/// CognitiveCandy core: C_i = R_i - P_i - alpha * RoH_i.
fn evaluate_cognitive_candy(
    profile: &CognitiveCandyHostProfile,
    input: &CognitiveCandyInput,
) -> (SovereignVerdict, f32, PsychLoadBand) {
    // Hard veto on corridors and RoH ceiling.
    if !input.lifeforce_ok || !input.neurorights_ok {
        return (SovereignVerdict::AutoDeny, 0.0, PsychLoadBand::BelowPreferred);
    }
    if input.roh_i_increment > profile.roh_ceiling {
        return (SovereignVerdict::AutoDeny, 0.0, PsychLoadBand::BelowPreferred);
    }

    let ci = input.ri_neurorights - input.pi_psych_risk - profile.alpha_psych_risk * input.roh_i_increment;
    let band = classify_psych_load(
        input.psych_load_level,
        profile.psych_load_floor,
        profile.psych_load_comfort_max,
    );

    let verdict = match band {
        PsychLoadBand::Preferred => {
            if ci >= 0.0 {
                SovereignVerdict::AutoAllow
            } else {
                SovereignVerdict::RequiresHostedApproval
            }
        }
        PsychLoadBand::BelowPreferred => {
            if ci >= 0.0 {
                // Helpful stimulation into preferred band.
                SovereignVerdict::RequiresHostedApproval
            } else {
                SovereignVerdict::AutoDeny
            }
        }
        PsychLoadBand::AboveComfort => {
            if ci >= 0.0 {
                SovereignVerdict::RequiresHostedApproval
            } else {
                SovereignVerdict::AutoDeny
            }
        }
    };

    (verdict, ci, band)
}

fn evaluate_ota_eligibility(
    thresholds: &LifeforceOtaThresholds,
    snapshot: &snapshot::TelemetrySnapshot,
) -> OtaEligibilityVerdict {
    if snapshot.resources.lifeforce_scalar < thresholds.lifeforce_floor {
        return OtaEligibilityVerdict::RejectedLifeforceFloor;
    }
    if snapshot.resources.blood_scalar < thresholds.blood_floor {
        return OtaEligibilityVerdict::RejectedBloodFloor;
    }
    if snapshot.resources.protein_scalar < thresholds.protein_floor {
        return OtaEligibilityVerdict::RejectedProteinFloor;
    }
    if !snapshot.is_canonical_host() {
        return OtaEligibilityVerdict::RejectedAuthorityBinding;
    }
    OtaEligibilityVerdict::Eligible
}

fn evolution_window_guard(
    prev: &snapshot::EvolutionMetrics,
    next: &snapshot::EvolutionMetrics,
    roh_ceiling: f32,
) -> EvolutionVerdict {
    if next.roh > roh_ceiling {
        return EvolutionVerdict::Deny;
    }
    let kf_delta = next.kf - prev.kf;
    let c_delta = next.continuity - prev.continuity;

    if kf_delta >= 0.01 && c_delta >= 0.01 {
        EvolutionVerdict::Allow
    } else {
        EvolutionVerdict::Brake
    }
}

/// Unified evaluation: Biocompat → CognitiveCandy → OTA/Evolution.
///
/// This is the function that higher-level routers (e.g., SovereignNeuralRope)
/// should call when deciding whether to admit a host-critical actuation.
pub fn evaluate_pipeline(
    cfg: &PipelineConfig,
    telemetry: &TelemetrySnapshot,
    candy_input: &CognitiveCandyInput,
) -> (SovereignVerdict, PipelineDiagnostics) {
    // Stage 1: Healthcare Biocompatibility Guard.
    let biocompat =
        BiocompatibilityScore::compute(
            &telemetry.ten_tags,
            &telemetry.biocompat_weights,
            telemetry.roh_scalar,
            telemetry.lifeforce_scalar,
            telemetry.lifeforce_floor,
        );

    if !biocompat.admissible {
        return (
            SovereignVerdict::AutoDeny,
            PipelineDiagnostics {
                biocompat_admissible: false,
                biocompat_score: biocompat.value,
                cognitive_ci: 0.0,
                psych_load_band: PsychLoadBand::BelowPreferred,
                cognitive_verdict: SovereignVerdict::AutoDeny,
                ota_eligible: false,
                evolution_verdict: EvolutionVerdict::Deny,
            },
        );
    }

    // Stage 2: CognitiveCandy Guard.
    let (cog_verdict, ci, band) = evaluate_cognitive_candy(&cfg.candy_profile, candy_input);

    if matches!(cog_verdict, SovereignVerdict::AutoDeny) {
        return (
            SovereignVerdict::AutoDeny,
            PipelineDiagnostics {
                biocompat_admissible: true,
                biocompat_score: biocompat.value,
                cognitive_ci: ci,
                psych_load_band: band,
                cognitive_verdict: cog_verdict,
                ota_eligible: false,
                evolution_verdict: EvolutionVerdict::Deny,
            },
        );
    }

    // Stage 3a: Lifeforce OTA Guard.
    let ota_verdict = evaluate_ota_eligibility(&cfg.ota_thresholds, telemetry);
    if !matches!(ota_verdict, OtaEligibilityVerdict::Eligible) {
        return (
            SovereignVerdict::AutoDeny,
            PipelineDiagnostics {
                biocompat_admissible: true,
                biocompat_score: biocompat.value,
                cognitive_ci: ci,
                psych_load_band: band,
                cognitive_verdict: cog_verdict,
                ota_eligible: false,
                evolution_verdict: EvolutionVerdict::Deny,
            },
        );
    }

    // Stage 3b: Evolution Window Guard.
    let evo_verdict = evolution_window_guard(
        &telemetry.prev_evolution,
        &telemetry.next_evolution,
        GLOBAL_ROH_CEILING,
    );

    let final_verdict = match (cog_verdict, evo_verdict) {
        // Any hard deny at longitudinal layer stays deny.
        (_, EvolutionVerdict::Deny) => SovereignVerdict::AutoDeny,
        // Brake dominates HostedApproval and AutoAllow.
        (SovereignVerdict::AutoAllow, EvolutionVerdict::Brake)
        | (SovereignVerdict::RequiresHostedApproval, EvolutionVerdict::Brake) => {
            SovereignVerdict::Brake
        }
        // Pure cognitive decision if evolution is Allow.
        (v, EvolutionVerdict::Allow) => v,
    };

    (
        final_verdict,
        PipelineDiagnostics {
            biocompat_admissible: true,
            biocompat_score: biocompat.value,
            cognitive_ci: ci,
            psych_load_band: band,
            cognitive_verdict: cog_verdict,
            ota_eligible: true,
            evolution_verdict: evo_verdict,
        },
    )
}
