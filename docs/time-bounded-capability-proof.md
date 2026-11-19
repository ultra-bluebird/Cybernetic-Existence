# Time-Bounded Capability Expiry Proof

## Scope

This design produces minimal evidence that a session capability was bounded by
expiry, revocation, integrity state, budget, purpose, and policy. It does not
prove a person's identity, status, augmentation, health, or eligibility.

## Capability Validity

```text
valid_at(capability, now) =
    signature_valid(capability)
    and now < capability.expires_at
    and not generation_revoked(capability.generation)
    and capability.remaining_budget > 0
    and policy_still_allows(capability)
    and purpose_still_matches(capability)
    and audience_still_matches(capability)
```

## Expiry Invariant

```text
for all session, capability, now:
    if now >= session.ttl:
        not valid_at(capability, now)
```

## Evidence Records

The audit vault stores only:

- event_type
- event_time
- session_pseudonym
- generation
- policy_version
- outcome
- reason_code
- capability_commitment
- retention_class

It does not store raw capability tokens, raw payloads, credentials, plaintext,
network address, biometric data, or private identity data.

## Required Terminal Events

- Capability issued.
- Capability rejected at expiry.
- Capability revoked.
- Capability blocked after integrity failure.
- Authority-off confirmation.
- Cold-state confirmation.

## Audit Interpretation

A commitment proves integrity of the committed record. It does not itself prove
that enforcement occurred. Enforcement evidence requires a protected policy
engine, a monotonic expiry source, a generation-revocation rule, and signed or
hash-linked terminal receipts.
