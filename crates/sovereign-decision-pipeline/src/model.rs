// Path: crates/sovereign-decision-pipeline/src/model.rs
#![forbid(unsafe_code)]
#![cfg_attr(not(test), no_std)]

use serde::{Deserialize, Serialize};

/// Overall pipeline decision, integrating all guards.
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum SovereignVerdict {
    AutoAllow,
    RequiresHostedApproval,
    Brake,
    AutoDeny,
}

/// Stage-by-stage diagnostics so callers can inspect which guard fired.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct PipelineDiagnostics {
    pub biocompat_admissible: bool,
    pub biocompat_score: f32,

    pub cognitive_ci: f32,
    pub psych_load_band: PsychLoadBand,
    pub cognitive_verdict: SovereignVerdict,

    pub ota_eligible: bool,
    pub evolution_verdict: EvolutionVerdict,
}

/// Psych-load bands tuned for "pleasant high-load".
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum PsychLoadBand {
    BelowPreferred,
    Preferred,
    AboveComfort,
}

/// Evolution window verdict for longitudinal guard.
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum EvolutionVerdict {
    Allow,
    Brake,
    Deny,
}
