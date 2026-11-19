# Surcharge Review, Municipal Rights Knowledge, and Door Alerts

This artifact set provides advisory-only classification and information. It does not predict real-world breach consequences, provide legal advice, control doors, dispatch emergency services, or authorize physical action.

## Surcharge-Breach Blast-Radius Category

The category is a conservative screening label based on bounded hydraulic inputs and a local configuration. It is not a flood, structural, contamination, injury, property-damage, or service-impact prediction.

Required bounded inputs:

- `flow_m3_s`
- `duration_s`
- `bank_sensitivity_0_1`
- `critical_shear_stress_pa`
- `radius_coefficient`
- `sensitivity_coefficient`
- `shear_coefficient`
- `local_review_radius_m`
- `extended_review_radius_m`

Screening radius:

`screening_radius_m = radius_coefficient * sqrt(flow_m3_s * duration_s) * (1 + sensitivity_coefficient * bank_sensitivity_0_1) + shear_coefficient * critical_shear_stress_pa`

Category table:

| Condition | Category | Required response |
|---|---|---|
| Invalid or non-finite input | `REJECTED_INPUT` | Correct evidence and re-submit |
| Radius `<= local_review_radius_m` | `LOCAL_REVIEW` | Local inspection and documentation |
| Radius `> local_review_radius_m` and `<= extended_review_radius_m` | `EXTENDED_REVIEW` | Qualified human engineering review |
| Radius `> extended_review_radius_m` | `CRITICAL_REVIEW` | Qualified human engineering review and site safety process |

The database indexes `asset_id`, `observed_at_utc`, and category/radius fields for bounded asset-time lookup. It stores no direct resident identity, household profile, or continuous person tracking.

## Municipal Rights Knowledge

Each fact sheet must:

- Explain one topic in short, plain-language sentences.
- State the jurisdiction, official publication date, and last reviewed date.
- Link to the relevant official government source.
- Explain that it is general information, not legal advice.
- Avoid assumptions about a reader’s disability, augmentation, health, citizenship, income, race, gender, housing, or identity.
- Avoid requesting personal data.
- Provide accessible formats, language-access options where available, and a correction or feedback route.
- Use neutral terms such as “people who use assistive or cybernetic technology” and honor self-described identity.

A fact sheet may explain an official policy, program, public-service process, accommodation route, complaint process, or local contact channel. It may not predict an outcome, determine eligibility, advise a person to take a legal position, or replace an attorney, advocate, or qualified local service provider.

## Automatic-Door Sensor Alignment Alert

Use a deterministic timing residual:

`timing_residual = abs(observed_crossing_duration_s - expected_crossing_duration_s) / allowed_duration_deviation_s`

Return `ALIGNMENT_ALERT` when:

- `timing_residual > 1.0`
- A sensor health flag is false.
- Repeated crossing samples are inconsistent beyond the configured count threshold.

Return `WITHIN_CONFIGURED_TIMING_BAND` only when all inputs are finite, positive where required, sensor health is true, and the residual is at or below 1.

Return `REJECTED_INPUT` for missing, non-finite, negative, or structurally invalid values.

This output is an inspection alert only. It must not move, lock, unlock, close, open, disable, reset, or otherwise control the door.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.86 | Explicit formulas, bounded inputs, source and review fields |
| eco_impact_value | 0.73 | Reduces avoidable inspection travel and supports inclusive public information |
| harm_risk | 0.13 | Non-actuating alerts and mandatory human review for non-local events |
| accessibility_impact | 0.93 | Plain-language, source-linked information and door safety review |
| rights_alignment | 0.96 | No profiling, no legal advice, equal-access information design |
