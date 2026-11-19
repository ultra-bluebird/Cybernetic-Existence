# Augmented-Hub C++ Architecture Guide

This directory contains C++20/C++23 implementation components for Augmented-Hub environmental telemetry, validation, governance integration, accessible civic infrastructure, resilience planning, and safety assurance.

The C++ layer converts authenticated, purpose-bound environmental observations into reproducible calculations and controlled decision-support outputs. It does not grant authority for irreversible external actions, personal ranking, identity assessment, behavioral surveillance, or loss of access to essential services.

## Purpose

C++ components in this directory support the project’s three-tier Cyboquatic Telemetry architecture:

1. **Telemetry Envelope Contract**  
   Represents a versioned environmental observation with provenance, quality, units, calibration lineage, uncertainty, purpose, publication boundary, and review status.

2. **Validation Kernel Contract**  
   Executes reproducible physical, statistical, energy, calibration, and safety calculations. It preserves input provenance and uncertainty rather than hiding them.

3. **Governed Impact Shard**  
   Packages validated outputs into bounded, explainable, reviewable evidence for planning and accountable governance. A shard is evidence, not an automatic action command.

The architecture is reusable across Cyboquatic Telemetry, heat-relief infrastructure, gathering hubs, transit equity, accessible paths, maintenance operations, distributed energy, and public-assistance systems.

## Core Principles

### Evidence before claims

Every environmental or infrastructure claim must be traceable to:

- A typed input observation.
- A stated measurement unit.
- A timestamp and applicable time interval.
- Calibration and uncertainty evidence.
- A deterministic or documented stochastic calculation.
- A validation status and plain-language explanation.
- A policy and review reference when the result is published or used for planning.

Do not fabricate sensor values, calibration results, ecological benefits, predicted outcomes, approval states, or external action receipts.

### Safety before automation

Safety-critical systems must use a verified control boundary that remains authoritative over machine-learning outputs.

Examples:

- A gesture model may request a door opening or assist mode.
- A gesture model may not directly energize a motor.
- Independent presence sensors, safety edges, interlocks, watchdogs, and emergency stop controls remain authoritative.
- Loss of safety evidence transitions the system to a safe state, such as `safe_open`, `halted`, or `degraded_hold_for_review`.
- Machine-learning uncertainty, timeout, disagreement, stale input, or out-of-envelope output results in non-action or verified fallback behavior.

### Accessibility as capability

Accessible interaction is a first-class system capability.

A voluntary accessibility preference may adapt:

- Output format.
- Input method.
- Pacing.
- Language presentation.
- Text-to-speech or captioning.
- Keyboard, switch, voice, or alternate controls.
- Offline synchronization.
- Accessible authentication alternatives.
- Accessible review and correction pathways.

Accessibility preferences must not affect:

- Eligibility.
- Ecological evidence weight.
- Civic-service priority.
- Credibility.
- Reputation.
- Rights of access.
- Appeal rights.
- Identity assessment.

### Identity-agnostic decisions

Environmental, civic, transit, repair, planning, maintenance, and accessibility decisions must not depend on:

- Claimed identity.
- Identity status.
- Augmentation status.
- Cybernetic-host status.
- Assistive-technology status.
- Biometric, neural, health, or disability-related information.
- Private learning-continuity information.
- Absence of optional telemetry.
- Absence of continuous connectivity.
- Absence of external identity verification.
- Use or non-use of a proprietary device.

The system may support respectful self-description in user-controlled presentation contexts. It must not require certification or disclosure of self-description for access to essential functionality.

### Preserve raw evidence

Never overwrite raw telemetry with a derived correction.

When a drift model or neighboring-sensor calculation suggests a corrected value:

1. Preserve the original observation.
2. Store the correction as a separate candidate result.
3. Link it to its inputs, method version, uncertainty, and policy reference.
4. Use `hold_for_review` or equivalent status when required.
5. Promote a corrected value only through the applicable validation and governance workflow.

## C++ Design Rules

### Public interfaces and implementation

Use a paired interface and engine layout for non-template components:

```text
cpp/
  component_name.hpp
  component_name.cpp
tests/
  component_name_tests.cpp
```

- `.hpp` files define public types, enums, documented invariants, and function declarations.
- `.cpp` files contain non-template implementations and internal helpers.
- `tests/` contains executable conformance tests.
- Keep headers lightweight and avoid exposing internal algorithms unnecessarily.
- Use include guards with a stable project prefix.

