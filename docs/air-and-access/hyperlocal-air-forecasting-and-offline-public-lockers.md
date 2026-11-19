# Hyperlocal Air Forecasting and Offline Public Lockers

## Purpose

This specification defines:

1. A neighborhood-level air-quality forecasting pipeline that uses fixed environmental sensors, meteorology, public land-use data, and aggregate traffic indicators without collecting individual vehicle, pedestrian, passenger, household, or device data.
2. A public-locker access system for essential goods that supports offline delivery and collection workflows without requiring a personal account, smartphone, app, biometric check, health disclosure, identity disclosure, or persistent user profile.

The systems are decision support and logistics tools. They do not determine a person's health, disability, identity, augmentation status, cybernetic-host status, service eligibility, credibility, income, household composition, or civic standing.

## Shared Rights Baseline

Both systems SHALL:

- Use local, aggregate, public, or fixed-infrastructure data.
- Avoid person tracking, vehicle tracking, phone tracking, Wi-Fi/Bluetooth collection, facial recognition, biometric collection, and persistent behavioral profiles.
- Provide clear uncertainty, status, failure, and human-support information.
- Retain only the minimum operational records needed for safety, repair, delivery confirmation, audit, and lawful records obligations.
- Support accessible non-digital alternatives for any essential-goods workflow.
- Avoid social scoring, financial ranking, service-priority ranking, property-value ranking, identity-based eligibility, or participation-frequency preference.
- Require human review for consequential exceptions, physical safety states, public alerts, and access failures.
- Use signed firmware, secure update channels, diagnosable fault states, repair-first maintenance, and offline-safe fallback operation.

## Part One: Neighborhood-Level Air Forecasting

### Permitted Data Sources

The forecasting system may use:

- Fixed low-cost air-quality sensors.
- Fixed reference-grade monitoring stations.
- Fixed weather stations.
- Public meteorological data.
- Public land-use, road-network, topography, vegetation, and building-form data.
- Aggregate road-segment traffic volume or publicly published traffic flow statistics.
- Fixed infrastructure conditions such as road closures, construction zones, wildfire-smoke conditions, and transit disruptions.
- Public emissions inventories where available.
- Time-of-day, day-of-week, seasonal, and weather variables.

The system SHALL NOT use:

- Individual vehicle GPS traces.
- License-plate data.
- Connected-vehicle identifiers.
- Mobile-phone locations.
- Wi-Fi or Bluetooth probe requests.
- Advertising identifiers.
- Individual commute histories.
- Personal health information, respiratory conditions, disability information, augmentation information, or cybernetic-host declarations.
- Household address data as a model target.
- Device identifiers or app usage patterns.

### Modeling Architecture

Use a staged hybrid model:

```text
sensor quality control
→ reference-station collocation and calibration
→ meteorology and land-use feature construction
→ land-use regression baseline
→ spatial residual interpolation
→ uncertainty estimation
→ aggregate zone forecast
→ public information and maintenance review
```

The model should provide a forecast at coarsened street-corridor or planning-zone resolution only where the sensor density, calibration quality, and uncertainty support that resolution.

### Land-Use Regression

For location \(s\) and time \(t\), let:

- \(Y(s,t)\): observed or predicted pollutant concentration.
- \(X_k(s,t)\): public environmental feature \(k\).
- \(\beta_k\): fitted coefficient.
- \(\varepsilon(s,t)\): residual error.

\[
Y(s,t) =
\beta_0 +
\sum_{k=1}^{p}
\beta_k X_k(s,t)
+
\varepsilon(s,t)
\]

Useful features include:

```text
wind_speed
wind_direction_components
air_temperature
relative_humidity
boundary_layer_proxy
road_length_by_class
aggregate_traffic_volume
distance_to_major_road
tree_canopy_fraction
impervious_surface_fraction
building_density
elevation
day_of_week
hour_of_day
regional_background_concentration
```

Land-use regression provides an interpretable baseline. Coefficients should be published with feature definitions, source dates, geographic resolution, calibration conditions, and uncertainty limitations.

