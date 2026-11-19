# Privacy-Preserving Water and Air Alert Systems

## Scope

This design covers:

- Edge anomaly detection for public drinking-water fountains and distribution points.
- Public air-quality alerts based on geographic service zones and aggregate planning data.
- Federated model improvement without transmitting raw sensor time series.
- Accessible communication without individual health records, persistent tracking, or identity-based targeting.

The systems provide decision support and public information. They do not certify drinking-water safety, make medical determinations, replace laboratory confirmation, determine individual vulnerability, or authorize automatic physical interventions.

## Rights and Safety Baseline

Both systems SHALL:

- Treat location, health, identity, augmentation, biometric, neural, and device information as sensitive by default.
- Avoid individual location tracking and avoid storing a direct sensor-to-public-address mapping in alert logs.
- Use aggregate geographic zones large enough to reduce re-identification risk.
- Provide equivalent alerts through non-digital and device-independent channels.
- Preserve public access to water and public information during outages.
- Present uncertainty, source provenance, last-update time, and a contact route for correction or accessibility feedback.
- Require qualified maintenance or public-health review before a finding is characterized as a confirmed contamination event.
- Use accessible, plain-language messages without medical assumptions about the recipient.

## Water Monitoring

### Suitable Parameters

Low-cost sensing is most useful for detecting changes from a locally established baseline. It is not a substitute for regulated compliance sampling.

| Parameter | Practical sensing role | Edge anomaly value | Main limitation |
|---|---|---|---|
| Water temperature | Detects thermal shifts, stagnation indicators, and sensor-enclosure conditions | High | Does not identify contamination |
| Turbidity | Detects suspended-particle changes and some distribution disturbances | High | Requires cleaning and calibration; bubbles and fouling can distort readings |
| pH | Detects acid-base shifts and potential corrosion/process changes | Medium to high | Electrode drift and maintenance burden |
| Electrical conductivity | Detects broad dissolved-ion changes and mixing anomalies | High | Non-specific; a deviation does not identify a contaminant |
| Oxidation-reduction potential | Supplemental treatment/disinfection-process indicator | Medium | Interpretation is context-dependent |
| Residual disinfectant | Useful where a validated chlorine or chloramine method is appropriate | High | Requires chemistry-specific maintenance and locally validated ranges |
| Flow or usage proxy | Helps distinguish stagnation, unusual draw, and sensor artifacts | Medium | Must not become person or device tracking |
| Enclosure temperature and battery voltage | Detects instrumentation faults | High | Measures sensor health, not water safety |

Temperature, pH, turbidity, and conductivity are established water-monitoring parameters. EPA materials identify temperature, pH, and turbidity among common monitoring parameters, while conductivity is routinely used as a broad water-quality indicator. [101][107]

### Data-Minimizing Node Design

Each sensor node SHALL use a locally generated random node alias. The public reporting system receives a zone-level summary only.

The following SHALL remain local to the operations environment:

- Exact fountain or distribution-point coordinates.
- Raw high-frequency sensor time series.
- Maintenance-worker identifiers.
- Local network addresses, wireless identifiers, and device serial numbers.
- Any camera, microphone, or user-presence data.

A node may transmit a minimum event envelope:

```json
{
  "event_type": "water_quality_anomaly_summary",
  "zone_id": "public_water_zone",
  "event_time": "2026-09-01T00:00:00Z",
  "anomaly_state": "maintenance_review_requested",
  "parameter_flags": [
    "turbidity_deviation",
    "conductivity_deviation"
  ],
  "model_version": "1.0.0",
  "sensor_health": "nominal",
  "raw_readings_included": false,
  "exact_location_included": false,
  "person_data_included": false
}
```

An event summary is not a drinking-water advisory. The public-facing system should use language such as:

> “This public water point is receiving maintenance review. Please use another available source if convenient. This notice is precautionary and does not identify a confirmed water-quality condition.”

### Edge Validation

Before anomaly scoring, the node SHALL reject or quarantine readings that are:

- Non-finite.
- Outside the calibrated physical measurement range.
- Missing required calibration metadata.
- Produced while probe-cleaning, calibration, or maintenance mode is active.
- Associated with inadequate battery voltage, enclosure overheating, or sensor communication failure.
- Inconsistent with configured rate-of-change limits unless independently corroborated.

A low-cost sensor is most reliable as a change detector when it has documented calibration, cleaning, drift checks, and a site-specific reference baseline. Negative turbidity readings, for example, can arise from probe cleaning or recalibration problems, reinforcing the need for explicit sensor-health gates. [105]

### Mahalanobis Anomaly Score

Let the locally normalized feature vector be:

\[
x_t =
\begin{bmatrix}
z_{\text{temperature},t} \\
z_{\text{turbidity},t} \\
z_{\text{pH},t} \\
z_{\text{conductivity},t}
\end{bmatrix}
\]

