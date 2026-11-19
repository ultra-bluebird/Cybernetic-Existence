# Camera-Free Public-Building Wayfinding and Fair Community Storage

## Purpose

This specification defines:

1. A privacy-preserving indoor wayfinding application for complex public buildings that operates without camera frames, visual SLAM, image storage, facial recognition, or location-history retention.
2. A distributed community energy-storage policy that protects essential public services during grid disruptions without ranking residential users or relying on household-level health, identity, wealth, or utility behavior data.

Both systems are advisory and rights-centered. They do not determine identity, health, disability, augmentation status, cybernetic-host status, legal eligibility, service entitlement, or personal credibility.

## Shared Rights Baseline

The systems SHALL:

- Require no camera permission, facial recognition, biometric capture, personal device identifier, personal account, health disclosure, augmentation disclosure, cybernetic-host disclosure, or continuous connectivity.
- Provide accessible non-digital alternatives, including posted wayfinding, printed directions, staff assistance, public terminals, and accessible public information.
- Store only aggregate equipment or system-state data needed for maintenance, safety, governance, and public accountability.
- Provide accessible explanations, correction pathways, appeal pathways, and human review.
- Use signed configuration updates, rollback, local diagnostics, and repair-first maintenance.
- Prohibit social scoring, financial ranking, property-value ranking, household-level profiling, account-age preference, participation-frequency preference, and identity-based priority.
- Ensure optional BLE support cannot gate essential access, alter energy priority, or create a persistent presence history.

## Part One: Camera-Free AR Wayfinding

### Privacy-Preserving Design

The application provides visual overlays only when the user chooses a display format that benefits from them. It must not require a live camera feed.

The application SHALL NOT:

- Access or store camera frames.
- Use visual SLAM, facial recognition, image matching, object recognition, or scene reconstruction.
- Record microphone input by default.
- Retain a route history, location history, floor-by-floor movement record, beacon encounter history, Bluetooth identifier, Wi-Fi identifier, or device identifier.
- Use BLE detections to infer presence, identity, health, disability, assistive technology, augmentation, or cybernetic-host status.
- Require AR display, Bluetooth, app installation, or personal device possession to obtain building access or wayfinding assistance.

ARKit world tracking normally uses visual-inertial odometry, combining device motion sensing with computer-vision analysis of the camera-visible scene. A camera-free application should therefore use a custom floor-plan renderer and inertial/BLE positioning component rather than ARKit world tracking. [235][237]

### Positioning Architecture

The application uses a preloaded building package:

```text
signed_floor_plan
accessible_route_graph
room_and_service_directory
stairs_and_elevator_locations
elevator_status_snapshot
public_restroom_locations
drinking_water_locations
service_counter_locations
accessible_entrances
emergency_exit_information
tactile_map_and_print_reference
beacon_layout_metadata
map_version
validity_window
```

The local position estimate combines:

- Optional user-selected starting point.
- Inertial measurement unit step and heading estimation.
- Optional barometer or floor-selection control.
- Optional BLE beacon observations processed on-device.
- Map matching to walkable corridors.
- User correction through a “recenter,” “select current landmark,” or staff-assisted action.

Let:

- \(p_t\) be estimated position.
- \(v_t\) be estimated velocity or step-derived movement vector.
- \(\Delta t\) be elapsed time.
- \(u_t\) be inertial input.
- \(z_t\) be optional local BLE observation.
- \(M\) be the floor-plan accessibility graph.
- \(\hat{p}_t\) be the corrected estimate.

The prediction update is:

\[
p_{t|t-1} =
f(p_{t-1}, u_t, \Delta t)
\]

The optional measurement update is:

\[
\hat{p}_t =
g(p_{t|t-1}, z_t, M)
\]

All \(z_t\) values are processed in volatile memory. The application discards beacon observations after calculating the current local display state.

### Positioning Target

Let:

- \(p_t\) be the estimated indoor position.
- \(p_t^*\) be a controlled-test reference location.
- \(N\) be the number of independent commissioning samples.

The root-mean-square positioning error is:

\[
E_{\mathrm{RMS}} =
\sqrt{
\frac{1}{N}
\sum_{t=1}^{N}
\left\|
p_t-p_t^*
\right\|_2^2
}
\]

The commissioning target is:

\[
E_{\mathrm{RMS}} < 1\ \mathrm{m}
\]

A system that cannot meet the target at a site must display lower-confidence guidance, ask the person to select a known landmark, use a corridor-level estimate, or direct them to posted signs and staff assistance. It must not represent uncertain positioning as precise.

