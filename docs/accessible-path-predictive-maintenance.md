# Predictive Maintenance for Accessible Pedestrian Paths

## Purpose

This system detects visible infrastructure conditions that may obstruct or degrade accessible pedestrian routes, including ramps, tactile warning surfaces, automatic doors, curb transitions, handrails, path surfaces, and accessible-route signage.

It uses edge cameras and local anomaly detection to create maintenance recommendations. It does not identify, track, classify, or profile people.

The system is decision support. A qualified municipal or facility maintenance workflow reviews the evidence and creates or confirms work orders. The system must not autonomously close access routes, deny building entry, issue citations, infer disability, determine legal compliance, or replace accessibility inspection.

## Inspection Targets

Permitted asset-condition classes:

- `ramp_surface_crack`
- `ramp_surface_deformation`
- `ramp_obstruction`
- `ramp_water_or_debris`
- `handrail_damage`
- `tactile_paving_damage`
- `tactile_paving_obstruction`
- `tactile_paving_low_contrast`
- `automatic_door_misalignment`
- `automatic_door_obstruction`
- `automatic_door_sensor_fault_indicator`
- `path_surface_crack`
- `path_surface_heave`
- `path_surface_obstruction`
- `signage_damage`
- `unknown_condition`

The system must not produce person classes such as:

```text
wheelchair_user
disabled_person
cybernetic_host
pedestrian_identity
face_identity
demographic_group
health_status
behavior_risk
```

## Privacy Boundary

- Cameras are fixed to inspect infrastructure surfaces and equipment, not people.
- Camera fields of view exclude faces, building interiors, nearby homes, and unrelated public space whenever technically possible.
- Perform detection and anomaly scoring on the edge device.
- Do not use facial recognition, person re-identification, demographic estimation, gait recognition, emotion analysis, license-plate recognition, or cross-camera tracking.
- Do not retain raw video or images after local condition inference except for a short, access-controlled, policy-approved maintenance evidence window.
- Blur or discard any incidental human image region before a maintenance image is retained.
- Store only asset identifier, condition class, confidence, severity estimate, time window, model version, and maintenance evidence hash.
- Do not link inspection events to fare systems, Wi-Fi, mobile devices, employee records, law enforcement, or access-control logs.
- Publish only aggregate maintenance-quality and response-time statistics.

## Training Data

Train a local asset-condition model using:

- Images of infrastructure defects and intact asset conditions.
- Synthetic augmentation for lighting, glare, shadows, rain, leaves, dust, and camera angle.
- Independently reviewed labels for visible asset conditions.
- Explicit exclusion of faces, people, body landmarks, identity labels, health labels, and augmentation labels.
- Stratified samples from varied neighborhoods, lighting conditions, pavement types, and maintenance histories.
- Accessibility expert review of class definitions and false-negative severity.

The training pipeline must reject records containing face crops, person identity, address-level resident data, or protected-class labels not strictly required for asset-condition validation.

## Model Architecture

Use two complementary edge models:

- **Condition detector:** A compact object-detection or segmentation network that finds known visible conditions such as obstructions, tactile-paving damage, cracks, or door misalignment.
- **Anomaly detector:** A reconstruction or embedding-distance model trained on normal asset-condition images, which flags unfamiliar wear or configuration changes for review.

For image patch \(x\), the anomaly score can be:

\[
A(x)
=
\left\|
x-\hat{x}
\right\|_2^2
\]

Where \(\hat{x}\) is the reconstruction produced by an autoencoder trained on normal infrastructure condition.

A combined condition score is:

\[
C(x)
=
0.65C_{\mathrm{detector}}(x)
+
0.35
\operatorname{clip}
\left(
\frac{A(x)}{A_{\mathrm{reference}}+\epsilon},
0,
1
\right)
\]

The model generates an observation only where:

\[
C(x)
\ge
\theta_{\mathrm{condition}}
\]

## Accessibility-Impact Priority

A maintenance ticket priority must reflect the potential barrier to route use, not merely the visible size of a defect.

For condition event \(e\):

\[
P_e
=
0.35S_e
+
0.25B_e
+
0.20R_e
+
0.10U_e
+
0.10D_e
\]

Where:

- \(S_e\): safety severity, including trip, roll, entrapment, or collision risk.
- \(B_e\): accessibility barrier magnitude.
- \(R_e\): route criticality, including whether the path is a sole or near-sole accessible route.
- \(U_e\): expected public-use and essential-service dependency.
- \(D_e\): duration and degradation trend.

All inputs are bounded from zero to one.

The priority band is:

| Priority score | Ticket class | Required action |
|---|---|---|
| 0.80–1.00 | Emergency accessibility barrier | Immediate human review and emergency response under approved safety procedures |
| 0.60–0.79 | Urgent repair | Rapid inspection and scheduled repair within published service target |
| 0.35–0.59 | Standard repair | Add to planned maintenance route with tracking |
| 0.00–0.34 | Monitor | Continue condition monitoring and inspect if degradation persists |

## Compliance-Aware Review

The model must not declare an asset legally compliant or noncompliant. It should instead report observed conditions relevant to inspection.

For example, detectable warning surfaces are specified in public-right-of-way accessibility guidance as firm, stable, slip-resistant surfaces with visual contrast and truncated-dome geometry; exact requirements depend on the applicable standard, facility, and jurisdiction. [234][243]

A human accessibility inspector determines whether an observed condition violates a legal or facility requirement.

## TFLite Edge Pipeline

```text
Fixed asset-facing camera
    |
    +--> Privacy crop and incidental-person redaction
    |
    +--> Frame quality check
    |
    +--> TFLite condition detector
    |
    +--> TFLite anomaly detector
    |
    +--> Confidence, persistence, and asset-location gate
    |
    +--> Priority calculation
    |
    +--> Maintenance evidence package
    |
    +--> Secure ticket recommendation API
    |
    +--> Immediate frame disposal
```

## Ticket Payload

A ticket recommendation includes:

```text
asset_reference
condition_class
condition_confidence
anomaly_score
priority_score
priority_band
observed_time_window
persistence_count
route_criticality
model_version
maintenance_evidence_hash
privacy_redaction_confirmed
human_review_required
```

A ticket recommendation excludes:

```text
person_identity
face_image
body_template
disability_status
cybernetic_status
health_data
device_identifier
passenger_or_pedestrian_count
location_history
behavior_data
```

## Human Review

A reviewer must be able to:

- Inspect redacted condition evidence.
- View the model condition class, anomaly score, confidence, and priority explanation.
- Confirm, reclassify, defer, or reject the ticket.
- Mark an emergency accessibility route issue.
- Request a field inspection.
- Correct route-criticality metadata.
- Record the maintenance response and resolution outcome.
- Appeal or correct a false infrastructure classification through an accessible public channel.

No autonomous closure or enforcement action may result from a model output.

## Model Evaluation

Evaluate:

- Condition-detection precision and recall.
- False-negative rate for emergency accessibility barriers.
- False-positive rate for routine conditions.
- Performance across lighting, rain, shadows, glare, debris, seasons, neighborhoods, and asset materials.
- Latency and energy consumption on the target edge hardware.
- Person-redaction success rate.
- Percentage of retained evidence verified as redacted.
- Repair-time improvement for high-priority accessibility barriers.
- Disparity in maintenance response time across districts.
- Human-review agreement and override rate.

The primary safety asymmetry is:

\[
\operatorname{Cost}(\mathrm{FalseNegative}_{\mathrm{critical}})
>
\operatorname{Cost}(\mathrm{FalsePositive}_{\mathrm{routine}})
\]

The system should favor rapid human inspection for uncertain, high-impact potential barriers rather than falsely declaring routes clear.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.92 | Uses edge detection, anomaly scoring, priority calculation, human review, privacy redaction, and condition persistence |
| eco_impact_value | 0.65 | Extends asset life, supports preventive repair, reduces emergency replacement, and improves walkable public infrastructure |
| harm_risk | 0.18 | Reduced through asset-only classes, edge processing, no identity analytics, retention limits, redaction, and human review |
| accessibility_impact | 0.99 | Prioritizes route barriers, tactile surfaces, ramps, doors, and sole accessible routes |
| rights_alignment | 0.99 | Prevents surveillance reuse, avoids identity inference, maintains accessible correction pathways, and prohibits autonomous enforcement |
