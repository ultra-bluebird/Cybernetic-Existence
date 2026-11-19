# Multi-Sensor Automatic Door Wiring and MQTT Pattern

## Safety Scope

This pattern is for an accessible pedestrian automatic door. Final installation must use a listed door operator, listed safety devices, manufacturer-approved interfaces, qualified installation, inspection, and the locally applicable building, electrical, and accessibility requirements.

Do not place a general-purpose microcontroller in the sole safety path of a production door operator. The listed operator, its monitored entrapment protections, emergency release, force limitation, and manual operation provisions remain authoritative.

Automatic door and gate standards address entrapment protection; designs commonly require independent protection methods for entrapment zones. The specific applicable standard and installation configuration must be verified with the operator manufacturer and qualified installer. [75][79][82]

## Electrical Domains

Separate electrical domains physically and electrically:

- Mains and door-operator power remain inside the listed operator enclosure and are serviced only by qualified personnel.
- The control enclosure receives only isolated low-voltage power from a listed, fused DC supply.
- LiDAR, ultrasonic array, pressure-mat interface, microcontroller, and MQTT gateway operate in the isolated low-voltage domain.
- Use opto-isolated or safety-rated relay/interface modules for every signal crossing from the edge controller toward the listed operator.
- Never use the edge controller to bypass, suppress, emulate, or defeat the operator’s monitored safety inputs.
- Provide manual open, manual stop, and emergency release paths independent of the microcontroller and network.

## Low-Voltage Wiring Topology

```text
Listed AC Supply
        |
        +--> Listed Automatic Door Operator
        |       |
        |       +--> Manufacturer-approved monitored safety inputs
        |       +--> Manual controls and emergency release
        |
        +--> Listed Isolated DC Power Supply
                |
                +--> Fused 24 VDC sensor branch
                |       |
                |       +--> 2D LiDAR
                |       +--> Ultrasonic sensor array
                |       +--> Pressure-mat interface
                |
                +--> Isolated DC-DC converter
                        |
                        +--> 5 VDC MCU and Ethernet/Wi-Fi gateway
                        +--> Watchdog supervisor
                        +--> Isolated relay/interface board
                                |
                                +--> Request-to-open input
                                +--> Reduced-speed request input
                                +--> Wider-opening request input
                                +--> Status feedback inputs
```

## Signal Wiring

Use shielded, correctly grounded low-voltage cabling for sensor data where required by the hardware vendor. Terminate shields at one defined point according to the sensor and enclosure grounding design to reduce ground-loop risk.

| Device | Recommended connection | Controller purpose |
|---|---|---|
| 2D LiDAR | Ethernet, RS-485, or vendor-supported serial interface | Maps protected and travel zones; supplies approach and obstruction context |
| Ultrasonic array | Individually labeled GPIO, I2C through robust bus isolation, or CAN-based node | Provides redundant near-field obstacle detection in zones subject to LiDAR occlusion |
| Pressure mat | Safety-rated monitored mat interface plus isolated diagnostic output | Provides contact-based occupancy protection; occupancy always blocks closing |
| Door operator feedback | Manufacturer-approved dry-contact status interface through opto-isolation | Confirms door position, motor movement, fault, and obstruction status |
| Door command interface | Manufacturer-approved low-voltage dry-contact inputs | Requests open, reduced speed, wider opening, or controlled close only |
| Watchdog | Hardware watchdog output to controller power-enable or approved fault relay | Places the edge controller into fault state when firmware stalls |
| Network gateway | Isolated Ethernet preferred; segmented Wi-Fi only when required | Publishes limited health and aggregate status; never becomes a control dependency |

## Redundancy and Fusion

The controller creates three independent evidence classes:

- LiDAR is the spatial, non-contact observation layer.
- Ultrasonic sensors are the near-field, non-contact redundancy layer.
- The pressure mat is the contact/occupancy protection layer.

Closing is permitted only when:

\[
\mathrm{CloseAllowed}
=
\mathrm{OperatorHealthy}
\land
\mathrm{PressureMatHealthy}
\land
\neg\mathrm{PressureOccupied}
\land
\neg\mathrm{LidarProtectedZone}
\land
\neg\mathrm{UltrasonicNearField}
\land
\neg\mathrm{MotorObstruction}
\]

