# Augmented-Hub Framework Core Contract

## Purpose

This contract defines the shared governance requirements for local-first,
advisory-only Augmented-Hub modules.

It protects host-declared terminology, privacy boundaries, accessibility
preferences, correction rights, review rights, appeal access, public-service
continuity, ecological accountability, and non-interference.

This contract does not verify, diagnose, certify, authenticate, operate,
monitor, control, modify, calibrate, repair, or assess private systems,
private designations, body-integrated systems, companion systems, health,
cognitive state, neural state, institutional affiliation, or legal status.

## Core invariants

### Terminology continuity

A host may provide terminology, communication preferences, accessibility
preferences, privacy boundaries, and continuity preferences.

A module that receives an active, purpose-scoped preference record must:

- Preserve host-approved terminology when relevant to the requested task.
- Avoid forced relabeling, ridicule, fictionalization, pathologization, and
  credibility inference.
- Avoid inferring health, capacity, eligibility, institutional affiliation,
  technical status, legal status, or credibility from terminology or
  non-disclosure.
- Require explicit host authorization before changing stored terminology,
  privacy settings, accessibility preferences, or continuity settings.
- Provide correction, withdrawal, deletion, and appeal paths.

### Consent and minimum disclosure

Every sensitive processing action must have:

- A stated purpose.
- Minimum necessary fields.
- Current and revocable consent where consent is required.
- A retention deadline.
- A deletion rule.
- A correction route.
- An external-export approval gate.

No ordinary assistance, accessibility support, public information, cooling
access, emergency egress, or public-service explanation may require identity
certification, public documentation, account creation, device fingerprinting,
or persistent identity linkage.

### Non-compensation

A decision cannot become `permitted`, `reviewed_advisory`, `validated`, or
`public_claim_ready` while any blocking condition is active.

Blocking conditions include:

- Rights violation.
- Identity discrimination.
- Accessibility failure.
- Consent revocation.
- Privacy violation.
- Safety failure.
- Species-impact threshold exceedance.
- Contamination concern.
- Missing, stale, failed, or contradictory required telemetry.
- Unresolved FOG condition.
- Missing provenance.
- Failed additionality.
- Unresolved conflict.
- Required human review.
- Missing accessible explanation.

No ecological, economic, computational, operational, credit, token, or model
performance value may remove a blocking condition.

### Fail-safe outcomes

Operational permits, external actions, ecological claims, sensitive exports,
and promoted advisory outputs must fail closed.

Allowed conservative outcomes are:

- `denied`
- `withheld`
- `pending_review`
- `advisory_low_confidence`

Public access, accessibility, and emergency egress must receive the safest
available accessible fallback. An operational telemetry failure must not be
used as a reason to deny essential human access.

### Human review and appeal

Material decisions require:

- A machine-readable explanation code.
- A plain-language explanation.
- An accessible correction route.
- An accessible appeal route.
- A policy version.
- An evidence or event reference.
- A review deadline where human review is required.

A review timeout results in `denied` or `pending_review`, never implicit
approval.

### Local-first and advisory-only operation

Modules must:

- Operate without requiring network connectivity for local validation.
- Avoid automatic export and external disclosure.
- Store only minimum necessary local data.
- Use append-only governance events for material state transitions.
- Preserve conflicts rather than using silent last-write-wins resolution.
- Treat local decisions made during a network partition as provisional.
- Revalidate policy, consent, evidence, and review status after reconciliation.

No module may emit a hardware command, physical actuation command, medical
instruction, infrastructure-control instruction, or external action without a
separate authorized process outside this framework.

## Shared envelopes

### EvidenceEnvelope

Required fields:

- `envelope_key`
- `domain`
- `evidence_status`
- `knowledge_factor`
- `ecological_value`
- `risk_vector`
- `uncertainty_status`
- `provenance_status`
- `spatial_scope`
- `temporal_scope`
- `policy_version`
- `review_status`
- `blocking_conditions`
- `explanation_code`

### DecisionEnvelope

Required fields:

- `decision_key`
- `decision_state`
- `explanation_code`
- `policy_version`
- `evidence_references`
- `review_required`
- `correction_path`
- `appeal_path`
- `created_at_utc`
- `material_change_reference`

Allowed decision states:

- `permitted`
- `denied`
- `pending_review`
- `withheld`
- `advisory_low_confidence`

### ConsentEnvelope

Required fields:

- `consent_key`
- `purpose`
- `minimum_necessary_fields`
- `consent_status`
- `granted_at_utc`
- `expires_at_utc`
- `revocation_path`
- `retention_until_utc`
- `deletion_requirement`
- `external_export_approved`

### AccessibleExplanation

Required fields:

- `explanation_code`
- `language_tag`
- `reading_level`
- `plain_language_text`
- `short_summary_text`
- `alternative_format`
- `human_help_route`
- `review_status`

### ReviewCase

Required fields:

- `review_key`
- `priority`
- `submitted_at_utc`
- `expires_at_utc`
- `review_status`
- `timeout_default`
- `explanation_code`
- `accessible_explanation`
- `correction_path`
- `appeal_path`

## Acceptance criteria

The framework core passes integration review only when:

- Every module emits a DecisionEnvelope.
- Every DecisionEnvelope includes a machine-readable explanation code.
- Every public-facing explanation code has an approved plain-language mapping.
- Every material state change produces a minimal append-only governance event.
- No result can transition to a promoted state while a blocking condition exists.
- Consent revocation prevents subsequent profile-derived processing and export.
- Missing, stale, failed, or contradictory sensors block affected operational permits.
- Accessibility requests and emergency egress are not blocked by operational
  optimization or sensor uncertainty.
- Public-service continuity outranks flexible workloads.
- Identity terminology is not used as a credential, diagnosis, eligibility
  factor, credibility signal, or automated-decision input.
- The complete fixture suite runs locally without network access, external
  export, user profiling, or physical-system control.
