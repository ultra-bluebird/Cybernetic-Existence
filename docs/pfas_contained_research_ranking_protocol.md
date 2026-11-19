# PFAS Contained Research Ranking Protocol

## Purpose

This protocol ranks contained PFAS research-study candidates against measured
hydrochemical conditions in a Phoenix-area hex anchor.

It does not select organisms for open environmental release, authorize
bioaugmentation, recommend use of a pathogen or opportunistic pathogen, establish
PFAS degradation, establish defluorination, certify a consortium, or authorize
physical deployment.

## Scope

The protocol applies only to:

- contained bench studies;
- approved mesocosm studies with documented containment;
- analytical-method development;
- literature evidence mapping;
- non-releaseable research prioritization.

The protocol does not apply to:

- canal, groundwater, sediment, aquifer, stormwater, or surface-water release;
- environmental inoculation;
- public-health decision-making;
- clinical or body-related systems;
- machine control.

## Candidate classes

Candidate records MUST use one of these classes:

- `literature_reference_only`;
- `nonpathogenic_contained_candidate`;
- `mixed_consortium_research_candidate`;
- `unknown_safety_profile`;
- `excluded_pathogenicity_or_ecology_risk`;
- `insufficient_analyte_specific_evidence`.

A candidate classified as `excluded_pathogenicity_or_ecology_risk` MUST NOT receive a
positive study-deployment rank.

## Required hydrochemistry vector

Each anchor/corridor sample set MUST record:

- salinity or conductivity with conversion method;
- pH;
- oxidation-reduction potential;
- dissolved organic carbon;
- temperature;
- dissolved oxygen;
- ionic-strength or major-ion context;
- sediment organic carbon where sediment is in scope;
- sample matrix;
- sample date/time;
- laboratory or instrument method;
- uncertainty;
- quality status;
- sub-basin source reference;
- anchor and geometry revision.

Sub-basin identity is contextual metadata. It MUST NOT replace local measurement.

## Evidence score

`K_evidence` is bounded in `[0, 1]`.

It MUST be zero when:

- the candidate lacks analyte-specific evidence;
- the study does not retain analytical PFAS measurements;
- the study lacks a fluoride mass-balance plan when defluorination is claimed;
- source provenance is absent;
- the evidence is limited to an unsupported assertion;
- a hard exclusion applies.

## Hydrochemistry match

For anchor vector x and candidate study envelope with center mu and covariance Sigma:

`M_hydrochem = exp(-0.5 * (x - mu)^T * inverse(Sigma) * (x - mu))`

The matrix Sigma MUST be positive definite or the candidate MUST be routed to
`review_required`.

A hydrochemistry match is an evidence-relevance score only. It MUST NOT be treated
as proof of organism safety, PFAS degradation, PFAS defluorination, environmental
fitness, or release eligibility.

## Hard gates

A candidate has a zero deployment rank when any condition is true:

- open-environment release is proposed;
- pathogenicity or opportunistic-pathogen risk is unresolved;
- ecological-risk review is unresolved;
- containment is absent or inadequate;
- legal or institutional authorization is absent;
- analyte-specific evidence is absent;
- fluoride mass balance is absent for a defluorination claim;
- source quality is rejected;
- human review is absent.

## Output categories

The system MAY output only:

- `research_gap`;
- `contained_method_review`;
- `contained_bench_priority`;
- `review_required`;
- `excluded`.

The system MUST NOT output:

- environmental release recommendation;
- strain deployment recommendation;
- canal inoculation instruction;
- aquifer inoculation instruction;
- organism safety certification;
- ecological clearance;
- autonomous action.

## Validation

Every output MUST retain:

- candidate source status;
- analyte;
- matrix;
- hydrochemistry match;
- containment basis;
- evidence gaps;
- hard-gate result;
- human review status;
- policy revision;
- uncertainty statement.
