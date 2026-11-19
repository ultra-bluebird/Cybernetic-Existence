# Private Revocation Status

## Scope

This document defines privacy-preserving credential status checks for narrow,
purpose-bound authorization. It does not implement public identity revocation,
CyberRank verification, medical or neural status, eligibility decisions, or
identity inference.

## Required Result

A verifier may learn only:

```text
credential_status =
    valid
    and not_expired
    and not_revoked
    and scope_allowed
    and purpose_allowed
```

The verifier must not receive a stable person identifier, raw credential,
private revocation handle, issuance transcript, or protected telemetry.

## Status Approaches

### Signed Bitstring Status List

Use a signed, versioned, compressed status list for the initial implementation.

- Cache the list locally.
- Verify issuer signature and list freshness before use.
- Treat an expired or missing list as a denial for external release.
- Preserve local offline documents and local status when external release is denied.
- Rotate status list endpoints and avoid automatic background fetches where
  privacy requirements prohibit them.

### Accumulator-Based Non-Revocation Proof

Use only after an independent cryptographic review.

```text
proof_valid =
    credential_binding_valid
    and accumulator_epoch_valid
    and non_membership_witness_valid
    and zero_knowledge_proof_valid
    and verifier_challenge_fresh
```

The proof must not reveal the private revocation handle.

## Update Budgets

Every supported deck configuration must measure:

- status-bundle size;
- signature-verification time;
- cache-storage use;
- accumulator witness-update time, if enabled;
- proof-generation time, if enabled;
- proof-verification time;
- battery consumption;
- offline freshness behavior;
- privacy effects of update transport and timing.

## Failure Rule

```text
status_unknown
or status_expired
or proof_invalid
or verifier_challenge_reused
=> deny_external_release
```

This rule must not delete local documents, remove accessibility settings, or
convert a status failure into an identity, health, credibility, or eligibility
claim.
