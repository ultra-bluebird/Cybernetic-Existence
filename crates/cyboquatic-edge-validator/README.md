# Cyboquatic Edge Validator

`cyboquatic-edge-validator` is a Rust library for validating and aggregating
environmental and Cyboquatic equipment telemetry at the network edge.

It is designed for heat-resilience, water-treatment, ecological-restoration,
and public-interest infrastructure research where data must be trustworthy,
privacy-preserving, and safe to use in later analysis.

The crate accepts environmental and equipment measurements, checks that they are
finite, timely, physically plausible, and within declared operational corridors,
then emits an aggregate-only record suitable for secure publication.

It is a validation and decision-support component. It does not control pumps,
release reclaimed water, modify weather, make service-eligibility decisions, or
perform autonomous actions affecting people or ecosystems.

## Capabilities

- Validates finite numeric telemetry and rejects `NaN`, positive infinity, and
  negative infinity.
- Enforces configured range corridors for air temperature, humidity, WBGT, and
  water flow.
- Rejects stale samples and excessive clock skew.
- Checks rate-of-change limits against a prior local observation.
- Requires a minimum aggregate count before records can leave the local node.
- Preserves only aggregate environmental and equipment fields in its output.
- Retains calibration and firmware versions to support reproducibility and
  technical accountability.
- Uses no network client, cloud dependency, database, personal data, location
  trail, biometric data, neural data, or device identifier.

## Privacy and Rights Model

The crate is intentionally limited to environmental and equipment telemetry.

It must not be used to export:

- Names, account identifiers, email addresses, phone numbers, or addresses.
- Persistent device identifiers or advertising identifiers.
- Faces, voices, images, video, or raw audio.
- Precise movement paths, individual trajectories, or presence histories.
- Biometric, health, neural, behavioral, or assistive-technology data.
- Individual-level cooling-service use or eligibility records.

An integration must aggregate locally before publishing. The recommended policy
requires a minimum group size and spatially coarse reporting, such as an H3 area
or another community-approved geographic aggregation.

## Data Flow

```text
Sensors
  -> local acquisition adapter
  -> cyboquatic-edge-validator
  -> local privacy aggregation
  -> MQTT over mutual TLS
  -> schema bridge
  -> Kafka aggregate stream
  -> TimescaleDB aggregate time series
  -> accessible research and public-interest reporting
```

The validation result is not an approval to operate an infrastructure system.
Water release, reclaimed-water use changes, site activation, data export, and
retention-policy changes require human, community, and applicable operational
review.

## Installation

Add the crate as a workspace dependency:

```toml
[dependencies]
cyboquatic-edge-validator = { path = "rust/cyboquatic-edge-validator" }
```

For a standalone local checkout:

```bash
cargo test
```

## Basic Use

```rust
use cyboquatic_edge_validator::{
    validate_and_aggregate,
    AggregatePolicy,
    RawTelemetry,
    SensorLimits,
};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let limits = SensorLimits {
        air_temperature_min_c: -30.0,
        air_temperature_max_c: 70.0,
        relative_humidity_min_percent: 0.0,
        relative_humidity_max_percent: 100.0,
        wbgt_min_c: -10.0,
        wbgt_max_c: 65.0,
        water_flow_min_m3_per_s: 0.0,
        water_flow_max_m3_per_s: 10.0,
        max_sample_age_seconds: 180,
        max_clock_skew_seconds: 60,
        max_temperature_rate_c_per_minute: 8.0,
        max_humidity_rate_percent_per_minute: 30.0,
        max_flow_rate_change_m3_per_s_per_minute: 2.0,
    };

    let policy = AggregatePolicy {
        minimum_aggregate_count: 20,
        location_precision_meters: 250,
    };

    let input = RawTelemetry {
        observed_at_unix_seconds: 1_700_000_000,
        received_at_unix_seconds: 1_700_000_030,
        h3_cell: "aggregate-area".to_string(),
        sample_count: 24,
        air_temperature_c: Some(42.0),
        relative_humidity_percent: Some(18.0),
        wbgt_c: Some(31.0),
        water_flow_m3_per_s: Some(0.25),
        calibration_version: "calibration-v1".to_string(),
        firmware_version: "firmware-v1".to_string(),
    };

    let aggregate = validate_and_aggregate(
        &input,
        None,
        &limits,
        &policy,
    )?;

    let encoded = serde_json::to_string(&aggregate)?;
    println!("{encoded}");

    Ok(())
}
```

## Validation Rules

| Rule | Purpose | Result when violated |
|---|---|---|
| Non-empty geographic aggregate | Associates data with an approved aggregate area | Record rejected |
| Minimum aggregate count | Prevents small-group reporting | Record rejected |
| Finite value check | Blocks `NaN` and infinite values | Record rejected |
| Range corridor | Blocks impossible or unsafe measurements | Record rejected |
| Sample age limit | Prevents stale telemetry from appearing current | Record rejected |
| Clock-skew limit | Detects time synchronization failure | Record rejected |
| Rate-of-change corridor | Detects likely sensor faults or abrupt invalid changes | Record rejected |
| Version metadata | Preserves calibration and firmware provenance | Record retained with version fields |

