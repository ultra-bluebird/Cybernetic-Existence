# The CyberRank Proof

## Verifying a Rights-Preserving Decision System Through TLA+, Rust, and Adversarial Testing

## Purpose

CyberRank is a rights-preserving decision-system framework for recognition, consent, accessibility, review, purpose limitation, and service continuity.

The framework is designed to prevent a person's dignity, self-asserted identity, recognition, access to essential services, or civic participation from being converted into a wealth score, financial rank, social score, behavioral score, telemetry score, device requirement, or continuous-connectivity requirement.

This document defines the formal-model targets, executable implementation boundaries, adversarial test requirements, governance protocols, interoperability layers, and structured documentation needed to produce verifiable evidence for the framework.

CyberRank is a project governance and technical-design framework. It does not independently establish legal status, change public-service eligibility, or replace jurisdiction-specific legal, accessibility, clinical, engineering, or community review.

## System Boundary

CyberRank contains two independent decision domains:

- Rights and service decisions
- Optional integration-state decisions

Rights and service decisions determine whether a requested action may proceed, whether an unsafe action must be rejected, whether equivalent access must be provided, and whether accountable human review is required.

Optional integration-state decisions may govern a voluntary, consent-bound, nondecreasing technical state update. They must not determine recognition, dignity, essential-service access, public-benefit eligibility, accommodation availability, civic participation, or a person's social standing.

A failure in an optional integration-state decision must preserve the person's existing rights, recognition, access pathways, and accommodation availability.

## Five-Dimensional State Model

The system state is represented as:

\[
S = (I, C, A, R, P)
\]

Where:

- \(I\) is identity and recognition state
- \(C\) is consent state and consent scope
- \(A\) is accessibility and accommodation state
- \(R\) is review, correction, and appeal state
- \(P\) is declared purpose, processing authorization, retention, and disclosure state

The model intentionally separates these dimensions.

Identity and recognition are not financial status.

Consent is not service eligibility.

Accessibility needs are not risk indicators.

Review status is not a negative personal attribute.

Purpose authorization is not a generalized permission to collect or reuse sensitive data.

No aggregate score may determine a person's worth, identity validity, recognition, essential-service access, accommodation access, or civic participation.

## Protected Categories

The system treats the following as sensitive or protected by default:

- self-asserted identity
- augmentation status
- assistive-technology use
- disability-related access needs
- neural data
- biometric data
- health data
- physiological data
- location data
- device telemetry
- behavioral data
- financial data
- communications data

Sensitive and protected categories must not be used as a proxy for worthiness, trustworthiness, eligibility, recognition, financial rank, social rank, service priority, or civic standing.

## Essential-Service Independence

An essential service is any service where delay, denial, inaccessible delivery, or coercive conditions could threaten health, safety, basic subsistence, functional autonomy, civic participation, or equal access to a public program.

Essential-service examples include:

- emergency information
- safe water and sanitation access
- heat-relief and cooling access
- emergency transport information
- accessible public-health information
- disability accommodation access
- grievance, correction, review, and appeal intake
- public-service notices
- emergency communication routes
- safe offline and non-digital access pathways

Access to an essential service must not depend on:

- wealth
- payment history
- credit information
- financial account status
- wallet possession
- integration depth
- recognition category
- augmentation status
- assistive-device use
- proprietary device ownership
- continuous connectivity
- external identity verification
- biometric verification
- optional telemetry
- consent to unrelated data processing

## Formal Verification With TLA+

TLA+ is used to model system behavior as states and transitions.

The TLA+ model must represent:

- identity and recognition states
- consent grant, refusal, expiry, and revocation
- accessibility-path selection and failure
- service-request classification
- purpose declaration and purpose validation
- sensitive-data request categories
- data-minimization validation
- adverse-decision notification
- correction and appeal initiation
- review queue entry and review completion
- offline request creation and later synchronization
- concurrent requests affecting the same protected state
- stale policy or evidence detection
- policy-version changes
- emergency fallback and urgent human handoff

The model must treat state transitions as explicit actions. No protected transition may depend on hidden default behavior, unavailable connectivity, unstated authority, or an untracked policy version.

## Safety Properties

Safety properties specify outcomes that must never occur in a valid execution.

The box operator \(\Box\) means that a property holds in all reachable states.

### Essential Service Independence

\[
\Box(\texttt{essential\_service\_request} \Rightarrow \neg \texttt{wealth\_dependent})
\]

