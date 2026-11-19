# AR Authorization Integration Contract

## Document status

This document describes the reference AR authorization module generated
for Hearthline.

It does not certify production security, legal compliance, accessibility
conformance, vendor suitability, or social benefit.

Generated code, executed tests, integration evidence, and release approval
are separate categories.

No compilation or test execution is established by generating this document.

Repository: mk-bluebird/Hearthline

Module directories:

- typescript/xr/
- typescript/ar/ where separately reviewed integration code is introduced

## 1. Purpose and non-goals

### Purpose

Authorize narrowly scoped optional AR features using:

- Accepted age eligibility evidence.
- Current authenticated account authority.
- Explicit feature-specific permission.
- Reviewed configuration and policy.
- Bound, current pathway and capability evidence.
- Single-use, time-bounded outstanding leases.
- Separately enforced active-session authorization.

Supported feature names are:

- private_expression
- public_information
- shared_authored_fragment

The public_information feature is member-gated AR in this module.
Public non-member information and text/2D access require their own policy.

### Non-goals

The module does not:

- Estimate age from a face, voice, movement, or biometric signal.
- Establish that a person is safe, trusted, compatible, or entitled.
- Authenticate an issuer merely by validating an object shape.
- Establish legal permission to exclude adults aged 18–29.
- Diagnose loneliness, emotion, disability, or health.
- Rank people or optimize their engagement.
- Grant access to another person's content from a generic permission flag.
- Verify live XR behavior from a declaration.
- Guarantee prevention of screenshots or external recording.
- Replace accessible non-AR functionality.
- Provide distributed transactions or durable storage.

## 2. Trust-zone placement

### Device

The device renders approved content and exposes stop controls.

It must not supply trusted eligibility, permission, registry approval,
policy authority, or attestation decisions.

Client assertions are requests, not authoritative decisions.

### Identity — AnchorLine

The Identity zone supplies narrow eligibility authority.

It owns accepted evidence routes and account binding.

The AR boundary receives only the necessary eligibility fields.

Identity recovery, documents, health, and protected attributes are not
part of the AR eligibility snapshot.

### Consent — CommonGround

The Consent zone supplies a coherent account-wide permission snapshot.

Each feature has an independent grant and deadline.

An account-wide revision covers material changes to that snapshot.

Shared sessions additionally require independently resolved mutual
consent bound to participants, session, and exact authored scope.

### Connection

The Connection zone orchestrates the approved operation.

It must not use eligibility or consent evidence for matching, ranking,
profiling, or unrelated recommendations.

Optional AR does not authorize messages, meetings, recording, location
disclosure, or continued participation.

### Governance

Governance maintains review evidence, policy versions, acceptance records,
retention decisions, and narrowly approved accountability records.

Afterlight integration is separate and purpose-limited.

The arrows between zones represent explicit contracts, not permission
for all data to flow through every zone.

## 3. Required injected dependencies

### Clock

Inject trusted nondecreasing epoch milliseconds.

Do not inject raw performance.now() into epoch deadline comparisons.

Define:

- Authority-time provenance.
- Permitted clock skew.
- Regression handling.
- Restart and restoration behavior.
- Suspension and resume handling.

The reference stores reject observed regression.

### Authority sources

Provide authenticated adapters for:

- Current eligibility.
- Current feature-indexed permissions.
- Revision-only reconciliation.

Missing or unavailable authority must not become an affirmative decision.

A fresh read may still be stale if its consistency contract permits lag.

### Review registries

Provide review-gated registries for:

- Configurations.
- Non-AR pathways and their configuration bindings.
- Capability manifests and their configuration/build bindings.
- Anchor attestations and their configuration/build bindings.
- Recording attestations and their configuration/build bindings.
- Immutable policy-version references.

A review callback must resolve real evidence and approved scope.

Returning true unconditionally is acceptable only in clearly labeled,
isolated synthetic fixtures.

### Storage and orchestration

The supplied lease store is in-memory and process-local.

Production integration must define:

- Capacity and rate limits.
- Durable state if required.
- Transactional or fenced authority ordering.
- Crash recovery.
- Cross-process coordination.
- Cleanup scheduling.
- Backup restoration.
- Replay and reference-reuse behavior.

