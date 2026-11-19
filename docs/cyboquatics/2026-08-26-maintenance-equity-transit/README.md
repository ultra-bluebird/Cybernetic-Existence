# Maintenance, Gathering Equity, and Transit FOG Metrics

This artifact set provides local, privacy-preserving decision support. It is not a controller and must not issue motor, brake, steering, signal, train, or bus commands.

## Maintenance-Bot Ethical Workload Bounds

The local maintenance bot may calculate and display a proposed workload but must require human review before any physical actuation.

A workload is `HUMAN_REVIEW_REQUIRED` when any condition is true:

- `energyreqJ >= energy_budget_j`
- `abs(delta_vt) >= thermal_delta_vt_threshold`
- `harm_risk_r > 0.30`
- Human review is unavailable or expired.
- A sensor, enclosure, lockout, site-access, ecological, or mechanical safety interlock is not verified.

A workload is only `WITHIN_REVIEW_BOUNDS` when:

- `energyreqJ < energy_budget_j`
- `abs(delta_vt) < thermal_delta_vt_threshold`
- `harm_risk_r <= 0.30`
- Required safety evidence is current.
- An assigned human reviewer is available.

`WITHIN_REVIEW_BOUNDS` does not authorize actuation. It means a human reviewer may assess the task under site procedures.

`delta_vt` is represented in volt-seconds and should be derived from a calibrated electrical/thermal model approved for the specific machinery. The system must reject non-finite values, negative energy demand, non-positive budgets, and non-positive thermal thresholds.

## Gathering-Hub Community Equity Metric

Use only spatially aggregated public or community-governed data. Do not collect names, device identifiers, precise individual locations, facial images, biometrics, neural data, household histories, or inferred identities.

For each census block or other approved aggregate geography:

- `population_weight`: Public aggregate population denominator or a community-approved weighting value.
- `hub_accessible`: Whether at least one public gathering hub meets the published physical, language, sensory, and service-access requirements.
- `transit_time_minutes`: Scheduled or observed aggregate transit travel time from the geographic centroid to the nearest qualifying hub.
- `time_threshold_minutes`: Locally adopted accessibility threshold.
- `coverage_ratio`: Fraction from 0 to 1 of residents or spatially weighted area meeting the hub-access condition.
- `data_quality`: Completeness and recency score from 0 to 1.

Compute:

`block_access_score = coverage_ratio * clamp01(1 - transit_time_minutes / time_threshold_minutes)`

`city_equity_score = sum(population_weight * block_access_score) / sum(population_weight)`

Also report:

`access_gap = max(block_access_score) - min(block_access_score)`

Do not use a high citywide score to conceal low-access blocks. Publish the distribution, suppression rules, data quality, missing areas, accessibility limitations, and an accessible correction or appeal route.

## Transit-System FOG-State Integration

A sensor reading must be `REJECTED_INPUT` when any required numeric input is non-finite, missing, or outside the declared physical range.

A reading must be `QUARANTINED_INPUT` when all required values are finite and bounded but `harm_risk_r > 0.30`.

A reading may be `REVIEWABLE_INPUT` only when all values are finite and bounded and `harm_risk_r <= 0.30`.

No output authorizes autonomous control. Quarantine, review, rejection, human interpretation, audit logging, and accessible remediation are the only permitted outcomes of this component.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.88 | Explicit bounds, formulas, and review routes |
| eco_impact_value | 0.76 | Energy-conserving task review and equitable hub planning |
| harm_risk | 0.16 | No actuation and fail-closed input handling |
| accessibility_impact | 0.92 | Measures accessible hub reach and requires review paths |
| rights_alignment | 0.95 | Data minimization, non-discrimination, and human oversight |
