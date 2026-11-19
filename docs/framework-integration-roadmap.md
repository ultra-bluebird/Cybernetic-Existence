# Framework Integration Roadmap

## Build objective

Unify Augmented-Hub governance, accessibility, privacy, ecological evidence,
public-service continuity, and review workflows into a local-first,
advisory-only framework.

The framework preserves host-declared terminology, protects privacy boundaries,
supports equal public access, records uncertainty, and blocks ecological,
operational, or economic optimization from overriding rights, accessibility,
consent, species protection, safety, provenance, or human-review requirements.

## Integration principles

1. Every decision carries a stable machine-readable explanation code.
2. Every public-facing decision has a plain-language explanation and human-help path.
3. Every sensitive data use has purpose limitation, minimum-data scope, retention,
   deletion, revocation, and export-approval constraints.
4. Every material policy, model, routing, interface, or schema change creates a
   reviewable continuity event.
5. Every favorable metric remains non-authoritative while a blocking condition exists.
6. Every timeout, missing input, stale record, sensor failure, conflict, or unknown
   state resolves to denied, withheld, or human review.
7. Every physical or external action remains outside this framework until separately
   authorized through applicable safety, legal, environmental, accessibility, and
   community-governance processes.

## Shared envelopes

### EvidenceEnvelope

Required fields:

- domain
- evidence_status
- knowledge_factor
- ecological_value
- risk_vector
- uncertainty_status
- provenance_status
- spatial_scope
- temporal_scope
- policy_version
- review_status
- withholding_conditions
- explanation_code

### DecisionEnvelope

Required fields:

- decision_key
- decision_state
- explanation_code
- policy_version
- evidence_references
- review_required
- correction_path
- appeal_path
- created_at_utc
- material_change_reference

Allowed decision states:

- permitted
- denied
- pending_review
- withheld
- advisory_low_confidence

### ConsentEnvelope

Required fields:

- purpose
- minimum_necessary_fields
- consent_status
- consent_granted_at_utc
- consent_expires_at_utc
- revocation_path
- retention_until_utc
- deletion_requirement
- external_export_approved

### AccessibleExplanation

Required fields:

- explanation_code
- language_tag
- reading_level
- plain_language_text
- short_summary_text
- alternative_format
- human_help_route
- review_status

### ReviewCase

Required fields:

- review_key
- priority
- submitted_at_utc
- expires_at_utc
- review_status
- timeout_default
- explanation_code
- accessible_explanation
- correction_path
- appeal_path

## Non-compensation invariant

A decision must not transition to `permitted` or `reviewed_advisory`
when any active blocking condition exists.

Blocking conditions include:

- rights violation
- accessibility failure
- consent revocation
- privacy violation
- identity discrimination
- safety failure
- species-impact threshold exceedance
- contamination risk
- sensor failure
- stale or missing telemetry
- unresolved FOG condition
- unresolved provenance failure
- unresolved conflict
- required human review
- missing accessible explanation

## First integration sequence

1. Define JSON Schema contracts for EvidenceEnvelope, DecisionEnvelope,
   ConsentEnvelope, AccessibleExplanation, and ReviewCase.
2. Define a strict SQLite schema that stores each envelope and append-only
   state-transition event.
3. Define a unified ALN governance policy that expresses non-compensation,
   fail-closed defaults, public-service continuity, correction, appeal,
   deletion, and external-action approval.
4. Implement a Lua local gate that rejects incomplete, stale, blocked, or
   non-promotable envelopes.
5. Implement C++ and Kotlin validators against the same synthetic test vectors.
6. Add a plain-language explanation registry and coverage test.
7. Add cross-module tests for:
   - consent revocation
   - model-rollout continuity
   - identity discrimination detection
   - sensor failure
   - public-service priority
   - species-impact threshold exceedance
   - additionality failure
   - review timeout
   - network partition conflict
   - correction and appeal

## Acceptance criteria

The integration milestone passes only when:

- Every module emits a DecisionEnvelope.
- Every DecisionEnvelope has an explanation code.
- Every public-facing explanation code has an approved plain-language mapping.
- No module can promote a result while a blocking condition is active.
- A model or policy update preserves active host-approved preferences or records
  a material-change review event.
- Consent revocation blocks subsequent profile-derived processing and export.
- A missing or failed sensor blocks operational promotion.
- A cooling-center or accessibility need outranks flexible workload optimization.
- Species, contamination, rights, privacy, accessibility, and consent blocks cannot
  be offset by ecological, energy, cost, or credit metrics.
- The full fixture suite runs without network access, external action, personal-data
  collection, or hardware control.
