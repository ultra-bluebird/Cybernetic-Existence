# Private Proof Suite Gate

## Purpose

This gate governs evaluation of selective-disclosure and zero-knowledge proof
systems for narrow, purpose-bound authorization.

It does not authorize public identity proof, CyberRank proof, neural or
biometric authentication, eligibility classification, medical assertion, or
institutional-status verification.

## Required Predicate

```text
proof_valid =
    credential_signature_valid
    and requested_scope_allowed
    and requested_purpose_allowed
    and intended_audience_bound
    and verifier_nonce_fresh
    and credential_not_expired
    and credential_not_revoked
```

## Mandatory Threat Review

| Risk | Required evidence before selection |
|---|---|
| Verifier correlation | Pairwise presentation design, short credential lifetime, metadata-minimization analysis |
| Revocation privacy | Cached signed status-list design or independently reviewed accumulator design |
| Key loss/recovery | Revocable device-held recovery path with accessible non-biometric fallback |
| Replay | Audience, purpose, nonce, expiry, protocol version, and transcript binding |
| Coercion | Minimal predicate, no surplus claims, local revoke/disconnect path |
| Issuer authority | Documented governance, issuance policy, appeal and correction path |
| Circuit correctness | Independent cryptographic review of statement, witness, constraints, and verifier behavior |
| Operational privacy | Update-transport, timing, IP/network metadata, logs, and support workflow analysis |

## Default Profile

Use short-lived, purpose-bound credentials and signed cached status lists unless
a documented threat model and independent cryptographic review demonstrate a
need for a more complex revocation construction.

## Rejection Conditions

Reject a suite if it:

- Requires a stable holder identifier for ordinary presentation.
- Exposes a raw credential or complete private governance record.
- Cannot bind proof to a verifier challenge and declared audience.
- Has no usable, accessible key-loss recovery process.
- Treats private preferences as public status or eligibility.
- Depends on unreviewed custom cryptographic primitives.
