# Private Acoustic Wildlife Monitoring and Citywide Digital Inclusion

## Purpose

This specification defines:

1. A passive acoustic monitoring system for birds and bats in urban green corridors that protects human privacy by preventing retention of conversations and other human-origin audio.
2. A citywide digital-inclusion index that combines aggregate measures of internet access, device access, digital-skills support, and accessibility of public digital services.

These systems support ecological stewardship and equitable public investment. They do not identify, rank, profile, score, track, or determine the worth of individual people, households, wildlife observers, visitors, residents, neighborhoods, cybernetic hosts, assistive-technology users, or service participants.

## Shared Rights Baseline

The systems SHALL:

- Collect only data necessary for ecological monitoring or public digital-inclusion planning.
- Prohibit names, contact data, facial information, voiceprints, speech transcripts, raw human conversation, device identifiers, Wi-Fi/Bluetooth signals, identity records, health data, augmentation data, cybernetic-host status, financial data, and social or reputation scores.
- Operate locally where possible and transmit only privacy-filtered, aggregate, or validated ecological results.
- Publish data provenance, uncertainty, calibration status, model limitations, and correction routes.
- Provide accessible public reporting, plain-language summaries, screen-reader-compatible materials, print alternatives, telephone or relay access, public kiosks, and staff-assisted pathways where relevant.
- Treat all automated classifications as advisory.
- Require human ecological or public-service review before consequential habitat or investment actions.
- Avoid using environmental sensing as a pretext for surveillance, exclusion, displacement, or digital eligibility screening.

## Part One: Wildlife Corridor Monitoring

### Purpose Limitation

Passive acoustic monitors may support:

- Bird and bat activity observation.
- Seasonal activity patterns.
- Habitat-management review.
- Vegetation, water, lighting, and corridor-connectivity evaluation.
- Comparison of pre-intervention and post-intervention ecological conditions.
- Community-readable biodiversity summaries.

They shall not support:

- Recording human conversations.
- Speech recognition, transcription, language identification, emotion inference, speaker identification, or voiceprint creation.
- Person detection or location tracking.
- Law-enforcement, immigration, employment, tenancy, protest, or behavioral surveillance.
- Public identification of individual wildlife observers, nearby residents, or corridor visitors.
- A biodiversity “score” that is treated as proof of ecosystem health without ecological context.

Acoustic detections can indicate activity or potential presence. They cannot independently establish population size, breeding status, species residency, habitat quality, or biodiversity health.

### Edge Audio Privacy Filter

The preferred architecture performs audio analysis on the edge device before any persistent storage or transmission.

```text
microphone input
→ short volatile analysis frame
→ frequency and energy screening
→ probable human-speech detection
→ speech-frame discard
→ animal-call candidate extraction
→ edge species model
→ confidence and quality gate
→ aggregate ecological event summary
```

The device must never retain a raw audio buffer after the current analysis frame unless an explicit, separately governed ecological validation protocol authorizes a short, non-speech wildlife clip.

#### Human Speech Filtering

Human speech commonly contains substantial energy in approximately the 300 Hz to 3.4 kHz telephony band, but frequency alone is not sufficient for safe privacy protection because birds, bats, insects, machinery, wind, and speech can overlap.

Use a conservative multi-stage filter:

1. Apply a high-pass or band-pass stage appropriate to the target taxon.
2. Estimate speech-likelihood from spectral, temporal, harmonic, and voice-activity features.
3. Discard every frame classified as probable or uncertain speech.
4. Do not attempt to transcribe, identify, or otherwise interpret discarded speech.
5. Run species inference only on frames that pass the privacy filter.
6. Retain only a species-event summary by default.
7. Store raw clips only under a separately approved research protocol with strict non-speech verification, short retention, encryption, access control, and public notice.

For bird monitoring, the model may use a taxon-relevant frequency window such as:

\[
f_{\mathrm{bird,min}}
\leq
f
\leq
f_{\mathrm{bird,max}}
\]

For bat monitoring, use an ultrasonic-capable microphone and sampling rate appropriate to the local species and call frequencies. Any down-conversion or time-expansion process must occur locally and must preserve the same human-speech exclusion rule.

### Species Classification

An edge model may use a TensorFlow Lite-compatible classifier derived from a publicly documented architecture or a locally trained, validated model.

The model receives a spectrogram-like representation:

\[
X \in \mathbb{R}^{F \times T}
\]

where:

- \(F\) is frequency-bin count.
- \(T\) is time-frame count.
- \(X_{f,t}\) is energy or transformed signal value.

The classifier estimates:

\[
p(c \mid X)
\]

where \(c\) is a candidate species or taxonomic group.

A detection is emitted only when:

\[
p(c \mid X)
\geq
\tau_c
\]

and:

\[
q_{\mathrm{audio}}
\geq
\tau_q
\]

where \(q_{\mathrm{audio}}\) is a quality estimate accounting for wind, rain, clipping, mechanical noise, overlapping calls, and microphone health.

Recommended event output:

