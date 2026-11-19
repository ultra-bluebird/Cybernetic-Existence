// File: crates/nanoswarm-bio/src/biotensor.rs
// Destination: mk-bluebird/nanorobotics/crates/nanoswarm-bio/src/biotensor.rs

#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

/// Tissue classes for nanoswarm interactions.
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum TissueKind {
    Brain,
    Vascular,
    Dermal,
    Dental,
    Hepatic,
    Renal,
    Cardiac,
}

/// Nanoswarm material classes informed by current nanorobotics literature:
/// stimuli-responsive polymers, magnetic swimmers, biohybrids, etc.
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum MaterialClass {
    StimuliResponsivePolymer,
    MagneticSwimmer,
    Biohybrid,
    MetallicMicrobot,
    BioresorbablePolymer,
}

/// Propulsion modes, as used in medical nanorobotics surveys.
#[derive(Clone, Copy, Debug, Serialize, Deserialize, PartialEq, Eq)]
pub enum PropulsionMode {
    Chemical,
    Magnetic,
    Acoustic,
    FlowDriven,
    Mixed,
}

/// Local biophysical context for a tissue region.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct LocalBiophysics {
    /// Normalized CNS or local tissue temperature in [0, 1],
    /// where 0.0 = baseline, 1.0 = upper corridor edge.
    pub temp_norm: f32,
    /// Inflammation marker scalar in [0, 1] from IL-6/CRP bands.
    pub inflammation_norm: f32,
    /// HRV band scalar in [0, 1] (higher = better HRV).
    pub hrv_norm: f32,
}

/// Biocompatibility tensor entry s ∈ [0, 1] for one configuration.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct BiocompatibilityTensorEntry {
    pub tissue: TissueKind,
    pub material: MaterialClass,
    pub propulsion: PropulsionMode,
    pub context: LocalBiophysics,
    /// Scalar score in [0, 1], feeding BiocompatibilityScore and ALN shards.
    pub score: f32,
}

impl BiocompatibilityTensorEntry {
    /// Simple conservative scoring function:
    /// - Penalize high temperature and inflammation.
    /// - Reward higher HRV (within corridor).
    /// - Adjust baseline per tissue/material combination.
    pub fn compute_score(&mut self) {
        let t = self.context.temp_norm.clamp(0.0, 1.0);
        let infl = self.context.inflammation_norm.clamp(0.0, 1.0);
        let hrv = self.context.hrv_norm.clamp(0.0, 1.0);

        // Baseline per tissue/material.
        let baseline = match (self.tissue, self.material) {
            (TissueKind::Brain, MaterialClass::BioresorbablePolymer) => 0.85,
            (TissueKind::Brain, _) => 0.75,
            (TissueKind::Vascular, MaterialClass::MagneticSwimmer) => 0.80,
            (TissueKind::Vascular, _) => 0.70,
            (TissueKind::Dermal, _) => 0.80,
            (TissueKind::Dental, _) => 0.65,
            (TissueKind::Hepatic, _) => 0.70,
            (TissueKind::Renal, _) => 0.70,
            (TissueKind::Cardiac, _) => 0.75,
        };

        // Temperature penalty: up to -0.20 at corridor edge.
        let temp_penalty = 0.20 * t;
        // Inflammation penalty: up to -0.25 at maximum inflammation.
        let infl_penalty = 0.25 * infl;
        // HRV reward: up to +0.10 at best HRV.
        let hrv_reward = 0.10 * hrv;

        let s = baseline - temp_penalty - infl_penalty + hrv_reward;
        self.score = s.clamp(0.0, 1.0);
    }
}
