# Heat Fairness, Biodegradation Evidence, and Canal Integrity

This artifact set is non-actuating, privacy-preserving decision support for ecological restoration. It must not be used for policing, immigration enforcement, individual eligibility, eviction, insurance, credit, or other punitive or exclusionary decisions.

## Heat-Island Recovery Fairness Map

Use an approved aggregate spatial cell or census-compatible area. Store no household identifier, name, face, biometric, neural signal, mobile-device identifier, vehicle identifier, precise residence, or individual trajectory.

For each aggregate cell:

- `surface_temperature_c`: Aggregated surface temperature.
- `reference_temperature_c`: Reference surface temperature from the same documented observation window.
- `coverage_quality`: Completeness and confidence of the aggregate measurement from 0 to 1.
- `community_review_available`: Whether an accessible community correction and review channel exists.
- `enforcement_use_prohibited`: Must be true.
- `displacement_risk_flag`: Community-reported planning review flag; it must not be inferred from personal data.

Compute a heat priority score only for restoration planning:

`heat_priority = clamp01((surface_temperature_c - reference_temperature_c) / temperature_range_c) * coverage_quality`

A cell with missing quality evidence, absent community review, prohibited-use violation, or a displacement-risk flag routes to `FAIRNESS_REVIEW_REQUIRED`.

A priority score means “consider community-led cooling resources.” It does not mean “increase monitoring,” “increase policing,” “target residents,” or “rank people.”

## Biodegradable Compound Evidence Consistency

A record is `INSUFFICIENT_EVIDENCE` when required metadata is absent, invalid, or internally incomplete.

Required metadata:

- Test method and version.
- Test duration and reporting intervals.
- Test temperature and temperature stability.
- Test medium and inoculum or compost source.
- Test material identity and concentration.
- Blank-control validity.
- Positive-control validity.
- O2 uptake/BOD data when using an oxygen-demand method.
- CO2 evolution data when using a carbon-dioxide method.
- Biological response or inhibition observation.
- Replicate count and replicate consistency.
- Measurement units, instrument calibration, and chain of custody.

A record is `INTERNALLY_CONSISTENT_REVIEW_REQUIRED` only if required metadata is complete, values are finite, controls are valid, and the declared method aligns with the observed response channel.

This classification is not a statement that a material is biodegradable, safe, compostable, non-toxic, legally compliant, or suitable for release.

## CanalNode Pseudonymous Integrity Indicator

Each canal observation contains only:

- `node_pseudonym`
- `observation_time_bucket_utc`
- `flow_m3_s`
- `temperature_c`
- `quality_0_1`
- `integrity_status`

The pseudonym must be non-identifying and rotate on a scheduled, documented basis. Exact coordinates, device serial numbers, camera imagery, continuous tracking histories, and direct identity fields are prohibited.

Integrity is `INTEGRITY_REVIEW_REQUIRED` if any value is non-finite, quality is below the local configuration threshold, the pseudonym is invalid, or time bucketing fails. Otherwise it is `INTEGRITY_EVIDENCE_PRESENT`.

The indicator reports data integrity, not water safety, valve control eligibility, public access eligibility, or a person’s behavior.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.87 | Explicit method and telemetry evidence requirements |
| eco_impact_value | 0.82 | Heat-resource prioritization and early evidence review |
| harm_risk | 0.14 | Aggregate-only mapping, rotating pseudonyms, non-actuation |
| accessibility_impact | 0.89 | Community review and correction are required |
| rights_alignment | 0.96 | Anti-surveillance, anti-discrimination, purpose limitation |
