# Corridor Drift, Identity Protection, and Door Accessibility

This artifact set is decision support only. It does not actuate machinery, determine legal identity, deny access, collect biometric data, or perform continuous surveillance.

## Corridor-calibration drift FSM

The detector consumes discrete calibration observations. It retains only the FSM state, the consecutive exceedance count, and an audit event; it does not require continuous telemetry.

Residual:

`residual = abs(observed - reference) / tolerance`

A sample exceeds the corridor when `residual > 1.0`.

States:

- `UNINITIALIZED`: No valid sample accepted.
- `NOMINAL`: Most recent accepted condition is within the calibration corridor.
- `SUSPECT`: One or more consecutive residual exceedances, fewer than `N`.
- `DRIFT_LOCKOUT`: At least `N` consecutive exceedances. The output is fail-closed and requires a documented manual calibration review.
- `INVALID_INPUT_LOCKOUT`: Invalid, non-finite, or non-positive-tolerance input. The output is fail-closed.

Transitions:

- Valid residual `<= 1.0`: transition to `NOMINAL`; reset count to zero.
- Valid residual `> 1.0`: increment consecutive exceedance count.
- Count `< N`: transition to `SUSPECT`.
- Count `>= N`: transition to `DRIFT_LOCKOUT`.
- Any invalid input: transition to `INVALID_INPUT_LOCKOUT`.

The FSM never sends commands to an actuator. `DRIFT_LOCKOUT` means that a downstream system must not rely on the affected measurement for automated environmental decisions until accessible human review and recalibration are documented.

## Acceptance-pattern fairness

A declared identity requires no technical proof, biological evidence, device inspection, neural measurement, or third-party authentication to receive respectful, non-discriminatory treatment.

The rule in this bundle evaluates only whether a declaration is coherent enough for a system to apply protection commitments. It must not be used to reject a person, score credibility, classify identity, or determine legal status.

A declaration is protection-eligible when:

- It is voluntarily supplied or represented by a trusted accessibility interface.
- It contains a non-empty self-description.
- Its declared constraints do not request harm, coercion, exclusion, or rights deprivation for other people.
- It does not require sensitive-data collection or identity verification.

The default on uncertainty is `PROTECT_WITHOUT_ADJUDICATION`: preserve access, respectful address, accessible appeal, and protection from discrimination.

## Automatic-door accessibility model

The controller configuration must use a locally validated, anonymous crossing-time distribution. It must not identify, classify, or track wheelchair users, older adults, cybernetic hosts, disabled people, or any other person.

Inputs:

- `minimum_safe_open_duration_ms`: Site safety baseline validated by the door manufacturer, authority having jurisdiction, and applicable accessibility requirements.
- `anonymous_crossing_times_ms`: A configuration dataset collected through voluntary usability testing, synthetic validation, or non-identifying aggregate facility studies.
- `quantile`: Conservative quantile such as 0.95.
- `safety_margin_ms`: Additional time for approach, maneuvering, and variable mobility conditions.
- `maximum_open_duration_ms`: A site-specific bound validated against fire, security, energy, and manufacturer requirements.

Calculation:

`recommended_open_duration_ms = clamp(max(minimum_safe_open_duration_ms, quantile(crossing_times, 0.95) + safety_margin_ms), minimum_safe_open_duration_ms, maximum_open_duration_ms)`

If the configuration is invalid or data are missing, the model returns `MANUAL_CONFIGURATION_REVIEW_REQUIRED`. It never shortens a door-open duration below the validated accessibility baseline.

## Impact metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.88 | Explicit state transitions, bounded inputs, and documented policy limits |
| eco_impact_value | 0.62 | Event-driven sensing and bounded door-open duration reduce avoidable energy use |
| harm_risk | 0.14 | No actuation, no identity adjudication, no biometric processing, fail-closed outcomes |
| accessibility_impact | 0.93 | Conservative timing, universal access framing, human review, and non-discriminatory defaults |
| rights_alignment | 0.95 | Self-asserted identity, privacy minimization, equal access, and accessible review paths |
