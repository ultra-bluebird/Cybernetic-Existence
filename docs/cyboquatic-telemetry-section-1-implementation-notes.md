# Cyboquatic Telemetry Section 1: Implementation Notes

## Purpose

This document operationalizes the three-tier Cyboquatic Telemetry architecture as a reusable interoperability spine for environmental measurement, ecological restoration, and civic repair workflows.

The architecture supports environmental observations and validated ecological indicators without making essential services contingent on personal identity disclosure, assistive-device telemetry, continuous connectivity, proprietary equipment, or unrelated data processing.

## Architecture

| Tier | Contract | Primary role | Main outputs |
|---|---|---|---|
| 1 | Telemetry Envelope Contract | Carries a self-describing environmental observation with provenance, units, quality, privacy, and publication boundaries | Versioned observation envelope |
| 2 | Validation Kernel Contract | Produces reproducible physical and statistical validation results from admissible observations | Metric result, uncertainty, evidence receipt |
| 3 | Governed Impact Shard | Publishes bounded ecological impact claims with explanations, review status, and accountability records | ALN policy shard and impact receipt |

## Tier 1: Telemetry Envelope Contract

### Required properties

Each envelope represents one environmental observation or one bounded measurement interval.

- `artifact_id`: Immutable identifier for the envelope.
- `artifact_type`: Observation category such as `SensorReading`, `CalibrationRecord`, or `DerivedMeasurement`.
- `schema_version`: Version of this interchange contract.
- `observed_at_utc`: ISO 8601 UTC observation time.
- `observed_interval`: Start and end time when the observation represents an interval.
- `phenomenon`: Measured environmental property, such as water flow, turbidity, contaminant concentration, hydraulic head, temperature, or energy use.
- `value`: Numeric measurement value.
- `unit`: UCUM-compatible unit expression where available.
- `quality_status`: Controlled status indicating the evidence condition.
- `uncertainty_value`: Non-negative measurement uncertainty in the same unit as `value`.
- `uncertainty_method`: Method or calibration basis used to estimate uncertainty.
- `source_provenance`: Sensor, collection method, calibration reference, and evidence lineage.
- `purpose`: Named environmental or operational purpose.
- `non_goals`: Explicit prohibited uses for the envelope.
- `privacy_class`: Publication and precision boundary.
- `human_review_status`: Current review state.
- `plain_language_summary`: Accessible explanation of what was measured and why it matters.

### Controlled vocabularies

`quality_status` values:

- `observed`
- `measured`
- `calibrated`
- `validated`
- `estimated`
- `rejected`

`human_review_status` values:

- `not_required`
- `candidate_for_review`
- `hold_for_review`
- `reviewed`
- `appealed`
- `superseded`

`external_action_status` values:

- `prohibited`
- `informational_only`
- `requires_separate_approval`
- `approved_for_bounded_action`

### Data boundary invariant

Environmental telemetry is distinct from personal, biometric, neural, health, identity, behavioral, augmentation, and private learning-continuity information.

Accessibility preferences may adapt presentation, interaction, authentication alternatives, and export formats. They do not alter access eligibility, evidentiary weight, ecological score, civic-service priority, or credibility of a participant.

## Tier 2: Validation Kernel Contract

### Core inputs

The validation kernel accepts only envelopes that include:

- A supported phenomenon and compatible unit.
- A known quality status.
- A bounded timestamp or interval.
- A non-negative uncertainty estimate.
- Purpose and non-goal declarations.
- Calibration provenance when the calculation requires calibrated data.

### Reproducible metric families

| Metric family | Formula or rule | Output |
|---|---|---|
| Hydraulic power | \(P_{hydro} = \rho g Q H\) | Watts, uncertainty, evidence identifiers |
| Wind power | \(P_{wind} = \frac{1}{2}\rho A C_p(U)U^3\) | Watts, uncertainty, evidence identifiers |
| Coupling efficiency | \(\eta_{couple} = \frac{\int P_{hydro}dt}{\int P_{wind}dt}\) | Dimensionless value bounded from 0 to 1 |
| Contaminant mass removal | \(M_x = \int(C_{in,x}-C_{out,x})Qdt\) | Kilograms, uncertainty, calculation interval |
| Water mass balance | Inflow minus outflow, storage change, evaporation, seepage, and known sources | Residual, tolerance state, explanation |
| Energy budget | Supplied energy minus useful work and stated losses | Residual, tolerance state, explanation |

### Kernel result requirements

Every calculated metric records:

