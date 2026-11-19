# Continuity Proof Relation

## Status

This document defines a research relation for future zero-knowledge proof work.

It is not a deployed ZK circuit, identity credential, continuity-status verifier, medical proof, device proof, public registry, eligibility mechanism, or legal determination.

## Public Statement

A verifier may receive:

- Protocol domain.
- Policy version.
- Provider service scope.
- Evidence epoch.
- SHA-256 commitment.
- Predicate version.

## Private Witness

The witness may contain only:

- Canonical provider-side service record.
- Fresh commitment randomness.
- Human-fallback availability flag.
- Non-digital-route availability flag.
- Correction availability flag.
- Appeal availability flag.
- Retention-compliance flag.
- Forbidden-field exclusion flag.
- Policy-version binding.

The witness must not contain person identity, private status, CyberRank data, health data, disability data, neural data, biometric data, device data, network data, personal trajectory, communication pattern, or private companion-system information.

## Relation

The relation holds when:

1. The SHA-256 commitment recomputes from the canonical record and fresh randomness.
2. The record policy version equals the public policy version.
3. The record service scope equals the public service scope.
4. The record epoch equals the public evidence epoch.
5. At least one accessible route is available.
6. Correction and appeal remain available.
7. Retention is within policy.
8. No forbidden field is present.

## Non-Claims

A proof of this relation does not prove:

- Any person's identity.
- Any person's private self-description.
- Cybernetic-host, CyberRank, BCI, companion-system, or assistive-technology status.
- Body, neural, biometric, health, device, network, or location facts.
- Legal entitlement, clinical status, or technical safety.
- Real-world delivery of a service outside the evidence scope.
