# Bounded-Outcome Utility: Consumer Obligations

Version: 0.1.0
Status: proposed-review-baseline
Applies to: lua/research/bounded_outcome_sensitivity.lua
Producer version: unversioned conversation draft; content not verified

SOVEREIGN-ATTRIBUTION
bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

Attribution is credit and metadata only. It establishes no identity,
consent, authorization, or execution evidence.

## 1. Permitted interpretation

The utility calculates arithmetic bounds over missing-value completions
of supplied arm summaries.

A computed result does not establish:
- Source-data accuracy or provenance.
- Randomization, causal identification, or population representativeness.
- Sampling uncertainty or confidence-interval coverage.
- Plausibility of a missing-outcome restriction.
- Clinical meaning, capability, consent, safety, or weaponization.

Consumers must not use these results to adjust integrations, determine
civic standing, or condition essential access.

## 2. Required analysis envelope

Before reporting a result, the consumer must attach:
- Exact producer artifact version or verified content reference.
- Outcome construct, instrument version, units, and scoring direction.
- Study population, assignment conditions, and fixed presenter framing.
- Counts, observed sums, and source-data provenance status.
- Global outcome bounds.
- Assumption mode: unrestricted, restricted, or restricted_no_op.
- Restriction reference and review status, when applicable.
- Sampling uncertainty: excluded or assessed by a named method.
- Identification status and applicable assumptions.

Matching numeric ranges does not establish matching outcome constructs.
Missing metadata makes the report incomplete, not implicitly compatible.

## 3. Primary estimand and missing outcomes

The proposed primary estimand concerns assignment in the full randomized
study population, including participants with missing outcomes or failed
comprehension checks.

Do not silently redefine it as an observed-respondent effect.

Report response fractions by condition. Do not interpret skipping,
withdrawal, or silence as satisfaction, refusal, or consent.

Principal-stratum analyses are exploratory unless separately registered
with a justified identification strategy.

## 4. Sensitivity restrictions

Always retain the unrestricted result alongside restricted results.

A restriction within the global bounds is arithmetically admissible;
it is not thereby substantively credible.

Record who proposed the restriction, why, its reference, and review status.
Do not impose an undocumented requirement that missing and observed means
must be close.

A restriction equal to the global bounds is restricted_no_op.
It must not be presented as producing tighter information.

## 5. Statistical reporting

Use the label:
“sample-completion bounds; sampling uncertainty excluded”
unless a separately justified inferential procedure has been applied.

Do not call the utility output a population estimate, confidence interval,
credible interval, equivalence result, or significance test.

Do not attach a p-value without defining the tested hypothesis and a
valid analysis accounting for the intended estimand and missingness.

Population claims require an explicit bridge from the supplied sample
summaries to the target population and an appropriate uncertainty method.

## 6. Validation and compatibility

Reject a contrast when construct, instrument, units, direction, conditions,
or assessment scope are incompatible—even when numeric ranges match.

Treat malformed input as validation failure.
Treat implausible assumptions as review findings, not arithmetic failures.
Treat producer exceptions separately from valid domain outcomes.

The current utility does not verify provenance, construct identity,
restriction plausibility, or producer authenticity. Consumers must supply
these checks or report them unresolved.

## 7. Privacy and retention

Process only the summaries needed for the analysis.

Do not infer reasons for missingness at the individual level.
Item-skipping metadata, condition assignments, and detailed timing require
their own approved retention and access rules.

A synthetic filename does not establish fictional provenance.
Classification rules are necessary but insufficient to prevent linkage
or inference concerning real people.

## 8. Release and assessment

A report is incomplete if required evidence or references are absent.
Do not repair incompleteness with invented defaults.

Project assessment fields remain not_scored until an approved rubric,
qualified review, required independence, evidence, disagreement handling,
and assessment scope are recorded.

Publication of this specification does not approve a study, verify the
utility, or establish consumer compliance.
