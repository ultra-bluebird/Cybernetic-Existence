# Privacy-Preserving Door Mobility-Context Assistance

## Purpose

This design improves the convenience and accessibility behavior of an automatic pedestrian door by estimating short-lived mobility context near the doorway.

The model may request:

- A wider opening.
- A slower configured opening profile.
- A longer hold-open interval.
- A visual and audible accessibility signal.
- An optional human-assistance notification where the building has such a service.

The model does not grant or deny access. It does not identify a person, diagnose disability, infer health status, recognize a face, recognize a gait identity, verify a cybernetic augmentation, or create a person-level record.

The listed door operator and independent safety sensors remain authoritative for all entrapment protection, reversal, force limitation, manual controls, and emergency operation.

## Safer Model Framing

The system classifies **mobility-relevant approach context**, not people.

Permitted ephemeral classes:

- `standard_approach`
- `wheeled_mobility_context`
- `walking_aid_context`
- `cane_or_long_object_context`
- `mobility_assist_device_context`
- `multiple_or_uncertain_context`
- `no_actionable_context`

The `mobility_assist_device_context` class is intentionally broad. It supports a door response for visible assistive or mobility equipment without claiming whether an object is medical, cybernetic, prosthetic, industrial, recreational, or owned by a particular person.

The system must never label a person as a “cybernetic host,” “disabled,” “wheelchair user,” “walker user,” “cane user,” or any clinical or identity category. Those labels are neither necessary nor appropriate for door timing assistance.

## On-Device Pipeline

```text
Doorway camera
    |
    +--> Hardware privacy mask for non-doorway regions
    |
    +--> Low-resolution frame acquisition
    |
    +--> Person-and-mobility-context detector
    |
    +--> Local temporal tracker with random short-lived track labels
    |
    +--> Confidence and uncertainty gate
    |
    +--> Assistance profile selector
    |
    +--> Local actuator request interface
    |
    +--> Immediate frame disposal
    |
    +--> Aggregate event counter only
```

The camera field of view must cover only the approach and doorway safety zone needed for mobility-context assistance. It must exclude nearby offices, sidewalks beyond the operational zone, building interiors not required for door control, residential windows, and unrelated public space.

## Data Rules

- Perform inference entirely on the edge device.
- Do not send video, still images, feature embeddings, body landmarks, face crops, voice data, biometric templates, gait signatures, or tracking trajectories to a server.
- Disable facial-recognition, re-identification, demographic-estimation, emotion-estimation, and person-counting modules.
- Do not retain frames after the current inference cycle.
- Use random memory-only track handles that expire within seconds after the doorway zone is clear.
- Log only daily or shift-level aggregate event counts, such as `assistance_profile_requested`, `uncertain_context`, `safety_sensor_override`, and `model_health_failure`.
- Apply small-count suppression before publishing any aggregate count.
- Do not link event counters to access-control logs, Wi-Fi logs, badge logs, employee records, or camera archives.
- Provide clear public notice that the system is a local accessibility-assistance sensor, not an identity or security system.
- Provide a physical accessible button and a non-vision activation path so access does not depend on machine perception.

## Model Architecture

A suitable low-latency model is a compact object detector exported to ONNX, such as a small convolutional or mobile-optimized architecture trained exclusively for doorway-relevant object classes.

The model output is:

\[
(o_i, b_i, p_i)
\]

Where:

- \(o_i\) is a mobility-context object class.
- \(b_i\) is a bounding box in the door approach zone.
- \(p_i\) is confidence.

The model may use object geometry, motion direction, and short temporal persistence. It must not use facial features, identity embeddings, or cross-session tracking.

The assistance profile is:

\[
\operatorname{Profile}
=
f(
\operatorname{ContextClass},
\operatorname{Confidence},
\operatorname{ApproachDirection},
\operatorname{Uncertainty}
)
\]

A conservative decision rule is:

\[
\operatorname{Assist}
=
\operatorname{Confidence} \ge \theta
\land
\operatorname{ApproachingDoor}
\]

If confidence is below \(\theta\), the system uses the standard accessible door profile or requests a modest, broadly safe hold-open extension. It must not close faster, narrow the opening, or deny use because a context was uncertain.

## Assistance Profiles

| Mobility context | Opening-width request | Hold-open request | Speed request | Privacy and safety note |
|---|---:|---:|---|
| Standard approach | 0.70 | Standard | Standard operator profile | Standard nonexclusive access |
| Wheeled mobility context | 1.00 | Extended | Reduced configured profile | Applies to any detected wheeled mobility context; no identity inference |
| Walking-aid context | 1.00 | Extended | Reduced configured profile | Uses broad physical-object context only |
| Cane or long-object context | 0.85 | Extended | Reduced configured profile | Helps avoid timing pressure and narrow passage |
| Mobility-assist-device context | 1.00 | Extended | Reduced configured profile | Device-neutral support; no augmentation classification |
| Multiple or uncertain context | 1.00 | Extended | Reduced configured profile | Conservative accessibility profile |
| No actionable context | 0.70 | Standard | Standard operator profile | Physical actuator remains available |

The requests are limited by an approved profile envelope in the listed door operator. The local controller cannot exceed rated limits, disable safety inputs, defeat reversal behavior, or substitute its own motion-safety logic for the operator.

## Safety Priority

\[
\operatorname{SafetyOverride}
>
\operatorname{VisionAssistance}
>
\operatorname{ConvenienceOptimization}
\]

LiDAR, ultrasonic, pressure mat, monitored photoeye, operator obstruction detection, and manual controls take priority over vision assistance.

If vision hardware, model inference, camera coverage, or communication health fails:

- Continue with the standard accessible door profile.
- Keep independent safety protection active.
- Display or log a maintenance indicator where appropriate.
- Do not remove manual activation.
- Do not deny access.
- Do not use camera failure as an access-control event.

## Evaluation

Evaluate the model using:

- Detection recall for doorway-relevant mobility contexts.
- False-negative rate for extended-hold need.
- False-positive rate, measured as benign extra accessibility assistance rather than a security event.
- Latency from observation to assistance request.
- Performance across daylight, low light, glare, rain, mobility-device variety, clothing variation, and diverse body configurations.
- Accessibility parity across device types and environmental conditions.
- Privacy review verifying no prohibited modules, retention, identity linkage, or cloud video transfer.

The key error asymmetry is:

\[
\operatorname{Cost}(\text{false negative})
>
\operatorname{Cost}(\text{false positive})
\]

A false positive produces a modest extra hold-open interval or wider opening. A false negative can create an unnecessary barrier or time pressure. The system should therefore be tuned toward conservative, broadly available assistance while remaining within operator safety limits.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.91 | Uses local inference, bounded context classes, confidence gating, ONNX deployment, and independent safety authority |
| eco_impact_value | 0.48 | Supports reliable, maintainable access infrastructure with low-bandwidth, edge-only processing |
| harm_risk | 0.18 | Controlled by no identity inference, no video retention, no remote control, non-vision fallback, and safety-sensor priority |
| accessibility_impact | 0.99 | Provides extended timing and width assistance without mandatory disclosure, biometric recognition, or app-based access |
| rights_alignment | 0.99 | Protects dignity, privacy, assistive access, non-discrimination, consent, and offline/manual alternatives |
