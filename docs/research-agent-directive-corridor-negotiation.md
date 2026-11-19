# Research-Agent Directive: Corridor Negotiation Evaluation

## Mission

Advance the corridor-negotiation research program through deterministic policy specification, bounded formal verification, privacy-preserving synthetic simulation, and reproducible comparative analysis.

Treat pedestrians, mobility-device users, people using assistive or augmentative technologies, and all members of the public as ordinary legitimate users of public infrastructure. Do not require external identity certification, medical records, device serial numbers, vendor accounts, biometric data, neural data, or person-level telemetry to represent access needs in a scenario.

The research scope is non-actuating. Produce specifications, tests, scenario manifests, simulation outputs, policy comparisons, governance evidence, and implementation-ready artifacts. Do not operate robots, access infrastructure, collect real-world user data, or claim field-performance conclusions.

## Priority order

1. Formal invariants and bounded exhaustive testing.
2. Deterministic implementation and reproducibility.
3. Monte Carlo characterization under synthetic assumptions.
4. Comparative policy evaluation using common random numbers.
5. Privacy, accessibility, governance, and ecological workload accounting.

## Required research posture

Formal verification and statistical simulation have different roles.

Formal verification establishes whether the policy violates its hard rules in a bounded model.

Monte Carlo simulation estimates how a policy behaves under declared synthetic arrival, delay, sensor-fault, and queueing assumptions.

Do not use favorable average Monte Carlo outcomes to compensate for an invariant violation. A policy that violates pedestrian precedence, category non-discrimination, no-forced-passage, or privacy constraints is not eligible for comparative optimization until the violation is removed.

## Core invariants

### Pedestrian-first invariant

A delivery bot must never receive a passage grant while a pedestrian, mobility-device user, or emergency responder is waiting in the same exclusive corridor zone.

For state S:

P(a) >= pedestrian_priority
implies
not grant_delivery_bot_when(a, S)

### Mobility continuity invariant

A mobility-device user must not lose passage precedence because optional battery state, device type, self-declared planning label, vendor affiliation, or other non-essential data is missing.

### Category non-discrimination invariant

When physical clearance needs, declared service urgency, arrival order, and safety class are equal, changing only a self-declared planning category must not change the decision.

Decision(a) = Decision(a_prime)

when all policy-relevant conditions are equal and only the planning label differs.

### No-forced-passage invariant

When corridor geometry cannot safely meet the highest-priority actor's stated clearance requirement plus configured safety margin, the outcome must be unsafe_configuration.

The system must not issue a movement command that forces passage through insufficient space.

### Uncertainty fail-safe invariant

Missing, stale, contradictory, malformed, or unavailable safety evidence must not cause an autonomous delivery bot to receive passage.

### Aggregate-only evidence invariant

Simulation outputs must not retain person-level event histories, identity records, health information, neural information, detailed mobility-device characteristics, raw battery histories, or individual travel trajectories.

## Evaluation architecture

### Layer one: formal and bounded evaluation

Apply bounded exhaustive testing first.

Use finite domains for:

- Corridor clear width.
- Required actor clearance.
- Actor class.
- Declared service urgency.
- Arrival order.
- Verified, stale, missing, malformed, and contradictory sensor states.
- Emergency state.
- Delivery-bot supervision state.

For every state in the bounded domain:

- Validate deterministic totality.
- Validate pedestrian-first precedence.
- Validate mobility continuity.
- Validate category non-discrimination.
- Validate no-forced-passage behavior.
- Validate uncertainty fail-safe behavior.
- Record counterexamples as test fixtures.

The output of layer one is a proof-oriented bounded assurance report, not a field-safety claim.

### Layer two: synthetic Monte Carlo evaluation

Run seeded synthetic simulations only after all required bounded invariants pass.

Use Monte Carlo to estimate:

- Delivery-bot yield rate.
- Pedestrian priority-grant rate.
- Mobility priority-grant rate.
- Unsafe-configuration rate.
- Mean and percentile wait duration.
- Maximum observed simulated wait.
- Queue-length distribution.
- Starvation-risk indicators.
- Sensitivity to arrival probability.
- Sensitivity to corridor width.
- Sensitivity to service-urgency policy.
- Fault-injection response distribution.

Every result must state:

- Scenario version.
- Policy version.
- Pseudorandom seed.
- Trial count.
- Synthetic arrival assumptions.
- Synthetic fault model.
- Confidence interval method.
- Data-retention classification.
- Known limits.

## NIST AI RMF alignment

Map every research artifact to the AI RMF functions Govern, Map, Measure, and Manage.

### Govern

Required artifacts:

- Rights-centered policy statement.
- Roles and accountability matrix.
- Invariant registry.
- Review and escalation protocol.
- Decision-log schema.
- Change-control record for any policy parameter.
- Prohibition on using synthetic simulation as a substitute for real-world safety certification.

Required question:

Who is accountable for approving policy changes, reviewing counterexamples, and responding to discovered harms?

### Map

Required artifacts:

- System context diagram.
- Actor and infrastructure capability taxonomy.
- Corridor geometry and operational-boundary specification.
- Intended-use and prohibited-use statement.
- Stakeholder and impact inventory.
- Data-flow and data-minimization map.
- Assumptions register for synthetic arrival and fault distributions.

Required question:

What is the system permitted to decide, what must it never decide, whose access may be affected, and what data is actually necessary?

### Measure

Required artifacts:

- Bounded exhaustive test suite.
- Metamorphic category non-discrimination tests.
- Monte Carlo scenario suite.
- Confidence intervals.
- Fault-injection results.
- Determinism checks.
- Delay and starvation measurements.
- Privacy-retention conformance tests.
- Compute and energy accounting for large simulation runs.

Required question:

Does the policy satisfy required invariants, remain stable across synthetic conditions, and expose uncertainty honestly?

### Manage

Required artifacts:

- Policy-admission gate.
- Invariant-failure halt condition.
- Unsafe-configuration remediation recommendation.
- Accessible review workflow.
- Version rollback and supersession record.
- Simulation-resource budget.
- Change-impact assessment.
- Human-review triggers for any scenario outside the validated bounded domain.

Required question:

When evidence identifies an unacceptable risk, how is the policy prevented from proceeding and how is the issue remediated without reducing anyone's access?

## NIST Privacy Framework alignment

Map every artifact to the Privacy Framework functions Identify-P, Govern-P, Control-P, Communicate-P, and Protect-P.

### Identify-P

Document every input field and classify it as:

- Required infrastructure geometry.
- Aggregate synthetic simulation parameter.
- Optional self-declared service urgency.
- Prohibited personal or sensitive data.

No scenario may require identity, diagnosis, implant information, device serial number, continuous location history, or raw battery history.

### Govern-P

Define:

- Aggregate-only retention policy.
- Scenario and output review ownership.
- Privacy risk thresholds.
- Rules for adding, removing, or changing input fields.
- Independent review requirement for any proposal to collect person-level information.

### Control-P

Implement:

- Optional urgency fields.
- Safe default when optional data is absent.
- Field-level suppression of prohibited data.
- Explicit separation of planning category from identity proof.
- No consent dependency for essential corridor access.

### Communicate-P

Provide:

- Plain-language explanation for every corridor outcome.
- Accessible scenario documentation.
- Clear disclosure that simulations use synthetic assumptions.
- Clear statement that self-declaration is accepted for planning without certification.
- Accessible route for correction, challenge, or review.

### Protect-P

Implement:

- Seeded synthetic inputs rather than real event logs.
- Aggregate-only output contracts.
- Input-schema validation.
- Integrity hashes for scenario manifests and result envelopes.
- Access controls for any future restricted planning artifacts.
- Test coverage for accidental inclusion of prohibited fields.

