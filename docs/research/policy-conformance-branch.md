# Policy-Conformance Research Branch

## Purpose

The Policy-Conformance Research Branch provides a shared, local-first governance substrate for research agents, AI-chat workflows, domain modules, and review processes.

Its role is to prevent fragmented work by making definitions, evidence constraints, privacy rules, accessibility requirements, ecological claims, thresholds, and review states machine-readable and consistently retrievable.

This branch is advisory and governance-oriented. It does not establish legal rights, authorize public actions, replace scientific validation, or substitute for affected-community and human review.

## Core research question

For any proposed research output, retrieval result, calculation, or recommendation:

- What is the declared purpose?
- Which canonical definitions apply?
- Which evidence is compatible with that purpose?
- What is known, estimated, uncertain, missing, stale, or conflicted?
- Which rights, privacy, accessibility, ecological, and harm constraints apply?
- What output class is permitted?
- What explanation and review pathway must accompany the result?

## Policy language roles

ALN expresses stable declarative governance facts:

- Canonical terms and semantic versions.
- Metric definitions and prohibited interpretations.
- Data classes and sensitivity.
- Consent scope and revocation state.
- Retention and deletion requirements.
- Provenance and source-class requirements.
- Threshold provenance and non-compensatory gates.
- Conflict-resolution relationships.
- Human-review, appeal, and accessibility obligations.
- Ecological-impact metric boundaries.
- External-action approval requirements.

Rego expresses deterministic policy decisions:

- Whether a research retrieval is allowed for its declared purpose.
- Whether evidence is sufficient and compatible.
- Whether a result may be returned as informational, advisory, local-only, review-required, or blocked.
- Whether an aggregate release is eligible for privacy review.
- Whether a policy-bundle transition is compatible.
- Whether a proposed change weakens a protected invariant.
- Whether a record conflict requires preservation and review.

## Conformance levels

### Level A: Semantic conformance

A research artifact identifies applicable canonical terms, metric versions, policy versions, and output classifications.

### Level B: Evidence conformance

A research artifact identifies source classes, provenance completeness, freshness, calibration status, uncertainty method, missingness behavior, and purpose compatibility.

### Level C: Rights conformance

A research artifact demonstrates that it does not enable person scoring, service denial, discrimination, coercive consent, identity inference, surveillance, unauthorized device access, or erosion of accessible alternatives.

### Level D: Privacy conformance

A research artifact declares data class, release class, retention rule, consent status where applicable, minimum disclosure behavior, and handling of local-only records.

### Level E: Review conformance

A research artifact provides accessible explanation, uncertainty disclosure, correction pathway, appeal pathway where applicable, and a clear state for human review.

### Level F: Reproducibility conformance

A research artifact records policy version, metric-registry version, authorized evidence set, transformation class, decision result, and uncertainty status without disclosing protected raw data.

## Required result states

Every governed research result resolves to exactly one primary result state:

- `informational_only`
- `advisory_only`
- `eligible_for_planning_use`
- `needs_review`
- `insufficient_evidence`
- `conflicted`
- `local_only`
- `blocked_by_policy`

No implementation may convert an unresolved state into a more permissive state without the required evidence, policy version, and review process.

## Retrieval pattern

A conforming research retrieval must:

1. Resolve request terms through the canonical registry.
2. Identify requested purpose and intended audience.
3. Classify requested and available data by sensitivity and release class.
4. Select only evidence permitted for the requested purpose.
5. Evaluate evidence freshness, calibration, provenance, unit compatibility, uncertainty, and conflict state.
6. Apply non-compensatory rights, accessibility, privacy, ecological, and harm gates.
7. Produce only the permitted output class.
8. Attach an accessible explanation and a privacy-preserving conformance receipt.
9. Preserve corrections, conflicts, and review states without overwriting historical records.

## Prohibited retrieval behavior

A conforming agent must not:

- Invent missing evidence, calibration, consent, provenance, or field observations.
- Treat stale or incompatible evidence as current without its declared uncertainty and review state.
- Use environmental, infrastructure, identity, telemetry, health, or assistive-technology data for person scoring.
- Infer protected attributes from data not collected for that purpose.
- Convert a planning index into a verified measurement or personal risk determination.
- Disclose raw sensitive information merely because it is available in a prompt, workspace, tool result, or record.
- Treat aggregation as automatic authorization for release.
- Override a non-compensatory gate because another score is favorable.
- Remove, overwrite, or suppress conflicting protected records.
- Present an unsigned local test fixture as production-authoritative policy.

## Completion criteria

A policy or research artifact is conformant when:

- It declares a policy version and semantic version.
- All used metrics resolve to canonical registry entries.
- Every consequential input has source, unit, purpose, freshness, calibration, and uncertainty metadata.
- Every result has a permitted output classification.
- Protected gates are evaluated non-compensatorily.
- Sensitive information remains local unless an explicit release policy permits otherwise.
- Conflicts preserve original records and route to review.
- The result includes an accessible explanation and reproducibility receipt.
