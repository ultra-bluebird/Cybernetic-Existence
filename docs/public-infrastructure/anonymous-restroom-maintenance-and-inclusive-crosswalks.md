# Anonymous Restroom Maintenance and Inclusive Crosswalks

## Purpose

This specification defines:

1. A public-restroom maintenance trigger using non-imaging occupancy indicators.
2. A smart-crosswalk timing controller that provides a universal minimum crossing time and may extend timing based on anonymous, short-lived crossing-zone occupancy.

Both systems are designed to preserve dignity, accessibility, privacy, repairability, and safe public access.

They must not capture images, record audio, recognize faces, identify people, infer disability or health status, identify mobility aids, store individual trajectories, associate sensor events with a person, or impose access restrictions based on occupancy sensing.

## Shared Rights Baseline

The systems SHALL:

- Use the least intrusive sensing method capable of the maintenance or safety purpose.
- Store only aggregate counts, event timestamps, equipment-health state, and short-lived anonymous safety state.
- Provide accessible manual and staff-assisted fallback routes.
- Preserve ordinary access when a sensor, network, controller, or power connection fails.
- Distinguish an uncertain sensor state from a confirmed facility or crossing condition.
- Provide local operation without continuous cloud connectivity.
- Support signed firmware, diagnosable faults, safe rollback, repair-first maintenance, and public correction reporting.
- Never use person detection, facial recognition, Bluetooth/Wi-Fi device tracking, location histories, or personal-device identifiers.
- Never use sensor output to build behavior profiles, reputation records, eligibility scores, or enforcement records.

## Part One: Public Restroom Maintenance

### Purpose Limitation

Occupancy sensing exists only to support cleaning, supplies, maintenance response, and accessible facility availability.

It SHALL NOT be used to:

- Lock a restroom door because a counter reports occupancy.
- Track dwell time by person.
- Identify restroom users.
- Restrict access to any person based on frequency of use.
- Trigger law-enforcement or immigration reporting.
- Monitor gender, disability, health, augmentation, cybernetic-host status, appearance, device presence, or any other personal characteristic.
- Publish restroom occupancy or usage patterns at a level that can reveal individual behavior.

### Sensor Architecture

Use a redundant, non-imaging sensor set:

| Sensor | Operational role | Privacy property | Failure consideration |
|---|---|---|---|
| Door-position switch | Detects door open/closed state | Does not identify a person | Can be damaged, misaligned, or bypassed |
| Privacy-latch switch | Indicates latch state where appropriate | Measures fixture state, not identity | Must not be treated as proof that a person is inside |
| Bidirectional infrared beam pair | Estimates entry/exit events | No image, audio, or identity capture | Tailgating, reverse movement, occlusion, and vandalism can cause error |
| Passive infrared activity sensor | Optional short-window activity indication | No image capture | Should not retain presence history or identify a person |
| Supply-level sensor | Supports refill scheduling | Does not sense people | Requires manual verification for false low readings |
| Water-leak or floor-moisture sensor | Detects facility hazard | Measures environment, not person | Must not trigger automatic door locking |
| Tamper switch | Detects opened enclosure or disconnected equipment | Equipment-only telemetry | Requires repair-first response, not user restriction |
| Manual staff-inspection control | Confirms sanitation state | Human operational action | Must remain available when sensors fail |

A bidirectional infrared beam pair is preferred over a single beam because it can estimate direction from beam-order transitions. Door and latch switches are secondary evidence. The cleaning state must be conservative when signals disagree.

### Count Reconciliation

Let:

- \(E_t\) be counted entry events by time \(t\).
- \(X_t\) be counted exit events by time \(t\).
- \(O_t\) be estimated anonymous occupancy.
- \(O_{\max}\) be maximum plausible occupancy for the restroom configuration.

\[
O_t =
\operatorname{clamp}
\left(
O_{t-1} + E_t - X_t,
0,
O_{\max}
\right)
\]

