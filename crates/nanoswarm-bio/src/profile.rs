// File: crates/nanoswarm-bio/src/profile.rs
// Destination: mk-bluebird/nanorobotics/crates/nanoswarm-bio/src/profile.rs

#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

use crate::material::NanoswarmMaterialFamily;
use crate::tissue::TissueClass;

/// Literature-anchored tag, hex-short code pointing into an offline registry.[file:44]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LiteratureTag {
    pub shorthex: String,
    pub description: String,
}

/// Hydrodynamic and thermal coefficients for one material family.[file:44]
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct HydroThermoCoefficients {
    /// Effective hydrodynamic radius in nm.
    pub radius_nm: f32,
    /// Tissue-specific drag coefficient in [0, 1].
    pub drag_coeff: f32,
    /// Thermal coupling coefficient in [0, 1].
    pub thermal_coupling: f32,
}

/// Per-tissue medical risk profile for nanoswarm density and RoH.[file:44]
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct TissueRiskProfile {
    /// True if material is allowed in this tissue corridor.
    pub allowed: bool,
    /// Max normalized swarm density in [0, 1] before hard stop.
    pub max_density: f32,
    /// RoH multiplier ≥ 1.0 for this material–tissue pairing.
    pub roh_multiplier: f32,
}

/// Complete biocompatibility description for a material family.[file:44]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BiocompatibilityProfile {
    pub family: NanoswarmMaterialFamily,
    pub hydro_thermo: HydroThermoCoefficients,
    /// Tissue allowlist and risk profile keyed by TissueClass.
    pub tissue_profiles: Vec<(TissueClass, TissueRiskProfile)>,
    /// Evidence-anchored tags (short hex and description); typically 10 tags.[file:44]
    pub literature_tags: Vec<LiteratureTag>,
}

impl BiocompatibilityProfile {
    /// Look up the tissue-specific risk profile, if present.[file:44]
    pub fn tissue_profile(&self, tissue: TissueClass) -> Option<TissueRiskProfile> {
        self.tissue_profiles
            .iter()
            .find(|(t, _)| *t == tissue)
            .map(|(_, p)| *p)
    }
}
