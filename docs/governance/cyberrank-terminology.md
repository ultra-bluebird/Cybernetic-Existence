# CyberRank Canonical Terminology

## Purpose

This document defines the canonical vocabulary for the CyberRank recognition framework.

CyberRank is a rights-centered institutional recognition framework for recording, reviewing, correcting, withdrawing, and—only with valid permission—publishing bounded descriptions of qualifying contributions. It is not a currency, asset, credit instrument, legal classification, clinical assessment, identity-verification system, employment system, government-service eligibility system, or behavioral scoring system.

All implementation artifacts, reports, policies, schemas, tests, and public materials use the terms in this document with the meanings defined here.

## Normative Language

The words **MUST**, **MUST NOT**, **REQUIRED**, **SHOULD**, **SHOULD NOT**, and **MAY** express implementation requirements.

A requirement using MUST or MUST NOT is a non-offsettable boundary. A favorable outcome, institutional objective, financial incentive, operational convenience, or aggregate score cannot override it.

## Core Concepts

### Recognition Record

A Recognition Record is a bounded institutional record describing a contribution, its submitted evidence, applicable review history, correction history, appeal history, withdrawal state, and publication permissions.

A Recognition Record MUST remain distinct from:

- Money, payment, wages, property, securities, collateral, tokenized assets, or financial instruments.
- Legal, governmental, immigration, clinical, disability, insurance, credit, or employment status.
- Essential-service access, including access to food, water, shelter, health services, emergency support, education, public benefits, mobility, communications, or grievance mechanisms.
- Mandatory identity verification, biometric collection, health-data collection, augmentation-data collection, neural-data collection, behavioral tracking, or continuous telemetry.
- A prediction of a person's worth, future conduct, capacity, loyalty, productivity, credibility, or eligibility.

### Recognition

Recognition is an institutional determination that a bounded contribution record has met the framework's documented criteria under an identified policy version.

Recognition describes a reviewed record. It does not confer ownership, authority over another person, compulsory public visibility, or entitlement to material advantage.

### Contribution

A Contribution is a documented action, research output, design, protocol, analysis, preservation activity, restorative intervention, or other work offered for institutional consideration.

A Contribution MAY include work completed through research, analysis, modeling, design, documentation, software development, public-interest planning, archival preservation, accessibility work, ecological stewardship, or other forms of protective and constructive effort.

A Contribution MUST NOT be evaluated by fame, wealth, publicity, personal identity disclosure, proprietary augmentation, physical presence, continuous connectivity, or willingness to surrender privacy.

### Hero Recognition

Hero Recognition is an optional descriptive recognition class for an exceptional documented contribution that substantially protects or restores a community, shared resource, ecological system, knowledge commons, critical service, or other protected public interest.

Hero Recognition MUST be:

- Achievement-based rather than spectacle-based.
- Specific to documented contribution records rather than a generalized judgment of human worth.
- Non-transferable, non-financial, non-collateralizable, and non-tokenizable.
- Subject to correction, appeal, withdrawal, and privacy controls.
- Independent of a requirement for continuing labor, public performance, or publicity.

### Recognition at Rest

Recognition at Rest means that a recognized person has chosen not to represent themselves as currently active in a contribution domain, or that no current activity claim is being made.

Recognition at Rest MUST NOT itself:

- Remove a historical recognition record.
- Downgrade a recognition decision.
- Reduce access to services, opportunities, or grievance processes.
- Trigger surveillance, outreach pressure, recurring evidence demands, or public labeling.
- Create an inference about capacity, health, cognition, reliability, or social value.

## Actor Roles

### Record Subject

The Record Subject is the person or collective represented by a Recognition Record.

A Record Subject MAY use a self-selected identifier, pseudonym, or holder-controlled credential. The system MUST support a Record Subject who does not provide a public name or external identity proof.

### Submitter

A Submitter is an actor who creates or contributes material to a Recognition Record.

A Submitter MAY be the Record Subject, an authorized representative, an institution, or another permitted contributor under the applicable policy version.

### Evidence Contributor

An Evidence Contributor supplies a bounded item of supporting, contextual, or corrective material.

Evidence contribution does not establish ownership of the Record Subject's identity, data, work, or future choices.

