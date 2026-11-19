# T3 Starfish Research Map

## Purpose

This document defines the research trajectory for a non-actuating,
privacy-preserving, reproducible assistive-technology research specification.

The map organizes work around six connected research arms:

1. Evidence and materials
2. Decoder and feature science
3. Security and cryptographic governance
4. Data rights and telemetry audit
5. Agency and federated coordination
6. Provenance, software assurance, and acceptance

The central requirement is that no research arm may bypass consent, purpose
limitation, non-interference, accessible human review, or evidence boundaries.

## Core invariant

\[
\operatorname{Advance}
=
\operatorname{EvidenceBound}
\land
\operatorname{NonActuating}
\land
\operatorname{PurposeBound}
\land
\operatorname{AgencyPreserved}
\land
\operatorname{Reproducible}
\land
\operatorname{HumanReviewAvailable}
\]

## Starfish arms

| Arm | Primary objects | Required outputs | Completion rule |
|---|---|---|---|
| Evidence and materials | 01–03, 07–09, 44–45 | Evidence map, duration/replication factors, limitations | Claims distinguish bench, preclinical, clinical, and review evidence |
| Decoder and feature science | 04–06, 10–12, 34–37, 42, 47 | Locked protocol, calibration report, feature sufficiency assessment | Primary analysis is preregistered and agency-preserving |
| Security and cryptography | 13–21, 31, 39–40 | Helper-data policy, cipher registry, SBOM link, key lifecycle record | Revoked algorithms cannot be selected and leakage budgets are documented |
| Data rights and telemetry audit | 22–29, 31, 46 | Consent receipts, authorization decisions, encrypted audit chain | Access is purpose-bound, minimum-scope, revocable, and reviewable |
| Agency and federation | 25, 32–33, 37, 41, 48 | Agency gate, local-authority rules, topology hypothesis | No hub can override local consent or require participation |
| Provenance and acceptance | 23–24, 30, 38, 43, 49–50 | Provenance graph, reproducibility manifest, acceptance report | Each result links claim, evidence, data, method, result, review, and governance |

## Research sequence

### Contract convergence

- Lock schemas and controlled vocabularies.
- Publish canonical serialization and test vectors.
- Lint every claim as sourced, assumed, hypothesized, open, superseded, or withdrawn.
- Reject prohibited physical-actuation and identity-ranking operations.

### Integration spine

- Implement crypto-agility registry selection and anti-downgrade tests.
- Implement audit-chain append, verification, signature, and checkpoint logic.
- Implement provenance graph validation and result reachability checks.
- Implement topology parser with non-actuation enforcement.
- Implement T3 acceptance validation in continuous integration.

### Controlled research evaluation

- Lock adaptive-decoder comparison rules before result access.
- Compare raw and derived features only under authorized local analysis.
- Evaluate calibration, abstention, confirmation burden, agency, workload, and correction burden.
- Build material evidence maps with setting, duration, endpoint, replication, and limitation fields.
- Record results with evidence manifests and reproducibility links.

### Acceptance release

A research specification is release-ready only when:

\[
\operatorname{T3ReleaseCandidate}
=
\operatorname{SchemaValidationPassed}
\land
\operatorname{PolicyTestsPassed}
\land
\operatorname{IntegrationTestsPassed}
\land
\operatorname{ProvenanceGraphPassed}
\land
\operatorname{SBOMGatePassed}
\land
\operatorname{HumanReviewRecorded}
\land
\operatorname{OpenQuestionsReported}
\]

## Non-negotiable boundaries

- No autonomous body or device control.
- No physical deployment claim from simulation evidence.
- No personal biomedical outcome claim without direct evidence.
- No public CyberRank status, eligibility use, or identity inference.
- No raw sensitive telemetry, private configuration, raw PUF response, secret, or full consent record in shared artifacts by default.
- No external action without explicit approval and a reviewable receipt.
- No removal of accessible human or non-digital fallback.
