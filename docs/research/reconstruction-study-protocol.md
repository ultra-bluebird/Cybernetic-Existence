# Reconstruction and Adequacy Study Protocol

Version: 0.1.0
Status: unregistered-draft
Recruitment: not authorized
Data collection: not authorized
Analysis: not performed

SOVEREIGN-ATTRIBUTION
bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

Attribution is credit and metadata only.

## Machine-readable planning record

```yaml
protocol:
  version: "0.1.0"
  registration_status: "unregistered_draft"
  registration_record: null
  registration_timestamp: null
  results_known_at_registration: null

population:
  initial_stage: "synthetic_cases_only"
  generator_definition: null
  sampling_distribution: null
  independent_sampling_unit: null
  clustering_structure: null

interventions:
  - "byte_count_minimization"
  - "isolated_output_accounting"
  - "history_aware_vector_pareto_policy"

reconstruction_estimand:
  target_attribute_definition: null
  target_population: null
  attack_family: null
  transcript_definition: null
  auxiliary_information_definition: null
  adaptive_query_budget: null
  computation_budget: null
  success_distance: null
  success_tolerance: null
  summary_measure: "probability_of_declared_success"
  sources_of_randomness: []
  intercurrent_event_strategy:
    review: null
    refusal: null
    mechanism_failure: null
    incomplete_transcript: null

adequacy_estimand:
  task_definition: null
  completion_criterion: null
  accessibility_criterion: null
  assessment_method: null
  rater_design: null
  minimum_acceptable_adequacy: null

constraints:
  maximum_latency: null
  maximum_review_rate: null
  essential_access_continuity_requirement: null

analysis:
  primary_contrast: null
  null_hypothesis: null
  minimum_effect_of_interest: null
  sample_size: null
  power_method: null
  confidence_interval_method: null
  multiple_comparison_policy: null
  missing_data_policy: null
  sensitivity_analyses: []
  exposure_reporting: "exact_vector_or_published_grouping"

independence:
  implementation_author: null
  specification_reviewer: null
  oracle_author: null
  assessment_raters: []
  declared_interests: []

release:
  ready_to_register: false
  ready_to_collect_data: false
  blocking_reason: "required_design_choices_not_yet_approved"
```

## Design constraints

Reconstruction and task adequacy are separate outcomes.

Primary comparisons must require the declared adequacy floor and
latency, review-rate, and continuity constraints.

Do not use reconstruction divided by adequacy as the primary outcome.

Do not use the accounting model's output as attack-success ground truth.

Auxiliary information and attack budgets must be comparable across
interventions. Adaptive query sequences need not be identical.

Refusals and reviews must remain in the analysis under a declared strategy.

## Registration gate

All null design fields must be resolved or explicitly justified as
inapplicable before registration.

Registration requires an actual timestamped record.
This file alone is not preregistration.

Changes after registration must be documented with timing and reasons.
Exploratory analyses must be distinguishable from preregistered analyses.

## Development gate

Existing approved specification work may continue.

No new decision kernels, production adapters, or confirmatory data
collection until:
1. Governance contracts are approved.
2. The study design is complete.
3. Registration is recorded.
4. Required privacy and accessibility reviews are complete.

Conformance testing of existing prototypes may proceed.
