# Offline Grievance and Private Sensor Calibration

## Purpose

This operational design provides:

1. A city grievance, correction, and appeal process with phone, paper, kiosk, and assisted-submission routes.
2. A privacy-preserving calibration protocol for temperature, noise, and air-quality sensors using reference stations, discrete calibration observations, and automated residual drift detection.

Neither system requires a personal smartphone, private internet service, government identity document, biometric check, cybernetic-host disclosure, health disclosure, augmentation record, or continuous connectivity.

## Part One: Grievance and Appeal System

### Equal Channel Principle

Every person must be able to initiate an appeal, correction request, complaint, or grievance through at least one of these channels:

| Channel | Submission method | Required accessibility support | Acknowledgment method |
|---|---|---|---|
| Paper form | Drop-off, postal mail, staff-assisted completion | Plain language, large print, alternative formats, translation/interpreter pathway, postage support where available | Printed receipt, postal acknowledgment, or phone callback if chosen |
| Telephone | Voice, relay, TTY-compatible, or authorized support-person call | Relay access, interpretation, extra time, written follow-up on request | Spoken confirmation plus mailed or printed reference receipt |
| Public kiosk | Accessible public terminal in a hub, library, or service center | Keyboard-only operation, screen reader, magnification, contrast, privacy screen, assisted support | Printed receipt and optional reference code |
| Staff-assisted intake | In-person supported entry | Permission-first assistance, private space option, accessible communication choices | Printed receipt and visible review of entered request |
| Online submission | Public website or voluntary personal-device use | WCAG-conformant workflow, no account requirement unless the external process truly requires one | On-screen and printable confirmation |

No channel may be treated as lower priority because it is paper-based, telephone-based, anonymous where permitted, incomplete due to an accessibility barrier, or submitted through an advocate.

### Required Information

The intake process collects only information necessary to understand and route the request:

- Request type: appeal, correction, complaint, grievance, information request, or accessibility concern.
- The service, program, or decision being challenged, if known.
- The visitor's statement in their own words.
- Any supporting documents the visitor elects to provide.
- Preferred contact method, if the visitor wants a response.
- Requested accessibility or communication format.

The intake process does not require:

- Device identifiers, browser fingerprinting, advertising identifiers, geolocation history, or biometric data.
- Disability, health, neural, augmentation, cybernetic-host, or assistive-technology details.
- A reason for choosing paper, phone, kiosk, or assisted submission.
- An account, email address, smartphone, or external identity credential unless independently required by the destination authority and accompanied by an accessible alternative.

### Acknowledgment Objective

Let:

- \(t_{\mathrm{received}}\) be the time that the hub, phone center, kiosk, mailroom, or intake worker receives the request.
- \(t_{\mathrm{ack}}\) be the time the system issues a dated acknowledgment.
- \(T_{\mathrm{ack}}\) be acknowledgement latency.

\[
T_{\mathrm{ack}} =
t_{\mathrm{ack}} - t_{\mathrm{received}}
\]

The target is:

\[
T_{\mathrm{ack}} \leq 24\ \mathrm{hours}
\]

For a paper form deposited outside operating hours, \(t_{\mathrm{received}}\) begins when the controlled intake point next opens or when the scan/drop system creates a tamper-evident intake event, whichever occurs first.

An acknowledgment confirms receipt by the intake system. It does not claim that the grievance has been decided, that an external agency has accepted jurisdiction, or that a requested outcome is guaranteed.

### Outage-Resilient Workflow

```text
RECEIVED
ACKNOWLEDGED
AWAITING_DIGITIZATION
DIGITIZED_PENDING_VERIFICATION
VERIFIED_FOR_ROUTING
QUEUED_FOR_DESTINATION
SUBMITTED_TO_DESTINATION
DELIVERY_UNCONFIRMED
UNDER_REVIEW
CLOSED_WITH_NOTICE
```

During a network outage:

1. Staff issue a numbered, dated paper acknowledgment at intake.
2. The submission is placed in a controlled physical queue or encrypted local queue.
3. The system records the channel, receipt time, accessibility format request, and retention deadline.
4. The request is digitized or transmitted only after connectivity and integrity checks are restored.
5. The person receives a correction notice if a submission cannot be delivered or needs clarification.
6. A person may choose to retain the paper route rather than authorize digitization.

The acknowledgement deadline remains in force during outages. The agency satisfies the 24-hour requirement through a documented local receipt even where external routing is delayed.

### Paper Digitization Without OCR Reliance

OCR must be treated as an assistive transcription tool, not an authoritative source record.

The authoritative record is:

- The original paper form, retained under a defined records schedule; or
- A high-resolution, integrity-checked image of the original form where authorized retention and destruction procedures apply.

The safe conversion sequence is:

```text
SCAN
IMAGE_QUALITY_CHECK
OCR_DRAFT_CREATION
FIELD_CONFIDENCE_CHECK
HUMAN_DOUBLE-ENTRY_OR_VISUAL_VERIFICATION
VISITOR_OR_STAFF_REVIEW
IMMUTABLE_SOURCE_LINKAGE
ROUTING_COPY_CREATION
```