Example:

```cpp
#ifndef AUGMENTED_HUB_COMPONENT_NAME_HPP
#define AUGMENTED_HUB_COMPONENT_NAME_HPP

namespace augmented_hub::domain {

struct Result {
    double value{};
};

}  // namespace augmented_hub::domain

#endif
```

### Namespaces

Use a focused nested namespace:

```cpp
namespace augmented_hub::sensor_fusion {
}

namespace augmented_hub::assurance {
}

namespace augmented_hub::urban_equity {
}
```

Avoid `using namespace` directives in headers.

### Error handling

Use `std::expected<T, Error>` for recoverable validation, policy, arithmetic-domain, and data-quality failures.

```cpp
enum class KernelError {
    empty_input,
    invalid_numeric_input,
    incompatible_unit,
    policy_denied
};

[[nodiscard]] std::expected<Result, KernelError> compute(
    const Input& input);
```

Use these conventions:

- Mark result-producing functions `[[nodiscard]]`.
- Return typed errors instead of exceptions for ordinary invalid external inputs.
- Validate all externally supplied numeric fields for finiteness and domain limits.
- Treat `NaN`, infinity, negative uncertainty, impossible interval order, incompatible units, and out-of-policy input as explicit errors.
- Include a plain-language explanation in successful governance-facing results.
- Do not encode sensitive values into error text or logs.

### Numeric safety

Environmental, power, geometry, and timing code must validate numerical assumptions.

At minimum:

- Check `std::isfinite()` for externally supplied floating-point values.
- Check non-negativity for variances, uncertainty, power, distances, energy, and durations.
- Check closed unit intervals for probabilities, normalized scores, and efficiencies.
- Preserve units in field names where practical, such as `flow_m3_per_s`, `energy_kwh`, `temperature_celsius`, and `timestamp_seconds`.
- Use `constexpr` constants for physical or policy values that are genuinely fixed in the kernel.
- Make deployment-specific thresholds configurable through typed policy structures.
- Clamp only where clamping is an explicit policy decision; otherwise return a typed error or a review status.

### Determinism and reproducibility

Validation kernels should be deterministic when supplied identical inputs and policy versions.

A result intended for review or publication should retain:

- Input artifact identifiers or hashes.
- Algorithm or formula version.
- Policy version.
- Timestamp or evaluation interval.
- Units.
- Assumptions.
- Uncertainty method.
- Validation state.
- Human-readable explanation.

Avoid hidden global state, wall-clock reads inside pure kernels, network calls, mutable static caches, and untracked random behavior.

If stochastic computation is necessary:

- Accept the seed or random-source configuration explicitly.
- Record the distributional assumptions.
- Record sample count, convergence criterion, and uncertainty interval.
- Return an uncertainty-aware result.
- Keep stochastic output advisory until review requirements are satisfied.

## Architecture Boundaries

### Telemetry boundary

The telemetry boundary admits environmental and infrastructure data necessary for stated purposes.

Typical allowed categories:

- Water flow, head, temperature, conductivity, pH, turbidity, and contaminant concentration.
- Air quality, thermal exposure, shading, lighting, noise, and energy readings.
- Sensor calibration, uncertainty, health, drift, and timing records.
- Environmental asset and equipment operational state.
- Aggregate, non-identifying facility and transit service outcomes.
- Aggregate accessibility-infrastructure condition data.

The telemetry boundary does not admit personal identity, health, biometric, neural, behavioral, or assistive-device telemetry unless a distinct, voluntary, purpose-limited subsystem is explicitly designed and approved. Such data must never be joined to environmental scoring or essential-service eligibility.

### Validation boundary

Validation kernels may:

- Check units and physical plausibility.
- Compute mass balance, energy budget, coupling efficiency, uncertainty, drift candidates, timing alignment, and calibrated metrics.
- Compare measurements with explicit spatial-gradient and uncertainty models.
- Produce a `hold_for_review` result.
- Produce planning evidence.
- Produce a policy-denial or validation-failure receipt.

Validation kernels may not:

- Invent missing measurements.
- Convert uncertain findings into assured outcomes.
- Change raw evidence in place.
- Dispatch a bot, unlock a door, change transit service, or modify public access.
- Evaluate a person’s identity, value, status, or credibility.

### Governance boundary

Governed outputs must include a separate external-action state.

Recommended states:

```text
prohibited
informational_only
requires_separate_approval
approved_for_bounded_action
```

