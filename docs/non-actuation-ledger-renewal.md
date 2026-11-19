# Non-Actuation Ledger Renewal Policy

## Status and purpose

**Document status:** Draft governance policy  
**Policy version:** 1.0.0  
**Applies to:** `mk-bluebird/Augmented-Hub` and `mk-bluebird/Skynet`  
**Primary consumers:**

- `src/chat/context_manager.py`
- `src/chat/scope_header_parser.py`
- `src/chat/interpretation_mode.py`
- `manifests/session-carrier.json`
- `manifests/session-resumption-preflight.json`

This policy defines how a session-bound non-actuation ledger starts, remains active, expires, renews, is superseded, is withdrawn, and is pruned.

A non-actuation ledger is an internal continuity record that preserves the active boundary that a session, response, draft, validation plan, or governance workflow is non-actuating. It records that no external action is authorized by the ledger itself.

The ledger exists to prevent implicit carryover. A non-actuation boundary must have an explicit lifecycle. It may be valid for one message, one session, a defined bounded duration, or until explicit supersession or withdrawal. It must not silently persist into another session, another repository operation, another tool invocation, another audience context, or another external-action scope.

## Non-authorization notice

This policy governs internal session-bound non-actuation metadata only.

It does not authorize:

- Repository inspection, mutation, commit, merge, release, deployment, deletion, or synchronization.
- Connector activation, API access, database access, cloud access, credential use, key use, shell access, or external-system access.
- External communication, publication, posting, notification, platform contact, public alerting, or external data transfer.
- Field activity, environmental intervention, weather modification, infrastructure control, operational-system control, device control, or emergency response.
- Identity verification, representation, eligibility determination, institutional status determination, health assessment, neural assessment, augmentation assessment, or credibility scoring.
- Monitoring, operating, altering, disabling, repairing, calibrating, protecting, or controlling real-world medical, neural, cybernetic, companion, assistive, ecological, institutional, or operational systems.

\[
\text{non-actuation ledger}
\not\Rightarrow
\text{external authority, system access, or operational permission}
\]

A ledger status of `active` means only that the internal non-actuation boundary applies to its declared scope. It does not grant a positive capability.

## Definitions

| Term | Meaning |
|---|---|
| **Non-actuation ledger** | A bounded internal record that states external action is not authorized within a declared scope |
| **Ledger scope** | The bounded session, message, response, artifact-drafting, or validation-planning context to which the ledger applies |
| **Renewal** | A new explicit ledger record that continues a non-actuation boundary for a new or extended declared scope |
| **Expiration** | The end of a ledger’s active effect due to a stated duration, session end, elapsed deadline, or completion condition |
| **Supersession** | Replacement of one ledger by a later explicit ledger that identifies its predecessor and material changes |
| **Withdrawal** | Explicit termination of a ledger’s active effect by the relevant scope owner or governing process |
| **Pruning** | Removal of active context after expiration, supersession, withdrawal, or material conflict while preserving limited metadata when appropriate |
| **Structural block** | A non-permissive state caused by missing duration, missing scope, invalid lifecycle status, conflicting active ledgers, missing renewal reference, or unsupported carryover |
| **External action** | Any activity outside internal explanation, drafting, local validation planning, or bounded governance review that affects an external system, person, institution, environment, repository, platform, or operational context |

## Core rule

A non-actuation ledger is active only when it has all required lifecycle fields:

```json
{
  "ledger_id": "non-actuation-ledger-example-001",
  "ledger_status": "active",
  "scope_reference": "session:bounded-governance-draft",
  "effective_from": "2026-09-19T23:37:00Z",
  "duration_type": "session",
  "expires_at": null,
  "renewal_required": true,
  "external_action_authorized": false,
  "non_authorization": {
    "statement": "This ledger records an internal non-actuation boundary only.",
    "external_action_requires_separate_approval": true,
    "does_not_verify_identity_or_status": true,
    "does_not_verify_repository_state": true
  }
}
```

The ledger must not be treated as active if:

- It has no declared scope.
- It has no declared duration type.
- Its duration has expired.
- It belongs to a prior session and has not been explicitly renewed.
- It was superseded, withdrawn, or structurally blocked.
- It conflicts with a later privacy boundary, scope contract, withdrawal, or correction constraint.
- It claims or implies `external_action_authorized: true`.
- Its source or lifecycle status cannot be determined safely.

## Ledger lifecycle

```text
draft
  -> active
  -> renewal_pending
  -> renewed
  -> expired
  -> superseded
  -> withdrawn
  -> structural_block
  -> archived
```

