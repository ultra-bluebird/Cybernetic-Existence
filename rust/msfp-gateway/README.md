# msfp-gateway

`msfp-gateway` is a Rust library for building a local, privacy-preserving gateway around short-lived, capability-bound digital sessions.

It provides a research-oriented implementation of the session-control portion of the Micro-Swarm Firebreak Protocol (MSFP):

- Mutually authenticated, transcript-bound ephemeral key agreement.
- Domain-separated per-session key derivation.
- Capability-bound message acceptance.
- Session identifier and generation binding.
- Strict sequence and nonce replay protection.
- Frame, byte, message, and replay-cache bounds.
- Explicit expiry, revocation, and terminal session states.
- Monotonic watchdog abstractions.
- Privacy-minimized acceptance and teardown receipts.
- In-memory zeroization support for owned session secrets.

The crate is intended for local gateways, cyberdeck-style research terminals, protocol emulators, offline-first security tools, and bounded external-session brokers.

## Scope

This crate models a digital session boundary.

It does not:

- Verify a person's identity, health, augmentation, credibility, eligibility, or institutional status.
- Assign, validate, publish, or enforce CyberRank as a public status.
- Operate, diagnose, calibrate, repair, monitor, or control real neural, medical, biological, cybernetic, companion, or institutional systems.
- Provide direct physical, actuator, firmware, raw-memory, or bodily-control authority.
- Guarantee universal physical memory erasure.
- Replace safety engineering, accessibility review, privacy review, cryptographic review, legal review, or human oversight.

## Security model

A session is accepted only when all of the following conditions hold:

\[
\operatorname{Accept}(m)
\iff
\operatorname{SessionActive}(m)
\land
\operatorname{SessionBindingValid}(m)
\land
\operatorname{WithinLease}(m)
\land
\operatorname{CapabilityPermits}(m)
\]

\[
\land
\operatorname{SequenceFresh}(m)
\land
\operatorname{NonceFresh}(m)
\land
\operatorname{WithinFrameBound}(m)
\land
\operatorname{WithinSessionBudget}(m)
\]

A session terminal state removes external authority:

\[
\operatorname{Terminated}
\Rightarrow
\neg\operatorname{ExternalAuthority}
\land
\neg\operatorname{KeyUsable}
\land
\neg\operatorname{CapabilityUsable}
\]

A subsequent interaction requires a fresh session generation and fresh admission. Expired or revoked sessions cannot be renewed in place.

## Session lifecycle

```text
Cold
  |
  | fresh admission, authenticated handshake, capability validation
  v
Active
  |
  +-- lease expiry ----------------------> Expired
  +-- user or policy revocation ---------> Revoked
  +-- replay or integrity failure -------> Revoked
  +-- frame or budget violation ---------> Revoked
  +-- watchdog expiry -------------------> Expired
                                            |
                                            | minimal teardown receipt
                                            v
                                           Cold
```

The only state that may hold external authority is `Active`.

## Main components

| Component | Purpose |
|---|---|
| `EphemeralKeypair` | Generates a temporary X25519 keypair from the operating-system randomness source |
| `HandshakeTranscript` | Canonically encoded context binding protocol version, session identity, generation, ephemeral keys, capability commitment, policy version, and lease |
| `SessionKeys` | Holds domain-separated transport, audit, replay, and capability-binding keys |
| `Capability` | Describes the bounded subject, purpose, permitted operations, permitted data categories, audience, expiry, revocation handle, policy version, and session generation |
| `GatewaySession` | Enforces session state, lease, capability, replay, frame, byte, message, and cache limits |
| `IncomingFrame` | Represents a session-bound inbound message request |
| `SessionLimits` | Configures maximum frame size, total session bytes, total session messages, and replay-cache entries |
| `AcceptanceReceipt` | Reports a bounded successful acceptance event without returning raw session content |
| `TeardownReceipt` | Reports a bounded terminal event using a session commitment rather than a raw session identifier |
| `watchdog` | Provides a monotonic lease and a one-time termination interface for independent authority revocation |

