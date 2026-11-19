# Privacy-Preserving Audit Protocol

## Principles

1. Auditors may inspect only non-private summaries.
2. Private data remains within the local protected boundary.
3. Audit decisions are recordable but not disclosable.
4. Biological data is never part of audit outputs.
5. Auditors cannot infer status from audit absence.

## Audit Flow

1. Local system generates audit summary.
2. Summary contains only non-private metadata.
3. Summary references private data without containing it.
4. Audit decision is recorded.
5. Private data is not transmitted.

## Audit Record

An audit record contains:
- event_id
- event_type
- timestamp
- operation_reference
- outcome
- non_private_summary

An audit record does NOT contain:
- biological data
- private keys
- system internals
- identity proofs
- personal information

## Verification

Audit records are verifiable by:
- hash chain continuity
- append-only sequence
- schema validation
- policy conformance

No verification requires access to private data.
