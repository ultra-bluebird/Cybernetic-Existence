# Rights State Model: Proof Groundwork and Research Objects

## Scope

This document defines the proof-groundwork category for a five-dimensional rights state model used in civic, smart-city, ecological, public-health, assistive-technology, and augmented-living workflows.

The model is designed to ensure that access to essential services, dignity, self-asserted identity, assistive technology, civic participation, and public benefits are not converted into financial, behavioral, biometric, connectivity, telemetry, or augmentation-dependent eligibility systems.

The five dimensions are:

\[
S = (I, C, A, R, P)
\]

Where:

- \(I\): identity and recognition state
- \(C\): consent state and consent scope
- \(A\): accessibility and accommodation state
- \(R\): review, correction, and appeal state
- \(P\): declared purpose, permitted processing, retention, and disclosure state

No dimension is a wealth score, social score, behavioral score, financial rank, or generalized eligibility score.

## Definitions

### Essential service

An essential service is a service where delayed, denied, inaccessible, or coercively conditioned access can threaten health, safety, basic subsistence, civic participation, functional autonomy, or equal access to a public program.

Examples include:

- emergency information and response
- safe water and sanitation access
- heat-relief and cooling access
- disability accommodations
- accessible public-health information
- emergency transport information
- grievance and appeal intake
- public-service notices
- basic civic participation routes

The system must preserve an accessible, equivalent service pathway even if an automated policy decision cannot resolve a non-essential administrative question.

### Sensitive data

Sensitive data includes neural, biometric, augmentation, health, disability, location, device telemetry, behavioral, identity, financial, and communications data.

Sensitive data is denied by default unless processing is necessary for a declared permitted purpose and all required authority, consent, minimization, security, and retention conditions are satisfied.

### Recognition at Rest

Recognition at Rest is a protected continuity condition.

Rest, sleep, recovery, device maintenance, assistive-technology maintenance, temporary disconnection, low-connectivity operation, or a decision not to emit optional telemetry must not lower a person's recognition, dignity, access, priority, accommodation availability, or essential-service pathway.

## Existing Safety Properties

The following properties are universal safety invariants.

\[
\Box(\texttt{essential\_service\_request} \Rightarrow \neg \texttt{wealth\_dependent})
\]

\[
\Box(\texttt{recognition} \not\Rightarrow \texttt{financial\_rank})
\]

\[
\Box(\neg \texttt{valid\_purpose\_and\_consent} \Rightarrow \neg \texttt{sensitive\_processing})
\]

\[
\Box(\texttt{adverse\_decision} \Rightarrow
\texttt{accessible\_notice} \land
\texttt{reason} \land
\texttt{correction\_path} \land
\texttt{appeal\_path})
\]

\[
\Box(\texttt{rest\_or\_inactivity} \Rightarrow \neg \texttt{recognition\_demotion})
\]

The box operator \(\Box\) means that the enclosed predicate must hold in every reachable state. This is a safety-property form: it asserts that prohibited conditions never arise in any valid execution path. TLA+ state-and-transition modeling and model checking are appropriate for exploring every reachable state and interleaving within explicit model bounds. [73][74]

## Expanded Safety Properties

### Identity separation

Identity recognition must not be derived from financial capacity, payment history, credit information, commercial participation, or asset possession.

\[
\Box(\texttt{identity\_update} \Rightarrow
\neg \texttt{uses\_wealth\_signal} \land
\neg \texttt{uses\_credit\_signal} \land
\neg \texttt{uses\_commercial\_signal})
\]

### Essential-service independence

A request for an essential service must remain available without requiring continuous connectivity, a proprietary device, external identity verification, biometric verification, optional telemetry, or unrelated consent.

\[
\Box(\texttt{essential\_service\_request} \Rightarrow
\neg \texttt{requires\_continuous\_connectivity} \land
\neg \texttt{requires\_proprietary\_device} \land
\neg \texttt{requires\_optional\_telemetry} \land
\neg \texttt{requires\_unrelated\_consent})
\]

### Data minimization

Processing must use no more sensitive data categories than are necessary for the declared permitted purpose.

\[
\Box(\texttt{sensitive\_processing} \Rightarrow
\texttt{declared\_purpose} \land
\texttt{purpose\_permitted} \land
\texttt{data\_minimized} \land
\texttt{retention\_bounded})
\]

A useful measurable form is:

\[
\texttt{minimization\_ratio} =
\frac{|\texttt{necessary\_data\_categories}|}
{|\texttt{requested\_data\_categories}|}
\]

The ratio should equal \(1\) only when every requested data category is necessary. Any requested category outside the necessary set creates a policy violation.

### Consent separability

Consent to optional processing must not be bundled with essential-service access.