### Reviewer

A Reviewer assesses evidence and applies documented criteria.

A Reviewer MUST provide an accessible, reasoned, reviewable explanation for an adverse, restrictive, or publication-affecting determination.

### Review Panel

A Review Panel is a designated group responsible for a review decision, appeal review, policy interpretation, or procedural oversight.

A Review Panel MUST follow neutrality, conflict-disclosure, accessibility, privacy, and due-process requirements.

### Accessibility Steward

An Accessibility Steward is responsible for ensuring that essential workflow paths remain available through accessible, assistive-technology-compatible, non-digital, and offline-capable options where applicable.

### Privacy Steward

A Privacy Steward is responsible for reviewing sensitive-data handling, consent scope, retention, deletion, aggregate-release safeguards, privacy-budget use, and publication-risk controls.

### Policy Steward

A Policy Steward is responsible for publishing versioned policy text, compatibility notes, rationale, review records, and effective dates.

### Auditor

An Auditor evaluates whether the system's behavior, artifacts, logs, policies, and reports conform to documented requirements.

An Auditor MUST NOT receive more personal data than is necessary for the audit purpose.

### Essential Service Provider

An Essential Service Provider supplies or administers an essential service.

An Essential Service Provider MUST NOT use a Recognition Record, recognition state, credential presentation, publication choice, or refusal to disclose data as a condition for essential-service access.

## State Dimensions

A Recognition Record uses separate state dimensions. No single label may be used as a substitute for the complete state vector.

### Record Status

Record Status describes the lifecycle of the Recognition Record.

Allowed values:

- `self_attested`
- `evidence_submitted`
- `recognition_pending`
- `recognized`
- `correction_pending`
- `appeal_pending`
- `withdrawn`
- `closed`

Record Status MUST NOT encode identity confidence, social worth, service eligibility, economic value, health status, disability status, augmentation status, or legal standing.

### Review Status

Review Status describes the procedural condition of review.

Allowed values:

- `not_requested`
- `intake_validation`
- `evidence_review`
- `decision_drafted`
- `decision_issued`
- `appeal_review`
- `review_complete`
- `review_blocked_for_accessibility`
- `review_abstained`

`review_blocked_for_accessibility` means the system cannot proceed fairly until an accessible participation path is available.

`review_abstained` means the responsible body declined to make a substantive determination under documented limits. Abstention is not an adverse finding.

### Publication Status

Publication Status describes the visibility of a Recognition Record or derived statement.

Allowed values:

- `private`
- `pseudonymous`
- `public`
- `delayed`
- `suppressed`
- `withdrawn_from_publication`

Publication Status is independent of Record Status. A recognized record MAY remain private or pseudonymous.

### Consent Status

Consent Status describes whether a specific, documented processing or publication purpose is permitted.

Allowed values:

- `not_requested`
- `requested`
- `granted`
- `denied`
- `revoked`
- `expired`
- `not_applicable`

Consent MUST be specific to a declared purpose, scope, audience, retention period, and revocation method.

### Appeal Status

Appeal Status describes the availability and progress of review after a decision.

Allowed values:

- `not_available`
- `available`
- `submitted`
- `accessibility_accommodation_pending`
- `under_review`
- `resolved`
- `withdrawn_by_appellant`

An Appeal Status of `not_available` is valid only where no decision requiring appeal availability has been issued.

## Decision Classes

### Allow

`allow` means that the requested operation is permitted because all applicable requirements are satisfied.

### Reject

`reject` means that the requested operation is prohibited. A rejection MUST provide an accessible, plain-language reason unless doing so would create a documented security or privacy risk.

### Require Review

`require_review` means automated processing cannot safely or legitimately make the requested determination and must route the matter to an authorized review process.

### Abstain

`abstain` means the system or reviewer does not have sufficient authority, evidence, or safe basis to make the requested substantive determination.

Abstention MUST NOT be silently converted into a negative recognition outcome, adverse publication state, identity-risk label, or service restriction.

## Evidence Classes

### Self-Attestation

Self-Attestation is a statement provided by or on behalf of the Record Subject without an assertion that it has been externally verified.

Self-Attestation MUST be treated with dignity. It is neither proof of identity nor a basis for compulsory external verification.