where each component is normalized using a locally maintained baseline.

Let:

- \(\mu\) be the baseline mean vector.
- \(\Sigma\) be a regularized baseline covariance matrix.
- \(\lambda > 0\) be a regularization constant.
- \(\Sigma_\lambda = \Sigma + \lambda I\).

The squared Mahalanobis distance is:

\[
D_M^2(x_t) =
(x_t - \mu)^T
\Sigma_\lambda^{-1}
(x_t - \mu)
\]

The node enters a preliminary anomaly state only when:

\[
D_M^2(x_t) > \tau
\]

for \(k\) consecutive validated samples, where \(\tau\) and \(k\) are locally calibrated from baseline data.

A conservative state machine is:

```text
NORMAL
SUSPECTED_ANOMALY
RECHECK_REQUIRED
MAINTENANCE_REVIEW_REQUESTED
LAB_OR_FIELD_CONFIRMATION_PENDING
RESOLVED
```

No state automatically asserts contamination, closes a water point, or makes a public health claim.

### Weekly False-Alarm Metric

For sensor \(s\) in week \(w\):

\[
\operatorname{FAR}_{s,w} =
\frac{\operatorname{FalseAlerts}_{s,w}}
{\operatorname{ValidatedObservationWindows}_{s,w}}
\]

The research target is:

\[
\operatorname{FAR}_{s,w} < 0.01
\]

The target must be reported alongside:

- Confirmed-event sensitivity.
- Median time from anomaly to maintenance review.
- Percentage of sensor uptime.
- Calibration completion rate.
- Number of alerts suppressed due to sensor-health failures.
- Number of alerts independently confirmed or rejected.
- Confidence interval and sample size.

A low false-alarm rate alone is not sufficient. A model can reduce false alarms by missing important events, so the program must monitor both false alarms and missed or delayed detections.

## Federated Learning

### Local-First Training

Each node retains its raw readings and trains on local rolling windows. It shares model updates only after local validation, clipping, and privacy review.

For node \(i\), local model parameters at learning round \(r\) are \(\theta_i^{(r)}\). The node computes a local update:

\[
\Delta_i^{(r)} =
\theta_i^{(r)} -
\theta^{(r)}
\]

The coordinating service receives a clipped update:

\[
\widetilde{\Delta}_i^{(r)} =
\Delta_i^{(r)}
\cdot
\min
\left(
1,
\frac{B}{\left\|\Delta_i^{(r)}\right\|_2}
\right)
\]

where \(B\) is a configured update-norm bound.

The next global model is:

\[
\theta^{(r+1)} =
\theta^{(r)}
+
\sum_{i=1}^{n}
\frac{w_i}{\sum_{j=1}^{n} w_j}
\widetilde{\Delta}_i^{(r)}
\]

where \(w_i\) is a bounded, non-personal training weight such as the count of locally validated windows.

Federated learning enables multiple edge nodes to collaboratively improve a model without sending raw local training data to a central coordinator. This makes it useful for privacy-preserving anomaly-detection research, while not eliminating the need for update-security and leakage testing. [103][104]

### Federated-Learning Protections

The federated coordinator SHALL:

- Accept only authenticated, attested node updates from approved maintenance infrastructure.
- Use secure aggregation so the coordinator cannot inspect an individual node update when deployment scale permits.
- Apply norm clipping and consider calibrated differential privacy noise after utility testing.
- Reject model updates from nodes in maintenance mode or failed sensor-health states.
- Maintain model-version rollback and independent holdout evaluation.
- Prevent a single node from changing global behavior materially.
- Avoid location-weighted or neighborhood-income-weighted learning.
- Publish aggregate model performance by environmental condition, not by individual or household characteristics.
- Keep raw sensor data and exact sensor locations outside the global-model service.

## Air-Quality Alerts

### Public, Zone-Based Model

Alerts are issued to public geographic zones, not to named people. A zone may be defined using planning districts, neighborhoods, transit-access areas, library-service areas, or public-weather-alert regions.

The system may use census-derived prevalence estimates only for planning the placement of public displays, radio coverage, translated material, and outreach capacity. It SHALL NOT:

- Build a list of people presumed to have asthma or another condition.
- Link a prevalence estimate to household, device, phone number, or identity data.
- Send a health-targeted message to an individual without their explicit, revocable subscription.
- Infer health status from browsing, mobility, purchases, pharmacy visits, assistive technology, or other behavior.

The public alert should be phrased for everyone:

> “Air quality in this zone may be unhealthy today. Consider reducing prolonged outdoor exertion if you are sensitive to air pollution. Check local public-health guidance for current conditions and support options.”

This approach allows people to interpret the alert based on their own knowledge of their health and circumstances, without disclosing those circumstances to the system.

### Trigger

For a zone \(z\), let \(PM_{2.5,z}^{24h}\) be a validated rolling 24-hour PM2.5 concentration.

The proposed alert trigger is:

\[
\operatorname{Alert}(z) =
\begin{cases}
1 & \text{if } PM_{2.5,z}^{24h} > 35\ \mu g/m^3 \\
0 & \text{otherwise}
\end{cases}
\]

The 35 \(\mu g/m^3\) figure corresponds to the United States 24-hour PM2.5 NAAQS level, expressed as a 98th-percentile form over a multiyear regulatory design-value framework. A local real-time public-alert rule is an operational communication policy, not a regulatory compliance determination. [102][111]

The system should distinguish:

```text
SENSOR_DATA_UNAVAILABLE
PRELIMINARY_ELEVATED_READING
VALIDATED_ZONE_ALERT
ALERT_UPDATED
ALERT_CLEARED
```

A preliminary sensor reading must not be represented as a validated public-health conclusion. Public alert thresholds, averaging windows, forecast use, and terminology should be reviewed with the responsible local air-quality and public-health authorities.

### Accessible Alert Channels

At minimum, each zone should have multiple independent communication paths:

| Channel | Privacy property | Accessibility value |
|---|---|---|
| Public displays | No individual enrollment or tracking | Reaches libraries, transit stops, community centers, cooling spaces, and public facilities |
| Radio and broadcast partners | No device requirement | Reaches people during outages, travel, and low-connectivity periods |
| SMS opt-in | Voluntary contact method | Short, timely text; must support easy opt-out and avoid health inference |
| Accessible web dashboard | No login requirement | Supports screen readers, keyboard navigation, contrast controls, languages, and plain text |
| Printed notices | No device or internet requirement | Useful at hubs, shelters, clinics, libraries, and community locations |
| Community organizations | Consent-based outreach | Supports trusted messengers and formats chosen by communities |
| Telephone or relay information line | No smartphone requirement | Supports people who prefer voice, relay, or human assistance |

WCAG 2.2 provides a current W3C accessibility baseline for web dashboards and alert pages, including keyboard accessibility and understandable interaction design. [83][86]

### Coverage Metric

Let:

- \(V_z\) be the estimated vulnerable population in zone \(z\), derived only from aggregate planning data.
- \(R_z(t)\) be the estimated number reached by at least one accessible alert channel by time \(t\).
- \(t_0\) be the alert-validation time.

The 30-minute coverage estimate is:

\[
\operatorname{Coverage}_{30} =
\frac{\sum_z R_z(t_0 + 30\text{ min})}
{\sum_z V_z}
\times 100
\]

The operational target is:

\[
\operatorname{Coverage}_{30} \geq 95\%
\]

Coverage must be treated as an estimate with uncertainty. It should not be calculated from individual read receipts, advertising identifiers, geofenced device pings, or health records.

A privacy-preserving coverage model may combine:

- Public-display operating status.
- Radio or broadcast service-area estimates.
- Aggregate opt-in SMS delivery success counts without content profiling.
- Community-partner distribution reports.
- Print-distribution counts.
- Aggregate survey results collected voluntarily and separated from alert-delivery systems.

## Public Audit and Retention

### Water audit event

```json
{
  "event_type": "water_anomaly_process_summary",
  "event_time": "2026-09-01T00:00:00Z",
  "zone_id": "public_water_zone",
  "state": "maintenance_review_requested",
  "sensor_health": "nominal",
  "raw_readings_retained_centrally": false,
  "exact_location_retained_in_public_log": false,
  "individual_data_present": false,
  "retention_class": "aggregate_limited"
}
```

### Air-alert audit event

```json
{
  "event_type": "air_quality_zone_alert",
  "event_time": "2026-09-01T00:00:00Z",
  "zone_id": "public_alert_zone",
  "state": "validated_zone_alert",
  "channels_enabled": [
    "public_display",
    "radio",
    "accessible_web",
    "opt_in_sms"
  ],
  "individual_health_data_present": false,
  "individual_tracking_present": false,
  "retention_class": "aggregate_limited"
}
```

Audit logs SHALL exclude exact sensor locations in public releases, recipients, phone numbers, names, health records, inferred conditions, device identifiers, advertising identifiers, precise mobility traces, cybernetic-host status, augmentation information, and reputation fields.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.88 | Uses established water-quality parameters, local multivariate anomaly detection, federated-learning architecture, and public PM2.5 alert design |
| eco_impact_value | 0.82 | Enables earlier maintenance, reduces avoidable water loss and unnecessary truck rolls, and supports informed pollution-exposure reduction |
| harm_risk | 0.33 | Sensor drift, false reassurance, false alarms, and uneven communication coverage remain material; confirmation gates and redundant channels reduce risk |
| accessibility_impact | 0.95 | Provides public displays, print, radio, accessible web, voluntary SMS, relay-compatible pathways, and no-device access |
| rights_alignment | 0.96 | Enforces data minimization, purpose limitation, no individual health profiling, local processing, accessible information, and accountable review |