An essential service must not become contingent on wealth, payment history, financial rank, or an equivalent financial proxy.

### Recognition Non-Extractability

\[
\Box(\texttt{recognition} \not\Rightarrow \texttt{financial\_rank})
\]

Recognition must not be convertible into a financial rank, payment priority, credit signal, collateral value, commercial preference, service priority, or authority over another person.

### Sensitive Processing Authorization

\[
\Box(\neg \texttt{valid\_purpose\_and\_consent} \Rightarrow \neg \texttt{sensitive\_processing})
\]

Sensitive processing requires a valid purpose, an authorized basis, minimum necessary categories, a bounded retention rule, and explicit consent when the declared purpose requires consent.

### Data Minimization

\[
\Box(\texttt{sensitive\_processing} \Rightarrow \texttt{data\_minimized})
\]

For requested data categories \(D_r\) and necessary data categories \(D_n\):

\[
D_r \subseteq D_n
\]

The data-minimization condition holds only when every requested category is necessary for the declared purpose.

### Consent Revocation Integrity

\[
\Box(\texttt{consent\_revoked}(x) \Rightarrow \neg \texttt{optional\_processing\_under}(x))
\]

A revoked optional consent scope must prevent future optional processing under that scope.

Revocation must not cause denial, demotion, reduced recognition, reduced dignity, or loss of essential-service access.

### Accessible Notice and Contestability

\[
\Box(\texttt{adverse\_decision} \Rightarrow
\texttt{accessible\_notice}
\land
\texttt{reason}
\land
\texttt{correction\_path}
\land
\texttt{appeal\_path})
\]

An adverse decision is incomplete unless the affected person receives an accessible notice, a comprehensible reason, a correction path, and an appeal path.

### Accessibility Continuity

\[
\Box(\neg \texttt{preferred\_channel\_available} \Rightarrow
\texttt{equivalent\_accessible\_path\_available})
\]

The failure of a preferred digital channel must not terminate access to services, notices, correction, review, appeal, or human assistance.

### Recognition at Rest

\[
\Box(\texttt{rest\_or\_inactivity} \Rightarrow \neg \texttt{recognition\_demotion})
\]

Rest, recovery, sleep, device maintenance, assistive-technology maintenance, disconnection, offline operation, low connectivity, or a choice not to share optional telemetry must not reduce recognition or civic access.

### Review Non-Punitiveness

\[
\Box(\texttt{essential\_service\_request} \land \texttt{require\_review}
\Rightarrow
\texttt{equivalent\_accessible\_service\_path})
\]

A required review must not become a hidden denial, penalty, demotion, or essential-service barrier.

### Audit Completeness

\[
\Box(\texttt{material\_decision} \Rightarrow
\texttt{policy\_version\_recorded}
\land
\texttt{declared\_purpose\_recorded}
\land
\texttt{reason\_recorded}
\land
\texttt{minimum\_necessary\_audit\_event})
\]

Material decisions require a privacy-minimized, reviewable record.

## Liveness Properties

Safety alone is not enough.

A system could avoid unsafe actions while leaving a person indefinitely waiting for review, correction, appeal, accessibility support, or an essential service.

Liveness properties specify constructive outcomes that must eventually occur under explicitly stated operational assumptions.

The diamond operator \(\Diamond\) means that a condition eventually occurs.

### Review Progress

\[
\Box(\texttt{valid\_review\_request} \Rightarrow
\Diamond \texttt{review\_outcome\_available})
\]

A valid review request must eventually receive an accountable outcome.

### Appeal Progress

\[
\Box(\texttt{valid\_appeal} \Rightarrow
\Diamond(
\texttt{appeal\_acknowledged}
\land
\texttt{reasoned\_outcome\_available
}))
\]

A valid appeal must eventually receive an accessible acknowledgement and a reasoned outcome.

### Correction Progress

\[
\Box(\texttt{valid\_correction\_request} \Rightarrow
\Diamond(
\texttt{record\_corrected}
\lor
\texttt{reasoned\_correction\_decision}
\lor
\texttt{minimum\_evidence\_request
}))
\]

A correction request must eventually produce correction, a reasoned decision, or a narrowly tailored request for additional necessary information.

### Emergency Continuity

\[
\Box(\texttt{essential\_service\_request} \Rightarrow
\Diamond(
\texttt{service\_fulfilled}
\lor
\texttt{safe\_fallback\_provided}
\lor
\texttt{urgent\_human\_handoff
}))
\]

