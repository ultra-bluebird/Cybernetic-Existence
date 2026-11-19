# Private Human Review Support and Untracked Transit Information

## Purpose

This specification defines:

1. A decision-support system for human reviewers handling appeals, corrections, and complex city-service requests while minimizing unnecessary sensitive-data exposure.
2. A real-time transit-information system that uses vehicle telemetry, fixed route data, and fixed infrastructure data without tracking passengers or requiring app use.

These systems are decision support and public information tools. They do not determine a person's identity, disability, health status, augmentation status, cybernetic-host status, credibility, service eligibility, legal outcome, or civic standing.

## Shared Rights Baseline

Both systems SHALL:

- Use the minimum information necessary for the stated public purpose.
- Require no personal device, application installation, account, location sharing, Bluetooth, Wi-Fi, or identity disclosure for baseline public information or appeal access.
- Maintain accessible human review, correction, appeal, and non-digital paths.
- Avoid social scoring, financial ranking, participation ranking, behavioral profiling, and identity-based service differentiation.
- Publish accessible explanations of system status, uncertainty, limitations, and correction routes.
- Use role separation, encryption, limited retention, and auditable access controls.
- Treat automated analysis as advisory; humans retain responsibility for consequential decisions.
- Preserve operations during upstream-network outages through signed local packages, cached data, and physical information channels where feasible.

## Part One: Human Review Decision Support

### Review Architecture

The system keeps source material, redaction processing, and reviewer-facing packets separate.

```text
Controlled source record
→ candidate sensitive-entity detection
→ structured and free-text redaction proposal
→ source-visible verification
→ minimum-necessary reviewer packet
→ human decision and explanation
→ appeal, correction, and retention workflow
```

A reviewer receives the contextual facts needed for a fair decision but does not receive unnecessary direct identifiers or sensitive records.

### Data Classes

| Data class | Reviewer visibility | Handling rule |
|---|---|---|
| Service decision, request text, submitted dates, stated remedy | Visible when necessary | Preserve decision-relevant context |
| Direct identifier | Hidden by default | Reveal only under documented necessity and authorized role |
| Contact information | Hidden by default | Separate contact-routing role from merits review |
| Health or disability record | Hidden by default | Do not reveal unless strictly necessary, authorized, and separately explained |
| Augmentation, cybernetic-host, implant, assistive-device, or neural information | Hidden by default | Never use as a credibility or eligibility signal |
| Self-asserted identity | Hidden unless directly relevant to requested communication accommodation | Respectful handling without adjudicating identity |
| Financial, property, or payment data | Hidden by default | Never treat as a measure of civic worth or credibility |
| Free-text explanation | Visible after sensitive-token review | Preserve relevant narrative, redact unnecessary sensitive details |
| Prior case outcome | Limited and purpose-bound | Use only when lawfully necessary; do not create a reputation profile |

### Redaction Principles

The system must distinguish:

- Direct identifiers: names, personal contact information, account numbers, identity documents, device identifiers, exact home location, signatures, and unique reference numbers.
- Sensitive attributes: health, disability, biometric, neural, augmentation, assistive-technology, identity, immigration, financial, or legal information.
- Quasi-identifiers: precise dates, rare combinations, small geographic areas, unusual events, or unique circumstances that could enable re-identification.
- Decision-relevant context: service type, claimed error, timeline, requested remedy, factual basis, evidence description, and accessibility need stated at a functional level.

Automatic redaction can propose removals, but it must not be the final authority. NIST's government de-identification guidance emphasizes governance, risk evaluation, and formal privacy methods rather than assuming identifiers alone solve re-identification risk. [278][279] HHS similarly cautions that a de-identified record can become distinguishable through codes, algorithms, or pseudonyms if re-identification mechanisms are not tightly controlled. [277]

### Redaction Metrics

Let:

- \(S\) be the number of sensitive tokens in a source document.
- \(R_S\) be sensitive tokens correctly removed.
- \(K\) be context tokens necessary for a fair review.
- \(L_K\) be necessary context tokens incorrectly removed.

Sensitive-token recall is:

\[
\operatorname{SensitiveRemovalRecall} =
\frac{R_S}{S}
\]

Context-loss rate is:

\[
\operatorname{ContextLossRate} =
\frac{L_K}{K}
\]

The research targets are:

\[
\operatorname{SensitiveRemovalRecall} > 99\%
\]

\[
\operatorname{ContextLossRate} < 5\%
\]

These are evaluation targets, not guarantees that a single automated system can safely redact every document. Metrics must be stratified by document type, language, handwriting/transcription quality, scanned versus born-digital form, and sensitive entity category.

### Redaction Workflow

1. Validate document type, source integrity, language, and page completeness.
2. Detect candidate sensitive entities using structured rules, dictionaries, named-entity recognition, pattern recognition, and context-aware models.
3. Replace candidates with typed placeholders, not empty deletions, such as:

```text
[PERSON_NAME_REDACTED]
[CONTACT_DETAIL_REDACTED]
[ACCOUNT_REFERENCE_REDACTED]
[HEALTH_DETAIL_REDACTED]
[ASSISTIVE_TECHNOLOGY_DETAIL_REDACTED]
[PRECISE_LOCATION_REDACTED]
```

