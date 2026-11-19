# Transit Occupancy and Air-Quality Sensor Fusion

## Purpose

This architecture produces real-time, privacy-preserving occupancy and ventilation indicators for buses and rail vehicles.

It combines:

- Overhead camera-derived anonymous doorway flow counts.
- Infrared beam-counter events.
- Carbon-dioxide measurements.
- Vehicle position, route, and operational context.
- Door-open and HVAC state.

The system provides riders with accessible information about crowding and air-quality conditions while keeping cameras and sensor signals out of identity, fare enforcement, policing, behavioral profiling, and person-tracking systems.

Carbon-dioxide monitoring can provide a practical indicator of ventilation adequacy in occupied indoor spaces, including public buses and shuttle vans, but it must be interpreted with vehicle context, outdoor background conditions, door cycles, and ventilation-system operation. [162] ASHRAE ventilation standards provide recognized design and acceptable-IAQ baselines, but vehicle-specific deployment must use the applicable vehicle and transit-facility requirements rather than a universal CO2 threshold. [166]

## Privacy and Rights Boundary

The system must:

- Count flows and occupancy only at aggregate vehicle level.
- Prohibit facial recognition, face matching, person re-identification, body-template storage, demographic inference, emotion inference, behavior scoring, or journey reconstruction.
- Process camera frames on the vehicle edge device.
- Discard frames immediately after producing count deltas and confidence values.
- Avoid storing raw images, video, embeddings, skeletal keypoints, device identifiers, ticket identifiers, MAC addresses, or person-level trajectories.
- Keep occupancy data separate from fare enforcement, law enforcement, immigration enforcement, advertising, and employment systems.
- Publish rider information at vehicle, route, or station aggregate level only.
- Provide a no-app route to information through onboard displays, station displays, voice announcements, and accessible web text.
- Avoid presenting occupancy as a guarantee of available accessible space; provide an uncertainty band and status label.

## Hardware Wiring Pattern

```text
Vehicle low-voltage supply
    |
    +--> Fused and isolated DC distribution
            |
            +--> Edge compute unit with hardware watchdog
            |       |
            |       +--> Encrypted local solid-state storage for short diagnostic buffers only
            |       +--> Cellular or rail Ethernet gateway
            |
            +--> Doorway sensor branch
            |       |
            |       +--> Overhead camera with narrow doorway field of view
            |       +--> Infrared beam-pair counter
            |       +--> Door-open state input from vehicle controller
            |
            +--> Cabin environmental branch
                    |
                    +--> NDIR CO2 sensor
                    +--> Temperature and humidity sensor
                    +--> HVAC run-state or ventilation-command interface
                    +--> Outdoor background CO2 sensor where practical
```

## Sensor Placement

| Sensor | Placement | Function | Privacy protection |
|---|---|---|---|
| Overhead camera | Above each doorway, downward-facing, field of view limited to threshold zone | Counts ingress and egress flow direction | Edge-only inference; immediate frame deletion; no face or identity processing |
| Infrared beam pair | Door frame at approved height and offset | Detects crossing direction and validates camera flow count | Produces event counts only |
| Door-state input | Vehicle controller interface | Gates count interpretation to door-open intervals | No passenger information |
| NDIR CO2 sensor | Representative breathing-zone location away from direct vents and doors | Measures ventilation-related CO2 trend | Environmental aggregate only |
| Temperature/humidity sensor | Near CO2 sensor | Adds thermal-comfort and calibration context | Environmental aggregate only |
| HVAC-state interface | Approved read-only vehicle interface | Provides ventilation context | No passenger information |
| Outdoor CO2 sensor | Exterior protected location where feasible | Establishes background reference | Environmental aggregate only |

The camera is never wired to an onboard security-video recorder or remote viewing console. It connects only to the edge counting process through a dedicated interface and network segment.

## Edge Fusion Model

For door \(d\) in time interval \(t\):

- \(C_{d,t}^{\mathrm{vision}}\): edge-derived camera count delta.
- \(C_{d,t}^{\mathrm{IR}}\): infrared beam count delta.
- \(\sigma_{d,t}^{\mathrm{vision}}\): camera uncertainty.
- \(\sigma_{d,t}^{\mathrm{IR}}\): infrared uncertainty.

Fuse count delta by inverse-variance weighting:

\[
\Delta O_{d,t}
=
\frac{
C_{d,t}^{\mathrm{vision}} / (\sigma_{d,t}^{\mathrm{vision}})^2
+
C_{d,t}^{\mathrm{IR}} / (\sigma_{d,t}^{\mathrm{IR}})^2
}{
1 / (\sigma_{d,t}^{\mathrm{vision}})^2
+
1 / (\sigma_{d,t}^{\mathrm{IR}})^2
}
\]

Update vehicle occupancy:

\[
O_t
=
\operatorname{clip}
\left(
O_{t-1}
+
\sum_{d \in \mathcal{D}}
\Delta O_{d,t},
0,
O_{\mathrm{rated}}
\right)
\]

The system retains an uncertainty estimate:

