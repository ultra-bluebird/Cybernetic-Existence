# Pedestrian-Safe Transit and Fair Load Shedding

## Purpose

This specification defines:

1. A rights-centered safety architecture for autonomous or supervised low-speed transit shuttles interacting with pedestrians and other vulnerable road users.
2. A fairness-constrained load-shedding planning model that preserves essential public and community loads and distributes residual inconvenience without wealth-based, identity-based, or neighborhood-stigma-based ranking.

The specification is decision support and engineering guidance. It does not authorize deployment on public streets, replace qualified safety engineering, certify an autonomous-driving system, make a public-utility operational decision, or determine any person's identity, health, disability, augmentation status, or eligibility.

## Shared Rights Commitments

Both systems SHALL:

- Treat all people as entitled to equal safety and access regardless of gait, mobility aid, prosthetic, assistive technology, communication method, appearance, age, perceived ability, or self-described cybernetic-host status.
- Avoid identity inference, disability classification, health inference, facial recognition, biometric tracking, and persistent person-level movement profiles.
- Use functional, safety-relevant uncertainty categories rather than personal classifications.
- Keep a human-operable fallback and accessible incident, correction, and appeal path.
- Log only the minimum technical evidence needed for safety and accountability.
- Prohibit physical actions based solely on unverified prediction or an opaque risk score.
- Preserve essential services, emergency communications, accessibility infrastructure, thermal refuge, and public safety functions during energy stress where physically possible.
- Publish the relevant operating rules, constraints, uncertainty, and review pathway in plain language.

## Part One: Pedestrian-Safe Autonomous Transit

### Safety Objective

The transit system shall not attempt to determine whether a person is disabled, uses a prosthetic, has an implant, uses an assistive device, or has a cybernetic limb. It must instead identify safety-relevant dynamic occupancy and uncertainty.

Permitted operational categories include:

- `person_associated_space`
- `mobility_aid_associated_space`
- `service_animal_and_handler_space`
- `unidentified_dynamic_occupancy`
- `child_sized_dynamic_occupancy`
- `static_obstacle`
- `uncertain_obstacle`

These are temporary scene-safety categories. They must not be stored as a person profile, linked across journeys, or used to infer a person's identity, health, disability, augmentation, or social status.

### Operational Design Domain

The shuttle shall operate only within an explicitly validated operational design domain that defines:

- Maximum vehicle speed.
- Road type and permitted route geometry.
- Maximum grade and surface conditions.
- Weather, visibility, lighting, and flooding limits.
- Geofenced service corridor.
- Allowed traffic complexity.
- Pedestrian-density threshold.
- Minimum sensor-health condition.
- Minimum localization confidence.
- Remote-support and human-fallback availability.
- Defined stop locations and minimal-risk stopping areas.

If an operating condition exits the validated domain, the shuttle SHALL transition to a minimal-risk condition such as a controlled stop in a pre-validated safe location, with accessible passenger support.

### Perception and Prediction

The training and validation dataset must be designed around scene diversity, not identity labels.

Required scenario coverage includes:

- Slow, fast, irregular, asymmetric, stopping, reversing, turning, and side-stepping movement.
- Wheelchairs, mobility scooters, walkers, canes, crutches, prosthetic limbs, service animals, strollers, bicycles, and micromobility devices.
- A person transferring to or from a mobility aid.
- Occlusions by parked vehicles, vegetation, shade structures, crowds, construction equipment, and street furniture.
- Daylight, glare, low sun, night conditions, rain, dust, heat shimmer, wet pavement, fog, and sensor contamination.
- Crosswalks, curb ramps, transit stops, pedestrian islands, shared spaces, loading zones, driveways, and narrow-access corridors.
- Children, groups, people carrying objects, seated people, people lying down, and people using varied communication or mobility patterns.
- Sensor faults, synchronization drift, reduced lidar return, camera exposure failures, GNSS degradation, map mismatch, and communication loss.

Data collection must use documented consent and privacy controls where needed, minimize retained imagery, remove direct identifiers, and separate any research dataset from operational deployment telemetry.

### Intention Prediction Constraint

Intention prediction is advisory. A person may move unpredictably, change direction, stop, or enter the shuttle path without warning.

Let:

- \(x_t\) be the observed motion history over a recent time window.
- \(\hat{p}_{t+\Delta}\) be the predicted occupancy distribution at future time \(t+\Delta\).
- \(U_{t+\Delta}\) be an uncertainty region derived from perception, motion, latency, and environmental uncertainty.
- \(O_{t+\Delta}\) be the conservative occupancy envelope.

