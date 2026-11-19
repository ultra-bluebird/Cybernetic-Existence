# FOG Normative Contract

## Scope

This contract defines interoperable state, privacy, accessibility, provenance,
and governance requirements for Field Observation & Governance workflows.

FOG outputs are advisory-only and non-actuating. They must not be used as
automated decisions about identity, health, augmentation, credibility,
eligibility, legal status, service access, community ranking, or allocation.

## Normative terms

The key words MUST, MUST NOT, REQUIRED, SHALL, SHALL NOT, SHOULD, SHOULD NOT,
MAY, and OPTIONAL are normative.

## State model

A FOG queue entry MUST use one of these states:

- RECEIVED
- LOCAL_PENDING
- HUMAN_REVIEW_REQUIRED
- REVIEW_REMINDER_DUE
- ESCALATED_REVIEW_REQUIRED
- REVIEW_OVERDUE_RETAINED
- HUMAN_DECISION_RECORDED
- RETAINED_WITHHELD
- REVIEW_COMPLETED
- EXPIRED
- SYNC_CONFLICT_REQUIRES_HUMAN_REVIEW

A queue entry in HUMAN_REVIEW_REQUIRED, REVIEW_REMINDER_DUE,
ESCALATED_REVIEW_REQUIRED, or REVIEW_OVERDUE_RETAINED MUST remain withheld.

A timeout MUST NOT cause a queue entry to transition to clear, accepted,
released, or deleted without the applicable documented retention process.

A state transition to a human-decision or review-completed terminal state
MUST have a human review reference, a signed time, and a documented decision.

## Escalation predicate

The threshold-qualified escalation predicate is:

Escalate if:

(U_media > theta_U) OR (K < K_min) OR (R > R_max)

All comparisons are strict. Equality at a configured threshold MUST NOT
escalate under this predicate.

## Bounded local queue

A LOCAL_PENDING entry MUST have an expiry boundary.

A local queue MUST have an approved positive capacity.

A full local queue MUST fail closed. It MUST NOT silently discard content,
replace a different event, clear the FOG state, or expand capacity without
a reviewed configuration change.

An expired entry MUST remove content-bearing local payloads according to its
retention policy. A minimum necessary expiry audit record MAY remain when
authorized by the retention policy.

## Human review and liveness

The system MUST record due, reminder, escalation, and maximum-review-age
boundaries for threshold-qualified withheld entries.

The system MUST support eventual human-governance handling by creating
review-request, reminder, and escalation records.

The system MUST NOT claim that software alone can guarantee a human response.

The system MUST retain withholding after a maximum review age and use an
explicit overdue state rather than treating timeout as approval or clearance.

## Privacy and non-inference

FOG event records MUST contain only minimum necessary derived metadata.

FOG event records MUST NOT include raw media, raw coordinates, addresses,
parcel identifiers, private property identifiers, personal activity history,
biometric data, neural data, health information, device inventories, reviewer
narratives, or direct identity data.

The system MUST NOT infer identity, disability, literacy, health,
augmentation, neural status, credibility, institutional affiliation,
community membership, eligibility, or entitlement from FOG records.

## Spatial and temporal provenance

Each applicable FOG event MUST record:

- aggregation window identifier
- window start in UTC
- window end in UTC
- IANA timezone identifier
- source hex resolution
- applied hex resolution
- opaque spatial scope identifier
- model version reference
- policy version reference

Aggregation windows MUST be half-open:

[start_utc, end_utc)

Raw coordinates MUST NOT be retained in ordinary FOG analytics, audit,
priority, correction, or review-queue records.

## Uncertainty

Uncertainty values, K, E, R, coverage, priority factors, and bounded
prediction scores MUST be finite IEEE-754 binary64 values in [0, 1].

NaN, infinity, negative infinity, and values outside declared ranges MUST
be rejected.

A formal probability bound MUST NOT be claimed unless its sample,
coverage, variance, drift, and calibration assumptions are documented as met.

When a formal probability bound is unavailable, the system MUST emit an
unavailable or insufficient-evidence status and preserve the applicable
withhold or human-review path.

## Conformal prediction

Conformal prediction outputs MUST be prediction sets, not autonomous
decisions.

The FOG media-label prediction set is bounded to:

- empty set
- UNMODELED_MEDIA only
- MODELED_MEDIA only
- both labels

An empty or two-label set MUST be handled conservatively.

Conformal coverage statements MUST state the exchangeability assumption and
MUST be described as marginal rather than individual, location-specific,
or universal guarantees.

## Imputed evidence

Indirect sensor estimates MUST be labeled DERIVED.

Derived estimates MUST NOT be represented as direct measurements.

Derived estimates MUST NOT support regulatory, enforcement, eligibility, or
person-level claims.

Derived estimates MAY reduce a bounded uncertainty contribution only when
an approved validation record demonstrates sufficient error and drift bounds.

## Review priority

Priority scores MAY order already-withheld human-review queue items.

Priority scores MUST NOT clear FOG states or override rights, privacy,
safety, accessibility, or human-review requirements.

Priority inputs MUST NOT contain individual, demographic, community-ranking,
or resource-allocation data.

Priority weights MUST be explicit, non-negative, sum to one, versioned, and
approved through documented human governance.

Tie-breaking MUST be deterministic.

## Accessibility

Every withholding record MUST support a plain-language explanation, an
accessible human-review path, and a correction path.

Essential access checks include:

- plain-language status
- programmatic labels
- logical heading structure
- keyboard reachability
- nonvisual status equivalence
- no forced time limit
- offline availability of essential status text
- community-reviewed translation status for non-default language variants

A composite accessibility score MUST NOT compensate for failure of an
essential access check.

Accessibility audits MUST NOT collect personal data, literacy labels,
disability labels, assistive-device identifiers, biometric data, or user
history.

## Correction and model lineage

Corrections MUST be append-only.

Historic FOG events, correction records, state transitions, and approved
model versions MUST NOT be retroactively rewritten.

Any correction reused for model improvement MUST have explicit data-reuse
consent.

Candidate model versions MUST have validation evidence and human approval
before promotion.

## Integrity logging

Each retained state transition MUST be linked through a SHA-256 hash chain
with:

- fixed domain-separation label
- canonicalization version
- previous hash
- canonical non-personal event data
- unique nonce
- event hash

Hash chains are tamper-evident, not independently tamper-proof.

Periodic integrity checkpoints MUST be retained separately from ordinary
mutable operational records.

## Decision boundary

FOG is advisory-only and non-actuating.

FOG MUST NOT generate device commands, operational commands, actuator
instructions, automatic enforcement, automatic benefit decisions, automatic
service denials, or automatic regulatory conclusions.