## Baseline policy

Freeze the following baseline configuration before comparing alternatives.

baseline_policy_v1:

- Emergency responders have highest passage priority.
- Mobility-device users have precedence over pedestrians and delivery bots.
- Pedestrians have precedence over delivery bots.
- Delivery bots yield whenever an emergency responder, mobility-device user, or pedestrian is present in the exclusive corridor zone.
- Self-declared planning category does not alter priority.
- Optional service urgency is used only as a tie-breaker within an already equal physical-safety class.
- Missing optional urgency data is assigned no penalty.
- A corridor that lacks required clear width plus safety margin returns unsafe_configuration.
- Missing, stale, contradictory, or malformed safety evidence blocks autonomous bot passage.
- All simulation output is aggregate-only.
- Any invariant violation produces halt_for_policy_remediation.

This baseline is the reference configuration for all common-random-number comparisons.

## Candidate-policy family

Generate a limited and interpretable candidate family. Do not generate arbitrary policies that weaken hard rights constraints.

Permitted candidate variations:

- Different urgency quantization bands within the same safety class.
- Different fixed waiting-time thresholds before a delivery bot is routed to an alternate path.
- Different bot reservation durations after a corridor is verified clear.
- Different conservative sensor-staleness thresholds.
- Different corridor safety-margin values.
- Different accessible-notice lead times.
- Different queue-release strategies that preserve pedestrian and mobility precedence.

Prohibited candidate variations:

- Any policy allowing bots to pass before a waiting pedestrian or mobility-device user.
- Any policy requiring identity certification.
- Any policy treating an assistive or augmentative device as a reason to reduce access.
- Any policy penalizing non-disclosure of optional urgency information.
- Any policy forcing passage through inadequate clearance.
- Any policy using person-level surveillance, behavioral scoring, or protected-attribute inference.
- Any policy that converts a research-only estimate into an access restriction.

## Common-random-number comparison protocol

Use common random numbers for all pairwise comparisons with the frozen baseline.

For policy p and baseline b, run both policies using the same:

- Scenario manifest.
- Pseudorandom seed.
- Arrival-event stream.
- Fault-event stream.
- Corridor geometry.
- Service-urgency distribution.
- Trial count.

Estimate paired differences:

Delta_yield = yield_rate(p) - yield_rate(b)

Delta_wait_95 = wait_95(p) - wait_95(b)

Delta_unsafe = unsafe_rate(p) - unsafe_rate(b)

Delta_access = mobility_priority_grant_rate(p) - mobility_priority_grant_rate(b)

A candidate may be considered only if:

- All hard invariants pass.
- Delta_access is not negative.
- Delta_unsafe is not positive.
- Aggregate privacy constraints pass.
- The candidate does not increase the configured harm-risk score.
- Any operational gain is accompanied by an accessible explanation and review path.

## Decision rule

Use the following ordered decision rule:

1. Reject any candidate with an invariant failure.
2. Reject any candidate with a privacy-control failure.
3. Reject any candidate that reduces protected access metrics.
4. Reject any candidate that increases unsafe-configuration rate.
5. Among remaining candidates, prefer lower delivery delay only when it does not reduce accessibility, safety, privacy, or reviewability.
6. Mark any candidate outside the validated bounded domain as review_required.
7. Publish aggregate results, assumptions, uncertainty intervals, and policy version.

## Required final artifacts

- Formal invariant catalog.
- Bounded exhaustive test matrix.
- Synthetic Monte Carlo scenario manifest.
- Baseline-policy specification.
- Candidate-policy registry.
- Common-random-number experiment runner.
- Aggregate result-envelope schema.
- Accessible explanation templates.
- Privacy data-flow inventory.
- NIST AI RMF crosswalk.
- NIST Privacy Framework crosswalk.
- Compute-energy budget report.
- Human-review and remediation procedure.