\[
O_{t+\Delta} =
\hat{p}_{t+\Delta}
\oplus
U_{t+\Delta}
\]

where \(\oplus\) denotes spatial expansion by the uncertainty region.

The planner must use \(O_{t+\Delta}\), not only a most-likely predicted path. Higher uncertainty requires a larger envelope and a more conservative speed or stop decision.

A prediction confidence value must never be used to justify ignoring an uncertain person-associated or dynamic-object detection.

### Time-To-Collision

For closing distance \(d\) and relative closing speed \(v_{\mathrm{rel}} > 0\):

\[
TTC =
\frac{d}{v_{\mathrm{rel}}}
\]

The target operational condition is:

\[
TTC > 3\ \mathrm{s}
\]

for every detected person-associated or uncertain dynamic occupancy.

A single TTC threshold is not sufficient at all speeds and road conditions. The stopping envelope must also account for perception delay, decision delay, braking-system latency, road grade, surface friction, vehicle mass, passenger stability, and uncertainty.

Let:

- \(v\) be shuttle speed.
- \(t_{\mathrm{delay}}\) be total sensing, fusion, planning, actuator, and brake-build delay.
- \(a_{\mathrm{safe}}\) be the validated conservative deceleration magnitude.
- \(m_{\mathrm{uncertainty}}\) be an uncertainty and clearance margin.

\[
d_{\mathrm{stop}} =
v t_{\mathrm{delay}}
+
\frac{v^2}{2a_{\mathrm{safe}}}
+
m_{\mathrm{uncertainty}}
\]

Safe continuation requires:

\[
d_{\mathrm{available}} >
d_{\mathrm{stop}}
\]

and:

\[
TTC >
\max
\left(
3\ \mathrm{s},
t_{\mathrm{delay}} +
\frac{v}{a_{\mathrm{safe}}}
\right)
\]

If the system cannot establish this inequality from validated sensor data, it shall reduce speed or enter a minimal-risk stop state.

### Conservative Courtesy Behavior

The shuttle shall:

- Yield to any pedestrian or uncertain dynamic occupancy within the planned path or safety envelope.
- Avoid pressuring people to move through honking, aggressive creeping, light flashing, or repeated automated requests.
- Maintain increased clearance around people, mobility aids, service animals, and uncertain objects.
- Use accessible, non-startling external communication that is supplementary and never the sole safety mechanism.
- Avoid blocking curb ramps, crossings, bus stops, accessible loading zones, building entrances, and mobility-device maneuvering spaces.
- Use a smooth deceleration profile compatible with standing and seated passengers.
- Never assume a person will react to an external signal, hear an alert, see a display, move quickly, or follow a predicted path.
- Provide a human support contact and accessible incident-report mechanism.

### Detection Performance

For scenario stratum \(g\):

\[
FNR_g =
\frac{FN_g}{TP_g + FN_g}
\]

The research target is:

\[
FNR_g < 0.01\%
\]

This target must be measured with confidence intervals, scenario counts, weather conditions, lighting conditions, route types, sensor condition, and independent validation sets.

A low aggregate false-negative rate is insufficient if performance degrades in accessibility-relevant scenarios. Required reporting includes:

- Overall false-negative rate.
- False-negative rate by scenario family.
- Minimum clearance violations.
- Emergency-braking events.
- Conservative-stop frequency.
- Unnecessary-stop frequency.
- Human-intervention frequency.
- Sensor-health lockout frequency.
- Near-miss and incident review outcomes.
- Dataset and operational-design-domain coverage gaps.

NHTSA's automatic emergency braking standard requires pedestrian detection in daylight and darkness for covered passenger vehicles, and requires pedestrian AEB performance at speeds up to approximately 45 mph. These requirements are not a deployment certification for a shuttle, but they reinforce the need to validate pedestrian detection across lighting conditions and braking regimes. [161][165]

### Safety Release Gates

The shuttle must not operate autonomously in the relevant operating domain when any condition is true:

- Sensor-health validation fails.
- Localization confidence falls below the route-specific minimum.
- A camera, lidar, radar, timing, braking, steering, or computing safety monitor reports a critical fault.
- Weather, lighting, road surface, crowding, or route conditions exceed the validated domain.
- Pedestrian or uncertain-object detection performance fails a safety threshold.
- A scenario family involving mobility aids, service animals, irregular motion, occlusion, or degraded sensing lacks sufficient validation evidence.
- The predicted occupancy envelope overlaps the shuttle's reachable trajectory.
- The system cannot establish the stopping-distance and TTC constraints.
- Human fallback, passenger communication, or minimal-risk stopping capability is unavailable.
- A safety-critical model, map, calibration, firmware, or hardware update has not completed regression validation.