The default corridor values are engineering examples. Every deployment must set
them from a documented sensor specification, local climate conditions, calibration
protocol, water-system constraints, and public-interest safety review.

## Error Handling

`validate_and_aggregate` returns `Result<AggregateTelemetry, ValidationError>`.

Expected validation outcomes include:

```rust
use cyboquatic_edge_validator::ValidationError;

fn classify_error(error: ValidationError) -> &'static str {
    match error {
        ValidationError::MissingH3Cell => "Missing geographic aggregate.",
        ValidationError::NonFiniteValue(_) => "Non-finite measurement.",
        ValidationError::OutOfRange(_) => "Measurement outside corridor.",
        ValidationError::StaleSample => "Sample exceeded age limit.",
        ValidationError::ClockSkew => "Clock skew exceeded limit.",
        ValidationError::AggregateTooSmall => "Aggregate group below privacy threshold.",
        ValidationError::RateExceeded(_) => "Rate of change exceeded corridor.",
    }
}
```

An integration should send rejected records to a local quality-event queue with a
coarse error category and timestamp. It should not retain raw invalid payloads
longer than needed for secure engineering investigation.

## MQTT, Kafka, and Storage Integration

The crate does not embed network transport. This separation keeps the validation
kernel testable and minimizes the privilege available to edge software.

A production adapter should:

1. Validate raw local telemetry with `validate_and_aggregate`.
2. Aggregate and remove prohibited fields before serialization.
3. Publish only accepted aggregate messages to an allowlisted MQTT topic.
4. Require mutual TLS for device-to-broker transport.
5. Validate the message schema again at the MQTT-to-Kafka bridge.
6. Publish only aggregate records to Kafka.
7. Store aggregate records and quality events in separate TimescaleDB tables.
8. Apply purpose-limited retention and access controls.
9. Make dashboards accessible and publish uncertainty, calibration status, and
   data-quality information alongside measurements.

## Recommended MQTT Topic Form

```text
cyboquatic/v1/aggregate/<approved-area>/<sensor-class>
```

Allowed examples:

```text
cyboquatic/v1/aggregate/heat-area/environment
cyboquatic/v1/aggregate/water-area/flow
cyboquatic/v1/aggregate/restoration-area/soil
```

Topic segments must not contain person names, device serial numbers, addresses,
precise coordinates, or sensitive service-use information.

## Development

Run formatting, linting, and tests before opening a pull request:

```bash
cargo fmt --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test
```

Build an optimized library artifact:

```bash
cargo build --release
```

## Test Expectations

The test suite should prove at minimum that the crate:

- Accepts a valid aggregate environmental record.
- Rejects an aggregate smaller than the privacy threshold.
- Rejects each out-of-range variable.
- Rejects `NaN` and infinite values.
- Rejects stale and clock-skewed samples.
- Rejects implausible rate changes.
- Preserves calibration and firmware version metadata.
- Does not contain fields for personal or persistent device identity.

## Security Notes

- Compile and deploy with a pinned Rust toolchain.
- Keep certificates, private keys, and broker credentials outside telemetry
  payloads and source control.
- Use mutual TLS and allowlisted publish/subscribe topics.
- Treat all incoming configuration, messages, and metadata as untrusted.
- Authenticate configuration updates and require review for corridor changes.
- Keep edge processes least-privileged and isolated from pump, valve, or
  treatment controls unless a separate reviewed safety controller exists.
- Log validation summaries and configuration versions without exporting
  prohibited personal or device-level data.

## Research Notes

This crate supports environmental measurement integrity. It can contribute to
research on:

- Urban heat and WBGT mapping.
- Reclaimed-water treatment and beneficial-use accounting.
- Managed aquifer recharge readiness.
- Ecological restoration monitoring.
- Sensor drift and calibration governance.
- Low-carbon water conveyance measurement.
- Aggregate-only heat-resilience service evaluation.

It does not establish causation, prove a cooling intervention is effective, or
justify water consumption on its own. Those conclusions require controlled study
design, calibrated instruments, appropriate comparison sites, uncertainty
analysis, lifecycle accounting, and independent review.

## Quality Metrics

- knowledge_factor: 0.88
  - Basis: finite-value, range, rate, age, and aggregation validation are
    established edge-systems practices.

- eco_impact_value: 0.89
  - Basis: prevents poor-quality telemetry from driving ecological claims or
    resource decisions and supports measured heat and water research.

- harm_risk: 0.16
  - Basis: residual risk comes from incorrect corridor configuration,
    calibration drift, and integration mistakes. The crate rejects rather than
    acts when validation fails.

- accessibility_impact: 0.90
  - Basis: aggregate-only environmental data can inform inclusive public cooling
    and restoration services without requiring personal tracking.

- rights_alignment: 0.95
  - Basis: data minimization, local aggregation, non-coercive system boundaries,
    audit-ready version metadata, and human review are core requirements.