\[
\Box(\texttt{essential\_service\_request} \land
\neg \texttt{optional\_consent}
\Rightarrow
\texttt{service\_path\_available})
\]

### Revocation integrity

After revocation becomes effective, further optional processing under the revoked scope must not occur.

\[
\Box(\texttt{consent\_revoked}(x) \Rightarrow
\neg \texttt{optional\_processing\_under}(x))
\]

### Accessibility continuity

An unavailable digital channel, inaccessible interface, or missing device capability must not terminate access to notices, corrections, appeals, reviews, or essential services.

\[
\Box(\neg \texttt{preferred\_channel\_available} \Rightarrow
\texttt{equivalent\_accessible\_path\_available})
\]

### Non-punitive review

A `require_review` result must not become a hidden denial, demotion, or essential-service barrier.

\[
\Box(\texttt{require\_review} \land
\texttt{essential\_service\_request}
\Rightarrow
\texttt{interim\_accessible\_service\_path})
\]

### Audit completeness

Any material decision must have an accountable and privacy-minimized decision record.

\[
\Box(\texttt{material\_decision} \Rightarrow
\texttt{policy\_version\_recorded} \land
\texttt{reason\_recorded} \land
\texttt{purpose\_recorded} \land
\texttt{minimum\_necessary\_audit\_event})
\]

## Liveness Properties

Safety alone is insufficient. A system can avoid prohibited actions while still leaving people indefinitely waiting, unheard, or unable to correct a record.

Liveness expresses that a valid condition eventually leads to a required constructive outcome.

\[
\Diamond \phi
\]

means that \(\phi\) eventually occurs.

### Review progress

A valid review request must eventually become an accountable human-review outcome.

\[
\Box(\texttt{valid\_review\_request} \Rightarrow
\Diamond \texttt{review\_outcome\_available})
\]

### Appeal progress

A valid appeal must eventually receive an accessible acknowledgement and a reasoned outcome.

\[
\Box(\texttt{valid\_appeal} \Rightarrow
\Diamond(\texttt{appeal\_acknowledged} \land
\texttt{reasoned\_outcome\_available}))
\]

### Correction progress

A valid correction request must eventually result in correction, a reasoned rejection, or a request for narrowly specified additional evidence.

\[
\Box(\texttt{valid\_correction\_request} \Rightarrow
\Diamond(\texttt{record\_corrected} \lor
\texttt{reasoned\_correction\_decision} \lor
\texttt{minimum\_evidence\_request}))
\]

### Emergency continuity

An essential-service request must eventually receive an accessible fulfillment, safe fallback, or urgent human handoff.

\[
\Box(\texttt{essential\_service\_request} \Rightarrow
\Diamond(\texttt{service\_fulfilled} \lor
\texttt{safe\_fallback\_provided} \lor
\texttt{urgent\_human\_handoff}))
\]

## Research Objects

### State Semantics Object

Define exhaustive enumerations for identity, consent, accessibility, review, purpose, and decision outcomes.

Acceptance evidence:

- Every state dimension has a closed vocabulary.
- No score field can represent a person's worth, wealth, social value, or essential-service eligibility.
- Each state transition carries an actor, declared purpose, timestamp, policy version, and minimum necessary evidence.

### Transition Authority Object

Specify who may request, authorize, review, contest, correct, revoke, or audit each transition.

Acceptance evidence:

- No actor can silently elevate their own authority.
- A review actor cannot use financial, telemetry, connectivity, or augmentation signals as a recognition criterion.
- A person can request correction, revocation, accommodation, and appeal without needing optional telemetry disclosure.

### Temporal Proof Object

Construct a TLA+ specification with controlled nondeterminism for:

- concurrent service requests
- consent revocation during processing
- review and appeal requests
- offline operation and later synchronization
- assistive-channel failure
- policy-version changes
- stale or conflicting evidence
- service outages and emergency fallback

Acceptance evidence:

- Model-check safety properties.
- Model-check liveness properties under stated fairness assumptions.
- Preserve counterexample traces as regression fixtures.
- Document each state variable, action, invariant, temporal property, fairness assumption, and bounded model configuration.

### Reference Evaluator Object

Create a Rust 1.86 reference evaluator whose decision output is deterministic and structurally explainable.

Acceptance evidence:

- Closed decision outcomes: `allow`, `deny_unsafe`, `require_review`, `provide_equivalent_access`, `urgent_human_handoff`.
- No implicit coercion from absent information to a negative identity or recognition outcome.
- Explicit validation errors for contradictory, irrelevant, overbroad, or prohibited inputs.
- Structured explanation and appeal metadata.
- Property-based tests over generated valid and invalid state transitions.

