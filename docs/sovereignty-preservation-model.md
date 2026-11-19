# Sovereignty Preservation Model

## Scope

This model treats sovereignty as a governance and authorization property.

It does not verify a person's identity, health, augmentation, neural status,
institutional status, or credibility.

## Protected system decomposition

H = <K, S, R, P, A>

- K: minimal root of trust for key custody, policy verification, and revocation.
- S: ordinary subsystems.
- R: independent recovery relationships and verified recovery artifacts.
- P: consent, privacy, accessibility, and non-interference policy.
- A: explicit authority graph.

## Authority non-escalation

For every compromised ordinary subsystem set X:

Compromised(X) implies
  EffectiveAuthority(X) is a subset of GrantedAuthority(X)

A compromised ordinary subsystem set must not be able to:

- Change holder policy.
- Override consent.
- Create new external capabilities.
- Extend a session.
- Replace recovery policy.
- Reuse a revoked key.
- Convert a private self-description into a public status.

## Recovery target

Recovery restores only to the most recent verified safe checkpoint, not merely
the most recent checkpoint.

t_safe = max { t | CheckpointValid(t) and IntegrityVerified(t) }

During recovery:

- External authority is denied.
- Prior session keys and capabilities are unusable.
- Recovery actions are audit-recorded with minimal disclosure.
- A new session requires fresh admission and consent.