The cumulative usage count is:

\[
U_t =
\sum_{\tau \leq t} E_{\tau}
\]

A bounded occupancy estimate is only a maintenance heuristic. It is not a reliable source for locking, enforcement, or proving whether a person is present.

### Cleaning Trigger

Let:

- \(U_t\) be cumulative validated entry events since last confirmed cleaning.
- \(t_{\mathrm{clean}}\) be the time of last confirmed cleaning.
- \(t_{\mathrm{now}}\) be current time.
- \(U_{\mathrm{threshold}}\) be the usage threshold.
- \(T_{\mathrm{threshold}}\) be the maximum time between cleaning reviews.

\[
\operatorname{CleanReview}(t) =
\begin{cases}
1 &
\text{if }
U_t > 50
\lor
(t_{\mathrm{now}} - t_{\mathrm{clean}}) > 4\ \mathrm{hours} \\
0 &
\text{otherwise}
\end{cases}
\]

A `CleanReview` event requests cleaning inspection. It does not assert unsanitary conditions and does not authorize a facility closure without an accessible operational review.

### Accessibility and Door Safety

Restroom occupancy sensing must never be coupled to automatic lockout. Specifically:

- Exterior access doors shall not lock merely because the estimated occupancy count is nonzero.
- An accessible restroom must maintain a manual, clearly operable privacy-latch process.
- Accessible privacy latches must not require a phone, app, biometric, visual-only prompt, or high-force action.
- Sensor faults, battery failure, communication loss, or counter disagreement must default to continued public access unless a separate verified life-safety hazard requires temporary closure.
- If closure is necessary for verified hazard remediation, provide clear accessible notice and the nearest available accessible alternative.
- Any automatic door operator must retain safe manual override and comply with the installation's applicable accessibility, fire, building, and manufacturer requirements.

The Access Board notes that single-user toilet rooms, when provided, require privacy latches; these privacy functions must remain under the user's control rather than inferred by a sensor system. [176]

### Vandalism and False-Count Resilience

The backend shall use a confidence state rather than assuming all sensor events are accurate.

```text
NOMINAL
COUNT_UNCERTAIN
MAINTENANCE_REVIEW_REQUESTED
CLEANING_IN_PROGRESS
CLEANING_CONFIRMED
SENSOR_TAMPER_OR_FAULT
ACCESSIBLE_ALTERNATIVE_NOTICE_REQUIRED
```

A counter becomes `COUNT_UNCERTAIN` when:

- Door and beam evidence conflict repeatedly.
- The inferred occupancy is negative or exceeds the configured physical maximum.
- A beam remains blocked longer than the maximum crossing window.
- A tamper switch is active.
- Sensor heartbeat is absent.
- A counter reset occurs unexpectedly.
- An event rate exceeds a physically plausible maximum.
- A cleaning staff member declares the count unreliable.

During `COUNT_UNCERTAIN`:

- Continue time-based maintenance review.
- Do not lock or deny access.
- Do not publish occupancy.
- Request repair or staff inspection.
- Record only the equipment fault category and time.

### False-Count Metric

Let:

- \(N_{\mathrm{false}}\) be the number of independently verified count errors.
- \(N_{\mathrm{entry}}\) be the number of independently audited entry events.

\[
\operatorname{FalseCountRate} =
\frac{N_{\mathrm{false}}}
{N_{\mathrm{entry}}}
\times 100
\]

The target is:

\[
\operatorname{FalseCountRate} < 1
\text{ per }
100
\text{ entries}
\]

This target must be estimated through voluntary, non-identifying commissioning observations, controlled test passages, maintenance logs, and sensor self-test records. It must not require video surveillance or identity tracking.

## Part Two: Smart Crosswalk Timing

### Core Principle

Every pedestrian receives a safe baseline crossing opportunity. Anonymous sensing may extend—not reduce—the pedestrian clearance interval when the crossing remains occupied or uncertain.