Property testing checks that behavioral properties hold across generated input spaces, rather than only against manually selected examples. [71][75]

### Policy Adversary Object

Create a Rego adversarial corpus that attempts to violate the universal invariants.

Required test families:

- wealth-to-recognition conversion
- recognition-to-financial-rank conversion
- essential-service conditioning
- consent bundling
- overcollection of sensitive data
- purpose substitution
- rest-based demotion
- accessibility-path removal
- review delay or appeal suppression
- missing audit justification
- local-profile weakening of core rights

Acceptance evidence:

- Every prohibited test returns `deny_unsafe`.
- Essential-service requests receive a non-discriminatory path even where a secondary administrative question requires review.
- Test failures include machine-readable reason codes and human-readable explanations.
- Mutation testing demonstrates that material changes to core rules are detected.

### Human Review Object

Specify an accountable protocol for `require_review`.

Acceptance evidence:

- `require_review` is non-punitive.
- Essential services continue through an accessible equivalent route.
- The person receives a plain-language, accessible notice.
- The review packet lists the specific conflict or uncertainty without unnecessary sensitive data.
- The person can correct information, request accommodation, add context, and appeal.
- The reviewer records a reasoned decision.
- The review process has time targets and an escalation path for urgent needs.

### Local Profile Object

Model Phoenix and future local deployments as profiles that can add protections or operational detail without weakening universal core properties.

Acceptance evidence:

- Local service definitions are configuration data, not hidden code branches.
- Public-law sources, institutional policy, and technical configuration remain explicitly separated.
- The local profile cannot require proprietary augmentation, continuous connectivity, financial data, or unrelated consent for essential services.
- A portable interoperability test verifies that core invariants hold in every profile.

### Interoperability Object

Define a portable exchange format for consent, decisions, explanations, review handoffs, and privacy-preserving audit records.

Acceptance evidence:

- Data classes, purposes, consent scopes, retention limits, review state, and provenance are explicit.
- Sensitive categories are optional and purpose-bound.
- Receiving systems can process a minimal proof of status without receiving raw neural, biometric, health, or device telemetry.
- Offline export and accessible non-digital routes remain available.

## Proof Dependencies

The safety properties depend on:

\[
\texttt{TypeCorrectness} \land
\texttt{TransitionAuthorization} \land
\texttt{PolicyCompleteness} \land
\texttt{InputValidation} \land
\texttt{AuditIntegrity}
\]

The liveness properties depend on:

\[
\texttt{FairScheduling} \land
\texttt{ReviewCapacity} \land
\texttt{AccessibleNoticeDelivery} \land
\texttt{FallbackAvailability}
\]

Liveness proofs must state operational assumptions openly. For example, an eventual review result requires a review capability that receives work and a reachable accessible contact path. This is not a weakness; it makes governance dependencies inspectable and accountable.

## Evidence Matrix

| Claim | Formal evidence | Executable evidence | Human evidence |
|---|---|---|---|
| Essential services are independent of wealth | TLA+ invariant | Rust property test and Rego adversarial case | Service pathway audit |
| Recognition is not a financial rank | State-domain restriction | Rego rule test and mutation test | Governance review record |
| Sensitive processing is purpose and consent bound | Transition precondition | Rust evaluator test and Rego policy test | Consent receipt and retention review |
| Adverse decisions are contestable | Temporal safety and liveness property | Decision-record validation test | Accessible notice and appeal exercise |
| Rest cannot cause demotion | Transition exclusion invariant | Generated inactivity scenarios | Community validation and incident review |
| `require_review` preserves access | Liveness property | Routing and fallback test | Review service-level audit |

## Readiness Criteria

A research object is ready for implementation when it has:

- a precise state definition
- an explicit threat model
- a safety or liveness property
- a TLA+ representation where temporal behavior matters
- a Rust reference test
- a Rego policy test where authorization or gating matters
- a human-accountability requirement
- an accessibility requirement
- a data-minimization requirement
- a locally configurable but core-invariant deployment boundary

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.98 | Integrates formal safety and liveness properties, executable evaluation, adversarial testing, and governance evidence |
| eco_impact_value | 0.60 | Supports local-first policy evaluation, minimized sensitive-data processing, bounded retention, offline operation, and reduced repeat computation |
| harm_risk | 0.09 | Prohibits wealth scoring, service conditioning, coercive data collection, rest-based demotion, inaccessible adverse action, and opaque review |
| accessibility_impact | 0.99 | Requires equivalent accessible paths, non-punitive review, accessible notice, correction, appeal, offline continuity, and accommodation support |
| rights_alignment | 0.99 | Centers dignity, self-assertion, consent, privacy, accessibility, repair, continuity, due process, and essential-service independence |
