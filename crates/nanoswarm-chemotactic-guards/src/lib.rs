// Path: crates/nanoswarm-chemotactic-guards/src/lib.rs
#![forbid(unsafe_code)]
#![deny(warnings)]

use core::f32;
use serde::{Deserialize, Serialize};

pub const ALN_MIGRATION_CYBERCORE_AUTHORITY_V1: &str =
    "ALN.MIGRATION.CYBERCOREAUTHORITY.v1";
pub const HOST_DID: &str = "did.aln.bostrom-organic-host";
pub const BOSTROM_ADDRESS: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
pub struct ChemotacticShapeCorridor {
    pub phi_max_major: f32,
    pub phi_max_non_major: f32,
    pub fp_density_ceiling: f32,
    pub v_rips_scale_capillary: f32,
    pub clogging_score_safe_max: f32,
    pub shape_cuff_phi_max_major: f32,
    pub shape_sheet_thickness_max_um: f32,
    pub shape_scaffold_porosity_min: f32,
}

impl ChemotacticShapeCorridor {
    pub const fn default() -> Self {
        Self {
            phi_max_major: 0.025,
            phi_max_non_major: 0.050,
            fp_density_ceiling: 0.050,
            v_rips_scale_capillary: 0.8,
            clogging_score_safe_max: 0.30,
            shape_cuff_phi_max_major: 0.015,
            shape_sheet_thickness_max_um: 30.0,
            shape_scaffold_porosity_min: 0.70,
        }
    }

    pub fn validate(&self) -> bool {
        self.phi_max_major > 0.0
            && self.phi_max_non_major > self.phi_max_major
            && self.fp_density_ceiling > self.phi_max_non_major
            && (self.v_rips_scale_capillary > 0.0 && self.v_rips_scale_capillary <= 1.5)
            && (self.clogging_score_safe_max > 0.0 && self.clogging_score_safe_max <= 1.0)
            && (self.shape_cuff_phi_max_major > 0.0
                && self.shape_cuff_phi_max_major <= self.phi_max_major)
            && (self.shape_sheet_thickness_max_um > 0.0)
            && (self.shape_scaffold_porosity_min > 0.5
                && self.shape_scaffold_porosity_min <= 1.0)
    }
}

#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
pub struct VesselOccupancy {
    pub is_major: bool,
    pub lumen_volume_um3: f32,
    pub swarm_volume_um3: f32,
}

impl VesselOccupancy {
    pub fn phi(&self) -> f32 {
        if self.lumen_volume_um3 <= 0.0 {
            1.0
        } else {
            let raw = self.swarm_volume_um3 / self.lumen_volume_um3;
            if raw < 0.0 {
                0.0
            } else {
                raw
            }
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum NonOcclusionVerdict {
    Allowed,
    Braked,
    Denied,
}

pub fn check_non_occlusion(
    corridor: &ChemotacticShapeCorridor,
    occ: &VesselOccupancy,
) -> NonOcclusionVerdict {
    if !corridor.validate() {
        return NonOcclusionVerdict::Denied;
    }

    let phi = occ.phi();
    if occ.is_major {
        if phi <= corridor.shape_cuff_phi_max_major {
            NonOcclusionVerdict::Allowed
        } else if phi <= corridor.phi_max_major {
            NonOcclusionVerdict::Braked
        } else {
            NonOcclusionVerdict::Denied
        }
    } else {
        if phi <= corridor.phi_max_non_major {
            NonOcclusionVerdict::Allowed
        } else {
            NonOcclusionVerdict::Denied
        }
    }
}

/// Clustering metrics at capillary scale for shape safety checks.
#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
pub struct ClusteringMetrics {
    pub v_rips_scale: f32,
    pub clogging_score: f32,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ShapeSafetyVerdict {
    ShapeSafe,
    ShapeRisk,
    ShapeUnsafe,
}

pub fn check_shape_safety(
    corridor: &ChemotacticShapeCorridor,
    metrics: &ClusteringMetrics,
) -> ShapeSafetyVerdict {
    if !corridor.validate() {
        return ShapeSafetyVerdict::ShapeUnsafe;
    }

    if metrics.v_rips_scale > corridor.v_rips_scale_capillary {
        return ShapeSafetyVerdict::ShapeUnsafe;
    }

    if metrics.clogging_score <= corridor.clogging_score_safe_max {
        ShapeSafetyVerdict::ShapeSafe
    } else if metrics.clogging_score <= 1.0 {
        ShapeSafetyVerdict::ShapeRisk
    } else {
        ShapeSafetyVerdict::ShapeUnsafe
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn corridor_validates() {
        let c = ChemotacticShapeCorridor::default();
        assert!(c.validate());
    }

    #[test]
    fn major_vessel_brake_and_deny() {
        let c = ChemotacticShapeCorridor::default();
        let occ_brake = VesselOccupancy {
            is_major: true,
            lumen_volume_um3: 100.0,
            swarm_volume_um3: 2.0,
        };
        let occ_deny = VesselOccupancy {
            is_major: true,
            lumen_volume_um3: 100.0,
            swarm_volume_um3: 3.0,
        };
        assert_eq!(
            check_non_occlusion(&c, &occ_brake),
            NonOcclusionVerdict::Braked
        );
        assert_eq!(
            check_non_occlusion(&c, &occ_deny),
            NonOcclusionVerdict::Denied
        );
    }

    #[test]
    fn clustering_safe_vs_risky() {
        let c = ChemotacticShapeCorridor::default();
        let m_safe = ClusteringMetrics {
            v_rips_scale: 0.7,
            clogging_score: 0.2,
        };
        let m_risk = ClusteringMetrics {
            v_rips_scale: 0.7,
            clogging_score: 0.6,
        };
        assert_eq!(
            check_shape_safety(&c, &m_safe),
            ShapeSafetyVerdict::ShapeSafe
        );
        assert_eq!(
            check_shape_safety(&c, &m_risk),
            ShapeSafetyVerdict::ShapeRisk
        );
    }
}
