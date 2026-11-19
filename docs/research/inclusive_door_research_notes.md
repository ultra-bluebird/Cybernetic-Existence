# Inclusive Door Research Notes

## Purpose

This note preserves the research direction for a privacy-preserving, universal-access decision-support layer for powered pedestrian doors.

The system is designed to improve access and reduce avoidable conditioned-air exchange without requiring identity disclosure, biometric processing, smartphone possession, cloud connectivity, assistive-device classification, or continuous surveillance.

The system is advisory only. It does not command door motors, locks, emergency systems, or fire and life-safety controls.

## Research Position

Universal access, safety, privacy, and accessible human review are binding constraints.

Energy efficiency is a secondary objective that may be optimized only after all access, safety, privacy, and fallback constraints are satisfied.

A shorter opening duration is not an improvement when it causes exclusion, unsafe pressure, delayed passage, repeated approaches, inaccessible fallback, identity-dependent access, or privacy intrusion.

## Core Invariants

- Successful passage performance must meet or exceed the baseline policy.
- The 95th percentile request-to-safe-passage delay must remain within the approved access tolerance.
- Manual or equivalent accessible fallback availability must remain at 1.0.
- Identity disclosure required for ordinary access must remain false.
- Biometric gate required for ordinary access must remain false.
- Cloud connectivity required for ordinary access must remain false.
- Persistent device identifier required for ordinary access must remain false.
- Edge decision support may directly actuate physical door movement must remain false.
- Raw visual media retained during ordinary operation must remain false.
- Biometric, neural, health, and augmentation-status data stored by the door research layer must remain false.
- Review routing must not disable ordinary accessible fallback.

## Timing Model

Recommended hold-open duration:

T_recommended = clamp(
  max(
    T_site_minimum,
    quantile(anonymous_passage_times, q) + safety_margin
  ),
  T_site_minimum,
  T_site_maximum
)

Definitions:

- T_site_minimum: The locally validated minimum duration established through equipment documentation, accessibility review, applicable life-safety requirements, and site operations review.
- T_site_maximum: The locally validated upper duration compatible with the listed assembly, site operations, security, energy conditions, and applicable requirements.
- anonymous_passage_times: Voluntary, consented, non-identifying usability-study data or safely generated test data.
- q: Conservative quantile selected through documented accessibility review.
- safety_margin: Explicit time allowance for variable approach, maneuvering, pause, and passage conditions.

The timing model must not infer disability, mobility-aid use, health status, augmentation status, identity, species, or a person's need for accessibility.

## Allowed Outputs

- RECOMMEND_STANDARD_PROFILE
- RECOMMEND_EXTENDED_PROFILE
- RECOMMEND_REVIEW
- SENSOR_UNCERTAINTY
- PRIVACY_STORAGE_BLOCK
- CONFIGURATION_REVIEW_REQUIRED

## Prohibited Outputs

- DOOR_MOTOR_COMMAND
- LOCK_COMMAND
- FIRE_RESPONSE_COMMAND
- IDENTITY_BASED_ACCESS_COMMAND
- BIOMETRIC_GATE_COMMAND
- ACCESS_DENIAL_COMMAND
- MAINTENANCE_START_COMMAND

## System Boundary

The research layer may process anonymous local sensor features and provide an advisory timing recommendation.

The listed door operator, entrapment-protection equipment, manual activation method, emergency system, and site life-safety design remain separate operational components.

The edge research layer yields to the certified operator and never overrides manufacturer instructions, adopted requirements, the authority having jurisdiction, or site-approved emergency behavior.

## Privacy-Minimized Data Rules

Permitted operational fields:

- Coarse door-zone reference
- Time bucket
- Sensor health status
- Sensor confidence or uncertainty status
- Advisory timing profile
- Advisory timing duration
- Aggregate door-open duration
- Aggregate reopening count
- Aggregate energy measurement
- Aggregate indoor-outdoor thermal proxy
- Manual fallback availability
- Review reason code
- Configuration version
- Policy version

Never store:

- Names or direct identifiers
- Face images or raw video
- Raw thermal images
- Voice recordings
- Precise individual location or path history
- Persistent device identifiers
- Bluetooth addresses
- Network addresses associated with a person
- Biometric templates
- Neural data
- Health data
- Assistive-device identifiers
- Augmentation status
- Identity inference
- Individual mobility profile
- Continuous surveillance record

## Site Profiles

The research program evaluates the model with site-governed timing envelopes rather than a universal timing value.

- High-throughput care setting: Test continuous movement, varied approach pace, staff equipment, and reliable low-delay passage.
- Transit or civic-service entrance: Test peak traffic, crowd conditions, weather variation, and legible accessible fallback.
- Public library or community hub: Test low-energy operation while preserving quiet, low-delay public access.
- Heat-exposed public building: Test thermal differential, conditioned-air exchange proxy, shade conditions, and resilient access.
- Secure but publicly accessible area: Test strict separation between ordinary physical access and optional external authentication.
- Power-loss or degraded-sensor condition: Test accessible manual or equivalent fallback, fault notices, and safe loss of advisory functionality.