The controller does not need to determine whether someone is a wheelchair user, uses a mobility aid, has a non-standard gait, has an assistive device, or has a cybernetic limb. It only needs to maintain a conservative crossing-zone safety state.

### Universal Minimum Timing

Let:

- \(W\) be the measured crossing width from the applicable start point to the safe refuge or far curb.
- \(v_{\mathrm{slow}}\) be the site-approved slowest expected walking speed.
- \(B\) be a fixed additional safety buffer.
- \(T_{\mathrm{walk}}\) be the WALK indication duration.
- \(T_{\mathrm{clear}}\) be the pedestrian clearance duration.
- \(T_{\min}\) be total minimum pedestrian time.

\[
T_{\min} =
\frac{W}{v_{\mathrm{slow}}}
+
B
\]

The minimum controller condition is:

\[
T_{\mathrm{walk}} + T_{\mathrm{clear}}
\geq
T_{\min}
\]

The MUTCD framework uses pedestrian clearance timing based on walking speed and specifically directs agencies to consider slower speeds where pedestrians who walk more slowly or use wheelchairs routinely use the crosswalk. [177][180] The stated formula is a planning expression; the final signal timing must be approved through applicable traffic-engineering, accessibility, and jurisdictional procedures.

### Recommended Timing Inputs

The controller configuration must include:

- Measured crossing width.
- Median refuge location, if any.
- Minimum WALK interval.
- Site-approved pedestrian clearance speed.
- Buffer for startup, approach, ramp transition, and uncertainty.
- Vehicle-phase constraints.
- Emergency-vehicle and transit-signal-priority constraints.
- Accessible pedestrian-signal requirements.
- School, hospital, senior-service, transit, community-hub, and other local access context.
- Construction, detour, weather, and outage fallback procedures.

Federal guidance generally treats pedestrian clearance time as crossing distance divided by walking speed and notes a 7-second minimum WALK interval in ordinary settings, subject to specified traffic-control provisions. [181]

### Anonymous Extension Sensing

A crossing controller may use short-lived sensing only to determine whether the active crossing zone remains occupied or uncertain.

Permitted sensing examples:

| Method | Permitted output | Retention limit | Prohibited output |
|---|---|---:|---|
| Infrared beam array | Crossing-zone occupied / clear | Immediate control cycle only | Person identity, body classification, trajectory archive |
| Pressure or load-sensitive crossing strip | Anonymous zone occupancy | Immediate control cycle only | Weight profile, biometric inference, person count history |
| Radar with edge-only occupancy grid | Anonymous moving-object occupancy | Immediate control cycle only | Face, identity, device identifier, persistent tracking |
| Thermal-array sensor with no image export | Coarse occupancy mask | Immediate control cycle only | Thermal image recording, body-temperature inference, recognition |
| Accessible push button | Pedestrian phase request | Minimal operational retention | Identity or device association |

The strongest privacy design uses a volatile occupancy bit:

```text
CROSSING_CLEAR
CROSSING_OCCUPIED
CROSSING_UNCERTAIN
SENSOR_FAULT
```

The bit is reset at the end of the signal phase and must not be stored as an individual travel record.

### Extension Rule

Let:

- \(T_{\mathrm{base}}\) be the universal minimum crossing duration.
- \(\Delta T\) be the extension increment.
- \(T_{\mathrm{max}}\) be the traffic-engineering-approved maximum pedestrian interval.
- \(Z_t\) be the anonymous crossing-zone state.

\[
T_{\mathrm{next}} =
\begin{cases}
\min(T_{\mathrm{current}} + \Delta T, T_{\max}) &
\text{if } Z_t \in
\{
\mathrm{CROSSING\_OCCUPIED},
\mathrm{CROSSING\_UNCERTAIN}
\} \\
T_{\mathrm{base}} &
\text{if } Z_t =
\mathrm{CROSSING\_CLEAR}
\end{cases}
\]