A calculation, recommendation, impact shard, or generated question is not sufficient authorization for a physical action.

A separately approved action must contain:

- The exact action scope.
- The responsible role.
- The specific evidence references.
- The applicable policy version.
- The time limit or expiry condition.
- Accessibility and ecological-impact considerations.
- Human approval records.
- A review, appeal, or correction path.

## Environmental and Ecological Kernels

Many C++ components are based on direct, auditable physical relationships.

### Hydraulic power

```text
P_hydro = rho_water * g * Q * H
```

Where:

- `rho_water` is water density.
- `g` is gravitational acceleration.
- `Q` is volumetric flow rate.
- `H` is hydraulic head.

Use explicit SI units and record uncertainty in flow, head, density assumptions, and measurement interval.

### Wind power

```text
P_wind = 0.5 * rho_air * rotor_area * Cp(wind_speed) * wind_speed^3
```

Record the power-coefficient model, rotor geometry, air-density assumption, wind-speed uncertainty, and time interval.

### Coupling efficiency

```text
eta_couple = integral(P_hydro dt) / integral(P_wind dt)
```

The result is dimensionless and should be bounded from 0 to 1 when the model assumptions support that interpretation. Unexpected values are a validation condition, not a value to silently clip.

### Contaminant mass removal

```text
M_x = integral((C_in_x - C_out_x) * Q dt)
```

The resulting unit is mass when concentration, flow, and time units are consistent. Preserve:

- Inlet and outlet measurement provenance.
- Flow source and calibration status.
- Integration method.
- Missing-data handling.
- Uncertainty propagation.
- Relevant contaminant identifier.

The C++ layer should make conservation checks and unit consistency transparent. Existing project material grounds this pattern in physically measurable energy, flow, concentration, and mass-balance quantities that can be independently validated. [51]

## Sensor Fusion and Calibration

### Multi-modal fusion

Fuse water quality, air quality, thermal, acoustic, LiDAR, camera, and related observations only after confirming:

- Time-alignment quality.
- Compatible measurement meaning.
- Spatial or corridor relationship.
- Calibration state.
- Uncertainty bounds.
- Policy-permitted use.

A sensor-fusion event candidate should be reviewable evidence, not an automatic command.

Recommended output fields:

```text
posterior_event_probability
aligned_modalities
timestamp_uncertainty
calibration_status
evidence_status
plain_language_explanation
```

### Drift monitoring

Neighbor disagreement is not automatically drift.

A drift assessment should account for:

1. Time synchronization.
2. Same-phenomenon and same-unit checks.
3. Expected local spatial gradient.
4. Combined sensor uncertainty.
5. Neighbor correlation weights.
6. Calibration currency.
7. Independent corroboration.
8. Persistence over time.
9. Environmental context, such as temperature, humidity, fouling, or weather.

Use a sequence such as:

```text
raw observation
  -> spatial and temporal consistency test
  -> drift candidate
  -> corrected candidate value
  -> validation/review
  -> approved calibrated metric or retained raw evidence
```

### Extrinsic alignment

LiDAR, camera, thermal, and acoustic systems require a versioned transform with evidence of:

- Translation residual.
- Rotation residual.
- Static feature or target availability.
- Time alignment.
- Vibration exposure.
- Thermal delta.
- Inlier ratio.
- Transform and calibration version.

For a 5 mm LiDAR-to-camera fusion target, performance-based residual checks should be authoritative. Time-based and vibration/thermal triggers provide additional early warning.

Do not apply a transform update when evidence is dominated by pedestrians, moving vehicles, vegetation motion, or other dynamic features. Use static landmarks, approved calibration targets, or a qualified static-scene process.

## Power and Resilience

### Common bus design

A regulated bus is not the arithmetic mean of input voltages. It is the outcome of controlled power flow, storage state, current limits, source availability, and converter control.

Use source-specific front ends:

| Source | Typical front end |
|---|---|
| Solar DC | MPPT buck, boost, or buck-boost |
| Piezoelectric AC | Active or synchronous rectifier with energy-extraction/impedance matching |
| Thermal DC | Ultra-low-voltage cold-start boost |
| Regenerative braking AC | Three-phase rectification with managed capture, storage buffering, and overvoltage protection |

Use dedicated point-of-load stages for:

- 3.3 V sensor electronics.
- 12 V lighting.
- 24 V controllers and actuators.
- 48 V assistance panels or kiosk hardware.