Any safety evidence of occupancy or obstruction overrides a closing command.

\[
\mathrm{ReverseRequired}
=
\mathrm{Closing}
\land
(
\mathrm{PressureOccupied}
\lor
\mathrm{LidarProtectedZone}
\lor
\mathrm{UltrasonicNearField}
\lor
\mathrm{MotorObstruction}
)
\]

The requested motion speed is bounded:

\[
v_{\mathrm{cmd}}
=
v_{\mathrm{rated}}
\cdot
\begin{cases}
0.20, & \text{if an obstruction is detected or range is below 0.45 m} \\
0.45, & \text{if an object is within 1.20 m} \\
0.75, & \text{otherwise}
\end{cases}
\]

The listed operator remains responsible for enforcing manufacturer-approved rated motion and safety limits.

## Fail-Safe States

| Condition | Required state | Door behavior |
|---|---|---|
| Pressure mat active during closing | Reopen | Stop closing and request low-speed reopening |
| LiDAR and ultrasonic layers both unavailable | Fault locked open | Do not initiate closing through the edge controller; request maintenance |
| Pressure-mat health unavailable | Fault locked open | Do not initiate closing; report urgent maintenance |
| Controller watchdog timeout | Fault locked open | Operator remains available through independent manual and listed safety controls |
| Motor feedback mismatch | Fault locked open | Disable edge-controller motion requests and report maintenance |
| LiDAR/ultrasonic disagreement near travel path | Conservative fault | Hold or reopen, record disagreement, require review |
| MQTT or local network outage | Local-only operation | Network loss must not prevent immediate local safety action |

A fault state must favor accessible passage and prevention of entrapment. It must not trap a person inside a doorway or depend on cloud connectivity to make a safety decision.

## MQTT Status Reporting

MQTT is diagnostic-only. It must not carry remote open, close, speed, or safety-override commands.

Topic structure:

```text
augmented-hub/door/site-zone/status
augmented-hub/door/site-zone/maintenance
augmented-hub/door/site-zone/audit
```

Example status payload:

```json
{
  "state": "Opening",
  "fault": "None",
  "speed_ratio": 0.45,
  "opening_width_ratio": 1.0,
  "lidar_healthy": true,
  "ultrasonic_healthy_count": 6,
  "pressure_mat_healthy": true,
  "pressure_mat_occupied": false,
  "motor_healthy": true
}
```

MQTT controls:

- Use TLS with mutual authentication where the deployment supports it.
- Use separate credentials per door controller.
- Permit publish-only device credentials for the status topic.
- Retain no imagery, LiDAR scans, ultrasonic traces, raw identifiers, or raw audio in MQTT.
- Publish only state, aggregate health, fault category, and maintenance-relevant values.
- Rate-limit messages and reject malformed payloads.
- Log diagnostic events with a monotonic counter and time source.
- Keep all opening, closing, reversal, and fault decisions local to the edge controller and listed operator.

## Accessibility and Privacy

- Provide a clearly reachable physical open actuator and a non-contact activation method.
- Do not require a smartphone, biometric identifier, cloud account, continuous network connection, or voice command to access the door.
- Ensure sensor placement considers wheelchair users, mobility aids, children, guide animals, people carrying equipment, and varied approach speeds.
- Use visible and audible motion indication with adjustable volume and accessible maintenance notices.
- Process LiDAR and ultrasonic information as short-lived occupancy geometry; do not retain person trajectories or use the system for identification.
- Provide a posted accessible contact path for reporting unsafe door behavior.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.91 | Uses independent sensing, explicit fusion gates, low-voltage isolation, watchdog supervision, and conservative fault behavior |
| eco_impact_value | 0.56 | Supports durable, repairable access infrastructure with modest energy and material overhead |
| harm_risk | 0.20 | Reduced by retaining listed operator safety authority, redundant sensing, local-only safety decisions, and fault-locked-open behavior |
| accessibility_impact | 0.98 | Prioritizes independent access, variable opening width, low-speed response, manual paths, and non-network access |
| rights_alignment | 0.97 | Prohibits identification, remote safety overrides, surveillance retention, and access requirements tied to external identity systems |