A release block does not restrict a person's access to transit. It requires the service operator to provide an accessible supervised, manual, alternate-route, or alternative transportation option.

## Part Two: Fair Load Shedding

### Essential-Load Definition

Essential load must be defined from public facility and service-function data, not from household-level health, disability, identity, consumer wealth, smart-meter behavior, or personal device data.

Protected essential-load categories may include:

| Priority class | Public function | Examples |
|---|---|---|
| Life safety | Prevent immediate loss of life or severe harm | Hospitals, emergency departments, fire and emergency operations, water and wastewater safety controls |
| Accessibility continuity | Preserve access for people who rely on public accommodations and communications | Accessible shelters, elevator safety functions, emergency communication, public accessibility systems |
| Thermal refuge | Protect community access to cooling or warming during extreme conditions | Cooling centers, heat refuges, community hubs, designated resilience centers |
| Essential public communications | Maintain public warnings and coordination | Emergency broadcast, public safety dispatch, accessible public information systems |
| Water and sanitation | Maintain basic public health infrastructure | Drinking-water pumping, water treatment, wastewater operations, sanitation facilities |
| Essential charging | Maintain public access to assistive and communication-device charging | Community hubs, resilience centers, designated public charging stations |
| Deferrable or discretionary load | May be curtailed only after protected-load review | Non-critical lighting, non-essential commercial loads, deferrable municipal computing, non-urgent charging |

The project’s existing priority-preserving load rule places life safety, accessibility, communications, thermal refuge, and essential charging ahead of non-critical convenience. [31]

No protected essential load may be shed merely to improve cost, revenue, comfort, advertising, property value, or a generalized optimization score.

### Planning Inputs

The model may use:

- Public facility inventories.
- Publicly documented critical-infrastructure designations.
- Public cooling-center and resilience-hub locations.
- Aggregate feeder capacity and network reliability data.
- Weather forecasts and grid-demand scenarios.
- Aggregate service-area population counts.
- Community-reviewed access gaps.
- Asset-condition and maintenance information.
- Publicly documented emergency plans.

The model must not use:

- Individual household medical, disability, identity, augmentation, cybernetic-host, financial, or utility-consumption data.
- Individual smart-meter traces for social prioritization.
- Consumer credit, rent, home value, property-tax yield, payment history, or customer profitability.
- Individual vulnerability scores or behavior profiles.

### Feasibility Before Fairness

Load-shedding optimization must first respect power-system constraints. Let:

- \(P_i\) be demand in service area \(i\).
- \(s_i\) be curtailed power in area \(i\).
- \(P_i^{\mathrm{essential}}\) be protected essential demand.
- \(P_{\mathrm{required}}\) be required aggregate load reduction.
- \(T\) be the planning horizon.
- \(x_i\) be outage duration for area \(i\).

The essential-load protection condition is:

\[
0 \leq s_i \leq
\max
\left(
0,
P_i - P_i^{\mathrm{essential}}
\right)
\]

The required reduction condition is:

\[
\sum_{i=1}^{n} s_i
\geq
P_{\mathrm{required}}
\]

If the required reduction cannot be achieved without curtailing protected loads, the system must escalate to emergency operations, demand-response alternatives, backup generation, mutual aid, public warning, and human incident-command review. It must not silently reclassify protected essential load as discretionary.

### Equity Objective

For each non-essential service area \(i\), let \(x_i\) be normalized residual outage burden after accounting for protected service continuity and documented unavoidable physical constraints.

Jain's fairness index is:

\[
F =
\frac{\left(\sum_{i=1}^{n}x_i\right)^2}
{n\sum_{i=1}^{n}x_i^2}
\]

The planning target is:

\[
F > 0.9
\]

where:

- \(F = 1\) indicates equal normalized burden.
- Lower values indicate more uneven burden distribution.

Fairness must be evaluated only after essential-load protection, grid feasibility, and immediate safety constraints are satisfied. Equalizing outages by removing electricity from a cooling center, hospital, water system, or accessible shelter would be unjust and unsafe.

### Burden Constraints

For an eligible non-essential service area \(i\), define:

