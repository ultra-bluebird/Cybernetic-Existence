# Temporal Non-Regression and Cascade Intercept

## Scope

This policy defines non-regression for durable rights and continuity
protections. It does not treat temporary external authority, session keys,
capability leases, or decrypted buffers as durable integration state.

## State Classes

| Class | Examples | Cascade Intercept Behavior |
|---|---|---|
| Volatile authority | Session keys, leases, replay counters, temporary capabilities | Invalidate immediately |
| Volatile sensitive data | Decrypted buffers, hostile frames, temporary parser allocations | Clear immediately |
| Durable accountability | Minimal receipts, policy version, reason code, integrity digest | Retain only according to retention policy |
| Durable continuity | Local documents, accessibility settings, local status, revoke path, export/review path | Preserve unless a separate approved deletion policy applies |

## Non-Regression Invariant

For every protected continuity guarantee `p`:

```text
rights_baseline(p, next_state) >= rights_baseline(p, current_state)
```

Protected continuity guarantees include:

- Local access to already authorized local materials.
- Accessible status explanation.
- Consent revocation path.
- Privacy and minimum-disclosure boundary.
- Local export and correction/review path.
- Accessibility preferences and supported input paths.
- Human fallback, where configured.

## Cascade Intercept

A Cascade Intercept is authorized only to:

1. End external session authority.
2. Invalidate volatile capabilities and session keys.
3. Clear volatile plaintext and hostile input buffers.
4. Block pending protected releases.
5. Create a minimal local recovery witness record.
6. Preserve accessible local status.

A Cascade Intercept must not:

- Infer identity, health, neural status, augmentation, credibility, or eligibility.
- Alter a private self-description or governance preference.
- Convert a session failure into loss of local documents or accessibility settings.
- Recreate external authority from an audit record.
- Preserve raw hostile payloads by default.
- Actuate, operate, diagnose, or control a real medical, neural, or cybernetic system.

## Safe-Failure Formula

```text
cascade_intercept =>
    not external_session_authority
    and not volatile_plaintext_retained
    and protected_release_blocked
    and local_continuity_available
    and recovery_witness_recorded
```
