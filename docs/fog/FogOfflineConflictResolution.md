# FOG Offline Conflict Resolution

## Scope

This policy governs synchronization of locally retained FOG event histories after
temporary loss of connectivity.

The policy applies only to derived, non-personal FOG metadata and append-only
state events.

## Retention rule

A local content-bearing payload may be retained only while:

now_utc - event_timestamp_utc <= maximum_staleness_seconds

Connectivity restoration does not restart or extend the retention clock.

An expired payload must not be uploaded.

## Synchronization rule

Synchronization may append a verified remote or local event only when:

- queue identifiers match
- retention is still valid
- event integrity records are valid
- sequence order is valid
- no same-sequence conflict exists
- no conflicting human-signed event exists

## Conflict rule

A synchronization conflict exists when:

- local and remote event hashes differ at the same sequence number
- local and remote histories contain competing human-signed decisions
- a prior-hash chain link cannot be verified
- a remote event would replace rather than append to retained history
- a local or remote event has an unsupported policy or canonicalization version

A conflict must produce:

SYNC_CONFLICT_REQUIRES_HUMAN_REVIEW

The system must preserve both relevant event references and integrity hashes.

## Prohibitions

The synchronization process must not:

- use last-write-wins for signed or review-related events
- change historic timestamps
- auto-clear on reconnect
- upload expired content-bearing payloads
- delete conflict evidence before human review
- merge different reviewer decisions into a single automatic outcome
- use personal data or precise location data to resolve a conflict

## Resolution

Only a documented human governance decision may resolve a conflict.

The resolution must append a new state event. It must not rewrite either the
local or remote historic event.