BLE indoor positioning can provide useful indoor location support, but RSSI-based estimates experience multipath effects, noise, and performance variation across buildings. Published surveys report wide variation in achieved accuracy, including around 0.9 to 1.8 meters in some controlled settings rather than universal sub-meter performance. [240][243][245]

### Accessible Guidance

The application supports multiple outputs:

| Output mode | Core function | Privacy and accessibility condition |
|---|---|---|
| High-contrast floor-plan overlay | Shows current corridor, route direction, elevator, ramp, restroom, or service desk | No camera required; local position only |
| Plain-language text directions | Gives step-by-step instructions with landmarks | Screen-reader compatible and printable |
| Audio guidance | Provides optional spoken instructions | On-device; no voice input or audio recording required |
| Haptic cues | Provides optional directional or arrival confirmation | Device-local only |
| Tactile building map | Provides fixed orientation and major-route reference | Available without app or Bluetooth |
| Staff-assisted route card | Provides printed or handwritten route guidance | Available without personal device |
| Public accessible kiosk | Provides building directory and route summary | Guest session with no retained search history |

Required interface controls include:

- Keyboard and switch access.
- Screen-reader labels.
- High-contrast mode.
- Text resizing.
- Reduced-motion mode.
- Non-color-only route cues.
- Plain-language error messages.
- Manual origin and destination selection.
- Recenter and “I am lost” controls.
- Elevator outage and accessible-route closure notice.
- Clear route confidence state.
- A no-camera, no-Bluetooth path.

### BLE Beacon Rules

BLE beacon infrastructure is optional. When used, it shall:

- Broadcast only a rotating or non-personal location reference needed for local map positioning.
- Avoid device discovery logs and avoid collecting device addresses.
- Avoid user-device pairing.
- Avoid signal-strength histories tied to a device.
- Avoid transmitting user BLE identifiers, phone identifiers, or route information off-device.
- Provide a visible and accessible “Bluetooth off” workflow.
- Preserve the same building access and wayfinding result through map, signage, staff, or kiosk alternatives.

BLE must not become a proxy for a person’s identity, cybernetic-host status, mobility condition, or presence history.

### Building Data Updates

Building packages must be:

- Signed by an authorized facility maintenance publisher.
- Versioned with a validity period and rollback information.
- Available as downloadable offline packages and through public kiosks.
- Updated after elevator outages, construction changes, closure changes, accessible-route changes, and public-service relocation.
- Audited for accessibility before release.
- Accompanied by human-readable release notes.
- Compatible with printed signage and staff-route guidance.

## Part Two: Fair Community Energy Storage

### Purpose Limitation

Community batteries smooth aggregate demand, support renewable integration, and provide resilience for essential public functions.

The system SHALL NOT:

- Use individual household medical, disability, health, identity, augmentation, cybernetic-host, financial, property-value, credit, rent, payment, or smart-meter behavior data.
- Rank residential users by wealth, social status, account history, political influence, utility profitability, or device ownership.
- Use residential battery access as a reward, punishment, or social-control mechanism.
- Deplete resilience reserves for speculative trading, advertising, discretionary computing, or avoidable commercial demand.
- Make emergency community power dependent on personal-device access, identity proof, or opt-in telemetry.

### Essential Load Categories

The battery reserve is allocated to public and community functions identified through public facility inventories and emergency planning.

Protected categories include:

| Priority class | Protected public function |
|---|---|
| Life safety | Hospitals, emergency operations, fire response, water and wastewater safety controls |
| Accessibility continuity | Accessible shelters, elevator safety, accessible communications, public assistance infrastructure |
| Thermal refuge | Cooling centers, warming centers, community hubs, designated resilience sites |
| Essential communications | Public warning, emergency broadcast, dispatch, accessible public information |
| Water and sanitation | Drinking-water treatment, pumping, wastewater treatment, sanitation facilities |
| Essential charging | Public charging at community hubs for assistive and communications access |
| Deferrable load | Non-urgent municipal computing, non-critical lighting, discretionary charging, non-essential commercial load |

The existing Augmented-Hub priority pattern protects life safety, accessibility, communications, thermal refuge, and essential charging before non-critical convenience. [31]

### State-of-Charge Reserve

Let:

- \(SOC_t\) be the battery state of charge at time \(t\), expressed as a fraction from zero through one.
- \(SOC_{\mathrm{reserve}}\) be the essential-services reserve floor.
- \(P_{\mathrm{charge},t}\) be charging power.
- \(P_{\mathrm{discharge},t}\) be discharge power.
- \(\eta_c\) and \(\eta_d\) be charging and discharge efficiencies.
- \(E_{\mathrm{nominal}}\) be nominal usable storage capacity.
- \(\Delta t\) be the control interval.

