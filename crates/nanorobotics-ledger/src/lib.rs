// crates/nanorobotics-ledger/src/lib.rs
#![forbid(unsafe_code)]

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use nanorobotics_types::{HostId, NanoswarmId};

/// Fixed-point encoding helper for nanoswarm metrics (0.0..1.0 -> 0..1_000_000).
pub fn metric_to_fixed(x: f32) -> i32 {
    let mut v = if x.is_nan() {
        0.0
    } else if x < 0.0 {
        0.0
    } else if x > 1.0 {
        1.0
    } else {
        x
    };
    v = (v * 1_000_000.0).round();
    if v < 0.0 {
        0
    } else if v > 1_000_000.0 {
        1_000_000
    } else {
        v as i32
    }
}

/// Nanoswarm ledger event representing a single nanoswarm operation or state change.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct NanoswarmLedgerEvent {
    pub event_id: u64,
    pub host_id: HostId,
    pub swarm_id: NanoswarmId,
    pub epoch_id: u64,
    pub event_type: u8,
    pub biocompatibility_fixed: i32,
    pub repair_intensity_fixed: i32,
    pub telepathic_depth_fixed: i32,
    pub neurorights_invariants_held: bool,
    pub swarm_active: bool,
    pub timestamp_logical: u64,
    pub timestamp_wallclock: DateTime<Utc>,
    pub did_anchor: [u8; 32],
    pub signature_web5: [u8; 64],
}

/// Nanoswarm state record representing the latest state snapshot for a nanoswarm.
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

/// Simple in-memory ledger for nanoswarm events and state.
/// For production use, this can be backed by a database or persistent store.
#[derive(Default)]
pub struct NanoroboticsLedger {
    events: Vec<NanoswarmLedgerEvent>,
    states: Vec<NanoswarmState>,
}

impl NanoroboticsLedger {
    /// Construct a new, empty nanorobotics ledger.
    pub fn new(_now: DateTime<Utc>) -> Self {
        NanoroboticsLedger {
            events: Vec::new(),
            states: Vec::new(),
        }
    }

    /// Append a ledger event.
    pub fn append_event(&mut self, evt: NanoswarmLedgerEvent) {
        self.events.push(evt);
    }

    /// Append or update a nanoswarm state record.
    pub fn upsert_state(&mut self, state: NanoswarmState) {
        if let Some(existing) = self.states.iter_mut().find(|s| s.host_id == state.host_id && s.swarm_id == state.swarm_id) {
            *existing = state;
        } else {
            self.states.push(state);
        }
    }

    /// List all hosts known to the ledger.
    pub fn all_hosts(&self) -> anyhow::Result<Vec<HostId>> {
        let mut hosts = Vec::new();
        for s in &self.states {
            if !hosts.contains(&s.host_id) {
                hosts.push(s.host_id);
            }
        }
        Ok(hosts)
    }

    /// List all nanoswarms known to the ledger.
    pub fn all_nanoswarms(&self) -> anyhow::Result<Vec<NanoswarmId>> {
        let mut swarms = Vec::new();
        for s in &self.states {
            if !swarms.contains(&s.swarm_id) {
                swarms.push(s.swarm_id);
            }
        }
        Ok(swarms)
    }

    /// Fetch the latest nanoswarm state for a given host and swarm.
    pub fn nanoswarm_state(
        &self,
        host_id: HostId,
        swarm_id: NanoswarmId,
    ) -> anyhow::Result<Option<NanoswarmState>> {
        let state = self.states
            .iter()
            .filter(|s| s.host_id == host_id && s.swarm_id == swarm_id)
            .max_by_key(|s| s.recorded_at);

        Ok(state.cloned())
    }
}