### Spatial Residual Interpolation

Let:

- \(\hat{Y}_{LUR}(s,t)\) be the land-use regression estimate.
- \(r_i(t)\) be the residual at calibrated sensor location \(s_i\).
- \(w_i(s)\) be kriging weights for prediction location \(s\).
- \(\hat{r}(s,t)\) be the interpolated residual.

\[
r_i(t) =
Y(s_i,t) -
\hat{Y}_{LUR}(s_i,t)
\]

\[
\hat{r}(s,t) =
\sum_{i=1}^{n}
w_i(s)r_i(t)
\]

The hybrid prediction is:

\[
\hat{Y}(s,t) =
\hat{Y}_{LUR}(s,t) +
\hat{r}(s,t)
\]

Ordinary kriging chooses weights that minimize prediction variance subject to unbiasedness:

\[
\min_{w_1,\ldots,w_n}
\operatorname{Var}
\left[
Y(s) -
\sum_{i=1}^{n}w_iY(s_i)
\right]
\]

subject to:

\[
\sum_{i=1}^{n} w_i = 1
\]

The corresponding kriging variance must be published or used to suppress overconfident fine-resolution output:

\[
\sigma_K^2(s) =
\operatorname{Var}
\left[
Y(s) -
\hat{Y}(s)
\right]
\]

The system should not publish a high-resolution prediction where uncertainty exceeds a community-approved threshold.

### Gaussian-Process Alternative

A Gaussian process is suitable when uncertainty estimation and nonlinear spatial relationships are important.

\[
Y(s,t) \sim \mathcal{GP}
\left(
m(s,t),
k((s,t),(s',t'))
\right)
\]

A composite kernel can include spatial, temporal, and meteorological structure:

\[
k =
k_{\mathrm{space}} +
k_{\mathrm{time}} +
k_{\mathrm{meteorology}}
+
\sigma_n^2 I
\]

The model must document kernel selection, training window, validation geography, uncertainty calibration, and extrapolation boundaries.

### Low-Cost Sensor Calibration

Low-cost sensors require collocation against reference equipment before their measurements are used for quantitative modeling.

EPA guidance defines collocation as operating a low-cost sensor and reference monitor in the same place and time under real conditions, then comparing their readings to assess and improve sensor performance. EPA recommends placing sensor inlets near the reference inlet, often within approximately 10 meters and at similar height, without obstructed airflow. [307]

A calibration model can include meteorology:

\[
\hat{Y}_{\mathrm{reference},t} =
a +
b_1Y_{\mathrm{sensor},t} +
b_2T_t +
b_3RH_t +
b_4Y_{\mathrm{sensor},t}RH_t
\]

where:

- \(Y_{\mathrm{sensor},t}\) is the raw low-cost-sensor value.
- \(T_t\) is air temperature.
- \(RH_t\) is relative humidity.
- \(\hat{Y}_{\mathrm{reference},t}\) is the corrected estimate.

Calibration requirements:

- Conduct collocation before deployment.
- Use multiple sensor units where resources allow.
- Capture representative environmental conditions.
- Test sensor-to-sensor reproducibility.
- Validate against a held-out time period.
- Recalibrate after sensor repair, relocation, major seasonal transition, persistent residual drift, or firmware change.
- Mark sensors `UNDER_REVIEW` when calibration evidence is missing, stale, or failed.

Regular in-season calibration can materially improve low-cost sensor validity; recent evaluation work highlights the value of repeated calibration cycles using high-quality reference data. [314][318]

### Dominant Error Sources

| Error source | Effect | Required control |
|---|---|---|
| Sensor drift | Long-term concentration bias | Collocation, residual monitoring, recalibration |
| Humidity and temperature cross-sensitivity | Pollutant misestimation | Environmental covariates and humidity-aware calibration |
| Sensor placement | Nonrepresentative local conditions | Documented siting, inlet height, obstruction review |
| Sparse network | Overconfident interpolation gaps | Kriging variance, coarser output, uncertainty map |
| Traffic proxy error | Biased roadside estimates | Aggregate public data, feature validation, sensitivity analysis |
| Temporal mismatch | Incorrect sensor/reference or weather alignment | Clock health, synchronized aggregation windows |
| Wildfire smoke and unusual emissions | Model extrapolation failure | Event flags, regional background inputs, manual review |
| Construction and changing street geometry | Stale land-use features | Versioned public infrastructure updates |
| Missing data | Artificially smooth outputs | Explicit missingness state and fallback to coarser regional information |

