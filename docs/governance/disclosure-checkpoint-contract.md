# Disclosure Checkpoint Contract

Version: 0.1.0
Status: proposed-review-baseline
Approval: not obtained
Operational deployment: prohibited pending acceptance evidence

SOVEREIGN-ATTRIBUTION
bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

Attribution is credit and metadata only. It establishes no identity,
consent, capability authorization, or execution evidence.

## Scope

This contract governs continuity of exposure accounting across sessions.
It does not certify actual recipient knowledge or privacy protection.

## Shared schema

All dependent implementations must use one versioned schema manifest.

Required manifest entries:
- Exact field names and accepted enums.
- Text and collection limits.
- Exposure dimensions and units.
- Integer bounds.
- Duplicate-key parser behavior.
- Unknown-field behavior.
- Error classes.
- Supported schema migrations.

Runtime implementations must not independently redefine these values.
Schema-generated implementations require translation-validation tests.

## Checkpoint content

A checkpoint must bind:
- Accounting domain.
- Epoch.
- Sequence.
- Exposure vector.
- Policy version.
- Schema version.
- Previous accepted checkpoint commitment.
- Current log commitment.
- Issuance time.
- Freshness and witness evidence references.

Exposure dimensions:
identity, health, location, linkability, inner_state.

Exposure unit:
integer_exposure_accounting_units.

Every dimension must be present by exact name.
Values must be bounded nonnegative integers.

## Acceptance

A checkpoint is acceptable only when:
1. Its encoding and schema are valid.
2. Its authenticity is established under the approved trust configuration.
3. Its domain and policy scope match the operation.
4. It extends the previously accepted checkpoint.
5. Its application-level state transition is valid.
6. Its freshness satisfies the approved freshness policy.
7. Required revocation and witness information is available.
8. No unresolved conflicting checkpoint is known.

Cryptographic verification and application-state verification are separate.

## Monotonicity

Within the accounting domain:
- Sequence must advance for committed state changes.
- Exposure must not decrease componentwise.
- An epoch change must not silently reset exposure.
- A migration requires explicit approval and preservation evidence.

Log append-only consistency alone does not establish these properties.

## Failures

Return distinct outcomes:
- malformed_checkpoint
- authenticity_unestablished
- stale_checkpoint
- conflicting_checkpoint
- invalid_state_transition
- unavailable_freshness_evidence
- acceptable_checkpoint

None of these is a participant-level assessment.

## Error classes

Malformed external data:
Return a typed validation outcome.

Unresolved policy or evidence:
Return a typed domain outcome.

Programming invariant violation:
Raise a programmer error; do not relabel it malformed external input.

Operational adapter failure:
Return a typed operational failure with a minimized diagnostic reference.

No public boundary may turn every exception into malformed_input.

## Workflow obligations

Exposure accounting and workflow history are separate.

Workflow history must preserve:
- Original intake time.
- Responsible owner.
- Deadline.
- Breach events.
- Escalation events.
- Repair events linked to the original obligation.
- Evidence of effective alternative delivery.

A fresh plan must not erase a prior breach.

## Cryptography

Use the approved sha2 SHA-256 implementation for commitment hashing.
Cryptographic implementation belongs in a separately reviewed adapter.

A digest does not establish authorship, freshness, or completeness.

## Release gate

No production integration until checkpoint transitions, freshness,
rollback, conflict handling, recovery, and parser behavior have documented
conformance evidence.

This document supplies no cryptographic implementation or approved
trust-anchor configuration.
