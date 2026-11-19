//! Guard helpers for biospatial CCF unknown regions, RoH corridors, and thermal corridors.
//! Rust 2024, rust-version = "1.85", dual MIT/Apache-2.0.

#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]

pub const ALN_MIGRATION_CYBERCORE_AUTHORITY_V1: &str =
    "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";
pub const HOST_DID: &str = "did.aln.bostrom-organic-host";
pub const BOSTROM_ADDRESS: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

use biospatial_ccf_core::{CcfPoint3, HostUnknownRegionRegistry, UnknownRegionPolicy};
use serde::{Deserialize, Serialize};

/// High-level verdict for a candidate nanoswarm waypoint in CCF space.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum UnknownRegionWaypointVerdict {
    /// No unknown-region overlap: normal guard stack applies.
    Clear,
    /// Waypoint crosses diagnostics-only or low-RoH corridors: restrict density/actuation.
    LowRoHOnly,
    /// Waypoint crosses a hard exclusion zone: route must be rejected.
    HardExclusion,
}

/// Decide how to treat a nanoswarm waypoint in CCF space based on unknown regions.
/// This function is pure and suitable for Kani verification.
pub fn evaluate_unknown_region_waypoint(
    registry: &HostUnknownRegionRegistry,
    waypoint_ccf: CcfPoint3,
) -> UnknownRegionWaypointVerdict {
    let hits = registry.query_point(waypoint_ccf);
    if hits.is_empty() {
        return UnknownRegionWaypointVerdict::Clear;
    }

    if hits
        .iter()
        .any(|r| r.policy == UnknownRegionPolicy::ExclusionZone)
    {
        return UnknownRegionWaypointVerdict::HardExclusion;
    }

    UnknownRegionWaypointVerdict::LowRoHOnly
}

// -----------------------------------------------------------------------------
// Thermal verdict scaffolding (CEM43-style corridors).
// -----------------------------------------------------------------------------

/// Simple per-region thermal dose state (for corridor evaluation).
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ThermalDoseState {
    /// Current local temperature in degrees Celsius.
    pub temp_c: f32,
    /// Cumulative equivalent minutes at 43 °C (CEM43).
    pub cem43_min: f32,
}

/// Corridor configuration for thermal dose limits.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct ThermalDoseCorridor {
    /// Maximum CEM43 in minutes for this region.
    pub max_cem43_min: f32,
    /// Maximum instantaneous temperature allowed.
    pub max_temp_c: f32,
    /// Soft fraction of CEM43 where damping should begin, in (0,1).
    pub soft_fraction: f32,
}

impl ThermalDoseCorridor {
    pub fn validate(&self) -> bool {
        (self.max_cem43_min >= 0.0_f32)
            && (self.max_temp_c > 0.0_f32)
            && (self.soft_fraction > 0.0_f32)
            && (self.soft_fraction < 1.0_f32)
    }
}

/// Verdict for thermal evaluation at a region/waypoint.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub enum ThermalVerdict {
    /// Thermal state well within limits.
    Allow,
    /// Approaching limits: dampen duty cycle or intensity.
    Dampen,
    /// Thermal dose exceeded soft limits: require cool-down.
    CoolDownRequired,
    /// Hard violation: further heating not allowed.
    HardStop,
}

/// Evaluate thermal state against corridor limits.
pub fn evaluate_thermal_dose(
    corridor: &ThermalDoseCorridor,
    state: &ThermalDoseState,
) -> ThermalVerdict {
    if !corridor.validate() {
        return ThermalVerdict::HardStop;
    }

    if state.temp_c > corridor.max_temp_c {
        return ThermalVerdict::HardStop;
    }

    if state.cem43_min >= corridor.max_cem43_min {
        return ThermalVerdict::HardStop;
    }

    let frac = if corridor.max_cem43_min > 0.0_f32 {
        state.cem43_min / corridor.max_cem43_min
    } else {
        0.0_f32
    };

    if frac >= 1.0_f32 {
        ThermalVerdict::HardStop
    } else if frac >= corridor.soft_fraction {
        ThermalVerdict::CoolDownRequired
    } else if frac >= 0.5_f32 * corridor.soft_fraction {
        ThermalVerdict::Dampen
    } else {
        ThermalVerdict::Allow
    }
}