### Audit adapter

Use a separately reviewed adapter for any audit destination.

The AR writer makes no external calls.

The adapter must not enrich events with sensitive identifiers or content.

## 4. Seven-step authorization flow

### Step 1 — Validate

Validate exact payload shapes and bounded values.

Reject extra keys, accessors, symbols, malformed references, and invalid
timestamps at the applicable intake boundary.

Shape validation is not authenticity validation.

Capture immutable snapshots before making a decision.

### Step 2 — Resolve

Resolve:

- Requested account and feature.
- Current eligibility.
- Current permission snapshot.
- Approved configuration.
- Current governing policy.
- Bound pathway, manifest, and attestations.
- Shared-session consent where applicable.

Resolve these through trusted service contracts.

Specify whether the reads share a consistent authority view.

### Step 3 — Verify

Require successful results from:

- Eligibility validation.
- Feature permission validation.
- Feature-specific policy.
- Non-AR parity verification.
- Sensor-inference declaration verification.
- Persistent-anchor declaration verification.
- Recording declaration verification.
- Current policy evaluation.
- Coordinator blocking checks.

Shared-session permission must refer to the exact operation.

Do not substitute a generic shared-fragment boolean for mutual consent.

### Step 4 — Propose

Call authorizeAr with resolved, captured inputs.

A proposal is not an issued lease.

Bound expiry by every relevant deadline:

- Store duration ceiling.
- Feature duration ceiling.
- Eligibility expiry.
- Permission snapshot acceptance deadline.
- Selected feature grant deadline.
- Configuration review expiry.
- Pathway review expiry.
- Manifest review expiry.
- Anchor review expiry.
- Recording review expiry.
- Shared consent deadline.
- Any applicable scheduled policy transition.

The reference authorizeAr does not yet compose every evidence deadline.
Trusted orchestration must supply the missing composition.

### Step 5 — Issue

Issue only behind the trusted orchestration boundary.

Recheck authority ordering and coordinator blocking.

Do not allow clients to submit arbitrary proposals directly to the store.

A matching proposal shape does not prove that it remains authorized.

### Step 6 — Consume

Use bound consumption for the expected account and feature.

Consumption performs one synchronous transition in one store instance.

Recheck current authority through the integration contract.

For shared sessions, bind activation to the checked session and manifest.

Consumption alone must not bypass the active-session controller.

### Step 7 — Audit

Produce only approved lifecycle events.

Mint independent opaque event references.

Use equal hour-bucket occurredAt and coarseEpoch values.

Use a public policy release label, not an internal policy reference.

Never include authored content, denial reasons, account references,
lease identifiers, or attestation identifiers.

Define audit failure behavior explicitly.

A failed post-consumption audit write cannot undo consumption.

## 5. Revocation propagation

### Outstanding leases

Eligibility and permission events invalidate matching account leases.

Configuration events invalidate matching configuration leases.

Policy events invalidate matching policy leases.

Higher observed revisions trigger conservative invalidation.

Duplicate and older events do not restore authority.

### Reconciliation

Track required references through trusted orchestration.

Use revision-only reads; do not fetch private content for reconciliation.

Unavailable sources block the affected scope and invalidate outstanding
matching leases.

Successful source recovery does not revive revoked leases.

Serialize overlapping sweeps or define generation/fencing semantics.

### Active sessions

Outstanding-lease revocation is not active-session termination.

Provide a separate controller that responds to:

- Permission withdrawal.
- Eligibility status changes.
- Policy changes.
- Review withdrawal.
- Expiry.
- Authority outages.
- Device suspension and resume.

Stop rendering and platform-controlled sharing when authority ends.

External copies and device-level retention may remain outside control.

### Evidence withdrawal

Anchor and recording registries support irreversible withdrawal.

Pathway and manifest withdrawal require an explicit additional contract
or configuration revocation.

Propagate evidence withdrawal to outstanding leases and active sessions.

## 6. Failure modes and handling

### Malformed input

Reject through the error taxonomy.

