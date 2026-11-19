# Satellite Canopy Assessment and Fair Public EV Charging

## Purpose

This specification defines:

1. A public-imagery pipeline for assessing urban tree canopy, canopy-condition indicators, and land-surface heat patterns without collecting ground-level surveillance data.
2. A public EV charging load-balancing policy that shares available charging current fairly without driver identity, payment tiering, vehicle history, VIN retention, residential ranking, or behavioral profiling.

The systems provide planning and operational decision support. They do not determine a person's identity, property value, service eligibility, financial standing, health, disability, augmentation status, cybernetic-host status, or civic worth.

## Shared Rights Baseline

Both systems SHALL:

- Use the least intrusive data required for public environmental planning or safe charging operation.
- Avoid facial recognition, ground-level camera surveillance, mobile-device tracking, Bluetooth/Wi-Fi collection, vehicle VIN storage, license-plate recognition, payment-tier ranking, and user behavior profiles.
- Publish methods, model versions, uncertainty, calibration and validation status, and correction pathways.
- Preserve equal access regardless of identity, account type, payment method, vehicle brand, vehicle age, driver history, device ownership, disability, augmentation, or self-described cybernetic-host status.
- Use repairable infrastructure, signed updates, local diagnostics, rollback capability, and human review for safety-critical exceptions.
- Prohibit social, financial, property, reputation, or participation scoring.
- Treat automated outputs as bounded decision support rather than final public-policy determinations.

## Part One: Satellite Canopy and Heat Assessment

### Data Sources

The pipeline uses publicly available or publicly licensed remote-sensing sources such as:

- Landsat Collection 2 Level-2 surface reflectance and surface-temperature products.
- Public aerial imagery where licensing and privacy conditions permit.
- Public land-cover, parcel-independent street, park, and public-facility data.
- Fixed public environmental-sensor summaries.
- Public tree-inventory and park-maintenance data where available.
- Public weather and climate summaries.

It SHALL NOT use:

- Ground-level surveillance cameras.
- Doorbell, private-security, or personally operated cameras.
- Smartphone locations, Wi-Fi probe requests, Bluetooth observations, advertising identifiers, or social-media location traces.
- Individual household tree-maintenance records, water use, income, property value, insurance data, or personal data.
- Aerial imagery collected in ways that violate public commitments, applicable law, or community privacy expectations.

USGS describes Landsat surface-temperature products as remotely sensed land-surface temperature data used for landscape thermal conditions, hydrologic modeling, and surface-energy studies. [290] Landsat 8 and 9 TIRS instruments provide thermal-band observations used to derive surface temperature, with the Collection 2 Level-2 product providing surface reflectance, surface temperature, and quality bands. [291][295]

### Canopy Segmentation

Let an orthorectified imagery tile be:

\[
X \in \mathbb{R}^{H \times W \times B}
\]

where:

- \(H\) and \(W\) are raster height and width.
- \(B\) is the number of spectral, elevation, or derived feature bands.
- \(X_{i,j}\) is the feature vector at pixel \((i,j)\).

A segmentation model estimates the tree-canopy probability:

\[
\hat{y}_{i,j} =
f_{\theta}(X_{i,j})
\]

where:

\[
\hat{y}_{i,j} \in [0,1]
\]

A binary canopy mask uses a documented threshold \(\tau\):

\[
M_{i,j} =
\begin{cases}
1 & \text{if } \hat{y}_{i,j} \geq \tau \\
0 & \text{otherwise}
\end{cases}
\]

A U-Net or related encoder-decoder segmentation architecture is an appropriate baseline for tree-canopy extraction because it combines multi-scale contextual features with pixel-level output. With limited labeled data, use transfer learning, geographically separated validation, active-error review, augmentation that reflects sensor conditions, and uncertainty estimation rather than overclaiming generalization.

Recommended model-development sequence:

1. Begin with a transparent vegetation-index and land-cover baseline.
2. Create labels from public imagery, public tree inventory, and trained annotation review.
3. Split training and test areas geographically to avoid overly optimistic performance from adjacent-image leakage.
4. Fine-tune a segmentation model from a public pretrained backbone where licensing permits.
5. Include imagery quality, season, shadow, drought, impervious surface, and sensor differences in evaluation.
6. Review errors in sparse canopy, shadows, irrigated turf, green roofs, shrubs, construction sites, and urban canyon conditions.
7. Publish accuracy, confusion matrix, area bias, uncertainty, model version, imagery date, and geographic transfer limitations.
8. Route uncertain or high-impact areas to community review or field verification using non-surveillant methods.

### Canopy Cover

For geographic planning area \(g\), let:

- \(N_{\mathrm{tree},g}\) be the number of pixels classified as canopy.
- \(N_{\mathrm{valid},g}\) be valid, non-cloud, non-nodata pixels.

