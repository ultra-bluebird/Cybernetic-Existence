# Cross-City Service and Maintenance Assurance

## Status and Scope

This document defines two research-to-implementation patterns:

1. A portable credential for essential-service accommodations, such as heat-safety cooling access.
2. A sensor-alignment and nondiscrimination assurance process for maintenance-bot perception.

It is a technical and governance proposal. It does not determine legal eligibility, medical status, institutional standing, public-service entitlement, or any person's identity. It must not be used to rank people, infer an undisclosed condition, control access to essential public services, or create a persistent cross-city tracking record.

## Shared Rights Baseline

Both systems SHALL:

- Minimize personal and sensitive data.
- Require no augmentation data, health diagnosis, biometric template, continuous location, external identity verification, or proprietary device.
- Provide an offline-accessible pathway and a human-accessible alternative.
- Offer plain-language explanations, correction, review, appeal, deletion, and export paths.
- Use purpose-limited audit records that do not contain raw personal claims or image/video streams.
- Separate decision support from physical actuation.
- Preserve an equivalent service path when a credential, device, network connection, or automated perception component is unavailable.

## Essential-Service Credential

### Functional Claim Model

A credential SHALL encode a functional accommodation rather than an underlying condition. The verifier receives only the claim required for the immediate service decision.

Example functional claim:

```json
{
  "@context": [
    "https://www.w3.org/ns/credentials/v2"
  ],
  "type": [
    "VerifiableCredential",
    "EssentialServiceAccommodationCredential"
  ],
  "validFrom": "2026-09-01T00:00:00Z",
  "validUntil": "2026-12-01T00:00:00Z",
  "credentialSubject": {
    "type": "EssentialServiceNeed",
    "service": "cooling_assistance",
    "activation": {
      "kind": "ambient_temperature_threshold",
      "operator": "greater_than",
      "value": 35,
      "unit": "degree_celsius"
    },
    "supportLevel": "standard_accommodation",
    "verificationMode": "offline_selective_disclosure"
  },
  "credentialStatus": {
    "type": "RevocationList2021Status"
  }
}
```

The credential SHALL NOT include:

- A diagnosis, impairment category, neural or augmentation data, genetic data, or treatment data.
- A legal name, street address, precise location history, citizenship status, income, account identifier, photograph, or biometric reference.
- A universal identifier visible to relying parties.
- A city-specific eligibility score or any social-ranking value.
- An assertion that a person must disclose a credential to receive an essential service.

### Minimal Disclosure

A cooling-site verifier may need only the following predicates:

- The holder presents a valid essential-service accommodation.
- The requested service is `cooling_assistance`.
- The threshold is active under locally measured or officially published ambient conditions.
- The credential has not expired and is not revoked.
- The credential is issued by an accepted public-interest issuer or a delegated trusted issuer.

The verifier does not need to learn:

- Why cooling is needed.
- Who the holder is.
- Which city issued the credential, unless required for issuer-trust verification.
- Whether the holder has used the service before.
- Whether the holder has other accommodations.

### Selective-Disclosure Protocol

A holder creates a derived presentation from a BBS-based credential. The presentation proves selected statements while omitting unrevealed credential attributes.

Let:

- \(C\) be the credential.
- \(M = (m_1, m_2, \ldots, m_n)\) be signed messages.
- \(D \subseteq M\) be the disclosed message set.
- \(H = M \setminus D\) be the hidden message set.
- \(\pi\) be a zero-knowledge derived proof.
- \(pk_I\) be the trusted issuer verification key.
- \(N_V\) be a verifier-generated nonce.
- \(A\) be verifier audience binding.
- \(t\) be presentation creation time.

The holder produces:

\[
P = \operatorname{DeriveProof}(C, D, H, N_V, A, t)
\]

The verifier accepts only when:

\[
\operatorname{Verify}(pk_I, P, N_V, A) = \text{true}
\]

and:

\[
t_{\text{now}} \leq \text{validUntil}
\]

and:

\[
\operatorname{StatusCheck}(C) \neq \text{revoked}
\]

and:

\[
\operatorname{ServiceMatch}(D, \text{requestedService}) = \text{true}
\]

and:

\[
\operatorname{ActivationSatisfied}(D, \text{localConditions}) = \text{true}
\]

The nonce and audience binding prevent a previously captured presentation from being replayed at another verifier.

### Offline Verification

Offline verification SHALL verify signature validity, disclosed claim semantics, presentation freshness, and a locally cached issuer trust bundle.

The verifier device SHALL maintain:

- A versioned trust bundle containing issuer public keys and policy metadata.
- A signed revocation/status snapshot with explicit `issuedAt` and `nextUpdate` fields.
- A local clock-health state.
- A maximum offline age configured by public-service governance.

Offline acceptance is permitted only if:

\[
\Delta_{\text{trust}} = t_{\text{now}} - t_{\text{trustBundleIssued}} \leq W_T
\]

\[
\Delta_{\text{status}} = t_{\text{now}} - t_{\text{statusSnapshotIssued}} \leq W_S
\]

\[
\Delta_{\text{presentation}} = t_{\text{now}} - t_{\text{presentation}} \leq W_P
\]

where \(W_T\), \(W_S\), and \(W_P\) are policy-configured maximum ages.

A stale revocation snapshot SHALL NOT result in automated service denial. The verifier SHALL enter `HUMAN_REVIEW_OR_EQUIVALENT_SERVICE_PATH`, display an accessible explanation, and avoid recording the presented credential.

### Performance Objective

The target is:

\[
T_{\text{verify}} =
T_{\text{parse}} +
T_{\text{signature}} +
T_{\text{status}} +
T_{\text{policy}}
< 500 \text{ ms}
\]

Performance testing SHALL report at least:

- Median verification time.
- 95th-percentile verification time.
- Device model and operating-system version.
- Credential and proof sizes.
- Trust-bundle and revocation-snapshot sizes.
- Offline versus connected verification results.
- Battery use per verification batch.

### Credential Lifecycle

- Issuance requires informed, specific consent and a non-digital alternative.
- The holder can export, revoke, and replace the credential.
- Issuers retain only the minimum issuance evidence required by applicable governance.
- Verifiers retain no credential payload by default.
- Audit events are aggregated and privacy-preserving.
- A holder may request accessible human review after denial, device failure, or verifier error.
- A service provider SHALL provide an equivalent route for people who do not use credentials.

## Maintenance-Bot Sensor Assurance

### Operating Boundary

This process evaluates perception quality and path-planning safety. It SHALL NOT:

- Identify, classify, rank, or track people by disability, health, race, gender, age, or augmentation status.
- Use demographic attributes as a live operational input.
- Infer disability or medical status from appearance, gait, mobility aids, behavior, or assistive technology.
- Authorize autonomous physical action from a fairness score.
- Replace site safety procedures, accessibility law, or trained human oversight.

The system may classify safety-relevant scene categories only to the extent necessary for conservative navigation, such as:

- `person_or_person_associated_space`
- `mobility_aid_associated_space`
- `service_animal_associated_space`
- `uncertain_dynamic_obstacle`
- `static_accessibility_infrastructure`

When uncertainty is high, the bot SHALL use conservative non-contact behavior, such as pausing, increasing clearance, requesting human review, or taking a pre-approved low-risk route.

### Dataset Requirements

The evaluation dataset SHALL be purpose-limited, consented where people are depicted, and governed by a documented data-use protocol.

Required scenario diversity includes:

- Manual and powered wheelchairs at varied angles, speeds, lighting conditions, and occlusion levels.
- Mobility scooters, walkers, canes, crutches, prosthetic limbs, and other assistive-device configurations.
- Service animals with handlers, harnesses, and diverse movement patterns.
- People standing, seated, transferring, turning, crossing, waiting, and using curb ramps.
- Mobility-aid-associated space, including turning radius and safe maneuvering envelope.
- Daylight, low light, glare, rain, dust, shadows, reflective surfaces, and construction contexts.
- Different clothing, body shapes, ages, heights, and skin-tone lighting conditions without treating protected characteristics as operational labels.
- Camera degradation, lidar sparsity, dirty lenses, vibration, clock drift, and partial sensor failure.
- Accessibility-critical infrastructure, including curb ramps, tactile paving, elevator approaches, bus stops, crossings, and doorway clearances.

The dataset SHALL document provenance, consent basis, annotations, known gaps, synthetic-data use, geographic transfer limits, and removal processes.

### Sensor Calibration

For corresponding lidar point \(X_i\) and image observation \(u_i\), with camera intrinsics \(K\), rotation \(R\), and translation \(t\):

\[
\hat{u}_i = \pi(K[R \mid t]X_i)
\]

The per-correspondence reprojection residual is:

\[
e_i = \left\|u_i - \hat{u}_i\right\|_2
\]

The root-mean-square reprojection error is:

\[
E_{\text{RMS}} =
\sqrt{
\frac{1}{N}
\sum_{i=1}^{N}
e_i^2
}
\]

The commissioning target is:

\[
E_{\text{RMS}} < 1.0 \text{ pixel}
\]

This target is necessary but not sufficient. A system may achieve low reprojection error while still failing under rain, glare, mobility-aid occlusion, timing misalignment, or unfamiliar environments.

Calibration SHALL include:

- Camera intrinsics and distortion estimation.
- Lidar-camera extrinsic estimation.
- Timestamp-offset estimation.
- Vibration and thermal-drift checks.
- Calibration target coverage across the full image field.
- Independent holdout validation.
- Periodic revalidation after impact, repair, sensor replacement, firmware changes, or detected drift.

