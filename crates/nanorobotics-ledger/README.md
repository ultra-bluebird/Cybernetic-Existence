# nanorobotics-ledger

`nanorobotics-ledger` implements the nanoswarm-centric ledger for the **Nano-Tree** repository. It provides:

- `NanoswarmLedgerEvent` – per-event records of nanoswarm operations and state changes.
- `NanoswarmState` – latest state snapshots for nanoswarms, including biocompatibility and telepathic integration metrics.
- `NanoroboticsLedger` – in-memory ledger with basic queries for hosts and nanoswarms.

This crate is designed to be consumed by **CyberFS/Cybercore** via:

```toml
nanorobotics-ledger = { git = "https://github.com/mk-bluebird/Nano-Tree", package = "nanorobotics-ledger" }
nanorobotics-types  = { git = "https://github.com/mk-bluebird/Nano-Tree", package = "nanorobotics-types" }
```

ensuring cross-repository / constellation correctness between Nano-Tree and CyberFS.

## Crate Layout

- `src/lib.rs`  
  Defines:

  - `metric_to_fixed` – fixed-point encoding helper for nanoswarm metrics (0.0..1.0).
  - `NanoswarmLedgerEvent` – event records with fixed-point metrics, neurorights flags, and signatures.
  - `NanoswarmState` – nanoswarm state snapshots used by CyberFS (`nanorobotics_core`) for views.
  - `NanoroboticsLedger` – simple ledger implementation with:
    - `append_event`
    - `upsert_state`
    - `all_hosts`
    - `all_nanoswarms`
    - `nanoswarm_state(host_id, swarm_id)`

- `src/main.rs`  
  CLI example that:

  - Constructs a `NanoroboticsLedger`.
  - Appends a dummy state and event.
  - Prints hosts and swarms known to the ledger.

## Usage in Nano-Tree

Inside the Nano-Tree repository, `nanorobotics-ledger` can be used by:

- Nanoswarm control kernels.
- Neuromorphic and nanomedical adapters.
- Governance layers that need to record nanoswarm state changes and events.

Example:

```rust
use nanorobotics_ledger::{NanoroboticsLedger, NanoswarmLedgerEvent, NanoswarmState, metric_to_fixed};
use nanorobotics_types::{HostId, NanoswarmId};

fn record_nanoswarm_event(ledger: &mut NanoroboticsLedger, host_id: HostId, swarm_id: NanoswarmId) {
    let state = NanoswarmState {
        host_id,
        swarm_id,
        state_id: uuid::Uuid::new_v4(),
        recorded_at: chrono::Utc::now(),
        biocompatibility_score: 0.93,
        repair_intensity: 0.70,
        telepathic_depth: 0.65,
        metadata_hash: "state-hash".to_string(),
    };

    ledger.upsert_state(state);

    let evt = NanoswarmLedgerEvent {
        event_id: 42,
        host_id,
        swarm_id,
        epoch_id: 7,
        event_type: 2,
        biocompatibility_fixed: metric_to_fixed(0.93),
        repair_intensity_fixed: metric_to_fixed(0.70),
        telepathic_depth_fixed: metric_to_fixed(0.65),
        neurorights_invariants_held: true,
        swarm_active: true,
        timestamp_logical: 123,
        timestamp_wallclock: chrono::Utc::now(),
        did_anchor: [0u8; 32],
        signature_web5: [0u8; 64],
    };

    ledger.append_event(evt);
}
```

## Usage from CyberFS

In `crates/nanorobotics_core` within CyberFS:

```rust
use nanorobotics_core::NanoroboticsHandle;
use nanorobotics_ledger::NanoroboticsLedger;
use chrono::Utc;

fn example() -> anyhow::Result<()> {
    let ledger = NanoroboticsLedger::new(Utc::now());
    let handle = NanoroboticsHandle::new(ledger);

    let hosts = handle.all_hosts()?;
    for host_id in hosts {
        let swarms = handle.all_nanoswarms()?;
        for swarm_id in swarms {
            if let Some(view) = handle.nanoswarm_state_view(host_id, swarm_id)? {
                println!(
                    "Host {:?}, swarm {:?}: biocompatibility {:.3}, repair_intensity {:.3}, telepathic_depth {:.3}",
                    view.host_id,
                    view.swarm_id,
                    view.biocompatibility_score,
                    view.repair_intensity,
                    view.telepathic_depth
                );
            }
        }
    }

    Ok(())
}
```

## Building

From the Nano-Tree repository root:

```bash
cd crates/nanorobotics-ledger
cargo build
cargo test
```

`nanorobotics-ledger` is intended to be a stable, shared ledger crate for Nano-Tree and its constellation (CyberFS, Cybercore, and related mk-bluebird repositories), ensuring consistent wiring for nanoswarm events, state, and biophysical metrics.
