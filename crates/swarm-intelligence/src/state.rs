// crates/swarm-intelligence/src/state.rs

use serde::{Deserialize, Serialize};
use nanoswarm_telemetry::row::TelemetryRow;

/// Aggregated view of nanoswarm context derived from telemetry.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SwarmContext {
    /// Host and identity bindings.
    pub host_did: String,
    pub bostrom_address: String,
    /// Identifier for this swarm group.
    pub swarm_id: String,
    /// Latest telemetry rows considered for decision-making.
    pub recent_rows: Vec<TelemetryRow>,
}

impl SwarmContext {
    pub fn new(host_did: String, bostrom_address: String, swarm_id: String) -> Self {
        SwarmContext {
            host_did,
            bostrom_address,
            swarm_id,
            recent_rows: Vec::new(),
        }
    }

    /// Ingest new telemetry rows into the context.
    pub fn ingest(&mut self, rows: Vec<TelemetryRow>) {
        self.recent_rows.extend(rows);
    }
}
