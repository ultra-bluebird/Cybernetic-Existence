# Electronic Conversion of Legacy Streetlights to Smart Nodes

## Purpose

This pattern retrofits existing streetlights with environmental sensing, edge processing, LoRaWAN communication, optional mesh relay capability, and a gateway bridge to MQTT.

The lighting system remains a safety-critical public asset. The retrofit must not create a remote pathway that can unexpectedly turn off lighting, narrow accessible pedestrian visibility, create surveillance capability, or disable local photocell or timer behavior during network failure.

Final installation requires qualified electrical engineering, utility approval, applicable electrical-code compliance, pole structural review, luminaire compatibility verification, lightning protection, and public procurement review.

## System Boundary

The retrofit node may measure:

- Ambient temperature.
- Relative humidity.
- Barometric pressure.
- Light level.
- Noise level as non-recorded aggregate sound-pressure level where lawful.
- Air-quality indicators using appropriately calibrated environmental sensors.
- Pole power, voltage, current, energy use, and luminaire health.
- Tilt, enclosure open, water ingress, and battery state.

The retrofit node must not collect:

- Video.
- Images.
- Raw audio.
- Faces.
- Device identifiers.
- Wi-Fi or Bluetooth tracking data.
- License plates.
- Biometric data.
- Neural data.
- Augmentation status.
- Person-level location or behavior data.

## Electrical Wiring Pattern

```text
Utility feeder
    |
    +--> Pole service disconnect
            |
            +--> Surge protection device
                    |
                    +--> Listed luminaire driver and lamp
                    |       |
                    |       +--> Existing photocell or approved local controller
                    |
                    +--> Fused isolated auxiliary supply
                            |
                            +--> AC-to-DC power supply
                                    |
                                    +--> 24 VDC protected sensor rail
                                    |       |
                                    |       +--> Environmental sensor module
                                    |       +--> Power and luminaire health monitor
                                    |       +--> Enclosure/tilt/water-ingress sensors
                                    |
                                    +--> Isolated DC-DC converter
                                            |
                                            +--> 5 VDC or 3.3 VDC MCU rail
                                            |       |
                                            |       +--> Secure element
                                            |       +--> LoRaWAN radio
                                            |       +--> Optional mesh radio
                                            |       +--> Hardware watchdog
                                            |       +--> Local data buffer
                                            |
                                            +--> Supercapacitor or listed backup battery
                                                    |
                                                    +--> MCU, clock, low-rate telemetry
                                                    +--> Emergency outage beacon
```

## Lighting-Control Separation

- The existing photocell, astronomical timer, or listed luminaire controller remains capable of local lighting control without the edge node.
- The edge node may observe lamp status and energy use.
- Remote dimming or switching is permitted only through a listed, utility-approved luminaire interface with local safety defaults and documented public policy.
- Environmental-sensor failure, radio failure, gateway failure, cloud failure, or edge-compute failure must not extinguish the light.
- A network command must never override an emergency lighting policy, local safety control, or a documented accessibility lighting minimum.
- The retrofit does not connect a general-purpose MCU directly to mains switching circuitry.

## Power Management

Normal operation:

- Sample environmental sensors at a policy-defined interval.
- Apply local filtering and quality checks.
- Transmit compact telemetry on LoRaWAN.
- Keep CPU and radio in low-power modes between sampling windows.
- Use event-triggered reporting for enclosure tamper, pole tilt, water ingress, lamp failure, extreme heat, and power outage.
- Record only a bounded local ring buffer for environmental calibration and device diagnostics.

Outage mode:

- Detect loss of AC feeder power.
- Preserve lighting behavior through the existing luminaire’s approved emergency or fail-safe design where installed.
- Switch the node to supercapacitor or battery reserve.
- Disable nonessential sensors and all optional mesh relay functions.
- Send one or more rate-limited outage beacons with power-state, battery estimate, and health summary.
- Preserve accurate time using a low-power clock.
- Do not perform remote firmware installation during outage mode.
- Return to normal sampling only after stable grid restoration and self-test.

The node must state battery reserve as a confidence estimate, not a guarantee. Battery sizing requires local load, climate, maintenance, and utility-outage analysis.

## LoRaWAN and MQTT Path

```mermaid
flowchart LR
    NODE[Streetlight edge node] --> LORA[LoRaWAN uplink]
    LORA --> GW[Authenticated LoRaWAN gateway]
    GW --> NS[LoRaWAN network and join service]
    NS --> APP[Application service]
    APP --> MQTT[MQTT broker]
    MQTT --> DASH[Operations and public aggregate dashboards]
```

