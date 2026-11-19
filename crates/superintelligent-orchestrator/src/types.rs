// File: crates/superintelligent-orchestrator/src/types.rs

#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

use cybernano_physio::state::{CorridorSnapshotAggregate, BciHostSnapshot};
use cybernano_physio::materials::MaterialLibrary;

/// High-level nanoswarm mission schedule for one planning horizon.
/// This schedule contains only admissible, corridor-bounded missions;
/// it must still pass through SovereigntyKernel and guard kernels.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct NanoswarmMissionSchedule {
    /// Unique schedule identifier.
    pub schedule_id: String,
    /// Per-tissue missions in time order.
    pub missions: Vec<NanoswarmMission>,
    /// Forecasted peak global RoH over the schedule in [0.0, 0.3].
    pub forecasted_roh_peak: f32,
}

/// Single nanoswarm mission slice for a specific region/tissue.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct NanoswarmMission {
    /// Biospatial region or voxel corridor identifier.
    pub region_id: String,
    /// Mission start time offset in seconds from planning epoch.
    pub t_start_s: f32,
    /// Mission end time offset in seconds from planning epoch.
    pub t_end_s: f32,
    /// Target nanorobot family identifier from MaterialLibrary.
    pub family_id: String,
    /// Duty fraction in [0.0, 1.0] over [t_start_s, t_end_s].
    pub duty_fraction: f32,
    /// Desired therapeutic label (e.g., "reduce_il6", "improve_hrv").
    pub objective_tag: String,
}

/// Input to the orchestrator: host corridors, BCI snapshot, and material space.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct OrchestratorInput {
    /// Aggregate corridor snapshot across organs and biospatial regions.
    pub corridors: CorridorSnapshotAggregate,
    /// Latest BCI host snapshot (EEG, HRV, cognitive load).
    pub bci: BciHostSnapshot,
    /// Available nanorobot families and their calibrated risk coefficients.
    pub materials: MaterialLibrary,
    /// Planning horizon in seconds.
    pub horizon_s: f32,
}

/// Configuration for the lexicographic optimizer.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct OrchestratorConfig {
    /// Hard RoH ceiling in [0.0, 0.3]; clinical stability is primary objective.
    pub roh_ceiling: f32,
    /// Minimum capability floor in [0.0, 1.0]; planner must preserve ≥ floor
    /// of configured capability (mission coverage) whenever corridors allow.
    pub capability_floor: f32,
    /// Maximum number of mission slices allowed in one schedule.
    pub max_missions: usize,
    /// Safety margin for RoH to keep away from 0.3 ceiling.
    pub roh_margin: f32,
}