The controller shall never shorten a pedestrian phase below the universal minimum because an anonymous sensor reports `CROSSING_CLEAR`.

### Fallback Behavior

When sensor output is missing, malformed, delayed, contradictory, or unreliable:

\[
T_{\mathrm{applied}} =
T_{\min}
\]

The fallback is a fixed, conservative pedestrian timing plan approved for the intersection. It must not default to a shorter interval, a skipped pedestrian phase, or a vehicle-priority-only mode.

If the system cannot safely offer the ordinary adaptive sequence, it must transition to a validated fixed-time accessible plan and notify traffic operations for maintenance review.

### Sensor and Timing Fault States

```text
CONFIGURATION_REVIEW_REQUIRED
FIXED_TIME_ACCESSIBLE_OPERATION
ADAPTIVE_OPERATION
CROSSING_OCCUPIED_EXTENSION
CROSSING_UNCERTAIN_EXTENSION
SENSOR_FAULT_FIXED_TIME_FALLBACK
TRAFFIC_ENGINEERING_REVIEW_REQUIRED
```

A sensor failure does not mean that pedestrians disappeared. It means the adaptive feature is unavailable and the controller must use its approved universal timing floor.

### Public Accessibility Controls

Every crosswalk design should include, as applicable:

- Accessible pedestrian signals with tactile, audible, and visual indications.
- Detectable warnings, accessible curb ramps, clear landing areas, and unobstructed pedestrian routes.
- Push buttons reachable from a wheelchair or mobility device and usable without fine motor precision beyond applicable requirements.
- A redundant request method where a push button cannot be used.
- Clear visual countdown information paired with non-visual communication.
- A public path to report a short signal, inaccessible push button, glare, barrier, noise issue, or sensor fault without an account.
- Temporary accessible detours during maintenance or construction.
- Human traffic-operations support for persistent timing issues.

## Privacy-Preserving Audit Records

### Restroom maintenance event

```json
{
  "event_type": "restroom_maintenance_summary",
  "public_facility_zone": "public_restroom_area",
  "event_time": "2026-09-01T00:00:00Z",
  "maintenance_state": "maintenance_review_requested",
  "usage_threshold_exceeded": true,
  "time_threshold_exceeded": false,
  "estimated_occupancy_retained": false,
  "image_data_present": false,
  "audio_data_present": false,
  "identity_data_present": false,
  "device_data_present": false,
  "door_lock_controlled_by_sensor": false,
  "retention_class": "aggregate_maintenance_limited"
}
```

### Crosswalk timing event

```json
{
  "event_type": "crosswalk_timing_summary",
  "intersection_zone": "public_crossing_zone",
  "event_time": "2026-09-01T00:00:00Z",
  "controller_state": "crossing_uncertain_extension",
  "adaptive_extension_applied": true,
  "universal_minimum_timing_preserved": true,
  "trajectory_retained": false,
  "identity_data_present": false,
  "biometric_data_present": false,
  "mobility_or_health_inference_performed": false,
  "sensor_fault_fallback_available": true,
  "retention_class": "aggregate_operations_limited"
}
```

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.91 | Combines non-imaging sensor redundancy, privacy-preserving event logic, accessible restroom principles, and pedestrian-signal timing guidance |
| eco_impact_value | 0.73 | Improves targeted cleaning, reduces unnecessary maintenance trips and consumable waste, and supports walkable low-emission mobility |
| harm_risk | 0.32 | Risks include false counts, sensor damage, missed crossing occupancy, and poorly calibrated timing; conservative fallback and human review reduce exposure |
| accessibility_impact | 0.99 | Preserves restroom access, avoids sensor-driven lockouts, provides universal crosswalk time, and extends safety time without requiring identity disclosure |
| rights_alignment | 0.99 | Enforces person-agnostic sensing, privacy, repairability, accessible public access, no profiling, and human-operable fallback |
