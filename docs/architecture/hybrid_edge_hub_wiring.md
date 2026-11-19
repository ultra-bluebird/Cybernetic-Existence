# Hybrid Edge–Hub Wiring Pattern

## Objective

Provide local-first ecological, accessibility, and civic-support functions while limiting hub synchronization to approved, aggregated, privacy-protective data.

## Edge Components

- Lua validation modules for sensor frames and local rule evaluation
- SQLite evidence, provenance, uncertainty, consent, review, and audit ledger
- Kotlin accessible mobile or assistance-panel workflows
- Local Rego policy evaluation where the deployment can support it
- Cached public information and offline explanations
- Local correction, appeal, and non-digital escalation records

## Hub Components

- Java service APIs for approved aggregate ingestion
- Rego authorization and release-policy evaluation
- ALN v2 governance contract validation
- Aggregated K/E/R reporting
- Differential-privacy release ledger
- Public methodology and accessible explanation publication

## Synchronization Rule

The edge uploads application-level change bundles. It does not mount or copy a live SQLite database over a network filesystem.

Every bundle includes:

- bundle version
- record type
- source replica label
- vector clock
- creation time
- policy version
- sensitivity classification
- aggregation status
- consent and retention status
- provenance reference
- integrity digest
- conflict-resolution class

## Conflict Classes

- `lww_cache`: non-sensitive, replaceable, non-consequential cache data
- `mergeable_aggregate`: aggregate values merged by period, metric, and aggregation version
- `append_only_protected`: consent, appeals, corrections, provenance, accessibility, safety, policy, and privacy-budget records
- `human_review_required`: concurrent updates with rights, safety, accessibility, identity, ecological, or privacy effects

## Non-Negotiable Constraints

- Essential access does not require continuous connectivity.
- Essential access does not require optional telemetry.
- Cybernetic-integration data is sensitive by default.
- No public service outcome uses cybernetic status as a penalty feature.
- No automated machinery actuation is authorized by this architecture.
- No automated service denial is authorized by this architecture.
- Every denied release or recommendation includes an accessible explanation and a correction or appeal path.
