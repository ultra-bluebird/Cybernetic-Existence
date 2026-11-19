# public-infrastructure-fallback

`public-infrastructure-fallback` provides deterministic fallback-selection contracts
for public-facing infrastructure interfaces.

The crate models how an interface can respond when a normal path is unavailable due
to network loss, remote-service failure, local sensor uncertainty, power degradation,
local-state loss, maintenance requirements, or an emergency state.

It is a contract and decision library. It does not operate doors, transit kiosks,
elevators, emergency stations, crosswalks, public displays, cameras, sensors, or
other real-world infrastructure.

## Scope

The crate supports declared fallback selection for public controls such as:

- Crosswalk request controls
- Transit kiosks
- Public information displays
- Assistance panels
- Automatic-door interfaces
- Elevator panels
- Emergency stations

The fallback decision is based on declared system capabilities and observable system
conditions. It does not require or infer identity, biometrics, health, disability,
behavior, location history, social status, urgency, or personal characteristics.

## Fallback classes

```text
INLINE_EXPLANATION
LOCAL_DRAFT
MANUAL_ROUTE
NO_OP_WITH_NOTICE
HARDWARE_DEFAULT
HUMAN_ESCALATION
```

| Fallback class | Purpose |
|---|---|
| `InlineExplanation` | Explain that a safe local function remains available with changed context |
| `LocalDraft` | Preserve user-entered information locally when the remote route is unavailable |
| `ManualRoute` | Direct the person to a declared manual or mechanical alternative |
| `NoOpWithNotice` | Prevent an unsafe or unavailable action while communicating the limitation |
| `HardwareDefault` | Use a declared physical safety baseline when sensor confidence is insufficient |
| `HumanEscalation` | Route to a declared staffed or emergency assistance process |

## Degradation states

```text
FULL
LIMITED
LOCAL
MANUAL
SAFE_STOP
```

| State | Meaning |
|---|---|
| `Full` | The normal declared path is available |
| `Limited` | A non-critical capability is unavailable |
| `Local` | Local controls or local information remain available |
| `Manual` | A manual, mechanical, or human route is required |
| `SafeStop` | The normal action must not proceed because a safe outcome cannot be established |

## Selection order

The crate uses a conservative selection order:

```text
1. Hardware default when physical safety is uncertain
2. Manual route when a safe manual alternative exists
3. Local draft when user-entered information should be preserved
4. Inline explanation when safe local operation remains available
5. Human escalation when a declared human response is available
6. No-op with notice when no safe alternative exists
```

This is a fallback selection policy, not a person-priority system.

## Privacy and non-discrimination

Fallback decisions must not use:

```text
- Legal identity
- Biometric information
- Disability classification
- Health information
- Behavioral profiling
- Social status
- Financial information
- Recovery context
- Location history
- Device fingerprinting
- Group-size scoring
- Inferred urgency
- Inferred energy or physical capacity
```

A control may use local safety signals such as obstacle detection or an explicit
accessibility hold request. Those signals control the safe action of the object; they
do not classify or rank the person using it.

## Example

```rust
use public_infrastructure_fallback::{
    select_fallback,
    FallbackCapabilities,
    FallbackClass,
    TriggerState,
};

let decision = select_fallback(
    TriggerState::NetworkUnavailable,
    FallbackCapabilities {
        physical_safety_uncertain: false,
        manual_route_available: false,
        local_draft_supported: true,
        safe_local_operation_available: true,
        human_escalation_available: false,
    },
);

assert_eq!(decision.fallback_class, FallbackClass::LocalDraft);
assert!(decision.local_data_preserved);
assert!(!decision.identity_collection_required);
assert!(!decision.biometric_collection_required);
assert!(!decision.external_action_authorized);
```

## Integration guidance

A higher-level system should:

1. Declare each public control's fallback capabilities before deployment.
2. Pass only observable infrastructure conditions to `select_fallback`.
3. Present the fallback using visible and nonvisual communication.
4. Preserve user-entered data locally when the selected fallback allows it.
5. Provide a manual or human route where the declared fallback requires one.
6. Keep the decision separate from identity, analytics, and person-level profiling.
7. Test each fallback path under network loss, service loss, sensor uncertainty,
   power degradation, maintenance conditions, and emergency activation.

## Non-goals

This crate does not:

- Control hardware
- Open or close doors
- Call emergency services
- Send notifications
- Collect personal information
- Authenticate users
- Process biometric information
- Make medical or disability determinations
- Predict urgency
- Rank people
- Route people by perceived priority
- Implement a network protocol
- Store telemetry
- Perform cloud synchronization
- Replace engineering safety standards, accessibility review, local law,
  human oversight, or site-specific operational procedures

## Development

Minimum supported Rust version:

```text
Rust 1.86
```

Build the crate:

```sh
cargo build
```

Run tests:

```sh
cargo test
```

Run formatting checks:

```sh
cargo fmt --check
```

Run lint checks:

```sh
cargo clippy --all-targets --all-features -- -D warnings
```

## Repository layout

```text
rust/public-infrastructure-fallback/
├── Cargo.toml
├── README.md
└── src/
    └── lib.rs
```

## License

Licensed under either of:

- MIT License
- Apache License, Version 2.0

at your option.
