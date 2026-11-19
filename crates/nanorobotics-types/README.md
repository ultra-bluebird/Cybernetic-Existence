# nanorobotics-types

`nanorobotics-types` defines shared types for the **Nano-Tree** nanorobotics ecosystem, including:

- `HostId` – unique host identity (UUID wrapper).
- `NanoswarmId` – unique nanoswarm identity.
- `NanoswarmMetrics` – biophysical metric bundle (biocompatibility, repair intensity, telepathic depth, lifeforce band).
- `NanoswarmState` – high-level nanoswarm state snapshot used across Nano-Tree, CyberFS, and Cybercore.

These types are used both:

- Inside the Nano-Tree repository (e.g., `nanorobotics-ledger`, nanoswarm control kernels).
- Externally by CyberFS / Cybercore through:

  ```toml
  nanorobotics-ledger = { git = "https://github.com/mk-bluebird/Nano-Tree", package = "nanorobotics-ledger" }
  nanorobotics-types  = { git = "https://github.com/mk-bluebird/Nano-Tree", package = "nanorobotics-types" }
  ```

to ensure cross-repository / constellation correctness.

## Crate Layout

- `src/lib.rs`  
  Defines all core types for hosts, nanoswarms, metrics, and nanoswarm state snapshots.

- `src/main.rs`  
  Simple CLI example that constructs a dummy `NanoswarmState` from metrics and prints it as JSON.

## Usage in Nano-Tree

In `crates/nanorobotics-ledger/src/lib.rs`:

```rust
use nanorobotics_types::{HostId, NanoswarmId, NanoswarmState};

fn record_state(ledger: &mut NanoroboticsLedger, host_id: HostId, swarm_id: NanoswarmId) {
    let metrics = NanoswarmMetrics {
        biocompatibility: 0.93,
        repair_intensity: 0.70,
        telepathic_depth: 0.65,
        lifeforce_band: Some(0.78),
    };
    let state = NanoswarmState::from_metrics(host_id, swarm_id, metrics, "state-hash".to_string());
    ledger.upsert_state(state);
}
```

## Usage from CyberFS

In `crates/nanorobotics_core` within CyberFS:

```rust
use nanorobotics_core::NanoroboticsHandle;
use nanorobotics_ledger::NanoroboticsLedger;

fn example(handle: &NanoroboticsHandle) -> anyhow::Result<()> {
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
cd crates/nanorobotics-types
cargo build
cargo test
```

`nanorobotics-types` is intended to be a stable, shared type crate for Nano-Tree and its constellation (CyberFS, Cybercore, and related mk-bluebird repositories), ensuring consistent wiring for nanoswarm identities, metrics, and state snapshots.