## Cryptographic wiring

The gateway uses a transcript-bound key-agreement pattern:

```text
External peer
    |
    | authenticated ephemeral public key
    v
Canonical handshake transcript
    |
    | transcript signature verification
    v
X25519 shared secret
    |
    | HKDF-SHA-256 with transcript hash and domain labels
    v
Per-session keys
    |
    +-- transport key
    +-- audit key
    +-- replay key
    +-- capability-binding key
```

The key-derivation context includes:

- Protocol label.
- Protocol version.
- Session identifier.
- Session generation.
- Peer ephemeral public key.
- Deck ephemeral public key.
- Peer identity-key commitment.
- Deck identity-key commitment.
- Capability commitment.
- Policy version.
- Lease expiration.

Each key has a distinct domain-separation label. A transport key is not reused as an audit key, replay key, or capability-binding key.

## Capability boundaries

A capability is an explicit, session-bound authority grant:

```text
Capability {
  subject,
  purpose,
  allowed_operations,
  allowed_data_categories,
  audience,
  expires_at_ms,
  revocation_handle,
  policy_version,
  session_generation
}
```

The gateway accepts a frame only when:

- The frame session identifier equals the active session identifier.
- The frame generation equals the active session generation.
- The operation appears in `allowed_operations`.
- The data category appears in `allowed_data_categories`.
- The audience equals the capability audience.
- The lease has not expired.
- The session remains active.
- The frame sequence is newer than the accepted sequence.
- The nonce commitment has not been seen before.
- Frame and session budgets remain available.

A capability is not widened in place. Any change to subject, purpose, audience, policy version, expiry, operation set, data-category set, or generation requires a new admission process and a new session.

## Replay protection

Replay protection binds the following values:

```text
session_id
generation
sequence
nonce
replay_key
```

The replay commitment is:

\[
C_{\text{replay}}=
H(
\text{protocol label}
\parallel
\text{replay key}
\parallel
\text{session identifier}
\parallel
\text{generation}
\parallel
\text{sequence}
\parallel
\text{nonce}
)
\]

A frame is rejected when:

- Its sequence is zero.
- Its sequence is not greater than the last accepted sequence.
- Its nonce commitment already exists in the replay cache.
- Its session identifier or generation differs from the active session.
- Its lease has expired.

Replay detection terminates the active session with a fail-closed terminal state.

## Resource bounds

`SessionLimits` configures four required bounds:

```rust
let limits = SessionLimits {
    max_frame_bytes: 4_096,
    max_session_bytes: 65_536,
    max_session_messages: 128,
    max_replay_entries: 128,
};
```

The implementation checks these bounds before accepting a frame:

- `max_frame_bytes` limits one frame payload.
- `max_session_bytes` limits cumulative accepted payload bytes.
- `max_session_messages` limits cumulative accepted message count.
- `max_replay_entries` limits retained nonce commitments.

Deployments should derive these values from measured workload, available memory, expected traffic, accessibility requirements, and the cost of false-positive interruption. Do not treat example values as universal defaults.

## Watchdog model

The watchdog uses monotonic elapsed time rather than wall-clock time.

```text
Application lease monitor
    |
    | normal session expiry and status updates
    v
Gateway session

Independent watchdog
    |
    | monotonic lease expiry or explicit termination
    v
Authority gate
    |
    | revoke active generation
    v
Gateway session terminal state
```

The `watchdog::MonotonicLease` abstraction uses `std::time::Instant` for interval measurement. It is suitable for local process-level or supervisor-level session timing. A production deployment that requires stronger isolation must place the authority gate in a distinct execution and failure domain.

## Quick start

Add the crate as a workspace dependency:

```toml
[dependencies]
msfp-gateway = { path = "../msfp-gateway" }
```

Create an ephemeral deck keypair, an external-peer keypair for a local test, a capability, and a transcript:

