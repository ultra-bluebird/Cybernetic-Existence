# Adaptive Tolerance, Inclusive Door Timing, and CEC Review

This artifact set is advisory-only. It must not issue door-control commands, infer disability or identity, track a person, determine access eligibility, establish regulatory limits, or authorize environmental action.

## Corridor-Calibration Adaptive Tolerance

Use:

`adaptive_tolerance = clamp(base_tolerance + temperature_coefficient * abs(current_temperature_c - reference_temperature_c), minimum_tolerance, maximum_tolerance)`

All parameters are site- and sensor-specific:

- `base_tolerance`: Commissioned baseline tolerance in the measurement unit.
- `temperature_coefficient`: Added tolerance per degree Celsius.
- `reference_temperature_c`: Calibration reference temperature.
- `minimum_tolerance`: Lower bound; prevents unrealistic precision claims.
- `maximum_tolerance`: Upper bound; prevents seasonal heat from masking unsafe or unreliable readings.

A result must route to `CALIBRATION_REVIEW_REQUIRED` when any input is invalid, calibration is stale, the sensor quality score is below its configured minimum, or the temperature is outside the sensor’s documented operating range.

Adaptive tolerance applies only to the stated measurement residual. It must not widen a hard physical safety limit, override an ecological corridor, or convert an out-of-range system condition into a safe condition.

## Automatic-Door Inclusive Timing

A door-timing advisor may calculate a recommended minimum hold-open time, but it never controls the door.

Use a locally approved, non-identifying set of accessibility timing requirements:

`recommended_hold_open_s = max(configured_minimum_open_s, approved_accessibility_profile_max_crossing_s + safety_buffer_s)`

Do not collect or infer individual movement speed, age, disability, cybernetic status, gait, face, body shape, device use, or identity. The “accessibility profile” is a published facility configuration created through accessibility review, testing, and user feedback—not a live surveillance distribution.

Raise `DOOR_TIMING_REVIEW_REQUIRED` when:

- The configured hold-open time is less than the recommended value.
- The safety sensor health flag is false.
- The profile review is expired.
- A public, accessible request-for-more-time route is unavailable.

A user-accessible activation control or clearly offered hold-open extension should be provided according to applicable site requirements. This logic is only an alert and review tool.

## Drainage-Decay CEC Trend Indicator

For a current CEC observation and an odd-size window of prior valid observations:

`rolling_median = median(prior_valid_cec_values)`

`relative_deviation = abs(current_cec - rolling_median) / max(abs(rolling_median), denominator_floor)`

`quality_weighted_deviation = relative_deviation * measurement_quality_0_1`

Route to `CEC_TREND_REVIEW_REQUIRED` only when:

- The number of prior valid observations meets the configured minimum.
- Measurement quality meets the configured minimum.
- `quality_weighted_deviation > configured_deviation_threshold`.

Route to `CEC_INSUFFICIENT_EVIDENCE` when baseline count or quality is insufficient.

This is an evidence-quality trend flag, not a soil-health, contamination, discharge, amendment, agricultural, or compliance determination. Configuration must state the extraction method, units, sampling depth, sample handling, and review authority.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.89 | Bounded formulas, explicit calibration and QA conditions |
| eco_impact_value | 0.79 | Heat-aware quality review and early soil-monitoring investigation |
| harm_risk | 0.11 | Non-actuation, no personal tracking, and fail-closed evidence states |
| accessibility_impact | 0.96 | Inclusive timing configuration and accessible extension request |
| rights_alignment | 0.97 | Privacy, equal access, transparent review, and correction paths |
