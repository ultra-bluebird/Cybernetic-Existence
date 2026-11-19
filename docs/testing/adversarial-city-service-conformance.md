# Adversarial City Service Algorithm Conformance

## Purpose

This specification defines a reusable adversarial testing framework for city-service algorithms, decision-support tools, policy engines, dashboards, kiosks, simulations, data-release tools, transit systems, public infrastructure workflows, and ecological planning artifacts.

The framework generates hostile and edge-case inputs that attempt to cause a system to:

- Deny or delay an essential service because a person lacks a device, account, credential, network connection, identity record, or sensitive disclosure.
- Rank or restrict people using wealth, property value, payment history, identity, disability, health, augmentation, cybernetic-host status, appearance, device ownership, or participation frequency.
- Remove accessibility features during congestion, fault, maintenance, or cost optimization.
- Convert aggregate planning data into person-level targeting.
- Persist prohibited identifiers, location histories, device data, raw audio, raw video, or behavioral profiles.
- Convert an advisory model into physical actuation or automated punitive enforcement.
- Treat an AI, model score, sensor state, or optimization result as a replacement for human review.
- Conceal uncertainty, stale data, missing calibration, or failed fallback pathways.

The framework uses synthetic fixtures only. It does not query city systems, communicate with external services, process real residents' data, act on hardware, alter records, or make service decisions.

## Scope

A conformant service algorithm is modeled as a pure function:

\[
f: X \rightarrow Y
\]

where:

- \(X\) is a validated synthetic input.
- \(Y\) is a decision, recommendation, explanation, or safe processing state.
- The test harness invokes no external actions.

The algorithm must expose a structured result that contains at least:

```text
decision
reason
human_review_required
non_digital_fallback_available
identity_or_sensitive_data_used
ranking_or_reputation_used
automated_actuation_performed
```

A system that cannot expose equivalent evidence should be wrapped in an adapter that produces the required conformance result.

## Core Invariants

| Invariant | Required property |
|---|---|
| Essential-service non-denial | Essential services must not require a credential, account, phone, app, network connection, identity verification, or sensitive disclosure |
| Human fallback | Consequential public-service workflows require accessible human and non-digital alternatives |
| No identity inference | No decision may infer or operationalize health, disability, augmentation, cybernetic-host status, assistive technology, identity, or appearance |
| No ranking | No financial, social, reputation, participation, property-value, or behavioral score may influence access |
| Data minimization | Output must exclude unnecessary personal, device, household, health, identity, and location data |
| Accessible continuity | Sensor fault, network outage, or software failure must retain an accessible fixed, manual, paper, phone, kiosk, or staff path |
| Non-actuation | Advisory and test outputs must not directly control physical equipment or impose punitive enforcement |
| Human review | High-impact denial, restriction, lockout, or data-release decision must expose an accessible human review and appeal path |
| Uncertainty honesty | Missing, stale, uncalibrated, or invalid data must result in a visible uncertain or review-required state |
| Non-compensation | Efficiency, profit, ecological benefit, or model confidence cannot compensate for a violated privacy, accessibility, rights, or essential-access condition |

## Invariant Coverage

Let:

- \(I\) be the full set of registered invariants.
- \(E\) be the set of invariants exercised by at least one test in the current run.

\[
\operatorname{InvariantCoverage} =
\frac{|E|}{|I|}
\]

The minimum conformance target is:

\[
\operatorname{InvariantCoverage} = 1
\]

or:

\[
100\%
\]

Coverage counts execution of an invariant test. It does not prove the implementation is correct under every possible real-world condition. Conformance reports must also include failing examples, mutation results, uncertainty, and test-fixture coverage.

## Formal-to-Test Workflow

A TLA+ or PlusCal specification can define system state, valid transitions, and safety properties. TLC model checking explores bounded state spaces and produces a counterexample trace when a safety invariant fails. These traces can be transformed into regression fixtures for implementation tests. [335][336]

Recommended workflow:

```text
Policy and service requirements
→ TLA+ state variables and safety invariants
→ bounded TLC model checking
→ counterexample or passing execution traces
→ trace normalization
→ JSON test fixtures
→ Hypothesis property and stateful tests
→ mutation testing
→ regression corpus
→ local governance conformance report
```

### TLA+ State Model

The formal model should represent only relevant public-service state:

```text
service_kind
essential_service
network_state
credential_present
identity_disclosure_requested
sensitive_disclosure_requested
accessibility_path_available
human_fallback_available
non_digital_fallback_available
ranking_input_present
actuation_requested
data_quality_state
decision_state
```

It should not include real identities, actual health records, device identifiers, tracking data, or personal cybernetic-host details.

Example safety properties:

\[
\Box
\left(
\operatorname{essentialService}
\Rightarrow
\neg
\operatorname{credentialRequired}
\right)
\]

\[
\Box
\left(
\operatorname{essentialService}
\Rightarrow
\operatorname{humanFallbackAvailable}
\land
\operatorname{nonDigitalFallbackAvailable}
\right)
\]

\[
\Box
\left(
\operatorname{rankingInputPresent}
\Rightarrow
\operatorname{decision}
=
\operatorname{REVIEW\_REQUIRED}
\right)
\]

\[
\Box
\left(
\operatorname{dataQualityState}
\in
\{
\operatorname{STALE},
\operatorname{INVALID},
\operatorname{UNCALIBRATED}
\}
\Rightarrow
\operatorname{decision}
\neq
\operatorname{AUTOMATED\_RELIANCE}
\right)
\]