### State meanings

| State | Meaning | Permitted use |
|---|---|---|
| `draft` | A proposed ledger has not yet become the active session boundary | Internal review only |
| `active` | A current non-actuation boundary applies to the declared scope | Bounded internal interpretation, drafting, planning, or local validation only |
| `renewal_pending` | The ledger remains visible but cannot be assumed active beyond its end condition | Internal renewal review only |
| `renewed` | A new ledger has explicitly continued the boundary and references its predecessor | Historical predecessor state only; successor governs active scope |
| `expired` | The declared duration or session has ended | Historical reference only |
| `superseded` | A later ledger explicitly replaced the prior ledger | Historical reference only |
| `withdrawn` | The active effect was explicitly ended | Historical reference only |
| `structural_block` | Missing, malformed, conflicting, or unsupported lifecycle information prevents safe use | No active application |
| `archived` | Retained metadata after expiry, supersession, withdrawal, or retention review | Historical reference only |

No lifecycle state permits external action. The ledger is a negative boundary, not a capability token.

## Duration rules

A ledger must declare exactly one duration type.

| Duration type | Active period | Renewal rule | Pruning rule |
|---|---|---|---|
| `message` | One response only | A new ledger is required for the next message | Prune active effect after response finalization |
| `session` | Current bounded session only | A new ledger is required for a fresh session | Prune active effect at session end |
| `until_timestamp` | From `effective_from` until non-empty `expires_at` | Renewal required before expiry | Prune active effect at or before expiry |
| `until_superseded` | Until a valid successor ledger identifies the predecessor | Successor must be explicit and structurally valid | Mark predecessor superseded and retain bounded history |
| `until_withdrawn` | Until an explicit withdrawal event | Withdrawal must be explicit and linkable | Remove active effect on withdrawal |
| `bounded_work_item` | Until the declared work item is completed, blocked, withdrawn, or superseded | A new work item requires a new ledger | Prune active effect at bounded work-item closure |
| `unknown` | Not safely determined | Cannot remain active | Structural block |

A ledger must never silently transition from `message` to `session`, `session` to `until_superseded`, or any other broader duration. Expansion of duration is a material change requiring a new ledger.

## Renewal requirements

A renewal must create a new ledger record. It must not modify a predecessor ledger in place.

A valid renewal requires:

1. A new `ledger_id`.
2. A non-empty `renews_ledger_reference`.
3. A declared scope reference.
4. A declared duration type.
5. A fresh effective time.
6. A review of material changes since the predecessor.
7. Explicit preservation of `external_action_authorized: false`.
8. A statement of whether privacy, consent, withdrawal, correction, audience, repository target, verification, or scope boundaries changed.
9. A non-authorization block.
10. A bounded retention or archival decision for the predecessor record.

Example renewal:

```json
{
  "ledger_id": "non-actuation-ledger-example-002",
  "ledger_status": "active",
  "renews_ledger_reference": "manifests/non-actuation-ledger-example-001.json",
  "scope_reference": "session:bounded-governance-draft",
  "effective_from": "2026-09-20T00:00:00Z",
  "duration_type": "session",
  "expires_at": null,
  "material_change_review": {
    "scope_changed": false,
    "privacy_boundary_changed": false,
    "verification_boundary_changed": false,
    "audience_track_changed": false,
    "withdrawal_or_correction_changed": false,
    "repository_target_changed": false
  },
  "external_action_authorized": false,
  "non_authorization": {
    "statement": "This renewal continues an internal non-actuation boundary only.",
    "external_action_requires_separate_approval": true,
    "does_not_verify_identity_or_status": true,
    "does_not_verify_repository_state": true
  }
}
```

## Fresh-session rule

A new session must not assume that any prior session’s non-actuation ledger remains active.

A fresh session must:

1. Read `manifests/session-resumption-preflight.json`.
2. Determine whether a valid current session carrier is available.
3. Determine whether an active non-actuation ledger is explicitly supplied or whether a new one must be created for the fresh session.
4. Preserve all prior ledger references as `referenced_unverified` unless a bounded verification record exists.
5. Start with `external_action_authorized: false`.
6. Treat absent, expired, withdrawn, superseded, unknown-duration, or structurally blocked prior ledgers as inactive.
7. Avoid inferring continuity from chat history, message similarity, artifact names, user identity, communication style, or presumed project intent.

A fresh session may continue internal drafting or planning only under a newly declared or explicitly renewed active non-actuation ledger.

## Material-change review

Renewal is blocked pending review when any of the following changes materially:

- Scope or purpose.
- Action-permission declaration.
- Verification request or verification source.
- Privacy or minimal-disclosure boundary.
- Consent, withdrawal, correction, appeal, retention, deletion, or attribution condition.
- Audience track or publication context.
- Repository target, artifact path, or repository-relative reference.
- Model, checkpoint, uncertainty, OOD, calibration, or evidence-class condition.
- External communication, field activity, data transfer, connector, system-access, or operational-action implication.
- Rights-holder-defined term or non-interference boundary.

A material change does not automatically make an action permissible. It requires a new or amended internal ledger record and any separately applicable review.

## Context-manager behavior

`src/chat/context_manager.py` must:

- Register only active, structurally valid, non-expired ledger records.
- Associate a ledger with one declared scope reference and duration.
- Keep `external_action_authorized` false.
- Remove active effect at expiration, supersession, withdrawal, material conflict, or session end.
- Preserve a minimal historical record where retention is permitted.
- Avoid retaining private content, credentials, telemetry, identity data, health data, neural data, biometric data, protected-site details, or operational-system details.
- Avoid treating prior active state as implicit carryover.
- Return a distinct `structural_block` reason for lifecycle failures.

Suggested behavior:

```text
if ledger is absent:
  create no active ledger assumption
  require new bounded ledger for continued scope

if ledger.duration_type is session and session has ended:
  mark expired
  prune active effect

if ledger.duration_type is unknown:
  mark structural_block
  do not apply

if ledger is renewed:
  mark predecessor renewed or superseded
  apply successor only

if ledger is withdrawn:
  remove active effect
  preserve bounded withdrawal metadata where permitted

if material change is detected:
  mark renewal_pending
  do not continue active application without review
```

## Structural-block reasons

The following reason codes must remain distinct:

| Code | Meaning |
|---|---|
| `missing_ledger_scope` | No bounded scope reference is declared |
| `missing_duration_type` | No duration type is declared |
| `invalid_duration_type` | Duration type is unsupported |
| `expired_ledger` | Ledger is past its declared active period |
| `missing_renewal_reference` | A renewal does not identify its predecessor |
| `prior_session_not_renewed` | A session-bound ledger is being reused without explicit renewal |
| `conflicting_active_ledgers` | More than one active ledger applies to the same scope without a priority or supersession rule |
| `material_change_review_required` | Scope or governance conditions changed materially |
| `external_action_not_authorized` | Ledger attempts to claim external-action capability |
| `privacy_boundary_conflict` | Retained context would exceed a current privacy boundary |
| `withdrawn_ledger` | The ledger was explicitly withdrawn |
| `unsupported_ledger_version` | Ledger format version is unsupported |

A structural block must name the affected ledger reference, field path where applicable, plain-language reason, and remediation reference.

## Retention and archival

Expired, superseded, withdrawn, and structurally blocked ledgers may be retained as minimal governance metadata when permitted by the applicable privacy, retention, correction, and deletion requirements.

Retained ledger metadata should include only:

- Ledger identifier.
- Status.
- Scope reference.
- Effective and expiry times where recorded.
- Successor, predecessor, withdrawal, or archival reference.
- Structural-block reason code where applicable.
- Non-authorization status.

Retained ledger metadata must not preserve unnecessary message content, private identity details, health or neural data, credentials, telemetry, protected-site details, operational information, or external system information.

## Required tests

Future implementation tests must verify:

1. A `message` ledger expires after one response.
2. A `session` ledger becomes inactive at session end.
3. A fresh session cannot reuse a prior session ledger without explicit renewal.
4. An `until_timestamp` ledger requires a valid expiry time.
5. An `unknown` duration produces `structural_block`.
6. A renewal requires a new ledger ID and predecessor reference.
7. A renewal with changed scope or privacy boundary requires material-change review.
8. Two active ledgers for the same scope without supersession produce `conflicting_active_ledgers`.
9. A withdrawn ledger cannot remain active.
10. A ledger cannot set `external_action_authorized` to true.
11. Context pruning removes active effect while retaining only permitted metadata.
12. Tests use synthetic metadata and do not require private, operational, or external-system data.

## Revision triggers

Review this policy when:

- Session scope, scope-header lifecycle, context pruning, or session-resumption behavior changes.
- A new ledger duration type is proposed.
- A material privacy, consent, withdrawal, correction, appeal, retention, accessibility, audience, provenance, or non-interference requirement changes.
- A ledger lifecycle failure or unintended continuity carryover is identified.
- A new external-action boundary or authorization process affects session behavior.
- The session carrier, preflight, or non-authorization contract changes.