4. Preserve the relationship between evidence and claim without exposing the sensitive value.
5. Run a context-preservation check for dates, requested remedies, service category, chronology, and decision rationale.
6. Require trained human verification before a reviewer packet is released in a consequential appeal or correction case.
7. Route the original source record only to authorized custodians under role-based access controls.
8. Provide an accessible correction channel where the person can identify a missing or wrongly redacted fact.
9. Retain access logs and review state, not unnecessary document copies.

### Blinded Review

Blinding is appropriate when protected or sensitive details are not necessary to decide the merits of a request.

A reviewer should generally receive:

- The service decision or action being challenged.
- The stated factual error, barrier, delay, or requested correction.
- Relevant dates and procedural deadlines.
- Non-sensitive supporting evidence.
- Applicable public policy or service rule.
- A functional accessibility requirement where needed to conduct the review fairly.
- A summary of redactions and the mechanism for requesting narrowly justified additional context.

A reviewer should not normally receive:

- Name, precise address, contact information, identity documents, account identifiers, or device identifiers.
- Health, disability, implant, augmentation, cybernetic-host, neural, or assistive-device information.
- Wealth, property, payment, or credit information.
- Prior complaint frequency, reputation information, participation record, social-media data, or inferred behavioral profile.

A blinded review must not hide facts that are necessary to prevent unfairness. The system should therefore support a documented, narrowly scoped “additional context request” reviewed by a privacy steward rather than allowing unrestricted access to source records.

### Bias Mitigation

Required safeguards:

- Blind reviewers to unnecessary direct and sensitive identifiers.
- Use standardized decision rubrics linked to public policy and service criteria.
- Require plain-language reasons for decisions.
- Use independent second review for denials, reversals, or other high-impact outcomes.
- Separate contact management, document custody, redaction review, and merits decision roles.
- Randomly sample completed cases for procedural-consistency audit.
- Monitor aggregate disparities by process channel, request type, language format, accessibility format, and resolution time without profiling individual people.
- Permit correction and appeal when redaction caused context loss.
- Prohibit predictive risk scoring, credibility scoring, social ranking, and identity inference.
- Review model updates with synthetic and de-identified test fixtures before deployment.

### Reviewer Packet

```json
{
  "case_reference": "case_local_reference",
  "request_type": "appeal",
  "service_category": "public_service",
  "issue_summary": "Plain-language summary preserving decision-relevant context",
  "timeline": [
    "Event and submission milestones"
  ],
  "requested_remedy": "Correction, reconsideration, explanation, or other requested action",
  "evidence_summary": "Source-linked, redacted factual summary",
  "redaction_summary": {
    "direct_identifiers_removed": true,
    "health_or_identity_details_removed": true,
    "augmentation_or_assistive_details_removed": true,
    "context_verification_complete": true
  },
  "review_standard_version": "1.0.0",
  "additional_context_request_available": true,
  "appeal_path_available": true
}
```

The reviewer packet must not include original source documents by default. It must not contain direct identifier values, contact information, raw health records, augmentation details, account numbers, device information, or personal location history.

## Part Two: Transit Information Without Passenger Tracking

### Data Sources

Arrival predictions use only:

- Vehicle GPS positions.
- Vehicle speed and heading.
- Trip and stop sequence from scheduled GTFS data.
- Vehicle-reported delay or schedule deviation.
- Fixed route geometry.
- Fixed stop location.
- Fixed intersection, road-closure, weather, construction, and traffic-condition data where lawfully available.
- Transit operations events, such as detours, disabled vehicles, block changes, or route suspensions.

The system SHALL NOT use:

- Passenger smartphone GPS.
- App location permissions.
- Wi-Fi probe requests.
- Bluetooth observations.
- Cellular identifiers.
- Fare-card identity or boarding history.
- Device MAC addresses.
- Browser identifiers.
- Camera-based passenger tracking.
- Individual trip history or rider profiles.

GTFS Realtime provides a standard mechanism for agencies to publish vehicle positions, trip updates, expected arrivals, and service alerts. [280][282]

### Arrival-Prediction Model

For vehicle \(v\), stop \(s\), and prediction time \(t\), define:

- \(d_{v,s,t}\): remaining route distance to the stop.
- \(\bar{u}_{r,\tau}\): expected route-segment speed for route segment \(r\) and time context \(\tau\).
- \(\delta_{v,t}\): current vehicle schedule deviation.
- \(h_{v,s,t}\): estimated dwell-time adjustment.
- \(q_{v,s,t}\): fixed-infrastructure or operational disruption adjustment.

The predicted time to arrival is:

\[
\widehat{ETA}_{v,s,t} =
\sum_{r \in \operatorname{path}(v,s)}
\frac{d_{r}}{\bar{u}_{r,\tau}}
+
\delta_{v,t}
+
h_{v,s,t}
+
q_{v,s,t}
\]

A practical implementation may use a hybrid method:

\[
\widehat{ETA} =
w_1\widehat{ETA}_{\mathrm{schedule}}
+
w_2\widehat{ETA}_{\mathrm{vehicle\ telemetry}}
+
w_3\widehat{ETA}_{\mathrm{route\ history}}
+
w_4\widehat{ETA}_{\mathrm{disruption}}
\]

with:

\[
\sum_{j=1}^{4}w_j = 1
\]

The weights must be trained and validated only from vehicle and fixed-infrastructure data. Passenger devices and app usage must not enter the model.

### Prediction Quality

For \(N\) validated predictions, let:

- \(a_i\) be actual arrival time.
- \(\hat{a}_i\) be predicted arrival time.

The mean absolute error is:

\[
MAE =
\frac{1}{N}
\sum_{i=1}^{N}
|a_i-\hat{a}_i|
\]

Define the proportion within one minute:

\[
P_{60} =
\frac{
\sum_{i=1}^{N}
\mathbb{1}
\left[
|a_i-\hat{a}_i|
<
60\ \mathrm{s}
\right]
}{
N
}
\]

The target is:

\[
P_{60} \geq 90\%
\]

and:

\[
MAE < 1\ \mathrm{minute}
\]

The system must publish performance by route, time of day, weather regime, disruption state, and service type. It must state when prediction confidence is low, vehicle telemetry is stale, detours are active, or a schedule-only estimate is being shown.

GTFS Realtime best practices recommend refreshing vehicle-position and trip-update information at least every 30 seconds, and recommend trip-update/vehicle-position data no older than 90 seconds. [284]

### Public Displays and Outage Fallback

Every high-use stop should support at least two information channels:

| Channel | Operating mode | Accessibility requirement |
|---|---|---|
| E-ink or low-power display | Cached latest arrival and alert snapshot | High contrast, large text, visible timestamp, plain-language outage state |
| Static printed schedule | Always available | Large-print and plain-language option where feasible |
| Tactile and readable stop marker | Always available | Clear route and stop identification |
| Public telephone or relay information | Central or local service | Accessible route and service-alert lookup |
| Accessible web page | Connected option | Keyboard, screen-reader, contrast, text-only, low-bandwidth support |
| Transit staff or hub assistance | Human fallback | Accessible explanation and route guidance |
| Local signed data cache | Network-loss operation | Shows last verified update and static schedule when live feed expires |

E-ink displays can support low-power or solar-supported transit information, including off-grid installations that reduce the need for new electrical construction. [288] Any display used for public transit must still provide non-visual, printed, human, and online-accessible alternatives. Product claims about particular display capabilities should be independently tested in the actual transit setting. [286]

### Outage States

```text
LIVE_VEHICLE_PREDICTION
STALE_VEHICLE_DATA
SCHEDULE_BASED_ESTIMATE
SERVICE_ALERT_ACTIVE
LOCAL_CACHE_ACTIVE
NETWORK_OUTAGE_STATIC_INFORMATION
DISPLAY_HARDWARE_FAULT
HUMAN_ASSISTANCE_AVAILABLE
```

When live data are unavailable:

1. Show the time of the last verified update.
2. Show the static scheduled service information.
3. Show current known service alerts from the last signed local cache.
4. Display a clear uncertainty notice.
5. Provide a phone, relay, printed, or staff-assisted information route.
6. Do not require a passenger app, account, device, or location permission.

## Privacy-Preserving Audit Records

### Review-system audit summary

```json
{
  "event_type": "human_review_packet_release",
  "time_window": "daily",
  "request_type": "appeal",
  "redaction_verification_complete": true,
  "direct_identifier_values_in_packet": false,
  "health_or_identity_details_in_packet": false,
  "augmentation_or_assistive_details_in_packet": false,
  "human_reviewer_assigned": true,
  "additional_context_request_available": true,
  "appeal_path_available": true,
  "retention_class": "case_limited"
}
```

### Transit-information audit summary

```json
{
  "event_type": "transit_information_quality_summary",
  "time_window": "hourly",
  "route_group": "public_route_group",
  "prediction_mode": "live_vehicle_prediction",
  "mae_seconds": 0.0,
  "predictions_within_60_seconds_fraction": 0.0,
  "vehicle_telemetry_age_seconds": 0.0,
  "passenger_device_data_used": false,
  "app_usage_required": false,
  "wifi_or_bluetooth_tracking_used": false,
  "fallback_display_available": true,
  "retention_class": "aggregate_operations_limited"
}
```

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.91 | NIST de-identification governance, source-preserving review workflows, GTFS Realtime data structures, vehicle-only ETA modeling, and outage-capable public information |
| eco_impact_value | 0.78 | Reduces unnecessary travel uncertainty, supports transit use, enables low-power public displays, and limits duplicate document handling |
| harm_risk | 0.32 | Redaction errors, biased review outcomes, inaccurate ETAs, and stale displays remain material risks; human verification, blinding, uncertainty notices, and non-digital fallback reduce exposure |
| accessibility_impact | 0.99 | Supports minimum-necessary appeal review, plain-language decisions, e-ink, print, phone, relay, kiosk, staff, and accessible web access |
| rights_alignment | 0.99 | Enforces privacy, non-discrimination, no user tracking, no scoring, human accountability, accessible correction, and public-service continuity |