### Forecast Quality

For observed concentration \(Y_i\) and predicted concentration \(\hat{Y}_i\):

\[
MAE =
\frac{1}{N}
\sum_{i=1}^{N}
|Y_i-\hat{Y}_i|
\]

\[
RMSE =
\sqrt{
\frac{1}{N}
\sum_{i=1}^{N}
(Y_i-\hat{Y}_i)^2
}
\]

For probabilistic intervals \([L_i,U_i]\), empirical interval coverage is:

\[
Coverage =
\frac{
\sum_{i=1}^{N}
\mathbb{1}
[L_i \leq Y_i \leq U_i]
}{
N
}
\]

The forecast service shall report errors by pollutant, season, weather pattern, time of day, land-use context, sensor density, and prediction uncertainty band.

## Part Two: Offline Public Lockers

### Essential-Goods Non-Denial Rule

Public lockers may supplement delivery access for food, medicine, assistive devices, hygiene goods, documents, and other goods. They must not become the only route to essential goods.

Every locker program handling essential goods SHALL also provide at least one accessible alternative:

- Staff-assisted collection.
- In-person counter pickup.
- Paper pickup notice.
- Telephone or relay-supported code retrieval.
- Accessible delivery coordination.
- Community hub pickup.
- Authorized support-person pickup with the recipient's chosen process.
- Human exception and escalation pathway.

No person may be denied an essential good because they do not have a phone, app, account, payment method, internet access, Bluetooth capability, biometric identifier, identity document, or live-server connection.

### Offline One-Time Code Model

The system uses a random, high-entropy one-time secret. The recipient receives the secret through a channel they choose, including paper, telephone/relay, staff-assisted communication, or an accessible printed receipt.

Let:

- \(K\) be a randomly generated one-time code secret.
- \(H\) be a cryptographic hash function.
- \(S\) be a locker-local random salt.
- \(E\) be expiry metadata.
- \(L\) be a locker compartment and delivery-record binding.

The locker stores only:

\[
V =
H(
\operatorname{domain}
\parallel
S
\parallel
K
\parallel
E
\parallel
L
)
\]

The recipient retains \(K\). The locker never needs to retain a recipient identity, phone number, email address, app account, VIN, payment tier, health record, augmentation data, or cybernetic-host status.

A submitted code is accepted only if:

\[
H(
\operatorname{domain}
\parallel
S
\parallel
K_{\mathrm{submitted}}
\parallel
E
\parallel
L
)
=
V
\]

and:

\[
t_{\mathrm{now}} \leq E
\]

and:

\[
\operatorname{state}(L) = \operatorname{READY}
\]

and:

\[
\operatorname{used}(L) = \operatorname{false}
\]

The comparison must use constant-time logic to reduce timing-leakage risk.

### Code Entropy

The required entropy is:

\[
H(K) \geq 80\ \mathrm{bits}
\]

A random code alphabet and length must satisfy:

\[
H(K) =
n\log_2(|\Sigma|)
\]

where:

- \(n\) is code length.
- \(|\Sigma|\) is alphabet size.

For example, a random 16-character code using a 32-character human-readable alphabet provides:

\[
16\log_2(32) =
80\ \mathrm{bits}
\]

Codes should avoid ambiguous characters where possible and should support an accessible spoken, printed, large-print, and staff-assisted representation.

NIST’s authentication guidance requires verifiers to generate random authentication secrets using approved random-bit generation, and describes one-time-password authenticators as a recognized authentication pattern. [305][308] The 80-bit requirement here is a stronger project-level target suited to a high-value offline collection secret.

