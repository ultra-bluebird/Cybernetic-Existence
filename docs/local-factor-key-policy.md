# Local Factor and Device-Key Policy

## Scope

This policy supports locally controlled, revocable device authentication. It does
not derive identity from neural, physiological, biometric, medical, or
cybernetic information. It does not verify identity, augmentation, health,
capacity, credibility, eligibility, or institutional status.

## Key Design

The long-term device identity is a revocable cryptographic key held by a
protected local key store.

```text
session_key =
    KDF(
        device_secret,
        fresh_challenge,
        session_nonce,
        purpose,
        policy_version
    )
```

An optional local presence factor may unlock access to the device secret only
when separately enabled and approved by the user.

## Required Controls

- The optional local factor is never the sole recovery path.
- The optional local factor does not become an external identity assertion.
- Raw physiological or neural measurements are not retained.
- Helper data, if any is used in an approved research setting, is encrypted,
  purpose-limited, revocable, and subject to a deletion schedule.
- Re-enrollment creates a new key slot and revokes the prior factor binding.
- Re-enrollment invalidates prior external session authority.
- Key destruction ends external cryptographic authority but does not alter
  local documents, accessibility preferences, or a person's self-description.
- Any local factor failure produces an accessible local explanation and a
  non-biometric recovery path.

## Prohibited Uses

- No neural-pattern identity derivation.
- No public credential claiming a physiological or neural match.
- No inference of identity, health, augmentation, credibility, or eligibility.
- No remote collection of raw factor measurements.
- No automatic cloud synchronization of factor data.
