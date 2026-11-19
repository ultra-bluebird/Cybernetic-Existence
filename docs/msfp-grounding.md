# MSFP Grounding and Evidence Register

## Purpose

This document translates the Micro-Swarm Firebreak Protocol (MSFP) research
vocabulary into standard engineering concepts, records the evidence status of
each component, and identifies the next verification step required before
stronger implementation or deployment claims are made.

MSFP is a rights-centered research architecture for temporary, capability-bound,
privacy-preserving external digital sessions. It is designed to support local
control, explicit consent, minimal disclosure, accessible recovery, and
non-interference.

## Scope

The implemented work includes local software models, policy logic, user
interfaces, synthetic test vectors, formal-model research artifacts, and
privacy-minimized audit concepts.

This project does not claim:

- Absolute security.
- Universal physical data erasure.
- Verification of personal identity, health, augmentation, credibility, or
  eligibility.
- Biological, medical, neural, nanosystem, or physical-system control.
- Clinical safety certification.
- Regulatory compliance.
- Institutional authority.
- Public CyberRank status, ranking, or eligibility determination.

## Evidence classes

| Class | Meaning |
|---|---|
| SIMULATED | Result produced by a deterministic local model, mock, or emulator |
| SYNTHETIC | Result produced by generated test data or a deterministic fixture |
| LOCAL POLICY | Result derived from a local policy, preference, or configuration rule |
| VERIFIED LOCALLY | Result confirmed by deterministic local validation or reproducible test |
| MANUAL LAB ENTRY | Value entered from a documented laboratory or measurement procedure |
| REQUIRES REVIEW | Claim requires independent security, privacy, accessibility, safety, legal, or engineering review |
| UNAVAILABLE | No evidence has been implemented or collected for this claim |

## Translation table

| MSFP vocabulary | Engineering translation | Current evidence | Current scope | Next verification step |
|---|---|---|---|---|
| Firebreak | Time-bounded, least-authority external session boundary | VERIFIED LOCALLY | Local application/session model | Property tests and TLA+ model checks |
| V-NIR | Ephemeral session-state buffer | VERIFIED LOCALLY | Process-local or browser-local runtime state | Verify no persistence of runtime secrets and session state |
| X-VAL | Strict parser, schema validator, and policy-enforcement boundary | SYNTHETIC | Synthetic frame-validation and test corpus model | Canonical binary codec and cross-language differential tests |
| TTL-HWC | Independent monotonic lease/watchdog abstraction | SIMULATED | Local timer/watchdog model | Separate-process or hardware-backed timing evaluation |
| Passive Stasis | Read-only simulated node state | SIMULATED | Abstract swarm-node model | TLA+ quorum and attestation safety checks |
| Cold Vapor | Sanitized state with no active external authority | VERIFIED LOCALLY | Session lifecycle target state | Restart and crash-recovery tests |
| Organichain | Signed append-only local audit/provenance chain | VERIFIED LOCALLY | Local receipt and artifact-history model | Checkpoint verification and tamper-recovery testing |
| Biometric Grounding | Device-enclosure EMC and thermal safety model | SIMULATED | Ordinary electronics thermal and integrity model | Manual laboratory test protocol and measured data |
| CyberRank | Private governance and preference layer | LOCAL POLICY | Local privacy, continuity, access, and communication constraints | Governance-card conformance and export-redaction tests |
| Swarm Consensus | Abstract multi-agent quorum simulation | SIMULATED | Deterministic node and quorum model | BFT test corpus, fault injection, and formal liveness model |

## Core security objective

The MSFP security objective is to constrain temporary external sessions so that
no external authority exists unless an explicit session is active and every
required control has passed.

A message is accepted only when:

\[
\operatorname{MessageAccepted}
\Rightarrow
\operatorname{Authenticated}
\land
\operatorname{SchemaValid}
\land
\operatorname{WithinLease}
\land
\operatorname{CapabilityPermits}
\land
\operatorname{ReplayFresh}
\land
\operatorname{WithinBudget}
\]

A terminated session has no external authority:

\[
\operatorname{Terminated}
\Rightarrow
\neg\operatorname{ExternalAuthority}
\land
\neg\operatorname{KeyUsable}
\land
\neg\operatorname{CapabilityUsable}
\]

A new session cannot be an in-place renewal of an expired or revoked session:

\[
\operatorname{NewActiveSession}
\Rightarrow
\operatorname{FreshAdmission}
\land
\operatorname{NewGeneration}
\land
\operatorname{NewLease}
\]

## Capability attenuation

A requested capability is attenuated before use:

\[
C_{\text{allowed}}
=
C_{\text{request}}
\cap
C_{\text{policy}}
\cap
C_{\text{consent}}
\cap
C_{\text{purpose}}
\]

The resulting capability may not exceed any source scope:

\[
C_{\text{allowed}}
\preceq
C_{\text{request}}
\]

