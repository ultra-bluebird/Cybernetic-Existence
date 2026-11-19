# Neural Telemetry Threat Model

## Scope

This document defines a privacy-preserving threat-model structure for protected telemetry,
configuration, research records, consent receipts, keys, and incident records.

It does not authorize access to, control of, calibration of, repair of, or modification of
any physical neural, medical, assistive, or institutional system.

## Security objectives

- Maintain confidentiality, integrity, availability, purpose limitation, revocability,
  non-interference, and human review.
- Process protected data locally whenever an authorized local path can satisfy the purpose.
- Require explicit authorization scope, expiry, auditability, and minimal disclosure.
- Preserve accessible human and non-digital alternatives.

## Protected assets

| Asset class | Examples | Default handling |
|---|---|---|
| Neural telemetry | Raw streams, derived features, sequence metadata | Local-first, encrypted, minimum necessary |
| Interface configuration | Preferences, decoder references, local policy | Encrypted, versioned, signed change records |
| Research records | Pseudonymized data, summaries, manifests | Purpose-bound workspace, de-identified release review |
| Consent receipts | Scope, retention, recipient, revocation state | Signed, append-only state transitions |
| Key material | Encryption and signing keys | Segregated custody, rotation and revocation |
| Incident logs | Integrity, access, and remediation events | Minimal, tamper-evident, restricted access |

## Authorization invariant

A protected-data request is allowed only when the actor, purpose, scope, authorization basis,
expiry, recipient/output mode, and audit sink are all valid.

\[
\operatorname{Permit}(\mathcal{A})
=
I \land P \land S \land B \land T \land M \land L
\]

## Non-interference invariant

Telemetry, configuration, and derived outputs are informational artifacts. They must not be
treated as authority to alter a person, make medical claims, control a physical interface, or
override a person’s stated choice.

## Incident classes

- Unauthorized access attempt
- Consent or purpose violation
- Key compromise or suspected compromise
- Integrity failure or signature mismatch
- Replay or sequence violation
- Configuration change outside authorized scope
- Software supply-chain exposure
- Availability degradation affecting authorized access
- Recipient revocation-propagation failure

## Incident response

1. Contain affected access paths.
2. Preserve minimal integrity evidence.
3. Revoke or rotate affected credentials and keys.
4. Assess scope without expanding unnecessary collection.
5. Notify authorized review roles and affected parties through accessible channels.
6. Apply corrective action and verify remediation.
7. Append a reviewable incident closure record.