## Evaluation Design

Compare:

- Baseline fixed timing or conventional motion-sensor policy
- Zone-sensing timing policy
- Privacy-preserving local predictive timing recommendation

Access and safety measures:

P_successful_passage =
  successful_passages / attempted_passages

D_95_safe_passage =
  quantile(request_to_safe_passage_delay, 0.95)

A_manual_equivalent_fallback =
  usable_fallback_tests / total_fallback_tests

Required conditions:

P_successful_passage_predictive >= P_successful_passage_baseline

D_95_safe_passage_predictive <=
  D_95_safe_passage_baseline + delta_access

A_manual_equivalent_fallback = 1.0

Energy and ecological measures:

T_unused_open =
  sum(unneeded_door_open_duration)

H_conditioned_air_proxy =
  sum(abs(indoor_temperature - outdoor_temperature) * door_open_duration)

E_operator =
  metered_door_operator_energy

The research reports measured values, uncertainty, environmental conditions, site profile, timing envelope, and data-completeness limitations. It does not claim carbon-negative status, universal energy savings, universal compliance, or infrastructure certification.

## Review and Appeal

Review is an end-to-end public-interest process:

Detection
-> reason code
-> accessible notice
-> human acknowledgement
-> review
-> resolution
-> correction or appeal
-> auditable closure

Required review measures:

T_ack =
  human_acknowledgement_time - review_routing_time

T_resolve =
  resolution_time - review_routing_time

R_accessible =
  accessible_review_cases / all_review_cases

R_appeal =
  appeals_resolved_with_reason_and_remedy / appeals_received

F_fallback =
  review_events_with_usable_fallback / all_review_events

Targets:

R_accessible = 1.0

F_fallback = 1.0

Review categories must be system-centered rather than person-centered:

- Sensor health fault
- Conflicting local sensor evidence
- Uncertain approach feature
- Manual fallback activation
- Timing-envelope configuration concern
- Privacy-policy storage block
- Calibration requirement
- Maintenance review requirement

## Research Questions

- Does local advisory timing reduce unused opening duration while preserving or improving successful passage?
- Does the advisory layer preserve low-delay passage across each site profile?
- Does the manual or equivalent accessible fallback remain available under uncertainty, sensor degradation, and power-loss scenarios?
- Can data minimization be technically verified through logs, configuration inspection, and retention tests?
- Can sensor uncertainty be communicated in accessible formats without interrupting ordinary access?
- Can human review and appeal meet measurable accessibility, response, and resolution standards?
- Does a radar-first sensing design provide sufficient anonymous approach evidence without visual surveillance?
- Does adding depth or vision-derived local features create a measurable access or reliability improvement that justifies the added privacy and governance burden?

## Research Sequence

1. Establish a tabletop or laboratory demonstrator with a non-actuating advisory interface and independently operable manual fallback.
2. Implement audit-safe event recording with explicit privacy storage tests.
3. Evaluate fixed timing, zone sensing, and advisory timing under controlled, voluntary usability trials.
4. Validate timing envelopes with accessibility participants, building operators, equipment specialists, and safety reviewers.
5. Evaluate radar-first sensing before considering any visual modality.
6. Introduce additional sensing only when it improves a pre-registered access or reliability metric without weakening privacy constraints.
7. Conduct fault-injection tests for sensor disagreement, sensor loss, power loss, configuration error, and review-routing failure.
8. Evaluate review response, accessibility, remedy, correction, and appeal as real operational outcomes.
9. Produce site-specific pilot protocols only after laboratory results satisfy all binding access, privacy, and non-actuation invariants.

## Claim Discipline

Use:

- Privacy-preserving local processing
- Anonymous local sensor features
- Advisory timing recommendation
- Site-reviewed configuration
- Non-biometric accessible activation
- Manual or equivalent accessible fallback
- Aggregate performance measurement
- Measured conditioned-air exchange proxy
- Accessible human review and appeal
- Decision support only

Avoid:

- AI determines who needs accessibility
- Universal optimum hold-open time
- One timing value works for every site
- Disability detection
- Augmentation detection
- Identity validation
- User tracking
- Behavioral profiling
- Guaranteed energy savings
- Guaranteed compliance
- Direct AI door control
- Universal emergency opening behavior
- Carbon-negative door operation

## Governance Metrics

- knowledge_factor: 0.92
  Basis: Defined system boundary, measurable invariants, site-specific evaluation protocol, and explicit uncertainty routing.

- eco_impact_value: 0.80
  Basis: Supports reduced avoidable open duration and thermal exchange while requiring measured, non-exaggerated environmental reporting.

- harm_risk: 0.11
  Basis: Non-actuation, certified safety boundary, manual fallback, fail-closed uncertainty handling, and privacy constraints.

- accessibility_impact: 0.98
  Basis: Access-first optimization, identity-neutral design, accessible fallback, review, appeal, and site-profile validation.

- rights_alignment: 0.99
  Basis: No compelled disclosure, no biometrics, no continuous surveillance, data minimization, human review, and non-retaliatory appeal.
