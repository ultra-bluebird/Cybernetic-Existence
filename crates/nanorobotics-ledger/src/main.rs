// crates/nanorobotics-ledger/src/main.rs
#![forbid(unsafe_code)]

use anyhow::Result;
use chrono::Utc;
use uuid::Uuid;

use nanorobotics_ledger::{NanoroboticsLedger, NanoswarmLedgerEvent, NanoswarmState, metric_to_fixed};
use nanorobotics_types::{HostId, NanoswarmId};

fn main() -> Result<()> {
    env_logger::init();

    let mut ledger = NanoroboticsLedger::new(Utc::now());

    let host_id = HostId(Uuid::new_v4());
    let swarm_id = NanoswarmId(Uuid::new_v4());

    // Create a dummy state and event
    let state = NanoswarmState {
        host_id,
        swarm_id,
        state_id: Uuid::new_v4(),
        recorded_at: Utc::now(),
        biocompatibility_score: 0.95,
        repair_intensity: 0.75,
        telepathic_depth: 0.60,
        metadata_hash: "dummy-meta-hash".to_string(),
    };

    ledger.upsert_state(state);

    let evt = NanoswarmLedgerEvent {
        event_id: 1,
        host_id,
        swarm_id,
        epoch_id: 1,
        event_type: 1,
        biocompatibility_fixed: metric_to_fixed(0.95),
        repair_intensity_fixed: metric_to_fixed(0.75),
        telepathic_depth_fixed: metric_to_fixed(0.60),
        neurorights_invariants_held: true,
        swarm_active: true,
        timestamp_logical: 0,
        timestamp_wallclock: Utc::now(),
        did_anchor: [0u8; 32],
        signature_web5: [0u8; 64],
    };

    ledger.append_event(evt);

    let hosts = ledger.all_hosts()?;
    println!("Hosts in ledger: {:?}", hosts);

    let swarms = ledger.all_nanoswarms()?;
    println!("Swarms in ledger: {:?}", swarms);

    Ok(())
}
