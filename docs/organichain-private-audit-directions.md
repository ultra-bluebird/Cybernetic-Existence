# Organichain Private Audit Directions

## Record Scope

Store only a minimal authorization commitment and decision record. Never store a
raw capability token, decrypted payload, credential secret, stable identity,
network address, or private physiological, neural, medical, or operational data.

## Record Fields

```text
record_version
record_commitment
parent_commitments
event_time
session_pseudonym
generation
capability_commitment
decision
reason_code
policy_version
policy_commitment
retention_class
metadata_commitment
integrity_proof
```

## Integrity Rule

```text
record_valid =
    canonical_record_encoding
    and record_commitment_matches
    and parent_commitments_are_unique
    and integrity_proof_verifies
```

## Privacy Rule

```text
audit_export =
    explicit_holder_approval
    and selected_minimal_fields
    and retention_permits_export
    and destination_declared
```

## Export Prohibition

An export must not include:

- Raw capability tokens.
- Raw session data.
- Credentials or private key material.
- Stable real-world identifiers.
- Full capability scope.
- Full policy inputs.
- Private telemetry.
- Network addresses.
- Data not selected by the holder for the declared audit purpose.

## Audit Interpretation

A valid signature or commitment proves integrity of the disclosed record. It
does not independently prove real-world identity, complete logging, policy
fairness, consent, safety, technical operation, health, or institutional
authorization.
