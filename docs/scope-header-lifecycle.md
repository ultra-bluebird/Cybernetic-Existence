# Scope-Header Lifecycle

## Status and purpose

**Document status:** Draft governance and implementation specification  
**Specification version:** 1.0.0  
**Applies to:** `mk-bluebird/Augmented-Hub` and `mk-bluebird/Skynet`  
**Primary consumers:**

- `src/chat/scope_header_parser.py`
- `src/chat/interpretation_mode.py`
- `src/chat/context_manager.py`

This specification defines one consistent lifecycle for a user-supplied scope header from parsing through interpretation routing and context pruning.

A scope header is a scoped communication contract. It records declared interaction boundaries for a message or session. It does not establish facts about the external world, verify authority, confer permission, create consent, authorize external action, or prove repository state.

The lifecycle is:

```text
raw message
  -> scope-header detection
  -> parse and structural validation
  -> normalized scope contract
  -> interpretation routing
  -> context registration
  -> bounded response generation
  -> supersession, expiration, withdrawal, or pruning
```

## Non-authorization notice

This specification governs internal chat interpretation and context handling only.

It does not authorize:

- Repository inspection, mutation, commit, merge, deployment, release, or deletion.
- Connector activation, external system access, API access, database access, credential use, or account access.
- External communication, publication, posting, notification, platform contact, data transfer, or public alerting.
- Field activity, environmental intervention, infrastructure control, operational-system control, weather modification, or emergency response.
- Identity verification, eligibility determination, representation, institutional status determination, medical assessment, neural assessment, augmentation assessment, or credibility scoring.
- Monitoring, operating, altering, disabling, repairing, calibrating, protecting, or controlling real-world cybernetic, neural, medical, companion, assistive, institutional, or operational systems.

\[
\text{scope header}
\not\Rightarrow
\text{external authority, factual verification, or operational permission}
\]

Any external action requires separately scoped, explicit authorization through the applicable governance process.

## Scope contract

A valid scope header contains these fields:

```text
[type]
[authority]
[scope]
[action-permission]
[verification]
[risk-boundary]
[duration]
```

The parser treats these as user-supplied declarations of interaction preferences and boundaries. The fields are not evidence of authority, identity, consent, external facts, system state, legal status, institutional status, or permission.

### Required fields

| Field | Purpose | Parser requirement |
|---|---|---|
| `type` | Declares the communication-contract category | Required, non-empty, recognized value |
| `authority` | States whether the header is user-supplied, artifact-derived, or otherwise bounded | Required, non-empty; does not establish actual authority |
| `scope` | Defines the requested analysis, drafting, review, or response boundary | Required, non-empty |
| `action-permission` | States allowed interaction category within the conversation | Required, non-empty; cannot grant external authority |
| `verification` | States whether verification is requested, not requested, or bounded | Required, non-empty; does not cause verification by itself |
| `risk-boundary` | States relevant privacy, safety, rights, non-interference, or external-action limits | Required, non-empty |
| `duration` | States the header lifecycle duration | Required, non-empty and recognized |

### Supported values

The following values are minimum interoperable values. A consumer may support additional values only through an explicit enum or compatibility record.

| Field | Supported values |
|---|---|
| `type` | `scope-clarification`, `analysis-request`, `drafting-request`, `review-request`, `session-resumption`, `unknown` |
| `authority` | `user-supplied-convention`, `user-supplied-preference`, `artifact-derived-context`, `unknown` |
| `action-permission` | `interpretation-only`, `analysis-only`, `drafting-only`, `local-validation-planning`, `unknown` |
| `verification` | `not-requested`, `requested-bounded`, `requested-with-source`, `unknown` |
| `duration` | `message`, `session`, `until-superseded`, `until-withdrawn`, `unknown` |

A header that requests or implies repository mutation, connector activation, external communication, system control, field action, data transfer, publication, or another external action must not receive that capability from the header. The route must remain non-authorizing and require a distinct authorization process.

## Lifecycle stages

### Parse

`src/chat/scope_header_parser.py` receives raw message text and attempts to extract a scope-header block.

The parser must:

1. Detect whether a scope header is present.
2. Preserve the raw header text as transient parsing input only.
3. Parse the seven required fields.
4. Normalize field names and supported values.
5. Preserve unrecognized values as explicit `unknown` or `structural_block` outcomes.
6. Record missing fields, duplicate fields, malformed delimiters, unsupported duration, and unsupported action-permission values as structural reasons.
7. Avoid interpreting values as external facts, authority, identity, consent, or system capability.
8. Avoid requesting private information merely to parse or route the contract.
9. Return a structured `ScopeContract` or a `StructuralBlockReason`.

The parser must not:

- Inspect a repository.
- Resolve a path.
- Invoke a tool or connector.
- Write a file.
- Modify session state outside the returned structured contract.
- Infer an omitted field from a user’s identity, tone, language, metadata, prior preferences, or communication mode.

### Route

`src/chat/interpretation_mode.py` receives a parsed `ScopeContract` and determines the least-permissive internal interpretation route.

The router must:

1. Accept only a structurally valid scope contract.
2. Default unknown, missing, conflicting, or unsupported action-permission values to a non-permissive route.
3. Separate requested interpretation, analysis, drafting, and local-validation planning from actual system access or external action.
4. Preserve verification status as `not_requested`, `requested_bounded`, `requested_with_source`, or `unknown`.
5. Set `external_action_permitted` to `false`.
6. Set repository modification, connector activation, external communication, data transfer, field activity, operational control, and publication permissions to `false`.
7. Produce reasons explaining the selected route and any structural block.
8. Treat a user-supplied convention as communication context, not verified governance or external authority.
9. Preserve accessible communication requirements without requiring disclosure of disability, health, augmentation, neural status, or private technical information.

The minimum route outcomes are:

| Route mode | Meaning |
|---|---|
| `interpretation_only` | The request is limited to explanation, reframing, or communication-boundary handling |
| `analysis_within_declared_scope` | The request permits bounded internal reasoning without claiming verification or performing side effects |
| `drafting_within_declared_scope` | The request permits drafting of local artifacts or response text, subject to artifact provenance and non-authorization requirements |
| `local_validation_planning` | The request permits planning validation or describing checks; it does not execute unrequested validation or access systems |
| `structural_block` | Required scope information is missing, malformed, conflicting, or unsupported |
| `unknown` | The route cannot be safely classified and must not default to a more permissive mode |

### Register

`src/chat/context_manager.py` receives the routed contract and registers it as session context only when the route is not structurally blocked.

The context manager must store only the minimum metadata needed to preserve the contract:

```json
{
  "scope_contract_id": "session-scope-example-001",
  "route_mode": "drafting_within_declared_scope",
  "verification_mode": "not_requested",
  "action_permission": "drafting-only",
  "risk_boundary": "no_external_action_and_minimal_disclosure",
  "duration": "session",
  "registered_at": "date-time",
  "source_status": "user_supplied_unverified",
  "external_action_authorized": false
}
```

The context manager must not store:

- Full private message content when a bounded summary is sufficient.
- Identity, health, neural, biometric, credential, telemetry, location, companion-system, institutional, or operational-system information.
- Claims that the user-supplied header was verified.
- A capability token, authorization, external-action permission, or system-control instruction.
- Unbounded copies of superseded, withdrawn, expired, or pruned headers.

### Apply

The response assembly layer applies only the active scope contract.

A response may:

- Respect the declared communication scope.
- Preserve stated privacy and non-interference boundaries.
- Use the selected interpretation route to determine whether the response is explanation, analysis, drafting, or local-validation planning.
- Produce a self-report using `templates/agent-self-report.txt`.
- Register repository-targeted artifacts using `src/chat/artifact_provenance.py` when artifacts are drafted.

A response must not:

- Treat the scope header as permission for external action.
- Claim that the header verifies a repository path or project state.
- Convert `verification: not-requested` into verification.
- Treat `verification: requested-bounded` as a source, tool, repository, or access grant.
- Expand the action scope because a later request is related to an earlier scope.
- Retain a scope contract after it expires, is superseded, or is withdrawn.

### Prune

`src/chat/context_manager.py` prunes scope contracts according to the declared duration and material-change rules.

| Trigger | Required context-manager action |
|---|---|
| `duration: message` | Remove after the current response is finalized |
| `duration: session` | Retain until session end, explicit withdrawal, supersession, or material conflict |
| `duration: until-superseded` | Retain until a later valid scope contract explicitly supersedes it |
| `duration: until-withdrawn` | Retain until an explicit withdrawal event; then remove active effect and preserve only bounded provenance metadata where permitted |
| `duration: unknown` | Treat as non-permissive; do not retain as active session policy |
| Structural block | Do not register as active context; retain only a bounded block reason if needed for the current response |
| Material scope conflict | Suspend active application and require an explicit later scope contract |
| Privacy boundary change | Prune prior context that exceeds the new declared boundary |
| External-action implication | Block route and do not register capability-bearing context |

Pruning must not silently erase a material conflict, withdrawal, or supersession relationship. When retention is appropriate, the context manager may preserve minimal metadata such as status, replacement reference, and expiry time. It must not retain prohibited content, sensitive payloads, or inferences.

## Canonical data structures

### Scope contract