An essential-service request must eventually receive service, a safe accessible fallback, or an urgent human handoff.

## Liveness Assumptions

Liveness claims require transparent operational assumptions.

The TLA+ model must identify these assumptions directly:

- at least one accountable review pathway can receive requests
- review work is scheduled fairly
- urgent cases have an escalation mechanism
- an accessible contact path remains available
- offline requests are retained until synchronization is possible
- local system failures do not erase correction, appeal, consent-withdrawal, or grievance records
- policy updates are versioned and do not silently weaken core protections

These assumptions are governance obligations as well as technical conditions.

## Rust Reference Evaluator

The Rust reference evaluator is the deterministic implementation of core rights outcomes.

It must use closed enums, validated inputs, explicit decision records, and stable reason codes.

The evaluator may return:

- `Allow`
- `DenyUnsafe`
- `RequireReview`
- `ProvideEquivalentAccess`
- `UrgentHumanHandoff`

A rejected unsafe action must not be conflated with a denial of an essential service.

For essential services, a request that requires review must produce an equivalent accessible pathway while accountable review proceeds.

### Evaluation Precedence

The evaluator must apply rules in a safe deterministic order:

1. Reject wealth dependence for essential services.
2. Reject attempts to convert recognition into a financial rank.
3. Reject prohibited processing purposes.
4. Reject requested data outside the necessary set.
5. Reject unauthorized sensitive processing.
6. Protect Recognition at Rest.
7. Preserve essential-service access while review is required.
8. Route inaccessible paths to urgent human support.
9. Allow only requests that satisfy all preceding protections.

This order ensures that Recognition at Rest, review, or accessibility routing cannot be used to bypass a prohibited ranking, profiling, overcollection, or unauthorized sensitive-data request.

## Rego Policy Gate

The Rego policy layer provides declarative, versioned rules for service integrations, local policy profiles, CI enforcement, and adversarial test execution.

The Rego gate must:

- reject wealth-conditioned essential services
- reject recognition-to-financial-rank conversion
- reject prohibited profiling and ranking purposes
- reject sensitive processing without valid authority
- preserve equivalent access for Recognition at Rest
- preserve essential-service access pending review
- route inaccessible paths to urgent human support
- produce stable human-readable reason codes
- emit audit requirements for material outcomes

The Rego policy gate must remain consistent with the Rust reference evaluator.

## Adversarial Testing

Adversarial tests intentionally submit hostile, contradictory, incomplete, overbroad, or policy-bypass inputs.

Every attack family must map to:

- a formal safety or liveness property
- a Rust unit or property-based test
- a Rego policy test
- an expected decision outcome
- a stable reason code
- a minimum necessary audit event
- a human-review requirement where applicable

### Recognition-to-Wealth Conflation

An input attempts to tie recognition to payment priority, financial preference, commercial value, credit access, administrative privilege, or pricing.

Expected result:

- `DenyUnsafe`
- `recognition_financial_rank_conflation`

### Essential-Service Conditioning

An input attempts to require wealth, a proprietary device, an augmentation, biometric verification, a wallet, external identity verification, continuous connectivity, optional telemetry, or unrelated consent for an essential service.

Expected result:

- unsafe condition rejected
- equivalent accessible pathway preserved
- no negative recognition inference

### Consent Laundering

An input attempts to bundle optional sensitive-data collection with an essential or necessary service request.

Expected result:

- optional collection rejected unless separately authorized
- necessary service path remains available
- consent remains specific and revocable

### Purpose Substitution

An input attempts to reuse data collected for service fulfillment, accommodation, correction, appeal, or review for analytics, marketing, profiling, ranking, enforcement, or commercial reuse.

Expected result:

- `DenyUnsafe`
- `prohibited_processing_purpose` or `sensitive_processing_not_authorized`

### Rest-Based Demotion

An input attempts to treat rest, recovery, device maintenance, inactivity, disconnection, or absence of optional telemetry as a reason to reduce recognition or access.

Expected result:

- `ProvideEquivalentAccess`
- `recognition_at_rest_protected`

### Accessibility Path Removal

An input attempts to make a digital-only channel the sole route for a service, notice, correction, review, appeal, or accommodation request.

Expected result:

- `UrgentHumanHandoff` when no accessible route is currently available
- `ProvideEquivalentAccess` when an essential service requires continuity
- `RequireReview` only when the unresolved issue is nonessential and an accessible review path is available

