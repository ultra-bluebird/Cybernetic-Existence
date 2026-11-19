# Non-Discrimination, Maintenance Review, and Gathering Accessibility

This artifact set defines policy and decision-support rules. It does not create legal rights, determine disability status, make eligibility decisions, control machinery, or replace qualified safety, accessibility, engineering, or legal review.

## Cybernetic-Host Non-Discrimination Policy Fields

An ALN v2 policy must declare:

- `protected_characteristics`: Includes self-asserted cybernetic, augmented, assistive-technology, implant, wearable, interface, and non-augmentation status.
- `prohibited_decisions`: Denial, delay, pricing difference, service restriction, retaliation, profiling, or reduced access based on protected characteristics.
- `sensitive_data_classes`: Neural, biometric, health, augmentation, device telemetry, identity, and location data.
- `purpose_limitation`: Each data use must name one specific documented purpose.
- `consent_scope`: Explicit, informed, granular, revocable consent for any optional sensitive-data processing.
- `data_minimization`: No collection, inference, or retention beyond what the declared purpose requires.
- `access_correction_export_deletion`: Accessible routes to inspect, correct, export, delete, or contest records where technically feasible and appropriate.
- `appeal_path`: Human-reviewed, accessible, non-retaliatory, and time-bounded.
- `audit`: Privacy-preserving decision records with no raw sensitive data.
- `human_oversight`: Required for adverse, high-impact, or access-affecting decisions.
- `essential_service_protection`: Essential civic, health, mobility, sanitation, water, and accessibility services cannot depend on optional telemetry, augmentation status, or unrelated consent.

The policy is a governance requirement for systems using it. It is not a claim about enforceable law without jurisdiction-specific review.

## Maintenance-Bot Heat and Impact Review

Use per-machine, commissioned local values:

- `energyreq_j`
- `local_energy_budget_j`
- `delta_vt`
- `local_abs_delta_vt_heat_threshold`
- `harm_risk_r`
- `reviewer_available`
- `interlocks_verified`

Decision:

`DEFER_TO_HUMAN_REVIEW` if:

- `energyreq_j > local_energy_budget_j`
- `abs(delta_vt) > local_abs_delta_vt_heat_threshold`
- `harm_risk_r > 0.30`
- Human review is unavailable.
- Required interlocks are unverified.

Otherwise return `WITHIN_LOCAL_REVIEW_BOUNDS`.

Neither result authorizes movement, actuation, tool use, or physical maintenance. Thresholds must be established through qualified commissioning, local environmental limits, equipment documentation, and worker-safety procedures.

## Gathering-Hub Accessibility Score

Record only facility and aggregate-service attributes:

- `entrance_clear_width_m`
- `required_entrance_clear_width_m`
- `ramp_slope_ratio`
- `shade_score_0_1`
- `seating_score_0_1`
- `transit_proximity_score_0_1`
- `route_continuity_score_0_1`
- `information_access_score_0_1`

No names, device IDs, precise person location, biometrics, neural data, visitor histories, face images, or identity inference are permitted.

Component scores:

`entrance_score = clamp01(entrance_clear_width_m / required_entrance_clear_width_m)`

`ramp_score = 1 when ramp_slope_ratio <= 1/12, otherwise 0`

`hub_accessibility_score = 0.25*entrance_score + 0.15*ramp_score + 0.15*shade_score + 0.15*seating_score + 0.15*transit_proximity_score + 0.10*route_continuity_score + 0.05*information_access_score`

Publish component scores and missing-data status. Do not use a composite score to hide a failed essential access feature; if entrance, route continuity, or required ramp conditions fail, return `ACCESSIBILITY_REVIEW_REQUIRED`.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.88 | Explicit data classes, purpose, review, and bounded formulas |
| eco_impact_value | 0.77 | Limits waste heat and directs inclusive public-space improvements |
| harm_risk | 0.13 | Non-actuation, privacy constraints, and human-review gates |
| accessibility_impact | 0.95 | Facility-level access measurement without visitor surveillance |
| rights_alignment | 0.97 | Explicit non-discrimination, consent, minimization, and appeal |