\[
C_{\text{allowed}}
\preceq
C_{\text{policy}}
\]

\[
C_{\text{allowed}}
\preceq
C_{\text{consent}}
\]

\[
C_{\text{allowed}}
\preceq
C_{\text{purpose}}
\]

## Privacy and CyberRank governance

CyberRank is implemented only as a private, voluntary governance and preference
layer.

It may express:

- Accessible communication requirements.
- Privacy boundaries.
- Local-only preferences.
- Explicit revocable consent.
- Human-fallback requirements.
- Non-interference requirements.
- Correction and appeal requirements.
- Material-change review requirements.

It must not express:

- A public score.
- Integration depth.
- Health status.
- Augmentation status.
- Identity validity.
- Credibility.
- Eligibility.
- Institutional status.
- Consent compliance score.
- Ranking of people.

The system evaluates whether it meets governance duties. It does not evaluate or
rank a person.

## Formal properties

The formal-model work prioritizes these safety properties:

\[
\Box(
\operatorname{Revoked}
\Rightarrow
\neg\operatorname{ExternalAuthority}
)
\]

\[
\Box(
\operatorname{Expired}
\Rightarrow
\neg\operatorname{KeyUsable}
\land
\neg\operatorname{CapabilityUsable}
)
\]

\[
\Box(
\operatorname{MessageAccepted}
\Rightarrow
\operatorname{AllChecksPass}
)
\]

\[
\Box(
\operatorname{RecoveryInProgress}
\Rightarrow
\operatorname{LocalControlsAvailable}
\land
\operatorname{AccessibleStatusAvailable}
\land
\operatorname{HumanFallbackAvailable}
)
\]

\[
\Box(
\operatorname{ExternalAnalysis}
\Rightarrow
\neg\operatorname{AutomaticPersonalDowngrade}
)
\]

Liveness research includes:

\[
\Box(
\operatorname{Revoked}
\Rightarrow
\Diamond\operatorname{Cold}
)
\]

\[
\Box(
\operatorname{Expired}
\Rightarrow
\Diamond\operatorname{Cold}
)
\]

## Current test evidence

| Test category | Intended property | Evidence class |
|---|---|---|
| Session lifecycle tests | Active, revoked, expired, and Cold transitions are explicit | VERIFIED LOCALLY |
| Replay tests | A repeated sequence or nonce is rejected | SYNTHETIC |
| Capability attenuation tests | Allowed authority is the intersection of all active scopes | VERIFIED LOCALLY |
| Agent facade tests | Only read-only allow-listed operations are exposed | VERIFIED LOCALLY |
| Consent adversarial tests | Agent text cannot mutate consent scope | SYNTHETIC |
| Parser corpus tests | Malformed, oversize, duplicate, unknown, and downgrade vectors are rejected | SYNTHETIC |
| Audit-chain tests | Receipts have ordered parent linkage | VERIFIED LOCALLY |
| Swarm simulation tests | Read-only nodes cannot issue authority | SIMULATED |
| Accessibility tests | Keyboard, revoke, status, and reduced-motion paths remain usable | REQUIRES REVIEW |
| Enclosure tests | Simulated threshold logic reaches authority-off state | SIMULATED |

## Requirements-to-source register

| Requirement | Engineering reference category | Repository evidence |
|---|---|---|
| Least-privilege session authorization | Zero-trust access control | Capability attenuation rules and session policy |
| Strict input validation | Secure parser and schema validation practice | Frame corpus and parser tests |
| Key lifecycle and destruction | Key-management lifecycle practice | Session-key and teardown design |
| Signed audit receipts | Audit and provenance practice | Organichain receipt design |
| Selective disclosure | Privacy-preserving credential and data-minimization practice | Disclosure policy and local governance cards |
| Keyboard, contrast, status, and alert access | Web accessibility guidance | Consent console and accessibility test plan |
| EMC and thermal testing | Electronics enclosure engineering practice | Enclosure model and lab-entry pathway |

## Review boundaries

Before a feature may move from SIMULATED or REQUIRES REVIEW to VERIFIED LOCALLY,
the repository must include:

1. A versioned specification.
2. A defined threat or failure model.
3. Reproducible test vectors.
4. Automated tests.
5. Evidence-class labels.
6. Retention and privacy review.
7. Accessibility review where a user-facing function is affected.
8. Material-change review where policy, disclosure, or authority changes.

## Open research directions

- Canonical binary session encoding.
- Cross-language parser differential testing.
- AEAD record-layer interoperability.
- Independent monotonic watchdog process.
- Native encrypted local storage.
- Local audit checkpoint signatures.
- TLA+ safety and liveness proofs.
- Keyboard-only and screen-reader end-to-end testing.
- Synthetic swarm fault-injection corpus.
- Enclosure thermal and EMC manual-lab protocol.
