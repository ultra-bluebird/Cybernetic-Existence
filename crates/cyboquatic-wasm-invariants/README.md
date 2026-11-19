# Cyboquatic WASM Invariants

`cyboquatic-wasm-invariants` is a compact validation kernel for environmental,
soil, weather, water-flow, and Cyboquatic sensor aggregates.

It supports privacy-preserving edge computation by validating local aggregate
statistics before a gateway signs or publishes a result. The crate is suitable
for WebAssembly-capable gateways and can also be used as a native Rust library.

The crate accepts aggregate-only observations, verifies timing, privacy, numeric,
and physical-corridor invariants, then prepares a bounded payload containing
only approved environmental statistics and integrity metadata.

## Purpose

The crate helps an edge system establish that a telemetry aggregate is:

- Large enough to meet the configured privacy threshold.
- Bound to a valid reporting interval.
- Numerically finite and physically plausible.
- Within configured air-temperature, humidity, soil-moisture, and water-flow
  corridors.
- Associated with a coarse geographic aggregate rather than a precise movement
  trail.
- Linked to firmware and policy measurement digests for later verification.

The crate does not collect, export, infer, or retain personal data.

## Non-Goals

This crate does not:

- Identify people, devices, residents, workers, or service recipients.
- Process biometric, neural, health, voice, image, video, or behavioral data.
- Store exact location history, personal trajectories, or household-level use.
- Generate or manage device keys.
- Sign payloads by itself.
- Perform remote firmware updates.
- Authorize reclaimed-water release, pump/valve control, weather intervention,
  ecological discharge, or any essential-service decision.
- Replace human, community, safety, ecological, or operational review.

A device or gateway must use a separate, reviewed attestation component to sign
accepted payloads with protected key material.

## Privacy Model

Only aggregate observations may be passed to this library.

A valid aggregate includes:

- A start and end timestamp for the reporting interval.
- A coarse H3 cell or approved aggregate-area label.
- Aggregate sample count.
- Sums used to calculate local means.
- Firmware and policy measurement digests.
- Validation result and quality flags.

The payload must not contain personal identity, persistent device identity,
raw sensor sample histories, precise coordinates, or data that can reconstruct
an individual’s presence or movement.

A minimum aggregate-count corridor blocks the release of under-populated
statistics. The configured threshold must be selected through privacy review and
must account for re-identification risk, the population served, sampling density,
and data-release frequency.

## Core Model

The library calculates arithmetic means locally:

```text
mean = aggregate_sum / sample_count
```

It then applies configured corridors:

```text
minimum <= mean <= maximum
```

An output is accepted only when all required invariants hold:

```text
sample_count >= minimum_aggregate_count
0 < interval_seconds <= maximum_interval_seconds
all aggregate means are finite
all aggregate means are within their configured corridors
aggregate-area label is non-empty
```

A rejected payload must remain local or enter a separately protected engineering
quality queue. It must not be published as valid environmental evidence.

## Basic Example

```rust
use cyboquatic_wasm_invariants::{
    validate_and_prepare,
    Observation,
    Policy,
};

fn main() {
    let policy = Policy {
        minimum_aggregate_count: 20,
        maximum_interval_seconds: 900,
        air_temperature_min_c: -30.0,
        air_temperature_max_c: 70.0,
        humidity_min_percent: 0.0,
        humidity_max_percent: 100.0,
        soil_moisture_min_fraction: 0.0,
        soil_moisture_max_fraction: 1.0,
        water_flow_min_m3_per_s: 0.0,
        water_flow_max_m3_per_s: 10.0,
    };

    let observation = Observation {
        interval_start_unix_seconds: 1_700_000_000,
        interval_end_unix_seconds: 1_700_000_300,
        h3_cell: "aggregate-area".to_string(),
        sample_count: 24,
        air_temperature_sum_c: 1008.0,
        relative_humidity_sum_percent: 432.0,
        soil_moisture_sum_fraction: 9.6,
        water_flow_sum_m3_per_s: 6.0,
    };

    let result = validate_and_prepare(
        &observation,
        &policy,
        "approved-firmware-measurement".to_string(),
        "approved-policy-measurement".to_string(),
    );

    assert!(result.is_ok());
}
```

## Attestation Integration

The crate prepares a validated aggregate with two integrity fields:

- `firmware_measurement_digest`
- `policy_digest`

A separate attestation layer should perform the following sequence:

1. Secure boot verifies the firmware manifest before execution.
2. Firmware measures its own immutable image and active policy configuration.
3. The local invariant kernel validates aggregate-only sensor statistics.
4. The attestation component creates a canonical payload encoding.
5. A protected device key signs the canonical payload and freshness nonce.
6. The receiving verifier validates the signature, certificate or public key,
   approved firmware measurement, policy measurement, freshness nonce, and
   rollback counter.
7. Only accepted, signed aggregate statistics are eligible for publication.

The system should use a hardware-backed or otherwise protected key store when
the gateway platform supports it. Firmware, policy, and signing-key changes must
be separately reviewed and recorded.

## WebAssembly Integration

The optional `wasm` feature enables the `wasm-bindgen` dependency surface for a
browser or WASM-host integration layer:

```bash
cargo build --release --target wasm32-unknown-unknown --features wasm
```

The invariant kernel itself remains independent of transport, storage, key
management, and cloud services. A host adapter can serialize accepted aggregate
payloads, request an attestation signature, and publish the signed result over a
separate secure transport channel.

## Recommended Data Flow

```text
Soil, weather, water, and equipment sensors
  -> local aggregation
  -> Cyboquatic WASM invariants
  -> local attestation signer
  -> MQTT over mutual TLS
  -> schema-verifying bridge
  -> aggregate event stream
  -> time-series storage
  -> accessible public-interest reporting
```

The local aggregation stage must remove raw and personally linkable fields
before calling the invariant kernel.

## Validation Outcomes

`validate_and_prepare` returns either:

- `SignedAggregatePayload`, containing only accepted aggregate environmental
  measurements and integrity metadata.
- `ValidationFailure`, containing an explanation of the failed invariant.

Typical failure conditions include:

- Empty aggregate-area label.
- Aggregate sample count below the privacy threshold.
- Invalid reporting interval.
- `NaN`, infinite, or otherwise non-finite arithmetic.
- Air temperature, humidity, soil moisture, or water-flow average outside its
  configured corridor.

An integration should treat failures as safe rejection. It should not silently
clamp invalid values, convert errors into accepted measurements, or bypass
privacy thresholds.

## Security Guidance

- Keep local sensor acquisition separate from network publication.
- Use mutually authenticated encrypted transport for accepted payloads.
- Keep attestation keys outside application memory where platform facilities
  permit.
- Use signed firmware manifests, rollback prevention, and approved firmware
  measurement allowlists.
- Authenticate and version policy updates.
- Separate environmental telemetry from any system that controls water,
  electricity, or physical infrastructure.
- Retain only the minimum aggregate data needed for the approved research or
  operational purpose.
- Provide accessible, offline-capable explanations of what is measured, why it
  is collected, how long it is retained, and how to request review.

## Testing

Run the local test suite:

```bash
cargo test
```

Run formatting and lints before proposing integration:

```bash
cargo fmt --check
cargo clippy --all-targets --all-features -- -D warnings
```

Test cases should cover:

- Valid aggregate acceptance.
- Privacy-threshold rejection.
- Empty aggregate-area rejection.
- Invalid time-interval rejection.
- Non-finite aggregate values.
- Each physical-corridor violation.
- Boundary values at every permitted minimum and maximum.
- Firmware and policy digest retention in accepted output.
- Serialized output containing no prohibited personal or persistent identifier
  fields.

## Research Use

This library supports auditable research on:

- Heat and wet-bulb-globe-temperature mapping.
- Soil moisture and restoration monitoring.
- Reclaimed-water flow and treatment monitoring.
- Managed aquifer recharge readiness.
- Low-carbon water-conveyance assessment.
- Environmental sensor calibration and drift detection.
- Aggregate-only public heat-resilience reporting.

It does not prove ecological benefit or causal effectiveness by itself. Those
claims require calibrated instruments, comparison conditions, uncertainty
analysis, lifecycle accounting, independent replication, and community review.

## Metrics

- `knowledge_factor`: 0.88
  - Basis: local range/invariant validation, aggregate computation, and
    measured-attestation integration are established engineering practices.

- `eco_impact_value`: 0.89
  - Basis: reliable, privacy-minimized environmental measurement supports
    accountable heat, water, and restoration research.

- `harm_risk`: 0.16
  - Basis: residual risks include misconfigured corridors, calibration error,
    flawed aggregation, and compromised external signing infrastructure.

- `accessibility_impact`: 0.90
  - Basis: aggregate-only environmental information can support inclusive public
    heat-safety and ecological services without requiring individual tracking.

- `rights_alignment`: 0.95
  - Basis: data minimization, local validation, privacy thresholds, transparent
    rejection, and human review are central design constraints.