```json
{
  "event_type": "wildlife_acoustic_detection_summary",
  "corridor_zone": "coarsened_green_corridor_zone",
  "time_window": "daily_or_weekly",
  "taxon_group": "bird_or_bat",
  "species_or_group_label": "validated_label",
  "detection_confidence_bucket": "high",
  "audio_quality_state": "valid",
  "probable_speech_frame_retained": false,
  "raw_audio_retained": false,
  "human_identity_data_present": false,
  "device_identifier_present": false,
  "model_version": "semantic_version"
}
```

### Validation Requirements

The monitoring program must validate:

- Microphone frequency response and calibration.
- Wind, rain, insect, traffic, construction, aircraft, and irrigation noise effects.
- Day/night variation.
- Species-call overlap.
- Seasonal migration and breeding-period variation.
- Model performance in the local bioregion.
- Human-speech false-pass rate.
- Animal-call false-discard rate.
- Edge inference latency, energy use, and storage behavior.
- The absence of raw speech, transcripts, voiceprints, and audio-exfiltration paths.

The project’s existing ecological-monitoring direction supports edge-based bird-call classification while explicitly stating that acoustic detections must not become a tool for recording or profiling people. [20]

### Chao1 Species-Richness Estimator

Let:

- \(S_{\mathrm{obs}}\) be the observed number of species or validated taxonomic groups.
- \(F_1\) be the number of singleton detections.
- \(F_2\) be the number of doubleton detections.

The Chao1 estimator is:

\[
\hat{S}_{\mathrm{Chao1}} =
S_{\mathrm{obs}} +
\frac{F_1^2}{2F_2}
\]

when:

\[
F_2 > 0
\]

When \(F_2 = 0\), use a bias-corrected form:

\[
\hat{S}_{\mathrm{Chao1}} =
S_{\mathrm{obs}} +
\frac{F_1(F_1-1)}{2}
\]

Chao1 is an estimate of undetected richness based on rare observed taxa. It is sensitive to survey effort, detection probability, classification quality, seasonal timing, habitat accessibility, and microphone placement. It must be reported with sampling effort and uncertainty, not as a definitive biodiversity count.

### Habitat-Management Use

Potential uses of aggregate acoustic indicators include:

- Comparing activity before and after native planting, shade expansion, water restoration, lighting changes, or corridor repair.
- Identifying time windows for quieter maintenance operations.
- Evaluating whether ecological lighting design reduces disturbance.
- Prioritizing vegetation, water, and habitat connectivity improvements.
- Detecting a need for ecological field verification.

The system must not use a low detection count to justify removal of public green-space access, accessible routes, public safety lighting, water access, or community participation.

## Part Two: Citywide Digital Inclusion Index

### Purpose

The Digital Inclusion Index measures whether people in an area can reasonably access essential digital public information and services through multiple accessible pathways.

The index guides investment in:

- Public Wi-Fi.
- Public-access terminals and community hubs.
- Device lending, repair, and replacement programs.
- Digital navigator staffing.
- Accessible government websites and forms.
- Translation, plain-language, relay, phone, paper, and kiosk access.
- Offline public information packages.
- Training and community support.

It shall not be used to rank individual residents, decide who deserves access, reduce non-digital services, infer technological competence, infer cybernetic-host status, infer disability, determine eligibility, or reward neighborhoods based on wealth or participation volume.

### Data Sources

Permitted aggregate sources include:

| Source | Permitted use | Privacy safeguard |
|---|---|---|
| Census and American Community Survey aggregates | Household computer and internet access patterns at published geographic level | Use published aggregates; do not construct household profiles |
| NTIA and Census digital-equity resources | Broadband availability, use, device-access, and digital-equity planning context | Use published totals and documented data vintage |
| Voluntary, aggregate community surveys | Digital-skills support needs, language and format barriers, service awareness | No name or device identifier required; suppress small cells |
| Public Wi-Fi aggregate operations | Access-point health, anonymous capacity, essential-service capacity availability | No MAC, browsing, DNS, or device history |
| Public kiosk and hub metrics | Uptime, accessible-workstation availability, print-form availability, staff-support hours | No search history or person-level session record |
| Website and form accessibility audits | Keyboard, screen-reader, contrast, language, error-message, and offline compatibility results | Technical service audit only |
| Digital navigator program records | Aggregate appointment availability, service hours, materials distributed, unresolved access barriers | Do not create participant profiles |
| Community review | Reported access barriers, correction requests, lived-experience feedback | Anonymous, phone, paper, kiosk, and staff-assisted options |

The Census Bureau's Digital Equity Act Population Viewer includes measures such as lack of computer or broadband access and non-use of internet, computer, or tablet technology. [319] NTIA's Computer and Internet Use Survey provides national-level context on household internet and device access, online use, and barriers, while digital-inclusion research notes that digital-skills needs often require carefully interpreted survey and support-program evidence rather than a single authoritative dataset. [321][329]

### Component Construction

For planning zone \(z\), define normalized components from zero through one:

- \(A_{\mathrm{internet},z}\): accessible, affordable, reliable connection availability.
- \(A_{\mathrm{device},z}\): availability of suitable devices, public terminals, device lending, repair, and alternatives.
- \(A_{\mathrm{literacy},z}\): availability of digital navigation, plain-language information, multilingual support, and skill-building assistance.
- \(A_{\mathrm{accessibility},z}\): accessibility of public portals, kiosks, forms, phone/relay, paper, staff, and offline pathways.

The baseline index is:

\[
DI_z =
\frac{1}{4}
\left(
A_{\mathrm{internet},z}
+
A_{\mathrm{device},z}
+
A_{\mathrm{literacy},z}
+
A_{\mathrm{accessibility},z}
\right)
\]

The components must be published individually. A single composite score must never hide a severe failure in accessibility or essential-service alternatives.

### Essential-Service Floor

For essential public-service access, each component must meet a defined minimum floor:

\[
A_{\mathrm{internet},z}
\geq
a_{\min}
\]

\[
A_{\mathrm{device},z}
\geq
d_{\min}
\]

\[
A_{\mathrm{literacy},z}
\geq
l_{\min}
\]

\[
A_{\mathrm{accessibility},z}
\geq
x_{\min}
\]

If any essential-access component is below its floor, the zone is marked:

```text
ESSENTIAL_ACCESS_GAP_REVIEW_REQUIRED
```

regardless of the total index value.

This prevents a high public Wi-Fi score from concealing a lack of accessible forms, a lack of paper/phone service, inaccessible kiosks, missing digital navigator support, or unavailable device access.

### Rights-Centered Weighting

An equal-weight baseline is useful for transparency:

\[
w_{\mathrm{internet}} =
w_{\mathrm{device}} =
w_{\mathrm{literacy}} =
w_{\mathrm{accessibility}} =
0.25
\]

A community may choose weights through an accessible public process, but the accessibility and essential-service pathway component should never fall below:

\[
w_{\mathrm{accessibility}}
\geq
0.25
\]

A weighted form is:

\[
DI_{w,z} =
w_I A_{\mathrm{internet},z}
+
w_D A_{\mathrm{device},z}
+
w_L A_{\mathrm{literacy},z}
+
w_A A_{\mathrm{accessibility},z}
\]

subject to:

\[
w_I+w_D+w_L+w_A=1
\]

\[
w_A \geq 0.25
\]

\[
w_I,w_D,w_L,w_A \geq 0
\]

### Investment Priority

The index should identify public-service gaps, not rank community worth.

Let:

- \(G_z = 1-DI_{w,z}\) be the digital-inclusion gap.
- \(P_z\) be aggregate population potentially affected.
- \(B_z\) be documented public-service barrier severity.
- \(U_z\) be uncertainty.
- \(D_z\) be displacement or exclusion risk.
- \(R_z\) be rights/accessibility risk.

A preliminary intervention priority can be:

\[
S_z =
0.45G_z +
0.30B_z +
0.15P_z +
0.10(1-U_z)
\]

subject to:

\[
D_z \leq D_{\max}
\]

\[
R_z \leq R_{\max}
\]

The score must not include income, property values, tax yield, commercial profitability, credit, rent, voting behavior, identity, health, disability, augmentation, cybernetic-host status, device identifier, app use, or public Wi-Fi session histories as a person-level ranking signal.

### Public Report

A public digital-inclusion report may include:

```json
{
  "event_type": "digital_inclusion_zone_summary",
  "planning_zone": "community_district",
  "time_window": "annual",
  "internet_access_component": 0.0,
  "device_access_component": 0.0,
  "digital_support_component": 0.0,
  "accessibility_component": 0.0,
  "digital_inclusion_index": 0.0,
  "essential_access_gap_review_required": false,
  "public_wifi_mac_addresses_retained": false,
  "public_wifi_browsing_history_retained": false,
  "kiosk_search_history_retained": false,
  "identity_or_health_data_used": false,
  "augmentation_or_cybernetic_host_data_used": false,
  "small_cell_suppression_applied": true,
  "community_review_status": "pending_or_complete",
  "retention_class": "aggregate_planning"
}
```

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.90 | Edge acoustic privacy filtering, species-richness estimation, aggregate digital-equity data, accessible public-service design, and hard essential-access floors |
| eco_impact_value | 0.86 | Supports habitat stewardship, lower-impact maintenance, biodiversity evidence, public Wi-Fi, repairable access infrastructure, and digital-navigation support |
| harm_risk | 0.31 | Acoustic false-pass risk, species-classification error, index oversimplification, and geographic stigma remain risks; edge filtering, uncertainty, component publication, and public review reduce harm |
| accessibility_impact | 0.99 | Supports non-digital alternatives, accessible public services, community hubs, kiosks, human assistance, and no-disclosure participation |
| rights_alignment | 0.99 | Enforces no speech surveillance, no identity inference, no user tracking, no digital ranking, essential-service alternatives, transparency, and community governance |
