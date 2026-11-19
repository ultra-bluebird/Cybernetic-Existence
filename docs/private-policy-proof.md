# Private Policy Proofs

## Purpose

This design supports privacy-preserving proofs of narrow, time-limited,
purpose-bound policy assertions. It does not create, verify, publish, rank,
diagnose, or authenticate CyberRank, augmentation, health, neural status,
identity, credibility, or eligibility.

## Allowed Statement

A verifier may learn only that the holder can demonstrate:

1. Possession of a valid scoped authorization or preference credential.
2. Authorization for the requested purpose and capability class.
3. A current expiry condition.
4. A non-revoked condition under the applicable privacy-preserving revocation design.
5. Fresh holder participation in the current verifier challenge.

## Prohibited Statement

The proof must not assert or reveal:

- A public CyberRank tier.
- A minimum or actual integration level.
- Integration methods or technical inventory.
- Medical, neural, biometric, physiological, or companion-system information.
- A stable personal identifier.
- Eligibility, credibility, diagnosis, or institutional status.

## Predicate

```text
proof_valid =
    credential_signature_valid
    and request_scope_allowed
    and requested_purpose_allowed
    and credential_not_expired
    and credential_not_revoked
    and verifier_challenge_is_fresh
    and holder_binding_is_valid
```

## Privacy Requirements

- Use fresh proof randomness and a fresh verifier challenge for every presentation.
- Do not include a stable holder identifier in the presentation.
- Disclose no claims beyond the verifier's documented, necessary purpose.
- Bind retention, deletion, and auditing rules to the verifier request.
- Provide a local accessible explanation and revoke path before presentation.
- Treat proof failure as a denial of the requested transaction, not as evidence
  about identity, health, augmentation, credibility, or status.

## Accountability Record

Retain only:

- event_type
- event_time
- session_pseudonym
- policy_ver
- outcome
- reason_code
- requested_capability_class
- released_capability_class
- retention_class

Do not retain credential contents, raw proof transcripts, secret witnesses,
stable identifiers, or verifier challenge material unless a specifically
reviewed retention policy requires a bounded portion.
