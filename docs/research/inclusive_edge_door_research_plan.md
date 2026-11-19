# Inclusive Edge Door Research Plan

## Purpose

Develop and evaluate a privacy-preserving, universal-access decision-support layer for powered pedestrian doors. The research evaluates anonymous local sensing and adaptive timing recommendations while preserving certified safety controls, manual operation, non-biometric access, and accessible review.

## Research Questions

- Can local trajectory-aware timing reduce unused open duration relative to a baseline sensor policy?
- Can the system preserve or improve successful passage, low-delay access, and fallback availability for diverse users without identity classification?
- Can the full system operate without retaining video, biometric, neural, health, device, or precise-location records?
- Can all uncertainty, sensor faults, and access-affecting outcomes route to accessible human review?

## System Boundary

The research component does not operate a door motor, lock, life-safety system, emergency interface, or entrapment-protection device.

Permitted outputs:

- RECOMMEND_STANDARD_PROFILE
- RECOMMEND_EXTENDED_PROFILE
- RECOMMEND_REVIEW
- SENSOR_UNCERTAINTY
- PRIVACY_STORAGE_BLOCK

Prohibited outputs:

- DOOR_MOTOR_COMMAND
- LOCK_COMMAND
- FIRE_RESPONSE_COMMAND
- IDENTITY_BASED_ACCESS_COMMAND
- BIOMETRIC_GATE_COMMAND

## Universal Access Invariants

- Access must not require a smartphone, account, identity disclosure, biometric signal, augmentation disclosure, external verification, or unrelated telemetry.
- Accessible non-biometric activation must be available.
- Manual operation or an equivalent accessible fallback must be available.
- The door must provide accessible visual, textual, and optional audio status feedback.
- A person may request human assistance and appeal without retaliation.

## Privacy Invariants

- Raw video retention equals zero during ordinary operation.
- Biometric templates equal zero.
- Neural and health data collection equals zero.
- Persistent device identifiers equal zero.
- Precise individual location history equals zero.
- External cloud telemetry equals zero by default.
- Audit events contain only minimized, non-identifying system state.

## Timing Model

Recommended hold-open duration:

T_recommended = clamp(
  max(T_site_minimum, quantile(anonymous_passage_times, q) + safety_margin),
  T_site_minimum,
  T_site_maximum
)

Where:

- T_site_minimum is established through applicable equipment, safety, accessibility, and site review.
- q is a conservative anonymous-data quantile.
- safety_margin supports varied approaches and safe clearance.
- T_site_maximum is determined by the applicable site and manufacturer constraints.

## Evaluation Conditions

Compare:

- Baseline motion sensor timing
- Zone-sensing timing
- Local predictive timing recommendation

Measure:

- Mean and percentile open duration
- Door reopening frequency
- Conditioned-air exchange proxy
- Successful passage rate
- Request-to-safe-passage delay
- Manual-fallback availability and completion rate
- Sensor availability and fault-routing rate
- Privacy invariant compliance
- Accessible review and appeal resolution rate

## Emergency and Life Safety

The research layer yields to the listed door assembly, certified controller, manufacturer requirements, applicable adopted codes, and authority having jurisdiction. It does not prescribe emergency actuation behavior.

## Governance Metrics

- knowledge_factor: 0.92
- eco_impact_value: 0.80
- harm_risk: 0.11
- accessibility_impact: 0.98
- rights_alignment: 0.99