### Nondiscrimination Evaluation

For group or scenario stratum \(g\), define:

\[
\operatorname{TPR}_g =
\frac{\operatorname{TP}_g}
{\operatorname{TP}_g + \operatorname{FN}_g}
\]

\[
\operatorname{FPR}_g =
\frac{\operatorname{FP}_g}
{\operatorname{FP}_g + \operatorname{TN}_g}
\]

A conservative equalized-odds gap is:

\[
\Delta_{\text{EO}} =
\max_{g,h}
\left(
\left|\operatorname{TPR}_g-\operatorname{TPR}_h\right|,
\left|\operatorname{FPR}_g-\operatorname{FPR}_h\right|
\right)
\]

The research target is:

\[
\Delta_{\text{EO}} < 0.05
\]

This metric SHALL be reported with confidence intervals, sample counts, operational context, and uncertainty. It SHALL NOT be treated as proof that the system is safe or nondiscriminatory.

Safety metrics must also include:

\[
\operatorname{MissRate}_g =
\frac{\operatorname{FN}_g}
{\operatorname{TP}_g+\operatorname{FN}_g}
\]

\[
\operatorname{ClearanceViolationRate}_g =
\frac{\text{unsafe proximity events}_g}
{\text{encounters}_g}
\]

\[
\operatorname{UnnecessaryStopRate}_g =
\frac{\text{unnecessary stops}_g}
{\text{encounters}_g}
\]

\[
\operatorname{HumanInterventionRate}_g =
\frac{\text{human safety interventions}_g}
{\text{operating hours}_g}
\]

The system SHALL investigate both unequal misses and unequal burden from excessive stops, detours, alarms, or requests for intervention.

### Path-Planning Assurance

For a dynamic object estimate \(o\), let \(d_{\min}(o)\) be the predicted minimum separation during the planning horizon. Let \(d_{\text{safe}}(o)\) be the larger of the configured human safety clearance and the uncertainty-expanded clearance.

\[
d_{\text{safe}}(o) =
d_{\text{base}} +
k_{\sigma}\sigma_o +
d_{\text{latency}}
\]

The bot may continue only when:

\[
d_{\min}(o) \geq d_{\text{safe}}(o)
\]

For uncertain detections or potential person-associated space, the planner SHALL set:

\[
\sigma_o \uparrow
\]

which increases required clearance. If safe continuation cannot be established, the bot SHALL transition to a non-contact safe state and request authorized human review.

### Test Gates

A release candidate SHALL be blocked from autonomous operation in the tested environment when any of the following are true:

- Reprojection error exceeds the calibrated acceptance threshold.
- Time synchronization exceeds the configured maximum skew.
- Any accessibility-relevant scenario has insufficient test coverage.
- Confidence intervals are too wide to support the asserted fairness threshold.
- Miss rate or clearance-violation rate exceeds the site safety limit.
- Equalized-odds gap exceeds 0.05.
- A critical regression occurs after sensor, model, route, mapping, firmware, or mechanical changes.
- The incident, appeal, or human-review workflow is unavailable.
- Data provenance or consent documentation is incomplete.

A block means the bot may not use the affected capability autonomously. It does not remove a person's access to public space or essential services.

## Governance and Audit

Audit data SHALL be minimized and segregated from raw credentials and raw perception data.

Recommended aggregate audit fields:

```json
{
  "eventType": "maintenance_perception_assurance",
  "eventTime": "2026-09-01T00:00:00Z",
  "systemVersion": "semantic-version",
  "calibrationStatus": "valid",
  "decisionMode": "advisory_or_safe_state",
  "scenarioFamily": "mobility_aid_associated_space",
  "metricSummary": {
    "reprojectionErrorRmsPx": 0.0,
    "equalizedOddsGap": 0.0,
    "clearanceViolationRate": 0.0
  },
  "reviewStatus": "pending_or_complete",
  "retentionClass": "aggregated_limited_retention"
}
```

No raw image, lidar cloud, subject identifier, credential content, medical information, or personal cybernetic/assistive-technology detail belongs in this audit event.

## Research Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.84 | Grounded in verifiable-credential architecture, offline cryptographic verification patterns, calibration mathematics, and documented AI-risk governance practices |
| eco_impact_value | 0.70 | Supports heat-safety access and reduces avoidable maintenance-bot detours, idling, incident response, and hardware replacement |
| harm_risk | 0.36 | Credential denial, stale-status handling, sensor misses, and automation misuse remain material risks; mitigated through equivalent service paths and human review |
| accessibility_impact | 0.94 | Centers functional accommodations, offline access, mobility-aid safety, clear explanations, and non-digital alternatives |
| rights_alignment | 0.95 | Enforces data minimization, revocable consent, purpose limitation, dignity, non-discrimination, appeal, and non-actuating safety controls |
