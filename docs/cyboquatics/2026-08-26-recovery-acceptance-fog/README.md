# Recovery, Acceptance, and FOG Review Metrics

This artifact set defines three decision-support metrics for ecological restoration. It does not make automated eligibility, enforcement, policing, tenancy, insurance, employment, service-access, or identity decisions.

## 1. Heat-Island Recovery Corridor Metric

### Minimum physical measurement set

Measure each quantity over the same public, non-residential sensing zone and time window:

1. `night_air_temperature_delta_c`: Corridor air temperature at 1.5–2.0 m minus a locally appropriate reference, collected during the nighttime window.
2. `albedo_delta`: Change in area-weighted shortwave reflectance of treated public surfaces relative to the pre-intervention baseline.
3. `canopy_shade_fraction`: Fraction from 0 to 1 of pedestrian-relevant public-route area receiving tree or shade-structure coverage during the defined local heat window.
4. `evapotranspiration_proxy`: A normalized 0–1 proxy based on vegetation condition and local moisture or sap-flow evidence; it must never identify households or people.
5. `airflow_obstruction_factor`: A normalized 0–1 obstruction estimate. Zero means no meaningful obstruction relative to baseline; one means the defined corridor is fully obstructed.

Do not infer cooling from surface temperature alone. Surface temperature, air temperature, wind, humidity, and shade measure distinct conditions and should remain separately auditable.

### Cooling potential

Let:

- `A = clamp01(albedo_delta / 0.25)`
- `V = clamp01(0.60 * canopy_shade_fraction + 0.40 * evapotranspiration_proxy)`
- `F = clamp01(1.0 - airflow_obstruction_factor)`

Compute:

`cooling_potential = clamp01(0.25 * A + 0.55 * V + 0.20 * F)`

The weights are a transparent planning prior, not universal coefficients. Calibrate them using held-out local nighttime observations before operational use.

### Observed recovery

`observed_night_cooling_score = clamp01((-night_air_temperature_delta_c) / target_night_cooling_c)`

where `target_night_cooling_c > 0`.

### Resident-protection gates

A corridor is `RECOVERY_ELIGIBLE_FOR_COMMUNITY_REVIEW` only if all gates pass:

- No resident, tenant, or community organization reports a project-caused displacement event in the measurement period.
- No evictions, rent increases, benefit denials, service restrictions, or access restrictions are attributed to the intervention without independent accessible review.
- No personal-device, neural, biometric, facial, license-plate, or household-level telemetry is collected for the metric.
- A public, accessible, multilingual appeal channel exists and has a documented response process.
- Community identity and cultural-use protections are documented through opt-in community governance, not inferred profiling.

Otherwise the result is `RECOVERY_HOLD_FOR_RIGHTS_REVIEW`, regardless of cooling performance.

## 2. Cybernetic-Host Social Acceptance Index

The index measures the acceptability of local conditions and institutions for people with cybernetic, assistive, augmented, or other self-asserted identities. It does not measure whether any person is socially acceptable.

### Collection constraints

- Voluntary and opt-in participation only.
- No collection of neural, biometric, health, device-telemetry, precise location, persistent identifier, or identity-proof data.
- Do not ask a participant to disclose an augmentation, diagnosis, disability, or identity category.
- Enforce a release threshold of at least 30 completed responses per reporting cohort.
- Publish only aggregate results, with a documented privacy budget if differential privacy is used.
- Suppress small cells and free text that could reveal a participant.

### Component values

All component values are normalized to 0–1.

- `anonymous_likert_mean`: Mean of an anonymous 1–5 voluntary response, transformed as `(mean - 1) / 4`.
- `policy_compliance_ratio`: Independently reviewed count of applicable anti-discrimination, accommodation, access, repair, interoperability, and grievance commitments met divided by commitments assessed.
- `appeal_resolution_ratio`: Accessible appeals resolved within the published service standard divided by valid appeals received.
- `appeal_rate`: Valid appeals received divided by services or decisions covered. It is an accountability signal, not a measure of complainant legitimacy.

### Index

`acceptance_index = clamp01(0.50 * anonymous_likert_mean + 0.30 * policy_compliance_ratio + 0.20 * appeal_resolution_ratio)`

Report `appeal_rate` beside, rather than inside, the index. A low appeal rate can mean safety and trust, but it can also mean barriers to appeal; interpret it with independent accessibility review.

## 3. FOG-State Preservation

A canal node must route media to `FOG_REVIEW` if any of the following is true:

- `uncertainty_flag = true`
- `classification_confidence < 0.70`
- `evidence_completeness < 0.90`
- `knowledge_factor < 0.70`
- The declared media class is absent from the approved local taxonomy.
- The sample chain of custody, calibration record, or retention metadata is missing.
- A human, animal, ecological, chemical, or hydraulic hazard flag is active.

Only a record with all required evidence and no active hazard can become `KNOWN_MEDIA`. `KNOWN_MEDIA` is a review classification, not authorization to discharge, manipulate, remove, or otherwise act on water.

## Governance metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.86 | Transparent inputs, bounded formulas, explicit uncertainty routes |
| eco_impact_value | 0.79 | Supports heat mitigation and precautionary water classification |
| harm_risk | 0.18 | Reduced through opt-in aggregation, suppression, and fail-closed review |
| accessibility_impact | 0.90 | Requires accessible appeals and avoids identity disclosure |
| rights_alignment | 0.94 | Protects identity, privacy, community continuity, and review rights |