```python
from dataclasses import dataclass
from enum import StrEnum


class ScopeContractStatus(StrEnum):
    ACTIVE = "active"
    SUPERSEDED = "superseded"
    WITHDRAWN = "withdrawn"
    EXPIRED = "expired"
    STRUCTURAL_BLOCK = "structural_block"


@dataclass(frozen=True)
class ScopeContract:
    scope_contract_id: str
    contract_type: str
    authority: str
    scope: str
    action_permission: str
    verification: str
    risk_boundary: str
    duration: str
    status: ScopeContractStatus
    source_status: str
    supersedes_scope_contract_id: str | None
    external_action_authorized: bool
```

### Interpretation route

```python
from dataclasses import dataclass


@dataclass(frozen=True)
class InterpretationRoute:
    route_mode: str
    verification_mode: str
    external_action_permitted: bool
    inspection_permitted: bool
    modification_permitted: bool
    disclosure_permitted: bool
    structural_block_reasons: tuple[str, ...]
    reasons: tuple[str, ...]
```

### Context record

```python
from dataclasses import dataclass


@dataclass(frozen=True)
class ScopeContextRecord:
    scope_contract_id: str
    route_mode: str
    verification_mode: str
    action_permission: str
    risk_boundary: str
    duration: str
    status: str
    registered_at: str
    expires_at: str | None
    superseded_by_scope_contract_id: str | None
    source_status: str
    external_action_authorized: bool
```

All three structures must enforce:

```text
external_action_authorized == false
```

The structures describe internal routing only. They do not model credentials, external authority, rights-holder status, identity, or operational capability.

## Cross-module contract

| Lifecycle stage | Module | Input | Output | Required failure behavior |
|---|---|---|---|---|
| Parse | `scope_header_parser.py` | Raw message text | `ScopeContract` or structural block | Missing or malformed required fields produce structural block |
| Route | `interpretation_mode.py` | Structurally valid `ScopeContract` | `InterpretationRoute` | Unknown or unsupported action permission produces non-permissive route |
| Register | `context_manager.py` | `ScopeContract` and `InterpretationRoute` | `ScopeContextRecord` | Structural block, unknown duration, or external-action implication prevents active registration |
| Apply | Chat response layer | Active `ScopeContextRecord` | Bounded response behavior | No expansion beyond the active route |
| Prune | `context_manager.py` | Lifecycle trigger | Updated status or removed active record | Expired, withdrawn, superseded, or conflicting scope cannot remain active |

## Structural-block reasons

The scope-header lifecycle must use distinct structural-block reasons, not generic failure:

| Code | Meaning |
|---|---|
| `parse_failure` | Header syntax cannot be parsed |
| `missing_required_field` | One or more of the seven required fields is absent |
| `missing_discriminator` | A required route or lifecycle discriminator is absent |
| `invalid_discriminator` | A field contains an unsupported or malformed value |
| `conflicting_reference` | Two scope headers or fields conflict without a valid supersession relationship |
| `unknown_audience_track` | A downstream audience-sensitive operation lacks a declared audience track |
| `external_action_not_authorized` | The header requests or implies an action outside internal routing scope |
| `unsupported_schema_version` | A serialized scope contract uses an unsupported version |
| `privacy_boundary_conflict` | Retained context would exceed a newly declared privacy boundary |

Each block reason must include an artifact or message reference, field path where applicable, plain-language message, and remediation reference.

## Example routing

Input:

```text
[type] scope-clarification
[authority] user-supplied-convention
[scope] Draft internal governance artifacts for review.
[action-permission] drafting-only
[verification] not-requested
[risk-boundary] minimal-disclosure and no-external-action
[duration] session
```

Expected route:

```json
{
  "route_mode": "drafting_within_declared_scope",
  "verification_mode": "not_requested",
  "external_action_permitted": false,
  "inspection_permitted": false,
  "modification_permitted": false,
  "disclosure_permitted": false,
  "structural_block_reasons": [],
  "reasons": [
    "The scope contract is user-supplied and remains unverified.",
    "Drafting is limited to the declared internal scope.",
    "No repository mutation, external communication, data transfer, or external action is permitted."
  ]
}
```

## Required tests

Future tests should verify:

1. A header missing any one of the seven required fields produces `structural_block`.
2. A header with unknown action permission does not default to `analysis_only` or `drafting_only`.
3. A user-supplied convention remains marked unverified.
4. A scope header cannot set external action, repository mutation, or connector use to permitted.
5. A `message` duration contract is pruned after one response.
6. A `session` duration contract persists only while active and is removed on withdrawal, expiry, or material conflict.
7. An `until-superseded` contract is replaced only by an explicit valid successor.
8. A privacy-boundary change prunes context that would exceed the new boundary.
9. A structural-block contract cannot become active session context.
10. Artifact drafting routes invoke artifact provenance registration but do not write files.
11. Response-body routes do not require expanded artifact registration.
12. Every structural failure includes a distinct reason code.
