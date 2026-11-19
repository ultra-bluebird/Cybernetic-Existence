// crates/nanorobotics-types/src/main.rs
#![forbid(unsafe_code)]

use chrono::Utc;
use uuid::Uuid;

use nanorobotics_types::{HostId, NanoswarmId, NanoswarmMetrics, NanoswarmState};

fn main() {
    let host_id = HostId(Uuid::new_v4());
    let swarm_id = NanoswarmId(Uuid::new_v4());

    let metrics = NanoswarmMetrics {
        biocompatibility: 0.96,
        repair_intensity: 0.72,
        telepathic_depth: 0.63,
        lifeforce_band: Some(0.80),
    };

    let state = NanoswarmState::from_metrics(
        host_id,
        swarm_id,
        metrics,
        "dummy-nanoswarm-state-hash".to_string(),
    );

    let json = serde_json::to_string_pretty(&state).expect("serialize nanoswarm state");
    println!("{}", json);
}
