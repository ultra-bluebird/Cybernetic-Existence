# Biodegradation Control, Surcharge Index, and Routing Provenance

This artifact set provides evidence-quality and review support. It does not certify biodegradability, predict real-world surcharge consequences, control equipment, infer personal identity, or make access or legal decisions.

## Biodegradable Assessment Control Validity

A single observation is always `INSUFFICIENT_EVIDENCE`.

A method-aligned record can be `CONTROL_VALIDITY_REVIEW_READY` only when all conditions hold:

- Test method and version are declared.
- Test duration is positive and meets the locally configured minimum for that declared method.
- At least the configured number of sample replicates is present.
- Blank or negative control status is valid.
- Positive or reference control status is valid.
- Replicate spread is at or below the configured maximum.
- A response channel is declared and populated: oxygen demand/BOD for oxygen-demand methods or CO2 evolution for CO2-evolution methods.
- Temperature, test medium, inoculum or compost source, units, calibration, and chain-of-custody metadata are declared.

Otherwise return `INSUFFICIENT_EVIDENCE`.

This logic assesses whether evidence is sufficient for review. It does not determine biodegradability, compostability, safety, environmental release suitability, product quality, or regulatory compliance.

## Surcharge-Breach Indexed Lookup

Primary lookup index:

`CREATE INDEX idx_surcharge_asset_time_desc ON surcharge_breach_events(asset_id, observed_at_utc DESC);`

Use it for an asset and time-window query:

`WHERE asset_id = ? AND observed_at_utc >= ? AND observed_at_utc < ? ORDER BY observed_at_utc DESC`

A non-local review view includes only `EXTENDED_REVIEW` and `CRITICAL_REVIEW` categories. The categories are conservative screening labels only; all non-local rows require qualified human engineering review.

## Cybernetic-Host Audit Provenance

Minimum routing-decision provenance fields:

- `observation_id`: Random or locally unique observation reference; not a personal identity.
- `node_pseudonym`: Rotating non-identifying node reference.
- `route_code`: Stable route outcome.
- `explanation_code`: Stable reason code.
- `explanation_text`: Plain-language explanation.
- `review_status`: Human-review lifecycle state.
- `observed_at_utc`: Observation or decision time.
- `policy_id`: Versioned rule set used.
- `input_schema_version`: Input-contract version.
- `audit_event_id`: Append-only audit record identifier.

Prohibited fields:

- Raw neural, biometric, health, or augmentation data.
- Exact personal location.
- Household IDs, device IDs, camera imagery, visitor history, or identity inference.
- Unbounded free text that can become a covert personal-data channel.

The audit log must be append-only, access-controlled, retention-limited, exportable through an accessible process, and connected to correction and appeal pathways.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.90 | Explicit controls, indexed retrieval, and stable provenance fields |
| eco_impact_value | 0.76 | Faster review and reduced false biodegradation interpretation |
| harm_risk | 0.11 | Non-actuation, minimized data, and human-review requirement |
| accessibility_impact | 0.90 | Plain explanations, export, correction, and appeal support |
| rights_alignment | 0.97 | Privacy-preserving accountability and non-discriminatory review |
