# Cryptographic Agility Policy

## Status

This is a cryptographic-agility research and governance policy.

It does not claim that any implementation is post-quantum secure, FIPS validated, hardware validated, medically suitable, body-integrated, or appropriate for a particular real-world device.

## Purpose

The policy defines a versioned migration process for cryptographic mechanisms used to protect provider-side continuity evidence, service integrity, and local authorization records.

## Algorithm Policy

Approved research labels:

- SHA-256 for commitment hashing through the approved `sha2` implementation.
- ML-KEM as the NIST-standardized key-establishment label.
- ML-DSA as the NIST-standardized primary signature label.
- SLH-DSA as a NIST-standardized alternative signature label.

No cryptographic implementation may be added without:

- A documented threat model.
- Version and supply-chain review.
- License review.
- Test vectors.
- Negative tests.
- Key-generation and key-storage assumptions.
- Rotation and recovery design.
- Privacy and metadata review.
- Human authorization.

## Required Migration Record

Every cryptographic migration record must identify:

- Current algorithm label.
- Proposed algorithm label.
- Purpose.
- Key identifier scope.
- Compatibility requirement.
- Version transition.
- Rotation plan.
- Recovery plan.
- Deprecation date or condition.
- Approval record.
- Privacy impact.
- Evidence of tests performed.

## Prohibited Practices

The system must not:

- Silently change algorithm identifiers.
- Reuse a key across incompatible purposes without documented review.
- Treat an algorithm label as proof of legal identity, private status, technical certification, or personhood.
- Publish private key material, seed material, recovery material, or person-specific cryptographic linkage.
- Use project-blacklisted algorithms or primitives.
- Claim post-quantum security without a reviewed implementation and scope-specific evidence.

## Limitation

Cryptographic agility reduces migration risk. It does not eliminate implementation defects, endpoint compromise, metadata leakage, coercion, key theft, policy misuse, or real-world operational risk.