### Offline Operation

Each locker controller maintains a local, signed manifest of active compartment records:

```text
compartment_reference
verifier_hash
salt
expiry_time
collection_state
attempt_counter
lockout_state
tamper_state
firmware_version
manifest_signature
```

The controller verifies the signed manifest before accepting a code. During a network outage, it can verify a submitted code locally without contacting a server.

The system must support:

```text
DELIVERY_PENDING
READY_FOR_COLLECTION
CODE_VERIFIED
ACCESS_OPEN
COLLECTION_CONFIRMED
CODE_EXPIRED
ATTEMPT_LIMIT_REVIEW
TAMPER_REVIEW_REQUIRED
OFFLINE_LOCAL_OPERATION
NETWORK_SYNC_PENDING
HUMAN_ASSISTANCE_REQUIRED
```

A network outage must not erase ready compartment records or invalidate already issued codes. On restoration, the controller sends an aggregate, privacy-minimized reconciliation result without recipient identity.

### Brute-Force Protections

The controller should enforce:

- Cryptographically secure code generation.
- Rate limits per physical keypad session and compartment state.
- Increasing delay after failed attempts.
- A bounded attempt count followed by staff review rather than permanent denial.
- Tamper detection for enclosure opening, lock state, power loss, key switch, and controller enclosure access.
- Signed firmware and configuration.
- Hardware-backed or protected key storage where appropriate.
- Secure boot and rollback protection where hardware supports it.
- A manual accessible override process requiring authorized staff and documented chain of custody.
- No display of recipient name or private goods description on public screens.

The locker must never show whether a code corresponds to medicine, food, assistive equipment, or another sensitive category.

### Tamper-Evident Hardware

Recommended hardware baseline:

| Component | Required control |
|---|---|
| Compartment door | Mechanical anti-pry design, monitored latch state, safe manual release procedure |
| Controller enclosure | Tamper switch, locked service access, sealed wiring routes |
| Key material | Protected local storage, key rotation, no plaintext code storage |
| Firmware | Signed update verification, rollback protection, documented update provenance |
| Power | Battery-backed graceful shutdown, power-loss audit state, manual service fallback |
| Network | Mutually authenticated update channel, no public network dependency for local code verification |
| User interface | Accessible keypad, tactile orientation, screen-reader/audio option where feasible, large-print instruction, physical help request |
| Environmental controls | Temperature and moisture sensing for device reliability, not user monitoring |
| Audit | Compartment and security state only; no recipient identity or goods category in public log |

### Locker Audit Summary

```json
{
  "event_type": "public_locker_operational_summary",
  "time_window": "daily",
  "locker_zone": "community_access_zone",
  "offline_local_verification_available": true,
  "one_time_code_entropy_bits": 80,
  "active_compartments_bucket": "10_to_19",
  "tamper_review_required": false,
  "staff_assisted_alternative_available": true,
  "recipient_identity_required": false,
  "smartphone_required": false,
  "network_required_for_collection": false,
  "health_or_augmentation_data_collected": false,
  "goods_category_retained_in_public_audit": false,
  "retention_class": "aggregate_operational_limited"
}
```

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.92 | Hybrid land-use and kriging modeling, reference-station calibration, uncertainty reporting, offline cryptographic verification, and tamper-aware physical access design |
| eco_impact_value | 0.87 | Supports actionable air-quality planning, reduces failed delivery trips, strengthens food and assistive-goods access, and supports efficient repair-first operations |
| harm_risk | 0.34 | Forecast error, low-cost sensor drift, code loss, hardware tampering, and delivery-access failures remain material risks; calibration, uncertainty, local verification, and human alternatives reduce exposure |
| accessibility_impact | 0.99 | Provides public air information without tracking and essential-goods collection without smartphones, apps, accounts, identity disclosure, or continuous connectivity |
| rights_alignment | 0.99 | Enforces aggregate sensing, anti-surveillance controls, no social scoring, offline resilience, privacy-preserving audit, accessible fallback, and essential-service non-denial |
