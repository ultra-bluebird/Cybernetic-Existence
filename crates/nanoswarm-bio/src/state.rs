// File: crates/nanoswarm-bio/src/state.rs
// Destination: mk-bluebird/nanorobotics/crates/nanoswarm-bio/src/state.rs

#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

use crate::material::NanoswarmMaterialFamily;
use crate::profile::{BiocompatibilityProfile, TissueRiskProfile};
use crate::tissue::TissueClass;

/// Nanoswarm state vector for a single tissue corridor, with biocompatibility-aware RoH.[file:44]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NanoswarmStateVector {
    /// Material family used in this swarm.
    pub material_family: NanoswarmMaterialFamily,
    /// Target tissue corridor for this swarm segment.
    pub tissue: TissueClass,
    /// Normalized swarm density in [0, 1] in this tissue.
    pub density: f32,
    /// Local actuation intensity in [0, 1] (duty amplitude summary).
    pub actuation_intensity: f32,
    /// Baseline RoH contribution from swarm dynamics before multipliers.
    pub base_roh: f32,
}

fn clamp01(x: f32) -> f32 {
    if x < 0.0 {
        0.0
    } else if x > 1.0 {
        1.0
    } else {
        x
    }
}

/// Compute a biocompatibility-aware RoH using the material profile.[file:44]
///
/// Returns:
/// - `None` if tissue is disallowed or density exceeds the tissue-specific ceiling.
/// - `Some(roH)` otherwise, with roH in [0, roh_ceiling] when used with guards.
pub fn roh_with_biocompat(
    state: &NanoswarmStateVector,
    profile: &BiocompatibilityProfile,
) -> Option<f32> {
    let tp: TissueRiskProfile = profile.tissue_profile(state.tissue)?;

    // Disallowed tissue corridor ⇒ automatic hard stop.[file:44]
    if !tp.allowed {
        return None;
    }

    let density = clamp01(state.density);
    if density > tp.max_density {
        // Density ceiling breach ⇒ hard stop.[file:44]
        return None;
    }

    // RoH multiplier ≥ 1.0, scaled again by normalized intensity.[file:44]
    let roh_multiplier = tp.roh_multiplier.max(1.0);
    let intensity = clamp01(state.actuation_intensity);
    let base = state.base_roh.max(0.0);

    let roh = base * roh_multiplier * intensity;
    Some(roh)
}