### Power safety

Power code should model and expose:

- Available source power.
- Converter efficiency.
- Switching, conduction, magnetic, and control losses.
- Temperature derating.
- Storage availability.
- Essential and sheddable loads.
- Bus-power sufficiency.
- Thermal operating limits.
- Voltage and current protection state.

Essential accessibility and safety loads must not be shed as a routine energy-optimization action. Examples include safe door operation, emergency communications, assistance panels, accessible wayfinding, and critical lighting.

## Safety-Critical Automation

### Authority model

For safety-critical infrastructure, authority is ordered as follows:

1. Physical emergency stop.
2. Independent presence and safety sensors.
3. Certified or verified safety interlocks.
4. Verified finite-state controller.
5. Runtime watchdog and health checks.
6. Human approval and maintenance procedure.
7. Machine-learning recommendations.
8. Non-safety optimization logic.

Lower-authority components cannot override higher-authority components.

### Required fail-safe behavior

When any of the following occurs, transition to a safe state:

- Emergency stop is pressed.
- A person is detected in a protected motion area.
- Independent safety sensing is unhealthy.
- A watchdog heartbeat expires.
- The verified controller is unavailable.
- A machine-learning output is stale, uncertain, unavailable, malformed, or outside its safe envelope.
- A required calibration or transform is invalid.
- A safety-critical policy gate cannot be evaluated.

Safe states include:

```text
safe_open
halted
restricted
degraded_hold_for_review
```

### Formal properties

Safety properties should be represented in a model-checkable form and mirrored in C++ tests and runtime monitors.

Examples:

```text
Always: person_detected implies not door_closing.

Always: emergency_stop_pressed implies eventually halted or open.

Always: assist_mode_requested implies eventually assist_mode or open.

Always: invalid_safety_evidence implies not autonomous_motion_permitted.
```

Machine learning may recommend an action but must be wrapped in a bounded command adapter that enforces the verified controller’s authority.

## AI Workload Components

AI question generators are planning and diagnostic tools. They generate structured questions from evidence contexts; they do not answer with fabricated data and do not authorize actions.

A generated question should carry:

- Stable question identifier.
- Question category.
- Telemetry or aggregate-evidence references.
- Calibration and uncertainty information.
- Policy reference.
- Safety constraints.
- Accessibility requirements.
- Ecological constraints.
- External-action status.
- Required evidence.
- Prohibited assumptions.
- Human-review requirement.

Generated questions must not request or depend on:

- Individual tracking.
- Identity inference.
- Facial recognition.
- Gait analysis.
- Biometric classification.
- Device fingerprinting.
- Private continuity information.
- Personal route history.
- Optional assistive-technology telemetry.

## Social and Civic Metrics

Social, transit, gathering-hub, and accessibility metrics are aggregate planning evidence.

They may measure:

- Accessibility-function availability.
- Wait-time equality.
- Affordable service outcomes.
- Accessible-stop coverage.
- Facility uptime.
- Barrier-resolution outcomes.
- Aggregate participation pathways.
- Ecological contribution.
- Service reliability.
- Maintenance response quality.

They may not:

- Rank people.
- Determine social worth.
- Infer or verify identity.
- Score personal dignity, belonging, or contribution.
- Reduce service because a feature has low observed use.
- Use identity-linked information as a proxy for service priority.

Low usage of an accessible route, assistance panel, or service does not establish that the service is unnecessary. Essential access remains a design and governance requirement.

## Testing Requirements

Every production component should include focused tests.

Minimum test coverage:

- Valid nominal input.
- Empty input.
- Invalid numeric input.
- Unit or semantic incompatibility.
- Timestamp-order or timing-budget violation.
- Calibration or provenance failure.
- Policy-denial path.
- Safety fallback path when applicable.
- Accessibility-preserving behavior.
- No identity-linked decision path.
- Plain-language explanation presence for governance-facing results.

For code that affects safety or physical infrastructure, add:

- Boundary-value tests.
- Property tests where useful.
- Replayable input fixtures.
- Watchdog timeout tests.
- Sensor disagreement and missing-data tests.
- Model-version compatibility tests.
- Regression tests for prior incidents or discovered defects.

Example test intent:

```cpp
const auto result = evaluate_layered_safety(
    SafetyMode::normal,
    SafetyEvent::person_detected,
    inputs,
    watchdog_policy);

assert(result.has_value());
assert(!result->autonomous_motion_permitted);
assert(result->next_mode == SafetyMode::safe_open);
```