\[
\sigma_{O_t}^2
=
\sigma_{O_{t-1}}^2
+
\sum_{d \in \mathcal{D}}
\left(
\frac{
1
}{
1 / (\sigma_{d,t}^{\mathrm{vision}})^2
+
1 / (\sigma_{d,t}^{\mathrm{IR}})^2
}
\right)
\]

When camera and infrared estimates diverge beyond a configured threshold, report lower confidence and request sensor inspection. Do not infer that a particular rider caused the discrepancy.

## Ventilation Indicator

Let:

- \(CO2_t\): cabin CO2 concentration.
- \(CO2_t^{\mathrm{out}}\): outdoor background concentration where available.
- \(O_t\): fused occupancy.
- \(H_t\): HVAC ventilation state.
- \(D_t\): door-open fraction.

\[
V_t
=
\operatorname{clip}
\left(
1 -
\frac{
(CO2_t - CO2_t^{\mathrm{out}})_+
}{
CO2_{\mathrm{reference}} - CO2_t^{\mathrm{out}} + \epsilon
},
0,
1
\right)
\]

The ventilation indicator is a relative operational signal, not a diagnosis of air safety. It should be interpreted together with occupancy trend, door-open periods, HVAC state, outdoor conditions, particulate monitoring where available, and the vehicle’s applicable ventilation design requirements.

## Rider-Facing Status

| Status | Occupancy display | Ventilation display | Accessible presentation |
|---|---|---|---|
| Comfortable | Low or moderate occupancy with high confidence | Favorable current ventilation indicator | Text, icon, high-contrast color-independent label, speech-compatible status |
| Busy | Elevated occupancy or moderate uncertainty | Ventilation indicator remains within current operating band | Text, icon, accessible web feed, voice announcement option |
| Crowded | High occupancy relative to rated capacity | Show current ventilation indicator and uncertainty | Text, icon, next-vehicle alternative, accessible-route suggestion |
| Check conditions | Sensor disagreement, low confidence, or environmental sensor fault | Do not make a strong air-quality claim | Text explanation, report time, alternative vehicle or station information |

The dashboard must not use color as the sole communication channel. It must provide text equivalents, clear time stamps, high contrast, screen-reader-compatible markup, and a low-bandwidth mode. Transit agencies commonly report operating and asset data through public performance systems; the architecture extends that transparency to rider-usable occupancy and ventilation information while retaining privacy boundaries. [160]

## Kafka Topics

```text
transit.vehicle.sensor.raw.v1
transit.vehicle.count.delta.v1
transit.vehicle.environment.v1
transit.vehicle.occupancy.fused.v1
transit.vehicle.rider.status.v1
transit.vehicle.sensor.health.v1
```

Raw topics must be retained only for the shortest approved diagnostic window and may contain no images, audio, biometric, identity, or trajectory payloads.

Fused and rider-status topics contain only:

- Vehicle pseudonym or rotating service identifier.
- Route and service direction.
- Coarse timestamp.
- Aggregate occupancy estimate and uncertainty.
- Relative occupancy band.
- CO2 concentration and ventilation-indicator band.
- Sensor health and confidence.
- Accessibility-relevant service notices.

## Flink Processing

The Flink job must:

- Validate schema and units.
- Reject stale, duplicate, non-finite, or implausible observations.
- Join doorway events with vehicle door-state windows.
- Apply inverse-variance fusion.
- Maintain keyed occupancy state by rotating vehicle-service identifier.
- Compute rolling CO2 trend and ventilation indicator.
- Emit rider-facing status with confidence.
- Emit sensor-health events when disagreement or drift persists.
- Apply retention and redaction policy before sink.
- Never emit raw images, video, audio, faces, embeddings, or identity attributes.

## Time-Series Storage

Store aggregate records in a time-series database with:

- Rotating vehicle-service identifier.
- Route and service direction.
- Time bucket.
- Aggregate occupancy estimate.
- Confidence interval.
- CO2, temperature, humidity, and ventilation indicator.
- HVAC and door-state aggregates.
- Sensor-health status.
- Accessibility-alert status.
- Schema version and calibration version.

Retention policy:

- Rider-facing recent status: short operational retention.
- Aggregate performance and calibration statistics: approved longer retention.
- Camera frames: zero retention after local inference.
- Raw infrared event sequence: shortest validated diagnostic retention.
- No join with fare, security, identity, device, or personnel systems.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.93 | Uses redundant sensing, uncertainty propagation, environmental context, stream validation, and explicit retention boundaries |
| eco_impact_value | 0.70 | Supports ventilation-aware operations, better vehicle utilization, and targeted HVAC maintenance without unnecessary fleet expansion |
| harm_risk | 0.19 | Reduced through edge-only counting, no image retention, identity prohibition, rotating identifiers, and accessible public reporting |
| accessibility_impact | 0.98 | Publishes real-time crowding and ventilation context through accessible, no-app, multimodal channels |
| rights_alignment | 0.99 | Prohibits surveillance reuse, identity profiling, discriminatory routing, and inaccessible information channels |
