# Rust Integration Spine: Safety and Privacy Modules

## Purpose

This document describes the integration of two non-actuating research components into the `augmented_hub` Rust crate:

1. **Safety redundancy matrix** — Evidence-assessment model for sensor-channel health and disagreement.
2. **Differential-privacy aggregate gate** — Policy-only release-decision model for aggregate data.

Both modules are intended for offline analysis, reproducible research, and policy evaluation. They do not control hardware, transit systems, devices, bodies, or external services.

---

## Public Module Paths

```rust
// Crate root: rust/src/lib.rs
pub mod safety;
pub mod privacy;

// Safety module path
use augmented_hub::safety::redundancy_matrix::{
    assess, RedundancyObservation, RedundancyPolicy, SafetyEvidenceState,
};

// Privacy module path
use augmented_hub::privacy::dp_aggregate::{
    assess_release, AggregateRequest, ReleaseDecision,
};
```

### Module Structure

```text
rust/
├── Cargo.toml                 # Crate manifest (name = "augmented_hub")
├── src/
│   ├── lib.rs                 # Crate root; exports `safety` and `privacy`
│   ├── safety/
│   │   ├── mod.rs             # Declares `pub mod redundancy_matrix`
│   │   └── redundancy_matrix.rs  # Safety evidence assessment logic
│   └── privacy/
│       ├── mod.rs             # Declares `pub mod dp_aggregate`
│       └── dp_aggregate.rs    # Differential-privacy release-gate logic
└── tests/
    ├── redundancy_matrix_tests.rs  # Integration tests for safety module
    └── dp_aggregate_tests.rs       # Integration tests for privacy module
```

---

## Inputs and Outputs (High Level)

### Safety Redundancy Matrix

**Input:** `RedundancyObservation`

- Sequence number.
- Channel-health states for primary sensor, secondary sensor, and watchdog timer.
- Boolean obstacle flags from optical and ultrasonic channels.
- Measurement disagreement in milliunits and a configured threshold.
- Manual-override state (NotRequested, Requested, Active, Unknown).
- Optional recovery-time measurement in milliseconds.

**Output:** `RedundancyAssessment`

- Boolean flags summarizing channel health combinations.
- State enumeration:
  - `OperationalEvidenceSufficient`
  - `ReviewRequired`
  - `SafetyEvidenceInsufficient`
  - `ManualOverrideRequiresReview`
- A list of human-readable reason strings explaining the state.

### Differential-Privacy Aggregate Gate

**Input:** `AggregateRequest`

- Request metadata (ID, purpose, timestamp).
- Contributor count and minimum threshold.
- Clipped sum, L1 sensitivity, epsilon (in micros).
- Cumulative epsilon usage and limit.
- `ConsentScope` describing purpose, data class, output mode, validity window, and consent state.

**Output:** `ReleaseAssessment`

- `ReleaseDecision` enumeration:
  - `AllowAggregateOnly`
  - `DenyConsentMissing`, `DenyConsentRevoked`, `DenyConsentExpired`
  - `DenyPurposeMismatch`
  - `DenyDataClassNotEligible`
  - `DenyOutputMode`
  - `DenyMinimumAggregationThreshold`
  - `DenyInvalidSensitivity`
  - `DenyHighSensitivityEpsilon`
  - `DenyCumulativeBudget`
- Projected cumulative epsilon after this request.
- Laplace scale numerator and denominator for downstream noise calibration (not performed here).
- A list of human-readable reason strings explaining the decision.

---

## Explicit Boundaries

### Non-Actuation Statement

Neither module:

- Controls hardware, transit doors, actuators, robots, or physical infrastructure.
- Issues stop commands, dispatch commands, or device-control instructions.
- Connects to networks, databases, enclaves, sensors, identity systems, or external recipients.
- Samples or publishes noisy results by itself.
- Collects raw telemetry, biometric samples, gait traces, thermal images, trajectories, keys, credentials, device IDs, or full consent records.

### Privacy Statement

The privacy module:

- Operates on synthetic or pre-aggregated metadata only.
- Denies aggregate release for sensitive derived-feature and high-sensitivity biometric classes in the baseline public aggregate-output path.
- Requires valid consent, exact purpose match, valid duration, allowed output mode, minimum aggregation threshold, positive sensitivity and epsilon, and remaining cumulative privacy budget.
- Fails closed: missing, revoked, expired, incompatible, or out-of-budget requests are denied.

### Safety Statement

The safety module:

- Evaluates evidence states only; it does not constitute certification, operational authorization, or a physical command.
- Treats manual override as a reviewable state, never an automated command.
- Treats dual-channel disagreement as a reviewable or insufficient-evidence condition.
- Does not silently treat unknown or degraded status as healthy.

---

## Test Execution Note

Normal Cargo validation (`cargo build`, `cargo test`, `cargo clippy`) is expected in CI or a separately authorized developer workflow. This session did not run any Cargo commands, Rust compiler commands, or Rust formatter commands.

---

## Minimal Usage Illustration

```rust
use augmented_hub::safety::redundancy_matrix::{
    assess, ChannelHealth, ManualOverrideState, RedundancyObservation, RedundancyPolicy,
};
use augmented_hub::privacy::dp_aggregate::{
    assess_release, AggregateRequest, ConsentScope, ConsentState, DataClass, OutputMode,
};

fn example_safety_assessment() {
    let observation = RedundancyObservation {
        sequence: 1,
        primary_sensor: ChannelHealth::Healthy,
        secondary_sensor: ChannelHealth::Healthy,
        watchdog_timer: ChannelHealth::Healthy,
        optical_obstacle_detected: false,
        ultrasonic_obstacle_detected: false,
        disagreement_milliunits: 50,
        disagreement_threshold_milliunits: 100,
        manual_override: ManualOverrideState::NotRequested,
        measured_recovery_ms: Some(80),
    };

    let assessment = assess(&observation, RedundancyPolicy::default());
    println!("Safety state: {:?}", assessment.state);
}

fn example_privacy_assessment() {
    let request = AggregateRequest {
        request_id: "example-001".to_owned(),
        purpose: "heat-safe-corridor-planning".to_owned(),
        requested_at_unix_ms: 1_800_000_000_000,
        contributor_count: 60,
        minimum_contributor_count: 50,
        clipped_sum: 100,
        l1_sensitivity_units: 1,
        epsilon_micros: 100_000,
        cumulative_epsilon_used_micros: 100_000,
        cumulative_epsilon_limit_micros: 500_000,
        consent: ConsentScope {
            purpose: "heat-safe-corridor-planning".to_owned(),
            data_class: DataClass::ThermalAggregate,
            output_mode: OutputMode::AggregateOnly,
            valid_from_unix_ms: 1_700_000_000_000,
            valid_until_unix_ms: 1_900_000_000_000,
            state: ConsentState::Valid,
        },
    };

    let assessment = assess_release(&request);
    println!("Release decision: {:?}", assessment.decision);
}
```

---

## Revision History

- Initial integration: wired `safety` and `privacy` modules into `augmented_hub` crate root.
- Added `rust/src/lib.rs`, `rust/src/safety/mod.rs`, `rust/src/privacy/mod.rs`.
- Created `rust/Cargo.toml` with crate name `augmented_hub` and `serde` dependencies.
- Verified existing test files reference `augmented_hub::safety::redundancy_matrix` and `augmented_hub::privacy::dp_aggregate`.
