# MSFP Privacy-Minimized Audit Chain

## Scope

This design records bounded lifecycle receipts for a local MSFP research
implementation. It does not store raw payloads by default and does not verify
identity, health, augmentation, eligibility, or institutional status.

## Receipt fields

Each receipt contains:

- Schema version.
- Local sequence number.
- Previous receipt head hash.
- Pairwise session pseudonym.
- Session generation.
- Event type.
- Bounded reason code.
- Policy version commitment.
- Retention class.
- Local event time.
- Commitment to approved minimum metadata.

Each receipt excludes:

- Raw message payloads.
- Session keys.
- Private identity material.
- Capability tokens.
- Biometric, medical, neural, or physiological data.
- Hardware inventory details unless separately consented and necessary.

## Chain construction

receipt_digest = Hash(CanonicalEncode(receipt))

head_hash = Hash(
  "MSFP-AUDIT-v1" ||
  previous_head_hash ||
  receipt_digest
)

signature = Sign(audit_key, head_hash)

## Verification

A verifier checks:

- Canonical receipt encoding.
- Sequence continuity.
- Previous-head linkage.
- Receipt digest correctness.
- Signature correctness.
- Checkpoint linkage, where available.
- Retention-class conformance.

## Privacy

Audit data is local by default. Export requires explicit approval.

Raw payload capture is disabled by default. Rejection storms are represented by
coalesced aggregate receipts rather than retained copies of repeated input.