- \(x_i\): planned outage duration.
- \(\bar{x}\): average outage duration across comparable non-essential service areas.
- \(\delta\): maximum allowed deviation.
- \(L_i\): documented physical grid limitation indicator.

The bounded-burden rule is:

\[
x_i \leq \bar{x} + \delta
\]

unless:

\[
L_i = 1
\]

and an authorized human review documents the technical reason, duration, mitigation, and restoration plan.

A temporary technical exception must trigger compensating **service continuity measures**, such as accessible cooling access, public charging, water access, transportation support, and clear multilingual/accessible notice. It must not trigger a financial, identity, or social-ranking intervention.

### Optimization Objective

A planning model can minimize unserved non-essential energy while penalizing unequal outage burden:

\[
\min
\left[
\sum_{i=1}^{n} c_i s_i
+
\lambda
\sum_{i=1}^{n}
(x_i - \bar{x})^2
\right]
\]

subject to:

\[
\sum_{i=1}^{n}s_i
\geq
P_{\mathrm{required}}
\]

\[
0 \leq s_i \leq
\max
\left(
0,
P_i - P_i^{\mathrm{essential}}
\right)
\]

\[
F > 0.9
\]

\[
x_i \leq x_{\max}
\]

\[
\text{essential load continuity} = \text{preserved}
\]

The coefficients \(c_i\) must represent transparent technical feasibility or non-essential operational impact. They must not encode wealth, property value, political influence, income, disability, race, identity, device ownership, or customer profitability.

### Fairness Evaluation

The system shall report:

- Total required reduction.
- Essential load preserved.
- Residual non-essential curtailed energy.
- Planned outage duration by aggregate service area.
- Jain fairness index.
- Maximum burden deviation from comparable areas.
- Number and reason of documented technical exceptions.
- Availability of cooling, charging, water, transportation, and communication mitigations.
- Restoration sequence and estimated uncertainty.
- Accessibility of public notifications.
- Community review and appeal availability.

The reported service areas must be large enough to avoid revealing individual household conditions, smart-meter patterns, or protected facility vulnerabilities.

### Public Notice

Outage and restoration information must be available through:

- Accessible website and low-bandwidth text page.
- Public displays at libraries, transit locations, resilience hubs, and cooling centers.
- Radio and broadcast channels.
- Opt-in SMS with easy opt-out.
- Telephone and relay-compatible information.
- Printed notices and in-person assistance.
- Community organizations and accessible-language partners.

Notices must include the affected public zone, estimated start and restoration window, public cooling and charging locations, accessible transportation information where available, water and sanitation guidance, and a route to report an access barrier.

## Privacy-Preserving Audits

### Transit audit event

```json
{
  "event_type": "shuttle_safety_state_summary",
  "event_time": "2026-09-01T00:00:00Z",
  "route_zone": "validated_transit_corridor",
  "state": "minimal_risk_stop",
  "reason_category": "uncertain_dynamic_occupancy",
  "sensor_health": "nominal",
  "identity_data_present": false,
  "biometric_data_present": false,
  "assistive_or_augmentation_status_inferred": false,
  "raw_video_retained_by_default": false,
  "human_review_available": true,
  "retention_class": "safety_limited"
}
```

### Grid fairness audit event

```json
{
  "event_type": "load_shedding_plan_summary",
  "event_time": "2026-09-01T00:00:00Z",
  "planning_horizon": "emergency_event_window",
  "essential_load_protected": true,
  "jain_fairness_index": 0.92,
  "technical_exception_count": 0,
  "individual_meter_data_used": false,
  "health_or_identity_data_used": false,
  "wealth_or_property_value_used": false,
  "accessible_notice_available": true,
  "human_incident_command_reviewed": true,
  "retention_class": "aggregate_operational"
}
```

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.90 | Safety-envelope mathematics, operating-domain governance, pedestrian-AEB context, essential-load protection, and fairness-constrained outage planning |
| eco_impact_value | 0.79 | Reduces collision risk, supports low-emission shuttle service, protects cooling and water systems, and shifts deferrable load before critical public functions |
| harm_risk | 0.39 | Transit perception and grid contingency systems are safety-critical; conservative fallback, hard constraints, human review, and public alternatives reduce but do not eliminate risk |
| accessibility_impact | 0.98 | Protects diverse pedestrian movement, mobility-aid space, accessible transit alternatives, cooling centers, emergency communications, and essential charging |
| rights_alignment | 0.99 | Enforces non-discrimination, privacy, non-profiling, essential-service continuity, human accountability, accessible notice, and appeal |
