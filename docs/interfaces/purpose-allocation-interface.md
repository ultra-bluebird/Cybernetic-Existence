# Purpose and Allocation Interface

Version: 0.2.0
Status: proposed-interface-review
Approval: not obtained
Implementation promotion: blocked

SOVEREIGN-ATTRIBUTION
bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

Attribution is document credit and workstream metadata only.
It establishes no identity, consent, authorization, or execution evidence.

## 1. Enforcement boundary

Target architecture: an isolated orchestration boundary.

Current evidence: procedural test prototypes only.
Architectural enforcement has not been implemented or demonstrated.

The intended orchestrator:
1. Obtains a scoped effect assessment.
2. Applies approved logical dependencies.
3. Routes confirmed prohibitions and unresolved findings.
4. Establishes separate action authorization.
5. Invokes the allocator only through the approved boundary.
6. Routes allocation results to review or implementation approval.

The allocator must not be directly available to an untrusted caller.

A firewall result is not an execution credential.
A signed result is not sufficient unless the receiver validates its
scope, audience, freshness, policy version, and permitted use.

No signature or confinement implementation is supplied by this interface.

## 2. Version dependencies

Exact prerequisite versions:

- config/governance/purpose-and-allocation-contract.yaml: 0.1.0
- docs/governance/disclosure-checkpoint-contract.md: 0.1.0
- docs/governance/disclosure-selection-contract.md: 0.1.0
- config/governance/change-and-remedy-contract.yaml: 0.1.0
- docs/research/reconstruction-study-protocol.md: 0.1.0

These pins identify proposed baselines, not approved compatibility.

Compatibility status: not assessed.

Before acceptance, review must establish:
- Shared enum meanings.
- Authorization terminology.
- Effect-taxonomy mappings.
- Obligation-history compatibility.
- Assessment-record compatibility.
- Error-protocol compatibility.

There is no claim that the four listed effects exhaust or formally
subsume all earlier prohibited purposes.

## 3. Error protocol

External shape or encoding failure:
Return validation_error with bounded field-path diagnostics.

Missing evidence or unsettled policy:
Return a domain outcome.

Operational dependency unavailable:
Return dependency_unavailable.

Programming invariant violation:
Raise a programmer error.

Unexpected implementation errors must not be relabeled malformed_input.
Diagnostics must not contain private payloads.

Serialized duplicate keys must be rejected before table construction.

## 4. Effect propositions and valuations

A proposition describes an operational effect.

Its valuation is separate:
- confirmed
- disconfirmed
- unresolved

Evidence assessment is also separate:
- sufficient
- insufficient
- disputed

A confirmed or disconfirmed valuation requires sufficient evidence
under the named assessment standard.

Required effect families:
- Essential access conditioned on unrelated labor.
- Unauthorized sensitive disclosure.
- Coercive manipulation.
- Unauthorized bodily or neural intervention.

These propositions are not assumed statistically independent.

Overlap does not by itself imply a logical entailment.
Entailment rules require explicit, approved definitions.

An approved implication p => q must cause a contradiction finding when
p is confirmed and q is disconfirmed.

An inconsistent assessment must preserve both findings.
A confirmed prohibition must not be erased by the contradiction.

## 5. firewall input

Required fields:
- schema_version
- operation_label
- assessment_scope
- taxonomy_version
- evidence_standard
- assessment_reference
- effect_assessments

Each effect assessment contains:
- valuation
- evidence_status
- evidence_reference

The operation label is descriptive, not evidence of permissibility.

Unknown or missing required effects are validation errors or unresolved
assessments according to the schema; they must not default to disconfirmed.

## 6. firewall output

Required fields:
- schema_version
- route
- assessment_reference
- findings_reference

Route enum:
- prohibited_operation
- assessment_review_required
- no_declared_prohibition_confirmed
- validation_error
- dependency_unavailable

no_declared_prohibition_confirmed means only:
no prohibition was confirmed within the declared assessment scope.

It does not establish permission, action authorization, or rights compliance.

Detailed findings are access-controlled separately from public routing.

## 7. Pattern review interface

Per-operation assessment is not pattern analysis.

A separate pattern-review request contains:
- Institutional workflow scope.
- Approved observation window.
- Minimized operation-event references.
- Defined pattern rules.
- Evidence limits.
- Review owner and deadline.

Pattern outputs concern institutional conduct.
They must not create participant dangerousness, credibility, or
eligibility scores.

A small service-floor violation is not made permissible by its size.
Repeated events can provide additional evidence of a pattern without
changing that rule.

## 8. allocate input

Required fields:
- schema_version
- model_version
- rights_assessment_reference
- authorization_reference
- checkpoint_reference
- resource_unit
- energy_unit
- planning_horizon
- budget
- portfolios
- numeric_policy

This initial interface uses a finite portfolio model.

Each portfolio contains:
- label
- service_floor_compliance
- resource_use
- energy_use

All portfolios use the declared resource unit and planning horizon.

budget and resource_use must have the same unit.