```rust
use msfp_gateway::{
    capability_commitment, derive_session_keys, Capability, EphemeralKeypair,
    GatewaySession, HandshakeTranscript, SessionId, SessionLimits,
};
use std::collections::BTreeSet;

let generation = 1;
let now_ms = 1_000;
let expires_at_ms = 31_000;

let deck = EphemeralKeypair::generate()?;
let peer = EphemeralKeypair::generate()?;

let capability = Capability {
    subject: "holder".to_owned(),
    purpose: "identity_proof".to_owned(),
    allowed_operations: BTreeSet::from([
        "identity.proof.verify".to_owned(),
    ]),
    allowed_data_categories: BTreeSet::from([
        "communication_preference".to_owned(),
    ]),
    audience: "authorized_peer".to_owned(),
    expires_at_ms,
    revocation_handle: "local-revocation-handle".to_owned(),
    policy_version: "v1".to_owned(),
    session_generation: generation,
};

let transcript = HandshakeTranscript {
    protocol_version: "v1".to_owned(),
    session_id: SessionId([7_u8; 16]),
    session_generation: generation,
    peer_ephemeral_public: peer.public_bytes(),
    deck_ephemeral_public: deck.public_bytes(),
    peer_identity_key_commitment: [1_u8; 32],
    deck_identity_key_commitment: [2_u8; 32],
    capability_commitment: capability_commitment(&capability)?,
    policy_version: "v1".to_owned(),
    lease_expires_at_ms: expires_at_ms,
};

let keys = derive_session_keys(
    &deck,
    peer.public_bytes(),
    &transcript,
)?;

let limits = SessionLimits {
    max_frame_bytes: 4_096,
    max_session_bytes: 65_536,
    max_session_messages: 128,
    max_replay_entries: 128,
};

let mut session = GatewaySession::new(
    transcript.session_id,
    generation,
    capability,
    keys,
    limits,
    now_ms,
)?;
# Ok::<(), msfp_gateway::GatewayError>(())
```

Accept a bounded, capability-permitted frame:

```rust
use msfp_gateway::IncomingFrame;

let frame = IncomingFrame {
    session_id: SessionId([7_u8; 16]),
    generation: 1,
    sequence: 1,
    nonce: [9_u8; 32],
    operation: "identity.proof.verify",
    data_category: "communication_preference",
    audience: "authorized_peer",
    payload: b"bounded local test payload",
};

let receipt = session.accept_frame(&frame, 1_001)?;

assert_eq!(receipt.sequence, 1);
assert!(session.has_external_authority());
# Ok::<(), msfp_gateway::GatewayError>(())
```

Revoke external authority and create a privacy-minimized receipt:

```rust
use msfp_gateway::TerminationReason;

let receipt = session.revoke(TerminationReason::ExplicitRevocation)?;

assert!(!session.has_external_authority());
assert_eq!(receipt.reason_code, "explicit_revocation");
# Ok::<(), msfp_gateway::GatewayError>(())
```

## Mutual authentication

Ephemeral key agreement alone does not identify a peer. Before deriving or accepting a session, verify signatures over the exact canonical transcript.

```rust
use ed25519_dalek::{Signer, SigningKey};
use msfp_gateway::{transcript_hash, verify_peer_signature};
use rand_core::OsRng;

let peer_signing_key = SigningKey::generate(&mut OsRng);

let digest = transcript_hash(&transcript)?;
let signature = peer_signing_key.sign(&digest).to_bytes();

verify_peer_signature(
    &peer_signing_key.verifying_key(),
    &transcript,
    &signature,
)?;
# Ok::<(), msfp_gateway::GatewayError>(())
```

A production integration should authenticate both sides and verify that:

- The peer signature binds the exact transcript.
- The deck signature binds the exact transcript.
- The transcript capability commitment matches the admitted capability.
- The transcript policy version matches the protected-side policy.
- The lease is still valid when the session is activated.
- The protected boundary independently verifies all required conditions.

## Failure handling