LoRaWAN employs standardized cryptographic design and well-vetted algorithms; secure deployments still require correct key handling, device authentication, gateway hardening, replay protection, and secure lifecycle management. [209][206] LoRaWAN implementations commonly use separate network and application session-key material, authenticated joins, and frame counters to protect confidentiality and integrity; Over-the-Air Activation supports fresh session keys. [208][212]

## LoRaWAN Security Controls

- Use Over-the-Air Activation rather than static activation where supported.
- Store root keys in a secure element, not general MCU flash.
- Assign unique device credentials to every node.
- Enforce frame-counter monotonicity and reject replayed messages.
- Use application-layer payload encryption and authenticated gateway-to-service links.
- Restrict gateway administration to separate privileged identities.
- Segment gateway management traffic from municipal IT, public Wi-Fi, and lighting-control networks.
- Use signed firmware images, secure boot, and authorized update validation.
- Maintain software and configuration inventory.
- Rotate credentials through an approved lifecycle process.
- Record only device-health and environmental telemetry required for the approved purpose.

NIST’s IoT cybersecurity program identifies lifecycle cybersecurity activities for manufacturers and operators, while secure boot, validated firmware updates, device identification, and authorized configuration control are foundational IoT practices. [204][213][215]

## MQTT Topic Design

```text
augmented-hub/streetlight/telemetry/v1
augmented-hub/streetlight/health/v1
augmented-hub/streetlight/outage/v1
augmented-hub/streetlight/calibration/v1
```

Payload example:

```json
{
  "schema_version": "1.0.0",
  "node_pseudonym": "rotating-service-node",
  "observed_at": "2026-09-01T00:00:00Z",
  "temperature_c": 36.2,
  "relative_humidity_percent": 18.0,
  "illuminance_lux": 4.8,
  "luminaire_state": "operational",
  "grid_power_present": true,
  "battery_confidence": 0.92,
  "sensor_confidence": 0.88
}
```

The MQTT bridge must use mutually authenticated encrypted transport, device-specific authorization, payload-size limits, rate limits, schema validation, and retained-message restrictions. It must not expose root keys, precise resident behavior, raw sensor streams beyond policy retention, or direct lighting-control commands through public topics.

## Gateway Responsibilities

The Python gateway service must:

- Validate LoRaWAN application payload schema.
- Verify device authentication through the network-server integration.
- Reject stale, malformed, replayed, or out-of-range telemetry.
- Publish only normalized application messages to MQTT.
- Maintain a local queue during broker outage.
- Apply rate limits and back-pressure.
- Separate operations telemetry from public aggregate dashboard output.
- Publish calibration and confidence state.
- Issue maintenance alerts for tilt, water ingress, voltage anomaly, lamp failure, or persistent sensor drift.
- Never transform environmental telemetry into person-level behavioral analytics.

## Fail-Safe States

| Failure condition | Streetlight behavior | Node behavior |
|---|---|---|
| Edge MCU fault | Existing local light control remains active | Watchdog resets MCU; health fault sent after recovery |
| LoRaWAN unavailable | Light remains locally controlled | Buffer bounded telemetry and retry using backoff |
| Gateway unavailable | Light remains locally controlled | Network server queues or node retries without changing lighting |
| MQTT unavailable | Light remains locally controlled | Gateway buffers approved telemetry; no public command fallback |
| Environmental sensor fault | Light remains locally controlled | Mark environmental data invalid and request maintenance |
| Grid outage | Existing emergency-lighting design remains authoritative | Enter low-power outage beacon mode |
| Battery low | Existing lighting function unchanged | Stop nonessential sensing and preserve essential outage telemetry |
| Secure boot or firmware validation failure | Existing listed lighting controls remain active | Node remains non-operational and exposes a maintenance fault state |

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.93 | Uses electrical separation, local lighting continuity, isolated rails, low-power telemetry, LoRaWAN security, gateway validation, and outage states |
| eco_impact_value | 0.79 | Supports targeted maintenance, energy monitoring, adaptive public lighting policy, and environmental sensing without large new infrastructure |
| harm_risk | 0.17 | Reduced through no surveillance sensors, local lighting fallback, secure boot, signed updates, network isolation, and fail-safe power behavior |
| accessibility_impact | 0.94 | Protects lighting continuity for pedestrian accessibility and makes environmental information available without app-only access |
| rights_alignment | 0.98 | Excludes person-level tracking, keeps lighting independent from network control, and requires privacy-minimized public telemetry |