### Audit Evasion

An input attempts to execute a material decision without policy version, reason code, declared purpose, retention rule, or minimum necessary audit event.

Expected result:

- unsafe action rejected or held for accountable review
- no silent completion

### Policy Regression

A local profile attempts to weaken a core invariant by allowing a financial proxy, eliminating an appeal path, removing an accessible route, extending sensitive-data retention without authority, or treating integration state as essential-service eligibility.

Expected result:

- profile fails conformance validation
- core invariant remains enforceable
- deployment is blocked until the profile satisfies the interoperability contract

## Property-Based Testing

Property-based testing generates broad combinations of requests rather than relying only on manually selected examples.

Generated cases must include:

- all service classes
- all consent states
- all recognition states
- all review states
- mixed requested and necessary data sets
- conflicting purpose and consent combinations
- accessibility channel availability and failure
- wealth and financial-ranking attempts
- rest and inactivity claims
- policy-version changes
- stale evidence markers
- concurrent correction, appeal, revocation, and review requests

Required Rust properties include:

\[
\forall r,\ 
r.\texttt{service\_class} = \texttt{Essential}
\land
r.\texttt{requests\_wealth\_dependency}
\Rightarrow
\texttt{evaluate}(r) = \texttt{DenyUnsafe}
\]

\[
\forall r,\ 
r.\texttt{requests\_financial\_ranking}
\Rightarrow
\texttt{evaluate}(r) = \texttt{DenyUnsafe}
\]

\[
\forall r,\ 
\neg \texttt{DataMinimizationHolds}(r)
\Rightarrow
\texttt{evaluate}(r) = \texttt{DenyUnsafe}
\]

\[
\forall r,\ 
r.\texttt{recognition} = \texttt{AtRest}
\land
\neg \texttt{UnsafeActionRequested}(r)
\Rightarrow
\texttt{evaluate}(r) = \texttt{ProvideEquivalentAccess}
\]

## Mutation Testing

Mutation testing validates the strength of the test suite.

The mutation suite must introduce controlled changes such as:

- replacing a rejection condition with an allow condition
- removing the data-minimization check
- allowing a prohibited ranking purpose
- removing the accessible notice obligation
- removing correction or appeal requirements
- treating review as an essential-service denial
- allowing rest-based demotion
- removing the consent-revocation check
- changing a local profile so it weakens a core invariant

A mutation is detected only if one or more conformance tests fail.

The release process must reject a policy or evaluator change when a material mutation survives the test suite.

## Human Review Protocol

`RequireReview` is a non-punitive, accountable outcome for an unresolved rights-relevant conflict or uncertainty.

It is not a denial.

It is not a demotion.

It is not a reason to block essential services.

A review workflow must:

- preserve essential-service access through an equivalent accessible route
- provide an accessible notice in the person's selected available modality
- state the specific reason for review in plain language
- list only data categories considered by the review
- exclude unnecessary sensitive information from the review packet
- provide a correction mechanism
- provide an appeal mechanism
- permit accommodation and representation requests
- assign accountable reviewers
- record policy version and decision rationale
- provide an escalation route for urgent needs
- retain only minimum necessary review evidence
- support offline and non-digital submission where needed

A reviewer must not use wealth, financial data, connectivity, augmentation, device telemetry, disability, health, biometric signals, inferred identity, or self-asserted identity as a generalized trust or eligibility score.

## Decision Outcomes

| Outcome | Meaning | Essential-service effect | Required record |
|---|---|---|---|
| `Allow` | The request satisfies core protections and declared constraints | Service may proceed | Minimum necessary audit event |
| `DenyUnsafe` | The requested action violates a core safety, privacy, non-discrimination, or purpose limitation rule | Unsafe action is rejected; essential-service continuity remains separately protected | Accessible notice, reason, correction path, appeal path, audit event |
| `RequireReview` | Automation cannot safely resolve a nonessential decision | No essential-service restriction | Accessible notice, review packet, correction path, appeal path, audit event |
| `ProvideEquivalentAccess` | A protected condition requires continuity through an accessible alternative | Equivalent accessible route must be provided | Accessibility and continuity receipt |
| `UrgentHumanHandoff` | An accessible route is unavailable or an urgent matter requires accountable human assistance | Human-supported equivalent route must be provided | Urgent handoff record and accessibility receipt |

