# Semantic Governance Research Pathway

## Purpose

This pathway establishes shared meaning before domain implementation, field calibration, external data ingestion, or public release. It preserves local-first operation, accessibility, privacy, ecological accountability, and non-compensatory rights protections across shade, water, and green-infrastructure research.

This document is a project governance research artifact. It does not establish legal rights, make legal claims, or replace jurisdiction-specific review.

## Core invariant

No planning score, ecological benefit estimate, evidence-confidence estimate, or optimization result may override the K/E/R gate.

A recommendation is eligible for active planning use only when all mandatory gate conditions are satisfied:

- Knowledge quality meets its documented threshold.
- Evidence is sufficiently current, compatible, and provenance-complete for its stated purpose.
- Harm risk is within its documented permitted range.
- Accessibility impact is not excluded or unresolved.
- Rights alignment is not excluded or unresolved.
- Any mandatory human review, accessible explanation, appeal path, or non-digital escalation requirement is present.

A high value in one dimension cannot compensate for failure in another protected dimension.

## Research sequence

### Semantic foundation

1. Reserve and define canonical metric names.
2. Define metric units, ranges, output classifications, evidence dependencies, uncertainty behavior, and prohibited interpretations.
3. Define immutable-record relationship vocabulary.
4. Define privacy-release classes and release-decision rules.

### Measurement foundation

1. Record threshold provenance and change controls.
2. Define domain evidence matrices for shade, water, and green infrastructure.
3. Define freshness, calibration, compatibility, missingness, and uncertainty behavior.
4. Define evidence-quality reporting without concealing disagreement or incompleteness.

### Lifecycle foundation

1. Define versioned policy-bundle metadata.
2. Create a local unsigned fixture for offline development validation only.
3. Define bundle consistency checks and fail-closed states.
4. Create scenario tests for rights, privacy, accessibility, evidence, and lifecycle conditions.

### Calibration readiness

Domain calibration may begin only after:

- Each measurement input has a declared unit and source-class policy.
- Each model output has a declared uncertainty method.
- Every threshold has provenance and a permitted change pathway.
- Sensitive information has a release class.
- Record conflicts preserve auditability and human-review capability.
- Offline behavior is explicitly tested.
- No metric is capable of determining a person's eligibility, worth, identity, health state, cybernetic status, or access to essential services.

## Cross-domain semantic requirements

All domains must use the same meanings for:

- `insufficient_evidence`
- `needs_review`
- `expired`
- `not_calibrated`
- `conflicted`
- `advisory_only`
- `active_use`
- `local_only`
- `aggregate_with_differential_privacy`
- `public`
- `corrects`
- `supersedes`
- `preserve_both_require_review`

A domain may add a domain-specific state only if it documents:

- The state definition.
- The allowed predecessor and successor states.
- Whether it blocks planning use.
- The required reviewer role or review pathway.
- The accessibility impact of communicating the state.
- The privacy implications of storing or releasing the state.

## Evidence rule

Evidence quality is not a proxy for truth, legitimacy, or community value. It is a bounded statement about whether a specific record is fit for a specific stated use.

No system component may use evidence quality to:

- Rank people or households.
- Infer disability, health, identity, augmentation status, behavior, or vulnerability.
- Deny essential services.
- Replace community testimony, accessibility review, or human oversight.
- Suppress conflicting observations.
- Treat missing information as consent or absence of harm.

## Release rule

Raw neural, biometric, health, identity, assistive-technology, augmentation, location-trace, and consent data are sensitive by default.

No release is permitted solely because a record has been aggregated, pseudonymized, encrypted, or transformed. Release must be classified, purpose-limited, reviewable, and consistent with the applicable consent and retention rules.

## Completion criteria

This research phase is complete when:

- All canonical metrics have schema-valid entries.
- All input variables used in domain formulas appear in a domain evidence matrix.
- All operational thresholds have provenance records.
- All protected-record conflicts have defined lifecycle semantics.
- All release classes have documented decision criteria.
- A local policy-bundle fixture validates only within its explicitly limited development state.
- Governance scenarios demonstrate that unsafe, stale, conflict-laden, inaccessible, or privacy-incompatible cases fail closed or require review.