- `metric_id` and `metric_version`
- `calculation_started_at_utc` and `calculation_completed_at_utc`
- `input_artifact_ids`
- `input_hashes`
- `formula_identifier`
- `formula_parameters`
- `value` and `unit`
- `uncertainty_value` and `uncertainty_method`
- `validation_status`
- `validation_explanation`
- `review_requirement`
- `human_review_status`

### Validation states

- `accepted`: Result satisfies all applicable physical, unit, uncertainty, and provenance rules.
- `accepted_with_limitations`: Result is usable with stated uncertainty or coverage limitations.
- `review_required`: Result is computationally complete but needs human assessment before governance use.
- `rejected`: Result does not satisfy required invariants and is retained only as an auditable non-actionable record.

## Tier 3: Governed Impact Shard

### Scope

A Governed Impact Shard carries a validated environmental claim into an accountable review workflow. It records the source evidence, kernel version, bounded eco-impact result, limitations, review state, and authorization state.

The shard does not create a personal reputation score, social rank, identity assessment, behavioral prediction, or eligibility determination.

### Required shard fields

- `shard_id`
- `shard_version`
- `issued_at_utc`
- `environmental_asset_id`
- `region_precision_class`
- `evidence_receipt_ids`
- `validation_kernel_version`
- `impact_metric_name`
- `impact_metric_value`
- `impact_metric_unit`
- `impact_uncertainty`
- `knowledge_factor`
- `eco_impact_value`
- `harm_risk`
- `accessibility_impact`
- `rights_alignment`
- `limitations`
- `plain_language_explanation`
- `human_review_status`
- `appeal_or_correction_path`
- `external_action_status`
- `provenance_hash`

### Metric bounds

All governance-facing scalar metrics are bounded from 0 to 1.

- `knowledge_factor`: Confidence supported by calibration, coverage, reproducibility, and independent review.
- `eco_impact_value`: Magnitude and durability of evidenced ecological benefit.
- `harm_risk`: Likelihood and severity of ecological, privacy, accessibility, or community harm.
- `accessibility_impact`: Degree to which the system enables equitable use across interaction modes and assistive technologies.
- `rights_alignment`: Consistency with autonomy, privacy, accessible review, consent, non-discrimination, and accountable governance.

## Cross-Tier Review Path

1. An environmental observation enters as a versioned Telemetry Envelope.
2. The Validation Kernel verifies unit compatibility, evidence provenance, uncertainty, and applicable conservation rules.
3. The kernel emits a reproducible metric result and an evidence receipt.
4. The Governed Impact Shard references only the necessary validated evidence and publishes a bounded, explainable impact statement.
5. Any external action remains prohibited or requires separately recorded approval.
6. A reviewer or affected community member can use the stated appeal or correction path without loss of essential access.

## Reuse Across Domains

The contracts are domain-portable.

- Heat-Relief Canopy can use the envelope for surface temperature, shaded-area coverage, irrigation use, maintenance events, and heat-exposure indicators.
- Civic Repair Lattice can use the envelope for repair outcomes, accessibility conditions, material diversion, work-order intervals, and inspection evidence.
- Cyboquatic systems can use the envelope for water-quality, flow, hydraulic, remediation, and energy observations.

Each domain preserves its own physical models while retaining the same provenance, uncertainty, privacy, review, and publication boundaries.

## Implementation Targets

| Layer | Target artifact | Role |
|---|---|---|
| C++20 | `cpp/cyboquatic_telemetry_contract.hpp` | Strong types, constructors, unit checks, result types, and validation interfaces |
| SQL | `sql/cyboquatic_telemetry.sql` | Tables, constraints, indexes, provenance links, and retention support |
| ALN | `policies/cyboquatic_impact_governance.aln` | Purpose, consent boundary, retention, approval gates, accountability, and review status |
| Schema | `schemas/cyboquatic-telemetry-envelope.schema.json` | Portable envelope validation for producers and consumers |
| Tests | `tests/cyboquatic_telemetry_contract_tests.cpp` | Unit, boundary, provenance, consent-boundary, and mass-balance tests |

## Metrics

- `knowledge_factor`: 0.90 — derives ecological claims from units, calibration, uncertainty, provenance, and reproducible calculations.
- `eco_impact_value`: 0.91 — supports independently reviewable measurements of remediation, energy efficiency, and environmental conditions.
- `harm_risk`: 0.12 — controlled through purpose limitation, minimized collection, review gates, and strict prohibition of personal scoring.
- `accessibility_impact`: 0.94 — treats accessible interaction and alternative formats as an integral interface capability.
- `rights_alignment`: 0.96 — supports privacy, autonomy, equitable access, transparent reasoning, and accessible correction pathways.