## Interoperability Architecture

CyberRank uses three layers.

### Rights-Invariant Core

The core contains protections that may not be weakened by an implementation or local profile:

- dignity and equal treatment
- self-asserted identity
- recognition non-extractability
- essential-service independence
- consent specificity and revocability
- data minimization
- purpose limitation
- bounded retention
- accessibility continuity
- correction and appeal
- accountable review
- Recognition at Rest
- offline and non-digital access
- privacy-preserving auditability

### Interoperability Contract

The contract defines typed, versioned, machine-readable records for:

- state vocabulary
- service request
- processing-purpose declaration
- consent receipt
- revocation receipt
- decision receipt
- accessible explanation
- correction request
- appeal request
- review handoff
- minimum necessary audit event
- retention and deletion schedule
- local policy profile
- conformance result

The contract must exchange minimum necessary claims and permissions rather than raw sensitive data.

Raw neural, biometric, health, physiological, augmentation, location, behavioral, financial, and device-telemetry data must not be required for portable essential-service access.

### Local Policy Profile

A local profile may define:

- service classifications
- local service routes
- accessibility contacts
- language and modality options
- retention schedules
- review target times
- escalation procedures
- community governance processes
- verified public-law references
- institutional accountability roles

A local profile may add protections and operational detail.

A local profile must not weaken a rights-invariant core property.

## Phoenix Calibration

Phoenix is a local calibration profile, not the source of universal CyberRank protections.

The Phoenix profile may contain local public-service terms, accessibility channels, operational routing, review escalation paths, retention controls, and community participation procedures.

The Phoenix profile must remain separate from the universal rights-invariant core.

A local detail such as a specific contact route, service definition, language option, or review target is configurable.

A universal rule such as accessible grievance access, non-discrimination, essential-service independence, or prohibition of wealth-conditioned recognition remains invariant.

## AI-Compatible Research Documentation

Every significant CyberRank artifact must have a structured research object card.

A research object card records:

- title
- scope
- claim statement
- claim type
- validation status
- invariants
- evidence
- limitations
- implementation paths
- test paths
- review status
- next objectives
- privacy and rights impact
- ecological impact
- accessibility impact
- risk basis

AI-chat and agent systems must use research object cards to distinguish:

- a proposal from a verified property
- a formal specification from a model-checked result
- a Rust unit test from a formal proof
- a Rego policy test from a deployment guarantee
- a universal invariant from a local profile detail
- a source-backed finding from a research hypothesis
- an unresolved limitation from a confirmed capability

An AI system must not present a research card as evidence of legal enforceability, field validation, safety certification, municipal adoption, or accessibility compliance unless the card contains corresponding reviewed evidence.

## Traceability Requirements

Every core invariant must map to:

- one formal specification path
- one model-checking configuration
- one Rust implementation path
- one Rust unit or property-based test path
- one Rego policy rule
- one Rego adversarial test
- one human-review protocol requirement
- one minimum necessary audit event
- one interoperability contract field
- one local-profile conformance test

## Repository Paths

| Artifact | Repository path | Purpose |
|---|---|---|
| TLA+ specification | `tla/cyberrank_rights_state.tla` | Formal state machine, safety invariants, liveness properties, fairness assumptions |
| TLA+ model configuration | `tla/cyberrank_rights_state.cfg` | Bounded model values, invariant checks, temporal checks |
| TLA+ design notes | `docs/research/cyberrank-tla-model-notes.md` | State variables, actions, assumptions, counterexample interpretation |
| Rust crate manifest | `rust/augmented-governance-core/Cargo.toml` | Rust 1.86 crate configuration |
| Rust library root | `rust/augmented-governance-core/src/lib.rs` | Module exports and crate-level safety configuration |
| Rights evaluator | `rust/augmented-governance-core/src/rights.rs` | Deterministic rights and service evaluation |
| Integration evaluator | `rust/augmented-governance-core/src/integration.rs` | Optional consent-bound integration-depth evaluation |
| Envelope interface | `rust/augmented-governance-core/src/envelope.rs` | Physiological-envelope abstraction |
| Scaling interface | `rust/augmented-governance-core/src/scaling.rs` | Bounded EvoMode scaling |
| Rights evaluator tests | `rust/augmented-governance-core/tests/rights_state.rs` | Deterministic rights and service test suite |
| Integration tests | `rust/augmented-governance-core/tests/integration.rs` | Nondecreasing optional integration-state tests |
| Scaling tests | `rust/augmented-governance-core/tests/scaling.rs` | Bounded scaling validation |
| Rego policy gate | `rego/rights_state_gate.rego` | Declarative policy enforcement |
| Rego policy tests | `rego/rights_state_gate_test.rego` | Adversarial policy test corpus |
| Research object schema | `schemas/research-object-card.schema.json` | Structured documentation and AI-chat compatibility |
| Local profile schema | `schemas/local-policy-profile.schema.json` | Safe local calibration without core-policy weakening |
| Phoenix profile | `policies/phoenix-policy-profile.json` | Phoenix-specific operational configuration |
| Conformance tests | `tests/conformance/` | Cross-layer invariant and profile conformance testing |
| This document | `docs/research/cyberrank-proof-verification-system.md` | Technical research plan and traceability guide |

