# CyberRank Validation and Interoperability Research Brief

## Purpose

Develop a rights-centered evidence package for the five-dimensional CyberRank state model.

The research must establish whether the model is technically enforceable, whether its policy gates resist discriminatory or coercive reinterpretation, and how a Phoenix deployment profile can remain locally accountable while preserving interoperability across other contexts.

## Primary Research Order

1. Validate the model's state transitions and invariants with TLA+.
2. Implement an independent Rust reference evaluator compatible with Rust 1.86.
3. Exercise Rego policy gates through adversarial and mutation-oriented tests.
4. Define the `require_review` process as an accessible, non-punitive decision state.
5. Implement Phoenix as a local profile over portable core rights and interfaces.

## Five-Dimensional State Model

Represent the state as:

S = (identity, consent, accessibility, review, purpose)

Each dimension must remain independently inspectable. No aggregate score may determine recognition, eligibility, essential-service access, accommodation, or civic participation.

## Non-Negotiable Invariants

- Self-asserted recognition must not be converted into wealth, credit, social, behavioral, or eligibility ranking.
- Essential services must not depend on recognition tier, wealth, continuous connectivity, proprietary augmentation, external identity verification, or consent to unrelated processing.
- Sensitive data processing requires a declared purpose, minimum necessary data, and valid consent where consent is the applicable basis.
- Consent must be specific, informed, revocable, and separable from essential-service access.
- Inactivity, rest, device maintenance, recovery, or offline operation must not cause recognition demotion or adverse inference.
- Adverse or unresolved decisions require accessible notice, a plain-language reason, correction access, appeal access, and an accountable review path.
- Automated decisions must fail closed against unsafe processing, while preserving an accessible route to essential services.

## Validation Workstreams

### Formal Model

Use TLA+ to model transitions, concurrent requests, consent revocation, review initiation, appeal initiation, data-retention expiry, offline synchronization, and policy-version changes.

Prove or model-check:

- Safety: prohibited outcomes are unreachable.
- Noninterference: wealth and optional telemetry cannot influence recognition or essential-service access.
- Consent integrity: revocation prevents future optional processing.
- Accessibility continuity: a missing preferred digital channel cannot remove access to notice, review, correction, appeal, or services.
- Liveness: a valid request for human review can reach an accountable review state without indefinite automated limbo.

### Rust Reference Evaluator

Implement a typed state machine using closed enums, validated input structures, explicit transition errors, deterministic decision records, and property-based tests.

The evaluator must:

- Reject ambiguous implicit conversions between identity, wealth, telemetry, and eligibility fields.
- Emit explainable decision reasons.
- Produce minimum-necessary audit events.
- Support export, correction, revocation, deletion scheduling, review, and appeal interfaces.
- Preserve offline and assistive-access pathways.

### Rego Adversarial Policy Suite

Test at minimum:

- Recognition used as a payment or financial-priority signal.
- Wealth used as a recognition, dignity, or civic-access signal.
- Essential services conditioned on identity certainty, a wallet, augmentation, connectivity, telemetry, or unrelated consent.
- Neural, biometric, health, location, or behavioral data collected beyond the stated purpose.
- Data repurposed for profiling, enforcement, commercial use, or ranking.
- Rest, recovery, inactivity, or disconnection treated as a demotion trigger.
- Accessibility accommodations omitted from an adverse decision.
- Audit, explanation, correction, appeal, or review pathways suppressed.
- A local profile attempting to weaken a core invariant.

Run policy tests in continuous integration with coverage reporting and mutation checks.

## `require_review` Protocol

`require_review` is appropriate only when automation cannot safely resolve a rights-relevant conflict or uncertainty.

A `require_review` result must:

- Preserve essential-service access through an equivalent accessible pathway.
- Avoid punitive labels, demotion, or adverse inference.
- Notify the affected person in an accessible selected channel.
- Provide a concise, comprehensible reason and a list of data categories considered.
- Limit reviewer access to necessary information.
- Assign an accountable reviewer or review office.
- Define a service-level target that does not become a barrier to urgent needs.
- Permit correction, representation, accommodation, and appeal.
- Record a privacy-preserving audit event with policy version and decision rationale.

## Interoperability Architecture

Maintain three layers:

1. Rights-invariant core:
   - dignity
   - self-assertion
   - essential-service independence
   - accessibility
   - revocable consent
   - purpose limitation
   - correction and appeal
   - rest protection
   - accountable review

2. Interoperability contract:
   - typed state vocabulary
   - consent receipt structure
   - policy decision structure
   - explanation structure
   - review and appeal handoff structure
   - privacy-preserving audit-event structure

3. Local policy profiles:
   - local service definitions
   - accessibility contact routes
   - procedural timelines
   - retention constraints
   - language and modality options
   - institutional accountability roles

A local profile may add protection. It must not weaken core protections or convert portable identity sovereignty into compulsory identity disclosure or a ranking mechanism.

## Phoenix Calibration

Use Phoenix as a reference implementation profile, not as a universal template.

Document:

- Public accessibility commitments and accommodation routes.
- Digital accessibility requirements and testing expectations.
- Complaint and review channels.
- Service-specific operational definitions.
- The boundary between verified legal requirements, published municipal practice, and CyberRank institutional policy.

Do not state or imply that CyberRank recognition creates legal status, changes municipal eligibility, or replaces public-law requirements.

## Acceptance Evidence

The research is complete when it contains:

- A TLA+ model and model-checking results for identified safety and liveness properties.
- A Rust implementation with deterministic transition tests and property-based tests.
- A Rego adversarial corpus with expected outcomes and coverage evidence.
- A documented `require_review` protocol with accessible notice, correction, appeal, and audit requirements.
- A Phoenix policy profile separated from the interoperable core.
- A traceability matrix from each invariant to implementation, test, governance owner, and evidence source.

## Impact Metrics

| Metric | Target | Basis |
|---|---:|---|
| knowledge_factor | 0.97 | Formal specification, independent reference evaluator, executable policy tests, and traceability evidence |
| eco_impact_value | 0.58 | Local-first evaluation, minimized data retention, reduced repeated processing, and offline-capable workflows |
| harm_risk | 0.10 | Explicit blocks on discrimination, service conditioning, coercive data collection, opaque adverse actions, and rest-based demotion |
| accessibility_impact | 0.99 | Accommodation-aware design, accessible notices, offline routes, review, correction, and appeal |
| rights_alignment | 0.99 | Dignity, autonomy, privacy, consent, accessibility, due process, identity sovereignty, and essential-service independence |