#### Required controls

- Scan the complete page set at a fixed minimum resolution determined by document type.
- Preserve page order, visible markings, signatures, attachments, and handwritten corrections.
- Record image checksum and page count.
- Use OCR only to prepare a draft transcription.
- Require visual verification for names, account references, deadlines, requested remedies, free-text narratives, checkboxes, signatures, and any field with low OCR confidence.
- Use independent double entry for high-impact fields when the visitor cannot review the transcription.
- Keep the original image available to the reviewer and to the person submitting the request where disclosure rules permit.
- Never silently overwrite the source image with an OCR-derived text value.
- Use an accessible correction process when a person identifies a transcription error.

### Conversion-Accuracy Metric

Let:

- \(N_{\mathrm{verified}}\) be the number of field values checked against the source image.
- \(N_{\mathrm{correct}}\) be the number of checked values matching the source image.

\[
\operatorname{ConversionAccuracy} =
\frac{N_{\mathrm{correct}}}{N_{\mathrm{verified}}}
\times 100
\]

The target is:

\[
\operatorname{ConversionAccuracy} > 99\%
\]

This metric must be calculated separately for:

- Structured fields.
- Handwritten free text.
- Checkboxes and selections.
- Attachments and page counts.
- High-impact routing fields.

A general 99% average is insufficient if critical fields have a lower accuracy rate. A correction or appeal must not be rejected because OCR failed to interpret handwriting or a scan was degraded.

### Human Review and Appeal

Any intake error, inaccessible workflow, late acknowledgment, digitization discrepancy, or routing failure must have:

- A plain-language explanation.
- A way to submit a correction without starting over.
- A human review route.
- An accessible escalation route.
- A non-retaliation commitment.
- A time-limited response standard.
- A record-retention explanation in the preferred accessible format.

## Part Two: Sensor Calibration Without Sensitive Data

### Scope

The calibration protocol supports environmental sensors such as:

- Ambient temperature and humidity.
- Noise-level or sound-pressure measurements.
- Particulate matter, ozone, nitrogen dioxide, or other air-quality measurements.
- Water-quality and ecological sensors where an appropriate reference procedure exists.

The protocol is for sensor-quality assessment and maintenance planning. It does not collect images, audio recordings, identities, device identifiers, faces, speech content, mobility trails, biometric information, or individual-level ground truth.

For noise sensing, store only calibrated aggregate sound-level statistics such as equivalent continuous sound level, percentile levels, and instrument-health values. Do not store intelligible audio by default.

### Reference-Based Calibration

For sensor \(s\) at time \(t\):

- \(y_{s,t}\) is the sensor measurement.
- \(r_t\) is the reference-station measurement.
- \(a_s\) and \(b_s\) are calibration intercept and slope.
- \(\hat{y}_{s,t}\) is the expected sensor value.
- \(e_{s,t}\) is the residual.

\[
\hat{y}_{s,t} = a_s + b_s r_t
\]

\[
e_{s,t} = y_{s,t} - \hat{y}_{s,t}
\]

For temperature and other reasonably linear instruments, \(a_s\) and \(b_s\) may be estimated using robust regression. For air sensors affected by temperature and humidity, the reference model may include environmental covariates:

\[
\hat{y}_{s,t} =
a_s +
b_{1,s}r_t +
b_{2,s}T_t +
b_{3,s}RH_t
\]

where \(T_t\) is temperature and \(RH_t\) is relative humidity.

Reference-station collocation compares the sensor and reference instrument at the same location and time under real-world conditions. EPA describes collocation with a regulatory reference or equivalent monitor as a necessary first step for understanding the accuracy of non-reference air-sensor data. [130][137]

### CUSUM Drift Detection

Let:

- \(e_t\) be a validated residual.
- \(\mu_e\) be the expected residual mean, ordinarily near zero after calibration.
- \(k\) be an allowance for normal variation.
- \(h\) be the decision threshold.

The one-sided CUSUM statistics are:

\[
S_t^{+} =
\max
\left(
0,
S_{t-1}^{+} +
(e_t-\mu_e) -
k
\right)
\]

\[
S_t^{-} =
\min
\left(
0,
S_{t-1}^{-} +
(e_t-\mu_e) +
k
\right)
\]

Potential positive drift occurs when:

\[
S_t^{+} > h
\]

Potential negative drift occurs when:

\[
S_t^{-} < -h
\]

CUSUM is well suited to detecting smaller sustained mean shifts that may not be obvious in an individual observation. [131][133]

The calibration state machine is:

```text
UNINITIALIZED
COLLOCATION_REQUIRED
NOMINAL
SUSPECT_DRIFT
DRIFT_REVIEW_REQUIRED
CALIBRATION_IN_PROGRESS
POST_CALIBRATION_VALIDATION
OUT_OF_SERVICE_FOR_AUTOMATED_RELIANCE
```

A drift state does not authorize automatic environmental action. It marks the measurement as unsuitable for automated reliance until an authorized calibration review is complete.

### Bayesian Alternative

