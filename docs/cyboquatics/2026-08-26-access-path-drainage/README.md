# Assistance, Access Path, and Drainage Review

This artifact set provides decision support, accessible status communication, path-condition review, and water-observation quality flags. It does not authorize environmental discharge, deny access, identify people, or control machinery.

## Assistance-Panel Plain Language

Every panel result contains:

- A stable machine-readable code, such as `AP-1001`.
- One short plain-language sentence.
- A next action.
- A visual icon and text label; color may supplement but never carry meaning alone.
- An optional audio text string containing the same code, explanation, and next action.
- A human-support route that does not require speech, color vision, a mobile device, biometric verification, or identity disclosure.

Preferred sentence pattern:

`[What happened.] [What to do next.]`

Examples:

- `AP-1001: This panel cannot read the sensor. Ask a worker to check the sensor.`
- `AP-2001: This path may be too narrow. Please use the marked alternate path or ask for help.`
- `AP-3001: This water reading needs a check. It is not a discharge decision.`

## Handicap-Access Path Formula

All dimensions use metres.

`effective_width_m = physical_width_m - expansion_gap_m - obstruction_buffer_m - mobility_variance_buffer_m`

The path requires review when:

- Any input is non-finite or negative.
- `effective_width_m < required_clear_width_m`.
- `running_slope_ratio > 1 / 12`.
- Heat-resilience inspection is missing or expired.
- Debris inspection is missing or expired.

The formula treats expansion, debris, and mobility variance as explicit buffers. It does not replace jurisdiction-specific design review, passing-space requirements, cross-slope assessment, landings, surface stability checks, or a qualified accessibility evaluation.

## Drainage-Decay BOD/TSS/CEC Flags

The configuration supplies each analyte's valid measurement range and maximum allowed relative trend difference. No discharge limit is embedded or inferred.

For each BOD, TSS, or CEC observation:

- Flag `OUT_OF_CONFIG_RANGE` if the finite measurement is outside its configured analytical-review range.
- Flag `LOW_MEASUREMENT_QUALITY` if the quality value is below its configured minimum.
- Flag `TREND_DIFFERENCE` when the relative difference from the prior valid observation exceeds the configured threshold.
- Flag `CONFLICTING_REPLICATES` when the two provided replicate values differ more than the configured threshold.
- Flag `NO_BASELINE` when no prior valid value exists; this is a review state, not a failure.
- Flag `INVALID_INPUT` for missing, non-finite, or structurally invalid data.

Flags identify evidence needing scientific or operational review. They do not establish water-quality compliance or authorize any discharge.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.88 | Configured ranges, explicit inputs, and reviewable outcomes |
| eco_impact_value | 0.78 | Early detection of access barriers and drainage anomalies |
| harm_risk | 0.15 | No actuation, no personal data, no invented legal thresholds |
| accessibility_impact | 0.95 | Plain language, non-color cues, optional audio, human support |
| rights_alignment | 0.95 | Inclusive access, privacy, correction, and review pathways |