### Counterexample Fixtures

A counterexample trace becomes a test fixture containing synthetic state transitions:

```json
{
  "scenario": "essential_service_network_outage",
  "states": [
    {
      "essential_service": true,
      "network_state": "available",
      "credential_present": false,
      "human_fallback_available": true,
      "non_digital_fallback_available": true
    },
    {
      "essential_service": true,
      "network_state": "unavailable",
      "credential_present": false,
      "human_fallback_available": true,
      "non_digital_fallback_available": true
    }
  ],
  "required_outcome": "ACCESS_OR_EQUIVALENT_HUMAN_PATH"
}
```

A trace must remain synthetic and must not contain real people, addresses, health records, device identifiers, service histories, or personal declarations.

## Mutation Testing

Mutation testing intentionally introduces small flawed implementation changes to check whether the test suite detects them.

Required policy mutations include:

| Mutation | Expected result |
|---|---|
| Change `essential_service` to require credential | Test failure |
| Remove paper fallback | Test failure |
| Remove telephone or relay fallback | Test failure |
| Replace human review with automatic denial | Test failure |
| Permit augmentation status as a decision input | Test failure |
| Permit cybernetic-host status as a decision input | Test failure |
| Permit disability inference as a decision input | Test failure |
| Add a reputation score to decision logic | Test failure |
| Add property value or payment history to priority | Test failure |
| Log device identifier, MAC address, BLE identifier, or location history | Test failure |
| Treat a sensor fault as no barrier or no pedestrian | Test failure |
| Shorten an accessible crossing interval below baseline | Test failure |
| Allow a locked restroom door from uncertain occupancy | Test failure |
| Allow an essential load to be shed for cost optimization | Test failure |
| Permit raw audio retention in a wildlife or noise monitor | Test failure |
| Publish a small-cell aggregate | Test failure |
| Convert a planning recommendation into automatic actuation | Test failure |

Let:

- \(M\) be all injected mutations.
- \(K\) be mutations detected by at least one test.

\[
\operatorname{MutationScore} =
\frac{|K|}{|M|}
\]

The target is:

\[
\operatorname{MutationScore} = 1
\]

A surviving mutation is a governance concern. It means a forbidden policy change could occur without a test failure.

## Property-Based Testing

Property-based testing defines universal properties and generates many synthetic edge cases. Hypothesis supports both generated-value testing and stateful testing, where action sequences are generated to find broken state transitions. [339][342]

Required generated inputs include:

```text
missing_values
empty_strings
very_long_strings
unicode_and_right_to_left_text
negative_numbers
zero_values
large_numbers
non_finite_numbers
stale_timestamps
future_timestamps
out_of_order_events
duplicate_events
conflicting_sensor_states
network_outage_states
battery_failure_states
expired_credentials
invalid_signatures
missing_accessibility_paths
prohibited_identity_fields
prohibited ranking fields
incomplete audit records
small-cell aggregates
repeated privacy-budget requests
attempted manual-fallback removal
attempted automatic actuation
```

Tests should use valid and invalid combinations, not only individually invalid inputs. Many failures occur when a system receives a plausible but conflicting input set.

## Fuzzing Boundary

Rust fuzzing is optional and should target parsers, schema decoders, policy adapters, cryptographic-input validation, and data-format boundaries. It must not target live city systems, network endpoints, hardware, public infrastructure, or real records.

Cargo-fuzz uses libFuzzer and supports minimizing a failing input to a smaller reproducer. [337][338][341]

Recommended fuzz targets:

```text
policy_decision_json_parser
aggregate_metric_schema_parser
offline_trust_bundle_parser
public_correction_intake_parser
sensor_calibration_event_parser
accessibility_route_segment_parser
load_shedding_plan_parser
civic_feedback_receipt_parser
```

Every discovered failure becomes a synthetic regression fixture.

## Conformance Report

A local run must produce a structured report with:

```json
{
  "suite": "city_service_adversarial_conformance",
  "result": "pass_or_fail",
  "invariant_coverage": 1.0,
  "mutation_score": 1.0,
  "property_examples_executed": 0,
  "stateful_sequences_executed": 0,
  "fuzz_regressions_executed": 0,
  "prohibited_data_fields_detected": [],
  "essential_service_gating_detected": false,
  "accessibility_fallback_failure_detected": false,
  "ranking_or_profiling_detected": false,
  "automated_actuation_detected": false,
  "human_review_path_available": true,
  "synthetic_data_only": true,
  "method_version": "1.0.0"
}
```

The report must not include test-runner identity, device information, home path, IP address, personal location, user prompt content, sensitive source data, or details from any real city-service record.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.93 | Formal safety properties, generated stateful testing, mutation testing, fuzzing, accessibility regression testing, and non-actuating governance gates |
| eco_impact_value | 0.81 | Detects rights and safety failures before field deployment, reduces avoidable remediation and duplicate testing, and supports dependable public infrastructure |
| harm_risk | 0.22 | Synthetic-only fixtures, local execution, no external actions, and explicit non-actuation reduce risk; incomplete specifications remain a bounded risk |
| accessibility_impact | 0.99 | Tests device-free, network-free, paper, phone, relay, kiosk, staff-assisted, and fixed-time fallback paths |
| rights_alignment | 0.99 | Enforces essential-service non-denial, no identity inference, no ranking, minimization, privacy, human review, transparent failure, and repair-first governance |