The state transition is:

\[
SOC_{t+1} =
SOC_t +
\frac{
\eta_c P_{\mathrm{charge},t}\Delta t
}{
E_{\mathrm{nominal}}
}
-
\frac{
P_{\mathrm{discharge},t}\Delta t
}{
\eta_d E_{\mathrm{nominal}}
}
\]

The requested essential-services floor is:

\[
SOC_t > 30\%
\]

or equivalently:

\[
SOC_t > 0.30
\]

Routine demand-smoothing discharge is allowed only when:

\[
SOC_{t+1} \geq SOC_{\mathrm{reserve}}
\]

where:

\[
SOC_{\mathrm{reserve}} = 0.30
\]

During a declared emergency or verified essential-service continuity event, discharge from the reserved state may occur only through authorized incident command, public emergency procedures, and a documented restoration plan. It must not be allocated through household rank or private consumption profiling.

### Essential-Service Autonomy

Let:

- \(E_{\mathrm{reserve}}\) be energy held above the technical minimum and designated for essential loads.
- \(P_{\mathrm{essential}}\) be forecast aggregate essential demand.
- \(\eta_d\) be discharge efficiency.
- \(r\) be a contingency reserve fraction.

\[
T_{\mathrm{essential}} =
\frac{
E_{\mathrm{reserve}}
\eta_d
(1-r)
}{
P_{\mathrm{essential}}
}
\]

This gives a planning estimate of essential-service support duration. It must be updated with verified battery health, ambient temperature, inverter availability, feeder condition, charging source availability, and actual essential load.

Energy storage supports grid resilience and can help microgrids sustain essential services during emergencies, but final reserve sizing must be validated against local electrical design, utility rules, facility critical-load studies, fire safety, and outage scenarios. [236][239]

### Consensus and Community Governance

No single owner, utility operator, technology vendor, community representative, or software component may unilaterally change the essential-service reserve, essential-load category list, discharge priority, or crisis discharge plan.

Use a threshold approval process with role separation:

| Governance role | Authority |
|---|---|
| Utility or microgrid operator | Verifies grid state and technical safety |
| Public emergency or resilience authority | Confirms emergency activation and essential-service need |
| Community governance representative | Confirms public-interest and equity commitments |
| Independent safety reviewer | Reviews battery and electrical safety constraints |
| Accessibility representative | Reviews impact on accessible services and communications |

A protected policy change requires approvals from at least three distinct role classes, including the technical operator and a community/public-interest representative.

The consensus condition is:

\[
\sum_{r \in R}
\mathbb{1}
[
\operatorname{approved}(r)
]
\geq
3
\]

subject to:

\[
\operatorname{distinctRoleClasses}(R)
\geq
3
\]

The system must reject any approval set dominated by one entity operating more than one nominal role.

### Community Storage Audit

Permitted aggregate audit record:

```json
{
  "event_type": "community_storage_state_summary",
  "time_window": "hourly",
  "battery_zone": "community_resilience_zone",
  "state_of_charge_percent": 0.0,
  "essential_reserve_floor_percent": 30.0,
  "essential_load_protection_active": true,
  "aggregate_essential_load_kw": 0.0,
  "aggregate_nonessential_discharge_kw": 0.0,
  "consensus_role_classes_approved": 3,
  "household_data_used": false,
  "health_or_identity_data_used": false,
  "property_or_financial_data_used": false,
  "residential_ranking_used": false,
  "retention_class": "aggregate_operational_limited"
}
```

Prohibited audit fields include household address, resident identity, smart-meter trace, medical equipment inference, disability inference, health record, augmentation or cybernetic-host status, home value, credit information, payment history, and any resident ranking.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.90 | Camera-free inertial and beacon-based positioning, accessible wayfinding, battery state-of-charge control, public essential-load prioritization, and multi-role governance |
| eco_impact_value | 0.86 | Supports low-device-dependence public navigation, renewable integration, demand smoothing, outage resilience, and protected cooling and water services |
| harm_risk | 0.34 | Indoor positioning uncertainty and battery-control failures can cause access or continuity problems; confidence signaling, offline alternatives, reserve constraints, and human approval reduce risk |
| accessibility_impact | 0.99 | Provides camera-free, Bluetooth-optional, offline, audio, haptic, text, print, kiosk, and staff-supported wayfinding while protecting essential public energy functions |
| rights_alignment | 0.99 | Enforces privacy, non-discrimination, no household profiling, no social ranking, essential-service continuity, transparent governance, and human review |