\[
\operatorname{CanopyCover}_g =
\frac{
N_{\mathrm{tree},g}
}{
N_{\mathrm{valid},g}
}
\times 100
\]

The system shall publish canopy cover at a scale that supports restoration planning while minimizing property-level inference. Preferred public reporting areas include park zones, planning districts, heat-analysis cells, corridors, and community districts rather than individual parcels.

### Canopy Condition Indicators

Imagery-derived canopy condition is a screening signal, not a diagnosis of a specific tree.

A normalized difference vegetation index may be calculated as:

\[
NDVI =
\frac{
NIR - Red
}{
NIR + Red
}
\]

where \(NIR\) is near-infrared reflectance and \(Red\) is red-band reflectance.

A canopy-condition anomaly for area \(g\) can compare current and historical seasonal values:

\[
\Delta NDVI_g =
NDVI_{g,t} -
\operatorname{median}
\left(
NDVI_{g,t-1},
\ldots,
NDVI_{g,t-n}
\right)
\]

The system must distinguish vegetation stress from cloud contamination, shadow, smoke, seasonal phenology, image misregistration, irrigation changes, construction, and sensor quality artifacts.

### Heat Hotspots

Land-surface temperature should be used as a thermal exposure indicator:

\[
LST_C =
LST_K -
273.15
\]

where \(LST_K\) is land-surface temperature in Kelvin.

For planning area \(g\), define a local heat anomaly:

\[
H_g =
\frac{
LST_g -
\operatorname{median}(LST_{\mathrm{reference}})
}{
\sigma_{\mathrm{reference}} + \varepsilon
}
\]

where \(\varepsilon\) avoids division by zero.

A hotspot candidate may be identified where:

\[
H_g \geq H_{\mathrm{threshold}}
\]

and the location also has a public-access, shade, water, transit, or pedestrian-route gap.

Thermal-band outputs should not be presented as air temperature, individual heat exposure, medical risk, or a precise pedestrian comfort measurement. They are one input into a broader heat-resilience assessment.

### Priority Without Property Ranking

A canopy-restoration or cooling proposal uses transparent public-interest factors:

\[
S_g =
w_HH_g +
w_AA_g +
w_C(1-\operatorname{CanopyCover}_g) +
w_EQ_g +
w_M M_g
\]

where:

- \(H_g\): normalized heat anomaly.
- \(A_g\): public-access gap to shade, benches, water, cooling, transit, or safe walking routes.
- \(1-\operatorname{CanopyCover}_g\): canopy deficit.
- \(Q_g\): ecological feasibility and habitat value.
- \(M_g\): maintenance, irrigation, survival, and repair feasibility.

The weights must satisfy:

\[
w_H + w_A + w_C + w_E + w_M = 1
\]

The tool shall include hard non-compensation gates for:

\[
\text{accessible-route continuity}
\]

\[
\text{public water and cooling access}
\]

\[
\text{anti-displacement review}
\]

\[
\text{ecological feasibility}
\]

\[
\text{privacy and non-surveillance compliance}
\]

A high modeled canopy or cooling benefit cannot compensate for displacement risk, removal of accessible public space, loss of water access, or the use of personal or property-ranking data.

## Part Two: Fair Public EV Charging

### Equal-Priority Rule

Every active charging session receives equal priority regardless of:

- Driver identity.
- VIN or persistent vehicle identifier.
- Payment method or membership tier.
- Vehicle brand, model, price, or battery size.
- Prior station use.
- Residence, income, property value, credit, account age, or customer profitability.
- Disability, health, augmentation, cybernetic-host status, assistive technology, or personal-device use.

An EV charging station may use temporary, in-session technical values needed for safe power transfer, but it must discard or aggregate them after the session under a documented retention limit.

### Minimal Vehicle Communication

The station may receive the minimum session-local technical data required for safe charging coordination:

```text
charging_connector_state
maximum_safe_vehicle_current
maximum_safe_station_current
requested_current
battery_state_of_charge_if_available
battery_energy_needed_if_voluntarily_provided
charging_protocol_state
thermal_fault_state
session_active_state
```

The station SHALL NOT persist:

```text
vin
vehicle_certificate_subject
plug_and_charge_identity
driver_identity
payment_tier
home_address
route_history
charging_history
vehicle_brand_profile
behavior_profile
location_history
reputation_score
financial_rank
```

Where ISO 15118 or related communication standards provide information beyond immediate charging control, the station shall apply data minimization and a session-local pseudonymous handling boundary. The Joint Office identifies ISO 15118, OCPP, OCPI, electrical metrology, and related interoperability work as relevant public-charging standards and reliability infrastructure. [294]

### State-of-Charge Handling

If state of charge is supplied, it is an optional short-lived technical input—not an identity field.

Let:

- \(SOC_t\) be current battery state of charge.
- \(SOC_{\mathrm{target}}\) be a user-selected or vehicle-safe target.
- \(E_{\mathrm{usable}}\) be usable battery energy.
- \(P_i\) be allocated charging power.
- \(\eta_i\) be charging efficiency.

A session may estimate remaining energy:

\[
E_{\mathrm{needed}} =
\max
\left(
0,
SOC_{\mathrm{target}} -
SOC_t
\right)
E_{\mathrm{usable}}
\]

This value may be used only for the active session's estimated completion display. It shall not be retained after the session or combined across sessions.

If no SoC is available, the station must still provide charging based on connector capability and equal-priority current allocation.

### Max-Min Current Allocation

Let:

- \(I_{\mathrm{site}}\) be available site current after electrical safety and facility-reserve constraints.
- \(I_i^{\max}\) be the currently safe technical maximum for active session \(i\).
- \(I_i\) be allocated current.
- \(n\) be the number of active sessions.

The allocation must satisfy:

\[
0 \leq I_i \leq I_i^{\max}
\]

\[
\sum_{i=1}^{n} I_i \leq I_{\mathrm{site}}
\]

Max-min fairness chooses allocation \(I^*\) such that no session's current can be increased without decreasing another session with an equal or lower allocation:

\[
I^* =
\operatorname{maxmin}
\left(
I_1,\ldots,I_n
\right)
\]

A practical water-filling implementation:

1. Divide remaining current equally among active sessions.
2. Cap any session at its safe technical maximum.
3. Redistribute unused current equally among uncapped sessions.
4. Repeat until all available current is allocated or all sessions are capped.
5. Recalculate only from current session-local technical limits and site capacity.

The system may use a round-robin time slice where physical charger hardware cannot vary current continuously. The same equal-priority rule applies: time allocation is based on current technical state, not user identity or payment tier.

### Grid-Stress Constraints

Let:

- \(P_{\mathrm{site}}\) be current site demand.
- \(P_{\mathrm{capacity}}\) be safe site capacity.
- \(P_{\mathrm{protected}}\) be protected facility demand.
- \(P_{\mathrm{EV}}\) be total EV charging power.

\[
P_{\mathrm{site}} +
P_{\mathrm{EV}}
\leq
P_{\mathrm{capacity}}
\]

Where a public station shares infrastructure with an essential public facility:

\[
P_{\mathrm{protected}}
\leq
P_{\mathrm{capacity}}
-
P_{\mathrm{EV}}
\]

The charging scheduler must reduce or pause discretionary EV load before threatening protected facility loads, including public cooling, water, sanitation, emergency communications, accessible building functions, or resilience-hub operation.

Managed charging can reduce peak demand and help distribute charging load more evenly across the grid; these operational benefits must remain separate from any user-level prioritization. [292]

### Session and Fault States

```text
CONNECTOR_READY
CHARGING_EQUAL_ALLOCATION
CHARGING_TECHNICAL_CAP
GRID_STRESS_REDUCTION
PROTECTED_FACILITY_RESERVE
SESSION_PAUSED_FOR_SAFETY
SESSION_COMPLETE
CHARGER_FAULT
ACCESSIBLE_HUMAN_ASSISTANCE_AVAILABLE
```

A technical cap or safety pause must show an accessible explanation and a public support route. It must not produce an account penalty, user trust score, or future-priority reduction.

### Public Audit Summary

```json
{
  "event_type": "public_ev_charging_aggregate_status",
  "time_window": "hourly",
  "station_zone": "public_charging_zone",
  "active_sessions_bucket": "4_to_7",
  "available_site_current_a": 0.0,
  "allocated_station_current_a": 0.0,
  "allocation_method": "equal_priority_max_min",
  "protected_facility_reserve_active": true,
  "vin_retained": false,
  "driver_identity_retained": false,
  "payment_tier_used": false,
  "vehicle_history_retained": false,
  "residential_ranking_used": false,
  "retention_class": "aggregate_operations_limited"
}
```

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.91 | Public satellite thermal products, pixel segmentation, canopy and vegetation indices, max-min allocation, and interoperable EV charging controls |
| eco_impact_value | 0.93 | Supports canopy restoration, heat mitigation, water-aware urban ecology, lower grid peaks, and efficient shared EV charging |
| harm_risk | 0.31 | Remote-sensing uncertainty, canopy misclassification, stale imagery, charger faults, and capacity constraints remain risks; quality gates, field review, technical safety caps, and human support reduce exposure |
| accessibility_impact | 0.96 | Preserves public information, accessible route and shade planning, equal charging access, and clear non-profiled technical explanations |
| rights_alignment | 0.99 | Prohibits ground-level surveillance, driver profiling, identity and payment-tier ranking, property-based prioritization, and opaque access control |
