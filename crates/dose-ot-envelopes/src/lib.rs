#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]

//! Optimal-transport dose envelopes and RoH coupling for vascular corridors.
//! This crate is intended to be used by tumor and portal-hepatic planners.

pub const ALN_MIGRATION_CYBERCORE_AUTHORITY_V1: &str =
    "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";
pub const HOST_DID: &str = "did.aln.bostrom-organic-host";
pub const BOSTROM_ADDRESS: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

use serde::{Deserialize, Serialize};

/// Corridor-local dose fractions from an OT plan.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct CorridorDoseFractions {
    /// Fraction of total dose entering this corridor.
    pub corridor_fraction: f32,
    /// Maximum voxel fraction in any voxel of this corridor.
    pub max_voxel_fraction: f32,
}

/// Envelope configuration for an OT dose plan.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct DoseOtEnvelope {
    /// Maximum allowed fraction of total dose per corridor.
    pub max_corridor_fraction: f32,
    /// Maximum allowed fraction in any voxel of the corridor.
    pub max_voxel_fraction: f32,
}

impl DoseOtEnvelope {
    pub fn validate(&self) -> bool {
        (self.max_corridor_fraction >= 0.0_f32)
            && (self.max_corridor_fraction <= 1.0_f32)
            && (self.max_voxel_fraction >= 0.0_f32)
            && (self.max_voxel_fraction <= 1.0_f32)
    }
}

/// Local risk scalar derived from dose fractions in a corridor.
/// This should be mapped into the density/material axes of the unified RoH kernel.
pub fn density_material_risk(
    env: &DoseOtEnvelope,
    fractions: &CorridorDoseFractions,
) -> f32 {
    if !env.validate() {
        return 1.0_f32;
    }

    let f_c = if env.max_corridor_fraction > 0.0_f32 {
        fractions.corridor_fraction / env.max_corridor_fraction
    } else {
        0.0_f32
    };

    let f_v = if env.max_voxel_fraction > 0.0_f32 {
        fractions.max_voxel_fraction / env.max_voxel_fraction
    } else {
        0.0_f32
    };

    let r_c = f_c.max(0.0_f32);
    let r_v = f_v.max(0.0_f32);

    (r_c + r_v) * 0.5_f32
}
