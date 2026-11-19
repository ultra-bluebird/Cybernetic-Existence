# Post-Quantum Device Session Profile

## Scope

This profile authenticates revocable device-held cryptographic keys. It does not
authenticate neural patterns, physiology, medical status, augmentation,
identity, credibility, or eligibility.

## Cryptographic Roles

- ML-KEM establishes an ephemeral shared session secret.
- ML-DSA signs device assertions, policy bundles, release artifacts, and
  maintenance grants.
- HKDF derives scoped traffic keys from the KEM secret and transcript hash.
- A cryptographically secure operating-system random source supplies protocol
  randomness.

## Acceptance Rule

```text
accept_session =
    supported_version
    and verified_peer_signature
    and fresh_client_nonce
    and fresh_server_nonce
    and transcript_binding_valid
    and kem_decapsulation_succeeds
    and policy_permits_requested_scope
    and lease_is_active
```

## Latency Rule

A sub-50 ms handshake is a measured local service objective, not a protocol
guarantee. Record p50, p95, p99, and timeout rate under:

- normal power;
- low-battery power profile;
- thermal throttling;
- cold start;
- resumed state;
- local wired or loopback transport;
- intended wireless transport.

A timeout ends external authority and preserves local continuity access.

## Prohibited Changes

- Do not substitute broken or unreviewed cryptography to reduce latency.
- Do not use neural or physiological signals as entropy sources or identity keys.
- Do not allow an ordinary session to create maintenance authority.
- Do not turn a device-key proof into a claim about a person's identity or status.