| Condition | Gateway result | Session result |
|---|---|---|
| Expired lease | `GatewayError::LeaseExpired` | `Expired`; external authority removed |
| Explicit revocation | Teardown receipt | `Revoked`; external authority removed |
| Signature failure | `GatewayError::PeerSignatureInvalid` or `GatewayError::DeckSignatureInvalid` | Admission must not proceed |
| Wrong session generation | `GatewayError::GenerationMismatch` | Frame rejected |
| Stale sequence | `GatewayError::ReplayDetected` | `Revoked`; external authority removed |
| Repeated nonce | `GatewayError::ReplayDetected` | `Revoked`; external authority removed |
| Capability mismatch | `GatewayError::CapabilityDenied` | `Revoked`; external authority removed |
| Oversized frame | `GatewayError::FrameTooLarge` | `Revoked`; external authority removed |
| Byte, message, or replay-cache limit | `GatewayError::RateLimited` or `GatewayError::MessageLimitExceeded` | `Revoked`; external authority removed |
| Watchdog expiry | Authority-gate revocation | `Expired`; fresh admission required |

A deployment may choose a separate, non-terminal soft-fault pathway for recoverable transport conditions such as bounded packet loss or jitter. That pathway must never override authentication, replay, capability, lease, schema, or integrity failures.

## Receipts and audit integration

`AcceptanceReceipt` and `TeardownReceipt` are intentionally small. They are suitable inputs to a separate local append-only audit chain.

A privacy-minimized audit event should contain only what is needed for accountability:

```text
schema version
local sequence
previous audit hash
session pseudonym or session commitment
session generation
event type
bounded reason code
policy version
retention class
local event time
minimal metadata commitment
```

Do not store raw payloads, session keys, raw capability tokens, private identity data, biometric data, neural data, or technical inventories by default.

## Build and test

From the crate directory:

```bash
cargo fmt --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test --all-features
```

To generate local API documentation:

```bash
cargo doc --no-deps --open
```

## Recommended integration sequence

1. Define canonical transcript and frame encodings.
2. Implement mutual transcript authentication.
3. Verify the capability commitment against the admitted capability.
4. Derive separate keys for transport, audit, replay, and capability binding.
5. Create `GatewaySession` with policy-derived limits.
6. Apply independent replay and capability validation at the cyberdeck and protected boundary.
7. Attach a monotonic watchdog through an `AuthorityGate`.
8. Emit a local, privacy-minimized acceptance or teardown receipt.
9. Require fresh admission, keys, generation, and consent for any later session.
10. Test malformed frames, replay, expiry, revocation, budget exhaustion, restart, and concurrent termination paths.

## Security considerations

- Use maintained cryptographic dependencies and keep them updated.
- Use only operating-system or platform-provided CSPRNG APIs for secret generation.
- Do not implement custom cryptographic primitives.
- Do not reuse a session generation or replay domain after restart.
- Do not reuse a nonce under the same authenticated-encryption key.
- Keep long-term identity keys outside `GatewaySession`.
- Use distinct execution and failure domains for the gateway and protected boundary where the deployment requires independent enforcement.
- Treat every network peer, removable medium, URL, attachment, and inbound frame as untrusted.
- Validate bounds before expensive parsing, decompression, cryptographic work, or audit writes.
- Keep audit data local by default and require explicit approval before export.
- Pair fail-closed external-session termination with accessible local status and a human fallback.
- Obtain independent cryptographic, accessibility, privacy, and threat-model review before any sensitive deployment.

## Limitations

This library provides application-level security controls. It cannot by itself prove:

- Hardware enclave integrity.
- Operating-system isolation.
- Physical memory remanence behavior.
- Universal secret erasure.
- Device supply-chain integrity.
- Network availability.
- Peer trustworthiness.
- Correct behavior of a separate protected boundary.
- Identity, health, augmentation, or institutional claims.

The crate’s zeroization support reduces accidental retention of owned in-memory secrets. It does not constitute proof that all possible copies, compiler temporaries, processor registers, caches, crash dumps, peripheral buffers, or storage artifacts have been erased.

## License

Licensed under either of:

- MIT License
- Apache License, Version 2.0

at your option.