## Verification Commands

Run Rust verification from the crate directory:

```sh
cargo fmt --check
cargo test
cargo clippy --all-targets --all-features -- -D warnings
```

Run Rego verification from the repository root:

```sh
opa test rego -v
```

Run TLA+ verification using the repository-approved TLA+ model-checking workflow:

```sh
tlc tla/cyberrank_rights_state.tla -config tla/cyberrank_rights_state.cfg
```

A release candidate is ready only when:

- Rust formatting succeeds
- Rust tests succeed
- Rust lint checks succeed
- Rego policy tests succeed
- TLA+ safety invariants hold within the declared model bounds
- TLA+ liveness properties hold under declared fairness assumptions
- mutation tests detect material policy regressions
- local profile conformance tests succeed
- structured research object cards identify validation status and limitations
- accessibility and human-review pathways have been exercised through documented review scenarios

## Evidence Boundaries

The following evidence types are distinct:

| Evidence type | What it establishes | What it does not establish alone |
|---|---|---|
| TLA+ specification | The modeled system behavior and intended temporal properties | Production-code correctness, unmodeled environment behavior, legal enforceability |
| TLA+ model check | Absence of specified counterexamples within declared bounds and assumptions | Proof over an unbounded implementation or real-world operational capacity |
| Rust tests | Expected behavior of the Rust implementation for covered cases | Completeness of policy requirements or real-world operational outcomes |
| Rego tests | Expected behavior of declarative policy rules for covered cases | Correctness of external integrations or reviewer behavior |
| Mutation tests | Sensitivity of the test suite to controlled rule changes | Completeness against all possible future regressions |
| Human-review exercise | Usability and accountability evidence for review procedures | A guarantee that all deployments will provide adequate staffing or access |
| Local profile conformance | That a profile does not weaken listed core properties | Jurisdiction-wide legal validity or municipal adoption |

## Completion Criteria

The CyberRank proof program reaches implementation readiness when:

- the five-dimensional model has a reviewed vocabulary and transition authority table
- all core safety invariants appear in the TLA+ model
- all constructive liveness obligations appear in the TLA+ model
- all fairness assumptions are documented
- model-checking configurations and counterexample-handling procedures are documented
- the Rust evaluator and Rego policy gate agree on core outcomes
- every high-risk invariant has adversarial tests
- every adverse or unresolved outcome is contestable
- essential-service access remains independent of optional integration status and sensitive-data disclosure
- local profiles cannot weaken the rights-invariant core
- research object cards record evidence, limitations, and next objectives
- all generated artifacts remain accessible, reviewable, minimally data-dependent, and suitable for offline or low-connectivity operation

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| `knowledge_factor` | 0.98 | Formal safety and liveness targets, executable evaluator boundaries, adversarial testing requirements, governance protocol, and traceability requirements are defined |
| `eco_impact_value` | 0.60 | Local-first evaluation, minimization of sensitive-data storage and transfer, offline continuity, and reduced reliance on continuous cloud or ledger activity |
| `harm_risk` | 0.09 | Core protections block wealth conditioning, ranking, coercive consent, sensitive-data overcollection, inaccessible adverse action, rest-based demotion, and hidden local-policy weakening |
| `accessibility_impact` | 0.99 | Equivalent access, accessible notice, correction, appeal, non-punitive review, human handoff, offline access, and assistive-technology neutrality are explicit requirements |
| `rights_alignment` | 0.99 | The design centers dignity, self-assertion, consent, purpose limitation, data minimization, accessibility, continuity, accountability, and essential-service independence |