Do not log the rejected payload or sensitive stack automatically.

### Policy denial

Return or translate a stable denial outcome.

Do not turn denial reasons into public reputation or matching signals.

### Authority unavailable

Fail closed for the affected capability.

Preserve independently authorized non-AR access.

Do not interpret an unavailable revision as zero.

### Clock failure or regression

Deny new operations.

Define safe active-session behavior separately.

Do not silently clamp a regressed authority clock.

### Duplicate consumption

Reject the second attempt.

The reference implementation does not recover a lost first receipt.

### Binding mismatch

Reject without consuming the outstanding lease.

### Audit capacity or delivery failure

Do not silently overwrite events.

Apply the reviewed operation-specific failure policy.

Draining is not acknowledged delivery.

### Restoration

Do not restore expired leases, stale consent, or revoked sessions.

Revalidate authority before enabling an affected capability.

## 7. What the module does not do

The module does not establish:

- Global device sensor suppression.
- Absence of OS capture, casting, or observer recording.
- Deployment artifact authenticity from a build-version string.
- Transactional consistency across authority sources.
- Legal applicability.
- Complete-task accessibility.
- A genuinely supported non-camera age-assurance route.
- Social benefit or reduced loneliness.
- Physical erasure from memory, backups, or external recipients.

## 8. Change control

### Policy

Every changed policy artifact receives a new immutable policyRef.

A replacement explicitly supersedes its predecessor.

Version numbers increase within the declared supersession lineage.

Do not reuse a policyRef for different content.

### Configuration

Configuration references are immutable.

Renewal or material change requires a new reference.

Configuration revocation is not reversed.

### Evidence

Pathways, manifests, attestations, and bindings must identify reviewed
scope and supported builds.

Material changes require renewed evidence and new references/bindings.

### Deployment

Bind reviewed build metadata to authenticated artifact identities.

The deployment process must prevent configuration/build substitution.

### Data and audit

Changing destinations, retention, fields, or access requires a material
change review.

Operational events do not automatically authorize research use.

## 9. Residual risks and release blockers

Outstanding blockers include:

- Trusted issuance and consumption orchestration.
- Distributed authority ordering.
- Active-session revocation enforcement.
- Shared-session capability binding.
- Complete expiry composition.
- Coordinator sweep concurrency.
- Evidence withdrawal propagation.
- Registry retention and capacity.
- Restoration and replay safety.
- Runtime capability enforcement.
- Authenticated deployment identity.
- Independent accessibility evaluation.
- Arizona-first legal applicability review.
- End-to-end non-camera admission evidence.
- Audit adapter delivery and retention governance.

Keep affected capabilities disabled until their blocker is resolved.

Text/2D alternatives must remain available under their own valid authority.

## 10. Acceptance gates

The stable gate identifiers are exported by:

typescript/xr/ar-conformance-suite.ts

The suite evaluates supplied, build-bound test observations.

It does not execute the behavioral tests.

### Test-runner obligations

Use isolated, clearly labeled synthetic fixtures.

Execute each required assertion against the implementation under test.

Generate observations from actual assertion outcomes.

Record a reviewable evidence artifact.

Bind the artifact to:

- The tested build.
- The governing policy.
- The selected feature.
- The executed tests.
- The test environment.
- Execution time and limitations.

Never populate passing observations without execution.

### Gate interpretation

A pass means all required observations were supplied as true and matched
the selected evidence scope.

It does not establish evidence authenticity or live deployment behavior.

A fail blocks the corresponding capability.

Missing evidence is a fail.

not_applicable is permitted only for shared-consent evaluation when the
selected feature is not shared_authored_fragment.

A shared-feature release must evaluate the shared feature explicitly.

### Release matrix

Evaluate every enabled feature separately.

Preserve test reports, failures, remediations, and limitations.

Add integration gates for:

- Compilation and runtime compatibility.
- Concurrent and distributed authority changes.
- Active-session termination.
- Runtime permissions and retention.
- Accessibility.
- Deployment identity.
- Legal approval.
- Vendor route evidence.
- Audit adapter behavior.

The twelve module gates are necessary observations, not a complete
production-release decision.