### Submitted Evidence

Submitted Evidence is material offered to support, contextualize, challenge, or correct a recognition claim.

### Corroborating Evidence

Corroborating Evidence is material that independently supports a bounded factual element of a claim.

### Corrective Evidence

Corrective Evidence is material submitted to amend, contextualize, or challenge an existing record.

### Restricted Evidence

Restricted Evidence is material that must not be publicly disclosed because of privacy, safety, consent, confidentiality, accessibility, or reidentification risk.

### Excluded Evidence

Excluded Evidence is material the system must not collect, retain, infer, or use for recognition decisions.

Excluded Evidence includes unnecessary neural, biometric, health, augmentation, location, behavioral, financial, government-issued identity, and continuous-telemetry data.

## Consent Scopes

A Consent Scope is a purpose-limited permission record.

Every Consent Scope MUST state:

- The specific purpose.
- The authorized data categories.
- The permitted audience.
- The publication mode, if any.
- The retention period.
- The withdrawal and revocation method.
- The accessibility accommodation path.
- The policy version governing the consent.
- The consequences of refusing or revoking consent.

Valid purposes include:

- `private_record_processing`
- `review_participation`
- `appeal_participation`
- `pseudonymous_publication`
- `public_publication`
- `aggregate_reporting`
- `credential_presentation`

A Consent Scope MUST NOT authorize unrelated secondary uses.

## Publication Modes

### Private

Private means the record is available only to the Record Subject and authorized parties required for the declared processing purpose.

### Pseudonymous

Pseudonymous means the record may be represented using a holder-selected or institutionally assigned non-public identifier without requiring public disclosure of civil identity.

### Public

Public means a specifically approved, minimized representation of the record may be disclosed to a defined public audience.

Public status MUST NOT imply permission to disclose all underlying evidence or personal data.

### Delayed

Delayed means publication is authorized only after a declared future event or time condition. The authorization remains revocable until publication occurs.

### Suppressed

Suppressed means disclosure is blocked because privacy, safety, low-count, consent, procedural, accessibility, or other documented safeguards require non-release.

## Audit Events

An Audit Event is a minimized, append-only record that an accountable system event occurred.

Audit Events include:

- `record_created`
- `evidence_submitted`
- `evidence_accessed`
- `review_requested`
- `review_started`
- `review_abstained`
- `decision_drafted`
- `decision_issued`
- `publication_requested`
- `consent_granted`
- `consent_revoked`
- `publication_suppressed`
- `publication_completed`
- `correction_requested`
- `correction_applied`
- `appeal_submitted`
- `appeal_resolved`
- `policy_version_activated`
- `retention_period_expired`
- `deletion_completed`
- `essential_service_independence_checked`

Audit Events MUST minimize personal data and MUST NOT expose raw sensitive evidence by default.

## Policy Version

A Policy Version is an immutable identifier for a published set of applicable governance and technical rules.

A Policy Version MUST include:

- Effective date.
- Change rationale.
- Accessibility impact statement.
- Privacy impact statement.
- Rights impact statement.
- Compatibility and migration statement.
- Review and appeal path for affected changes.

## Non-Offsettable Boundaries

The following boundaries apply to every state, transition, policy, schema, report, credential, and interface:

- Recognition MUST NOT convert into money, property, collateral, tradable value, creditworthiness, financial access, or authority over another person.
- Recognition MUST NOT be used to gate essential services.
- A person MUST NOT be required to reveal identity, biometrics, health information, augmentation information, neural information, location history, or continuous telemetry merely to self-attest, request review, request correction, appeal, withdraw, or access an essential service.
- Publication MUST NOT occur without valid purpose-specific permission or another explicitly documented and rights-reviewed basis.
- Consent revocation MUST stop future processing or publication within the scope of the revoked permission, subject only to clearly documented retention obligations.
- An adverse final decision MUST NOT be issued without accessible notice, understandable reasons, a correction path, an appeal path, and a documented opportunity to participate.
- Inactivity, rest, disability, assistive-technology use, offline access, refusal of optional telemetry, or refusal of public disclosure MUST NOT result in demotion, deprivation, or adverse inference.
- Credential possession or verification MUST NOT be treated as identity disclosure or essential-service eligibility.