Where reference data are intermittent or site conditions vary substantially, use a Bayesian dynamic calibration model:

\[
y_t =
\alpha_t +
\beta_t r_t +
\epsilon_t
\]

\[
\alpha_t =
\alpha_{t-1} +
\eta_{\alpha,t}
\]

\[
\beta_t =
\beta_{t-1} +
\eta_{\beta,t}
\]

The posterior distributions of \(\alpha_t\) and \(\beta_t\) provide an uncertainty-aware indication of offset and gain drift.

A calibration review is triggered when:

\[
\Pr
\left(
|\alpha_t| > \alpha_{\max}
\lor
|\beta_t - 1| > \beta_{\max}
\mid
\text{observations}
\right)
\geq p_{\mathrm{trigger}}
\]

This approach reports uncertainty directly and does not require any person-level labels or passersby-derived ground truth.

### Temporal Convolution Alternative

For high-frequency sensor data, a temporal convolutional model may detect changes in residual patterns. It should use only environmental and instrument-health features:

\[
x_t =
[
y_t,
r_t,
T_t,
RH_t,
V_{\mathrm{battery},t},
q_t
]
\]

where \(q_t\) is a sensor-quality indicator.

The temporal model output must be advisory:

\[
p_{\mathrm{drift},t} =
f_{\theta}
(x_{t-W+1},\ldots,x_t)
\]

A model alert is valid only when:

- The input window passes instrument-health checks.
- The model has been independently evaluated against calibration records.
- A reference or manual verification process is available.
- The event enters `SUSPECT_DRIFT`, not an automatic control or enforcement action.
- The model is not trained on images, audio content, personal-device signals, or individual movement data.

### Calibration Interval

Let:

- \(E_{\max}\) be the maximum allowable absolute error.
- \(d\) be a conservative estimated drift rate in error units per day.
- \(I_{\mathrm{cal}}\) be the maximum calibration interval in days.

\[
I_{\mathrm{cal}} =
\frac{E_{\max}}{d}
\]

For deployment, use a safety factor \(s > 1\):

\[
I_{\mathrm{scheduled}} =
\frac{E_{\max}}{s d}
\]

If uncertainty in drift rate is high, use an upper confidence bound \(d_{\mathrm{UCB}}\):

\[
I_{\mathrm{scheduled}} =
\frac{E_{\max}}{s d_{\mathrm{UCB}}}
\]

The interval is a planning estimate, not permission to ignore a detected anomaly. A sensor may require immediate recalibration after physical damage, environmental extreme, firmware update, power anomaly, reference discrepancy, or CUSUM threshold crossing.

### Low-Disruption Scheduling

Calibration scheduling should minimize public disruption while maintaining measurement quality:

- Prioritize remote diagnostics and reference comparison before a physical site visit.
- Conduct planned service during lower-use windows established from aggregate facility operations, not personal mobility tracking.
- Maintain redundant coverage so one sensor can be serviced while nearby reference coverage remains available.
- Post an accessible public maintenance notice where a sensor supports a community-facing display.
- Avoid closing accessible paths, seating, water access, transit approaches, or public amenities for routine calibration.
- Use a portable reference device or scheduled collocation period where taking a sensor offline would leave a coverage gap.
- Document delayed calibrations and their effect on uncertainty.
- Require post-calibration validation before restoring a sensor to automated reporting.

## Privacy-Preserving Audit Fields

### Grievance process summary

```json
{
  "event_type": "grievance_intake_process",
  "received_at": "2026-09-01T00:00:00Z",
  "submission_channel": "paper",
  "acknowledged_at": "2026-09-01T00:00:00Z",
  "acknowledgment_within_24_hours": true,
  "digitization_state": "verified_for_routing",
  "accessibility_format_requested": "plain_language_print",
  "identity_or_health_data_required": false,
  "retention_class": "case_limited"
}
```

### Sensor calibration summary

```json
{
  "event_type": "sensor_calibration_summary",
  "observed_at": "2026-09-01T00:00:00Z",
  "sensor_class": "air_quality",
  "zone_id": "public_environment_zone",
  "calibration_state": "suspect_drift",
  "reference_comparison_available": true,
  "personal_data_present": false,
  "raw_audio_present": false,
  "raw_video_present": false,
  "automated_actuation_performed": false,
  "retention_class": "maintenance_limited"
}
```

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.90 | Draws on channel-neutral service design, source-preserving digitization, reference-station calibration, CUSUM monitoring, and uncertainty-aware statistical models |
| eco_impact_value | 0.76 | Better calibration reduces unnecessary maintenance travel, avoids replacing functional equipment prematurely, and improves environmental measurement reliability |
| harm_risk | 0.29 | Risks include transcription errors, missed acknowledgments, calibration error, and overreliance on models; mitigated through source preservation, verification, redundancy, and human review |
| accessibility_impact | 0.98 | Guarantees paper, phone, kiosk, assisted, and online paths with equivalent acknowledgment and correction rights |
| rights_alignment | 0.98 | Enforces privacy, minimal data, accessible appeal, non-retaliation, correction, explainability, and non-surveillance calibration |
