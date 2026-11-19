# Continuity Governance Envelope

## Status

This document defines the companion controls required around the six-object
continuity and provenance substrate.

The substrate is a private, local-first documentation and verification system.
It does not determine real-world identity, personhood, medical or cybernetic
status, continuity, legal standing, institutional eligibility, or authority.

No signature, score, attestation, state transition, invariant result, or
capability gate may be interpreted as such a determination.

## Required companion modules

| Module | Purpose | Minimum guarantee |
|---|---|---|
| Threat model | Defines adversaries, assets, trust boundaries, and residual risks | Privacy and security claims are scoped, never absolute |
| Recovery and revocation | Handles compromise, loss, expired consent, and withdrawal | Recovery cannot silently override revocation or privacy boundaries |
| Portability and exit | Allows export, local retention, and replacement of implementations | A user may leave without surrendering private records or attribution |
| Dispute and appeal | Provides accessible challenge, correction, and remedy pathways | A record conflict does not become an automated adverse decision |
| Accessibility and offline access | Supports assistive communication, low-resource, and disconnected use | No smartphone, cloud account, literacy level, or continuous network is required |
| Independent audit | Reviews implementation claims, security posture, and downstream misuse | Audits inspect both code behavior and institutional use conditions |
| Downstream-use restriction | Prevents silent conversion into ranking, identity, or eligibility infrastructure | Outputs are non-authoritative unless separately governed by lawful process |
| Lifecycle and deletion | Defines retention, erasure, artifact preservation, and public-anchor limits | Public commitments contain no private payload and deletion requests are actionable locally |

## Non-goals

The system does not:

- Authenticate a natural person, cybernetic host, agent, or institution.
- Diagnose consciousness, capacity, continuity, medical status, or cybernetic status.
- Create a public registry, public rank, credential, eligibility score, or identity database.
- Actuate infrastructure, medical systems, companion systems, financial systems, legal systems, or services.
- Replace legal process, institutional due process, guardianship law, accessibility law, or human judgment.
- Force public disclosure, mandatory key custody, mandatory cloud synchronization, or mandatory participation.

## Mandatory review triggers

A transition requires accessible human review before proceeding when it:

- Widens data disclosure or creates a new correlatable identifier.
- Changes from local to networked operation.
- Changes from non-actuating to actuating behavior.
- Adds a third-party recipient or institutional integration.
- Cannot be reversed or cannot preserve a recoverable artifact.
- Conflicts with an invariant, revocation, accessibility fallback, or privacy boundary.
- Involves a disputed predecessor, merge, fork, attribution, or delegated-consent claim.
- Would affect another person, a community, a public service, ecological conditions, or regulated activity.

## Evidence boundary

A valid signature means only that a specific public key verified a signature over
a specific canonical byte sequence. It does not establish the signer’s real-world
identity, intent, authority, truthfulness, legal ownership, capacity, continuity,
or institutional standing.

## Non-eligibility boundary

No output may be used as the sole or decisive basis to:

- Grant, deny, price, prioritize, condition, or terminate a benefit or service.
- Determine employment, housing, insurance, education, healthcare, credit,
  immigration, legal status, public assistance, or civic participation.
- Rank, classify, profile, surveil, or infer the identity or status of a person.
- Require disclosure of private continuity, neural, medical, biometric,
  physiological, cybernetic, companion-system, or operational information.

Any external request to use an output for those purposes must be refused by
default and routed to a separate lawful process with independent review,
meaningful notice, correction, appeal, and a non-digital alternative.