## Build Expectations

C++ components should compile under the project’s configured C++ standard. Prefer C++23 when `std::expected` is required directly; otherwise use the project-approved equivalent compatibility layer.

Use a strict warning profile in CI:

```cmake
target_compile_options(target_name
    PRIVATE
        $<$<CXX_COMPILER_ID:Clang,GNU>:-Wall -Wextra -Wpedantic -Wconversion>
        $<$<CXX_COMPILER_ID:MSVC>:/W4 /permissive->
)
```

Recommended development checks:

```text
configure and build
run unit tests
run static analysis
run sanitizer-enabled test build where supported
verify generated policy/schema compatibility
review provenance and safety test coverage
```

Do not add a new dependency without documenting:

- Purpose.
- License compatibility.
- Security maintenance posture.
- Platform support.
- Data or network behavior.
- Whether it is used in a safety or privacy boundary.

## Coding-Agent Workflow

When adding or extending a C++ component:

1. Read the relevant policy, schema, telemetry contract, and prior test fixtures.
2. State the domain scope and non-goals in the public header or accompanying documentation.
3. Define strongly typed inputs and outputs with explicit units.
4. Validate numeric, temporal, provenance, and policy boundaries.
5. Keep core calculations deterministic and side-effect free.
6. Return typed errors for invalid input and explicit review states for uncertain but retained evidence.
7. Preserve raw evidence and derivations separately.
8. Add a plain-language explanation to planning, governance, and safety outputs.
9. Write conformance tests for safety, privacy, accessibility, and policy invariants.
10. Do not add implicit external action, network communication, device control, or data export.
11. Ensure a separately approved adapter exists before any real-world actuation is introduced.
12. Report the component’s knowledge, ecological, harm-risk, accessibility, and rights-alignment metrics in the associated documentation or governed artifact.

## Review Checklist

Before proposing a merge, verify:

### Evidence and correctness

- Are all input units and ranges explicit?
- Are non-finite values rejected?
- Are uncertainty and calibration states preserved?
- Are raw and corrected values separate?
- Is the calculation reproducible from its stated inputs?
- Are source assumptions and thresholds configurable and versioned?

### Privacy and autonomy

- Does the component avoid identity, biometric, neural, health, behavior, and private continuity data?
- Does it avoid individual tracking and social scoring?
- Does it require only minimum necessary environmental or aggregate civic data?
- Can optional preference data adapt interaction without changing rights or eligibility?
- Does it avoid external network access unless a separate approved integration explicitly requires it?

### Safety and accessibility

- Does a safety-critical component have an independent safety boundary?
- Are watchdog, timeout, sensor-health, and fallback states tested?
- Does an ML component remain advisory and bounded?
- Are accessible routes, alternate interfaces, and essential service continuity preserved?
- Does the output contain an accessible plain-language explanation and review path?

### Governance and ecology

- Is the external-action status explicit?
- Are irreversible actions separated from analysis and recommendations?
- Are ecological claims measured rather than asserted?
- Are nuisance, energy, material, water, maintenance, and accessibility effects considered where relevant?
- Does the artifact preserve an auditable pathway for review, appeal, and correction?

## Metrics Convention

Substantive C++ components should report these normalized values from 0 to 1 with a short basis:

| Metric | Meaning |
|---|---|
| `knowledge_factor` | Strength of provenance, calibration, reproducibility, validation, and uncertainty treatment |
| `eco_impact_value` | Potential for measurable ecological restoration, efficiency, waste reduction, or environmental resilience |
| `harm_risk` | Likelihood and severity of foreseeable privacy, safety, accessibility, ecological, or social harm after mitigations |
| `accessibility_impact` | Contribution to equivalent access, interoperable interaction, accessible review, and assistive-technology compatibility |
| `rights_alignment` | Alignment with autonomy, privacy, consent, non-discrimination, explainability, human review, and civic participation |

These values are planning and governance signals. They do not score people, identities, or personal worth.

## Maintainer Intent

This directory is designed to make environmental and civic infrastructure more verifiable, repairable, accessible, privacy-preserving, and accountable.

When there is uncertainty:

- Keep evidence.
- State the uncertainty.
- Use `hold_for_review` when appropriate.
- Preserve accessible service continuity.
- Prefer reversible, bounded, and explainable behavior.
- Build the smallest complete component that strengthens the existing architecture.