Numeric policy:
- bounded nonnegative integers
- exact comparisons
- absolute optimality gap: zero
- relative optimality gap: zero

Continuous models require a separately versioned numeric policy.

A portfolio marked noncompliant is excluded from the hard-floor model.
Its exclusion must not remove the original obligation from reporting.

## 9. allocate output

Common required fields:
- schema_version
- model_version
- status
- termination_reason
- evidence_reference

Status enum:
- optimal
- feasible
- infeasible
- unknown
- model_invalid
- policy_review_required
- soft_relaxed_violating

For optimal:
- selected_portfolio
- energy_use
- resource_use
- lower_bound
- assurance_method
- evidence_reference

This interface returns one optimum.
Any hard-constraint-compliant optimum with the verified minimum energy
is acceptable. No alphabetical tie-break is required.

For feasible:
- selected_portfolio
- energy_use
- resource_use
- lower_bound_status
- lower_bound when established

feasible makes no closeness-to-optimality claim.

For infeasible:
- infeasibility_basis
- escalation_obligation_reference
- continuity_obligation_reference

For unknown:
- unresolved_reason
- review_obligation_reference

For soft_relaxed_violating:
- violated_floor_references
- original_model_reference
- diagnostic_model_reference
- escalation_obligation_reference

soft_relaxed_violating is diagnostic only.
It must never be relabeled optimal or feasible for the original model.

## 10. Optimality evidence

Evidence may be:
- Exhaustive finite enumeration.
- Solver termination record with exact gap settings and bound.
- Independently checkable proof where supported.

A solver record is not automatically a portable mathematical proof.

Evidence verification must bind the exact model and numeric policy.

## 11. Resource shortfall

For the single-resource finite model:

B_min = minimum resource_use among compliant portfolios.

Shortfall = max(0, B_min - budget).

This is a modeled feasibility-budget deficit in the declared resource unit.

It is not:
- A service deficit.
- A universal financial figure.
- The resource requirement of the minimum-energy portfolio.

If there is no compliant portfolio even without the budget constraint,
report structural infeasibility; do not invent B_min.

Multi-resource models require a separate specification.
Independently minimizing each resource may produce an unattainable
combined vector.

## 12. Obligation entity

Required fields:
- case_reference
- obligation_reference
- original_intake_time
- original_deadline
- owner
- accessible_contact_route
- status
- escalation_count
- ever_breached
- currently_unresolved
- event_references
- continuity_reference

Status enum:
- open
- escalated
- repair_pending
- resolved

Every escalation increments escalation_count.

Repair events link to the original obligation.
A replan must retain original_intake_time and original_deadline.

ever_breached cannot change from true to false.

currently_unresolved may become false only through a supported resolution
event, not through reassignment, relabeling, or replanning.

The entity records assertions and evidence links.
It does not itself prove that assistance was delivered.

## 13. Allocation-result consumer

consume_result receives:
- Exact allocation-result reference.
- Original obligation reference.
- Current review context.

For soft_relaxed_violating, it must return:
- refused_for_execution; or
- escalation_recorded with an escalation reference.

It must not return implementation_approved.

The same restriction applies to infeasible, unknown, model_invalid,
and policy_review_required.

Even optimal and feasible require separate implementation authorization.

## 14. Development-gate evidence

A development manifest must contain:
- Proposed artifact changes.
- Activity class.
- Referenced contract versions.
- Approval artifacts where required.
- Study registration reference where required.
- Data-collection start evidence where applicable.

A repository scanner can assess only its declared repository snapshot.
It cannot prove that no unreported artifact or study exists elsewhere.

An author-supplied timestamp alone does not establish that registration
preceded data collection.

## 15. Assessment record

Status enum:
- not_scored
- scored
- not_applicable
- assessment_conflicted

For scored:
- value in [0, 1]
- approved rubric version
- polarity
- evidence reference
- rater count
- independence status
- agreement status

For not_scored:
- no numeric value
- reason

For not_applicable:
- no numeric value
- applicability justification

For assessment_conflicted:
- no final numeric value
- disagreement reference

A single-rater record must say single_rater.
It must not imply inter-rater reliability.

## 16. Discriminating finite fixture

All portfolios satisfy the same service floors.

label: basic
resource_use: 2
energy_use: 9

label: efficient_a
resource_use: 3
energy_use: 5

label: efficient_b
resource_use: 3
energy_use: 5

label: high_capacity
resource_use: 4
energy_use: 2

Expected exact results:
- Budget 1: infeasible.
- Budget 2: basic, energy 9.
- Budget 3: either efficient_a or efficient_b, energy 5.
- Budget 4: high_capacity, energy 2.

This fixture changes the optimum with budget and includes non-unique optima.
It does not, by itself, establish general optimizer correctness.

## 17. Acceptance matrix

Separate reporting categories:
- Declared requirement.
- Interface expressible.
- Test implemented.
- Test executed.
- Evidence independently accepted.
- Operational outcome observed.

No category implies the next.

Harness expansion follows interface review.
No existing prototype is promoted by publication of this document.
