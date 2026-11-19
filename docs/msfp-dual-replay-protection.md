# MSFP Dual Replay Protection

## Scope

Replay protection is independently enforced by the cyberdeck and the protected
MSFP boundary. A deck acceptance does not authorize protected-boundary
acceptance.

## Message binding

Every message must bind:

- Session identifier.
- Session generation.
- Direction.
- Key epoch.
- Monotonically increasing sequence number.
- Unique nonce.
- Message expiration.
- Capability identifier.
- Policy version.
- Authenticated payload.

## Acceptance

A verifier may accept a message only if:

- The message authentication succeeds.
- The schema is valid.
- The session identifier and generation match the active session.
- The message is within the lease.
- The capability authorizes the operation and data category.
- The sequence number is strictly newer than the verifier's accepted value.
- The nonce commitment is not present in the replay cache.
- The frame is within message, byte, and rate budgets.
- The session and capability are not revoked.

## Restart rule

A restart must not resume a prior replay domain.

A new session requires:

- Fresh admission.
- New session generation.
- New transport key epoch.
- Fresh sequence counters.
- Fresh replay-cache namespace.

## Privacy

Replay caches store keyed or cryptographic commitments to nonce and session
metadata, not raw application payloads or unnecessary identity information.
