# Preventive Maintenance Usage

This guide demonstrates how to create a deterministic preventive-maintenance plan for a continuity-sensitive corridor asset using the `popmath::preventive_maintenance` module.

The example schedules maintenance for a corridor sensor. It models a bounded planning horizon, an available field technician, and one calibration-kit inventory unit. The solver selects the earliest feasible maintenance slot after applying its stable ordering and validating all capacity constraints.

## Import the module

```rust
use std::collections::BTreeMap;

use popmath::preventive_maintenance::{
    solve_with_deterministic_fallback,
    AssetKind,
    CrewAvailability,
    MaintenanceAsset,
    MaintenancePlanningInput,
    PartInventory,
};
```

## Build a maintenance plan

```rust
let input = MaintenancePlanningInput {
    horizon_slots: 12,
    assets: vec![
        MaintenanceAsset {
            asset_id: "corridor-sensor-north".to_owned(),
            asset_kind: AssetKind::CorridorSensor,
            corridor_id: "north-corridor".to_owned(),
            required_crew_role: "field-tech".to_owned(),
            required_part_id: "sensor-calibration-kit".to_owned(),
            maintenance_duration_slots: 1,
            due_by_slot: 5,
            maximum_consecutive_downtime_slots: 1,
            continuity_disruption_weight: 80,
            essential_service_asset: true,
        },
    ],
    crews: vec![
        CrewAvailability {
            crew_role: "field-tech".to_owned(),
            available_crew_count_by_slot: BTreeMap::from([
                (0, 1),
                (1, 1),
                (2, 1),
                (3, 1),
                (4, 1),
                (5, 1),
            ]),
        },
    ],
    parts: vec![
        PartInventory {
            part_id: "sensor-calibration-kit".to_owned(),
            available_quantity: 1,
        },
    ],
};

let plan = solve_with_deterministic_fallback(&input)?;
```

## Verify the plan

```rust
assert!(plan.unscheduled_asset_ids.is_empty());
assert!(plan.essential_service_continuity_preserved);
assert_eq!(plan.scheduled_maintenance.len(), 1);

let scheduled = &plan.scheduled_maintenance;

assert_eq!(scheduled.asset_id, "corridor-sensor-north");
assert_eq!(scheduled.start_slot, 0);
assert_eq!(scheduled.end_slot_exclusive, 1);
assert_eq!(plan.total_weighted_continuity_disruption, 80);
```

## Complete executable example

```rust
use std::collections::BTreeMap;

use popmath::preventive_maintenance::{
    solve_with_deterministic_fallback,
    AssetKind,
    CrewAvailability,
    MaintenanceAsset,
    MaintenancePlanningInput,
    PartInventory,
};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let input = MaintenancePlanningInput {
        horizon_slots: 12,
        assets: vec![
            MaintenanceAsset {
                asset_id: "corridor-sensor-north".to_owned(),
                asset_kind: AssetKind::CorridorSensor,
                corridor_id: "north-corridor".to_owned(),
                required_crew_role: "field-tech".to_owned(),
                required_part_id: "sensor-calibration-kit".to_owned(),
                maintenance_duration_slots: 1,
                due_by_slot: 5,
                maximum_consecutive_downtime_slots: 1,
                continuity_disruption_weight: 80,
                essential_service_asset: true,
            },
        ],
        crews: vec![
            CrewAvailability {
                crew_role: "field-tech".to_owned(),
                available_crew_count_by_slot: BTreeMap::from([
                    (0, 1),
                    (1, 1),
                    (2, 1),
                    (3, 1),
                    (4, 1),
                    (5, 1),
                ]),
            },
        ],
        parts: vec![
            PartInventory {
                part_id: "sensor-calibration-kit".to_owned(),
                available_quantity: 1,
            },
        ],
    };

    let plan = solve_with_deterministic_fallback(&input)?;

    assert!(plan.unscheduled_asset_ids.is_empty());
    assert!(plan.essential_service_continuity_preserved);

    for scheduled in &plan.scheduled_maintenance {
        println!(
            "asset={} start_slot={} end_slot_exclusive={}",
            scheduled.asset_id,
            scheduled.start_slot,
            scheduled.end_slot_exclusive,
        );
    }

    println!(
        "total_weighted_continuity_disruption={}",
        plan.total_weighted_continuity_disruption,
    );

    println!(
        "essential_service_continuity_preserved={}",
        plan.essential_service_continuity_preserved,
    );

    Ok(())
}
```

## Expected result

The deterministic fallback selects slot `0` because it is the earliest feasible start slot.

| Field | Value | Meaning |
|---|---:|---|
| `asset_id` | `corridor-sensor-north` | The scheduled corridor asset |
| `start_slot` | `0` | The first assigned planning slot |
| `end_slot_exclusive` | `1` | The asset is maintained during one discrete time slot |
| `total_weighted_continuity_disruption` | `80` | `continuity_disruption_weight × maintenance_duration_slots` |
| `essential_service_continuity_preserved` | `true` | The maintenance duration remains within the asset's one-slot downtime bound |
| `unscheduled_asset_ids` | Empty | Required crew availability and part inventory were sufficient |

## Model meaning

For each asset \(a\) and eligible start time \(t\), the planning model defines:

\[
x_{a,t} =
\begin{cases}
1 & \text{if maintenance starts for asset } a \text{ at slot } t \\
0 & \text{otherwise}
\end{cases}
\]

The solver minimizes weighted continuity disruption:

\[
\min \sum_{a \in A} \sum_{t \in W_a}
w_a d_a x_{a,t}
\]

Where:

- \(A\) is the set of maintenance assets.
- \(W_a\) is the set of feasible maintenance start slots for asset \(a\).
- \(w_a\) is `continuity_disruption_weight`.
- \(d_a\) is `maintenance_duration_slots`.

Each asset receives one maintenance assignment:

\[
\sum_{t \in W_a} x_{a,t} = 1
\]

The input in this guide creates one eligible sensor asset, one available field technician, and one available calibration kit. Since all slots from `0` through `5` have one available technician, the deterministic fallback chooses slot `0`.

## Operational safeguards

The example is intentionally asset-centered rather than person-centered.

- It uses corridor and asset identifiers, crew roles, time-slot capacity, and inventory quantities.
- It does not require personal identity data, health information, implant data, disability status, or individual travel histories.
- It enforces maximum consecutive downtime through `maximum_consecutive_downtime_slots`.
- It surfaces unassigned maintenance through `unscheduled_asset_ids` rather than silently declaring a partial schedule successful.
- It identifies whether required maintenance for an essential asset remains within its configured continuity boundary.
- It supports accessible service notices by making planned maintenance windows explicit and inspectable.

## Extension pattern

A service can run the deterministic planner for reproducible scheduling and then publish an accessible maintenance notice based on the result:

```rust
let plan = solve_with_deterministic_fallback(&input)?;

for maintenance in &plan.scheduled_maintenance {
    let notice = format!(
        "Scheduled maintenance for {} runs from planning slot {} until slot {}.",
        maintenance.asset_id,
        maintenance.start_slot,
        maintenance.end_slot_exclusive,
    );

    assert!(!notice.is_empty());
}
```

The planning output can be integrated with corridor-continuity assessment, alternative-service routing, and accessible outage notifications without tying essential access to device registration, vendor identity, or continuous personal telemetry.
