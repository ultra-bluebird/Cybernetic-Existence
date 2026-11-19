// crates/nanorobotics-types/src/lib.rs
#![forbid(unsafe_code)]

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// Unique identifier for a host in the nanorobotics ecosystem.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct HostId(pub Uuid);

/// Unique identifier for a nanoswarm instance.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct NanoswarmId(pub Uuid);

/// Biophysical metric bundle for nanoswarm state.
///
/// All values are in floating-point form (0.0..1.0) and can be encoded into
/// fixed-point by functions in `nanorobotics-ledger` when needed.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct NanoswarmMetrics {
    /// Biocompatibility score (0.0..1.0).
    pub biocompatibility: f32,
    /// Repair intensity (0.0..1.0).
    pub repair_intensity: f32,
    /// Telepathic / deviceless integration depth (0.0..1.0).
    pub telepathic_depth: f32,
    /// Optional lifeforce band index (0.0..1.0).
    pub lifeforce_band: Option<f32>,
}

/// High-level nanoswarm state snapshot used across Nano-Tree and CyberFS.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct NanoswarmState {
    pub host_id: HostId,
    pub swarm_id: NanoswarmId,
    pub state_id: Uuid,
    pub recorded_at: DateTime<Utc>,
    pub biocompatibility_score: f32,
    pub repair_intensity: f32,
    pub telepathic_depth: f32,
    pub metadata_hash: String,
}

impl NanoswarmState {
    /// Construct a state from metrics and a metadata hash.
    pub fn from_metrics(
        host_id: HostId,
        swarm_id: NanoswarmId,
        metrics: NanoswarmMetrics,
        metadata_hash: String,
    ) -> Self {
        NanoswarmState {
            host_id,
            swarm_id,
            state_id: Uuid::new_v4(),
            recorded_at: Utc::now(),
            biocompatibility_score: metrics.biocompatibility,
            repair_intensity: metrics.repair_intensity,
            telepathic_depth: metrics.telepathic_depth,
            metadata_hash,
        }
    }
}
