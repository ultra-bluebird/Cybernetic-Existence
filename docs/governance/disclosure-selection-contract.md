# Disclosure Selection Contract

Version: 0.1.0
Status: proposed-review-baseline
Approval: not obtained

SOVEREIGN-ATTRIBUTION
bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

Attribution is credit and metadata only, not authorization.

## Orthogonal findings

Purpose:
- permitted_in_scope
- prohibited
- unresolved

Participant permission:
- granted
- absent
- unknown

Action authorization:
- established
- not_established
- unknown

Evidence:
- adequate
- inadequate
- unknown

Participant permission means an applicable voluntary grant is reported.
Action authorization means the specified operation has passed its
separate scope, recipient, time, lineage, and enforcement checks.

Neither field establishes its own authenticity.

## Eligibility routing

Preserve all four findings and return one route:

1. prohibited
   Purpose is prohibited.

2. permission_not_granted
   Permission is absent.

3. authorization_not_established
   Action authorization is not established.

4. unresolved
   Purpose, permission, or action authorization is unknown or unresolved.

5. incomplete_evidence
   The preceding checks pass, but evidence is inadequate or unknown.

6. eligible
   Purpose permitted, permission granted, action authorization established,
   and evidence adequate.

These routes concern the operation, not civic or service eligibility.

## Pareto quotient

The planner operates only on operation-eligible candidates.

Return:
groups[canonical_vector_key] = {
    exposure = complete five-dimensional vector,
    labels = set of candidate labels
}

Do not return a privileged first candidate.

Candidates sharing a vector belong to the same exposure-equivalence group.
They need not be equivalent in usefulness, accessibility, or user preference.

Within one group, strict exposure dominance is impossible because
the vectors are equal.

Retain only nondominated groups.

Canonical vector key:
identity|health|location|linkability|inner_state
using bounded nonnegative base-10 integers without leading zeros,
except the integer zero itself.

## Incomparable groups

No automatic winner is implied.

A selection policy must:
- Be named and versioned.
- Preserve eligibility.
- Never select a dominated group.
- Specify equal-vector treatment.
- Disclose any additional criteria.
- Preserve accessible participant choice where applicable.
- Avoid augmentation-status preference.
- Be invariant to enumeration order.

Display order is not a selection mechanism.

## Accounting semantics

Use conservative, no-subtraction accounting.
Do not describe it as belief, probability, or physiological severity.

Any contextual contribution must be bound to:
- Accepted checkpoint.
- Coalition threat-model version.
- Purpose.
- Policy version.
- Assessment method.

## Threat model

Reconstruction claims must be expressed relative to a declared model.

Required model content:
- Authorized recipients.
- Modeled recipients and coalitions.
- Sharing channels.
- Auxiliary information.
- Query and computation budgets.
- Inference procedures.
- Designated target attributes.
- Known exclusions.

A monotone derivation model must explicitly say that it tracks possible
derivability and does not model belief revision or disconfirmation.

## Reporting

Report reconstruction outcomes by exact exposure vector or by a
published grouping function. Undisclosed scalar bands are prohibited.

Do not subtract accounting units from reconstruction probabilities.

## Assessment records

Each project assessment field must return:
- status: not_scored, scored, or assessment_conflicted
- value: absent unless status is scored
- rubric_version
- polarity
- rater_count
- independence_status
- agreement_status
- evidence_reference

Single-rater assessments must say single_rater.
They must not imply inter-rater reliability.

Required project fields:
knowledge_factor, eco_impact_value, harm_risk,
accessibility_impact, rights_alignment.

Polarity:
- Higher is favorable: knowledge_factor, eco_impact_value,
  accessibility_impact, rights_alignment.
- Lower is favorable: harm_risk.

No approved rubric applied means not_scored.

## Mutation evidence

A mutation claim must identify:
- Executed corpus.
- Reference semantics.
- Mutant implementation.
- Observed disagreement or error.
- Equivalence assessment.
- Required-mutant classification.

Caller-provided killed=true labels are not computed mutation evidence.

Mandatory mutation classes:
- Unknown permission becomes eligible.
- Missing action authorization becomes eligible.
- Prohibited purpose becomes eligible.
- Inadequate evidence becomes eligible.
- Dominated candidate survives as nondominated.
- Equal-vector alternatives are dropped.
- Stale state is accepted.
- Boundary inclusion is reversed.

Invalid, equivalent, and unresolved mutants require separate reporting.

## Promotion gate

No new operational or reference kernel until this contract and the
checkpoint contract are approved.

Conformance harness development is permitted because it evaluates
existing prototypes rather than introducing new decision behavior.
