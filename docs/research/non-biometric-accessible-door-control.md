# Non-Biometric Accessible Automatic Door Control

## Purpose

This research object specifies a privacy-preserving automatic pedestrian-door controller that provides dignified, accessible entry and exit without biometric scanning, device authentication, identity verification, augmentation detection, mobility-aid classification, or continuous personal tracking.

The controller opens and holds a door safely based on anonymous environmental signals.

It must provide equal access for:

- people walking independently
- people using wheelchairs
- people using walkers, canes, crutches, or other mobility aids
- people using prosthetics or cybernetic assistive technology
- people accompanied by caregivers or service animals
- people carrying packages, medical equipment, or other necessary items
- people using non-digital, offline, or manual access pathways

The controller is an accessibility and safety system.

It is not an identity system.

It is not an eligibility system.

It is not a surveillance system.

It is not a mechanism for ranking, restricting, or conditionally granting access to essential services.

## Rights Constraints

The controller must not collect, store, infer, transmit, or use:

- facial templates
- fingerprints
- iris data
- gait patterns
- voiceprints
- device identifiers
- wireless identifiers
- mobile-phone identifiers
- Bluetooth identifiers
- Wi-Fi identifiers
- implant identifiers
- prosthetic identifiers
- augmentation status
- disability status
- health information
- individual movement histories
- demographic inferences
- financial information
- social or behavioral scores

The controller must not require:

- a phone
- a wearable
- a badge
- a wallet
- a digital identity
- biometric enrollment
- continuous connectivity
- a proprietary device
- a specific mobility aid
- disclosure of an augmentation or assistive technology
- consent to unrelated telemetry

Manual and accessible activation routes must remain available even when automated sensing, local software, or network connectivity is unavailable.

## Functional Objective

The system opens a pedestrian door when anonymous presence indicates an approach or an accessible manual actuator is used.

The system prevents closing while a person, mobility aid, service animal, object, or other obstruction remains in the monitored door zone.

The system does not attempt to identify what or who caused a sensor activation.

## Core Conditions

Let:

- \(d_{\mathrm{approach}}\) be the anonymous detected distance to an approaching object in the activation zone
- \(d_{\mathrm{safe}}\) be the configured approach activation distance
- \(A_{\mathrm{door}}\) be the monitored opening, closing, threshold, and swing-path safety area
- \(O(A_{\mathrm{door}})\) be the anonymous obstruction predicate for the monitored door area
- \(M\) be the accessible manual-activation predicate
- \(E\) be the emergency-egress predicate
- \(H\) be the sensor-health predicate

The activation condition is:

\[
\texttt{OpenCommand} =
M
\lor
E
\lor
(d_{\mathrm{approach}} < d_{\mathrm{safe}}
\land
H_{\mathrm{activation}})
\]

The closing condition is:

\[
\texttt{CloseCommand} =
\neg O(A_{\mathrm{door}})
\land
H_{\mathrm{safety}}
\land
\texttt{minimum\_open\_time\_elapsed}
\]

The door must not close when the safety system detects an obstruction:

\[
O(A_{\mathrm{door}})
\Rightarrow
\neg \texttt{CloseCommand}
\]

If the system detects a safety-sensor fault, sensor disagreement, untrusted sensor state, or controller health failure, it must enter a safe configured mode appropriate to the door type and building emergency plan.

The controller must never interpret an unknown object as evidence that no person is present.

## Non-Biometric Sensing Strategy

### Activation sensing

Activation sensors detect that an object or person is approaching the door.

The preferred activation configuration uses at least two anonymous modalities where site conditions warrant redundancy:

- microwave or radar motion sensing
- passive infrared motion sensing
- ultrasonic proximity sensing
- pressure-sensitive activation mat where physically appropriate
- accessible push plate or push button
- contactless accessible activation control
- physical pull, push, or low-force fallback route

Activation sensors may open a door.

Activation sensors must not be used alone to determine that it is safe to close a door.

### Presence and obstruction sensing

Presence and obstruction sensors detect whether the monitored door area remains occupied.

The preferred safety configuration uses diverse sensing modalities:

- monitored active infrared presence sensors
- monitored photoelectric beams
- safety edges where door type and entrapment geometry require contact detection
- low-height and high-height coverage for people, mobility aids, service animals, packages, and objects
- door-operator inherent obstruction detection
- door-position and door-motion feedback

Presence sensors must cover the relevant approach, threshold, swing, and closing areas for the installed door type.

The controller must use presence sensing to inhibit or reverse unsafe closing.

### Sensor fusion

The controller fuses anonymous modality outputs into four separate predicates:

- approach detected
- monitored area occupied
- obstruction detected
- sensor health valid

It must not output:

- person identity
- person count
- demographic category
- disability category
- augmentation category
- confidence about a specific person
- persistent tracking identifier

## Reliability Requirements

### False rejection rate

For valid anonymous activation attempts under the test protocol:

\[
\mathrm{FRR} =
\frac{
N_{\mathrm{valid\ attempts\ without\ timely\ access}}
}{
N_{\mathrm{valid\ activation\ attempts}}
}
\]

The operational target is:

\[
\mathrm{FRR} < 0.001
\]

The test protocol must include:

- bright sunlight
- shade
- rain where the installation is exposed
- dust and debris conditions appropriate to the site
- night conditions
- glare and reflective surfaces
- people using mobility aids
- people moving slowly
- people moving unpredictably
- people approaching with service animals
- people carrying necessary equipment
- people using manual activators
- people approaching from varied heights and angles

The FRR target must be reported with its confidence interval, test sample size, sensor configuration, operating conditions, and unresolved limitations.

### False activation rate

Let:

\[
\mathrm{FAR} =
\frac{
N_{\mathrm{unnecessary\ openings}}
}{
T_{\mathrm{observation}}
}
\]

where \(T_{\mathrm{observation}}\) is the monitored operating duration.

False activation is an operational and energy-use concern.

It must not be reduced by tightening activation settings in a way that excludes slower-moving people, people using mobility aids, people carrying equipment, or people who require additional approach time.

### Door-zone safety coverage

Let \(A_{\mathrm{door}}\) be the area requiring safety coverage and \(A_{\mathrm{covered}}\) be the area covered by at least one validated presence sensor.

\[
C_{\mathrm{door}} =
\frac{
A_{\mathrm{covered}}
}{
A_{\mathrm{door}}
}
\]

The safety design objective is:

\[
C_{\mathrm{door}} = 1
\]

Safety-zone coverage must include the physical and temporal movement envelope of the installed door, including relevant thresholds, panels, swing arcs, and closing paths.

### Sensor-health condition

Let:

- \(h_i \in \{0,1\}\) indicate sensor health for sensor \(i\)
- \(m_i \in \{0,1\}\) indicate that sensor \(i\) is communicating and has completed required self-monitoring
- \(S_{\mathrm{required}}\) be the set of required sensors

The safety-sensor health predicate is:

\[
H_{\mathrm{safety}} =
\bigwedge_{i \in S_{\mathrm{required}}}
(h_i \land m_i)
\]

A required sensor failure must be observable by the controller.

The controller must not silently treat an unavailable safety sensor as a clear doorway.

## Tailgating Without Identification

Tailgating prevention must not be solved through identity verification, biometric surveillance, device authentication, or person tracking.

For public, civic, health, cooling, transit, emergency, and accessibility entrances, the default priority is safe and equitable passage. The controller should not attempt to decide whether a second person is authorized based on sensor interpretation.

Where a facility has a legitimate non-public controlled-area requirement, access control must be separate from the automatic-door safety and accessibility controller.

The access-control system must not:

- make essential service access dependent on a biometric check
- block emergency egress
- remove accessible manual activation
- use augmentation status as an access criterion
- require mobile-device presence for accessible passage
- cause a safety sensor to become an identity sensor

Privacy-preserving tailgating mitigations include:

- architectural zoning that separates public and controlled areas
- staffed and accessible reception routes
- door-held-open alerts without person identification
- anonymous passage-duration monitoring
- local alarm states that do not retain identity data
- physical layout that discourages unintended following while preserving mobility-aid clearance
- safety-first door timing based on occupancy, not assumed person count

A door controller may report:

- `door_open_duration_exceeded`
- `safety_zone_occupied`
- `sensor_disagreement`
- `manual_activation_used`
- `maintenance_required`

A door controller must not report:

- `tailgater_identity`
- `person_count`
- `suspected_disability`
- `suspected_augmentation`
- `device_present`
- `identity_confidence`

## Accessibility Requirements

The system must include:

- an accessible manual activation control
- clear floor space outside the hazardous door-swing area
- activation controls operable with one hand
- activation controls that do not require tight grasping, pinching, twisting, or excessive force
- clear visual, tactile, and plain-language signage
- accessible route continuity
- emergency egress continuity
- maintenance procedures that preserve accessible access during service
- an alternative route if an automatic door is unavailable
- low-height and high-height detection coverage appropriate to the installation
- audible and visual indicators where useful and non-disruptive
- a non-digital route for requesting assistance

The system must be evaluated against the applicable building, accessibility, fire-safety, door-operator, and local requirements before installation.

## Fail-Safe Behavior

The controller has three distinct failure responses.

### Activation-sensor failure

If only an activation sensor fails:

- preserve accessible manual activation
- preserve mechanical/manual door use where safe
- create a maintenance event
- do not deny entry because automated approach detection is unavailable

### Presence-sensor failure

If a required safety or presence sensor fails:

- inhibit automatic closing or enter the manufacturer-approved safe mode
- provide an accessible manual or staffed alternative
- create an urgent maintenance event
- do not operate in a mode that can expose people to an unmanaged entrapment risk

### Controller or communication failure

If the central controller, sensor bus, or network link fails:

- do not depend on external connectivity for door safety
- preserve local safety behavior
- preserve emergency-egress behavior
- preserve an accessible manual path
- store a local maintenance event where safe to do so
- do not erase fault records solely because a network is unavailable

## Privacy-Preserving Event Records

Event records must be operationally minimal.

Permitted event fields include:

- event time
- door-controller state
- anonymous sensor-health state
- anonymous sensor disagreement state
- obstruction state
- operator fault state
- manual-activation availability
- maintenance urgency
- configuration version

Event records must not include personal identifiers, persistent movement traces, images, audio, device identifiers, biometric information, or identity inferences.

## Acceptance Criteria

A door-control configuration is ready for controlled integration testing when:

- sensor inputs are anonymous by design
- no biometric or device-authentication requirement exists
- manual accessible activation is present
- door safety is locally operable without external connectivity
- activation and presence sensing are logically separated
- required presence sensors are monitored
- safety sensor failure produces an observable safe response
- no safety-sensor fault is interpreted as a clear zone
- essential-service access remains available through an accessible route
- event logs contain only minimum necessary operational data
- all settings are versioned
- a test matrix covers lighting, weather exposure, mobility aids, assistive technologies, slow approaches, varied approach angles, and manual activation
- the deployment profile identifies the applicable site-specific safety, building, and accessibility requirements

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| `knowledge_factor` | 0.94 | Sensor fusion, zone coverage, failure behavior, privacy constraints, accessibility requirements, and test criteria are specified |
| `eco_impact_value` | 0.69 | Redundant sensing can be designed for low-power local operation while reducing unnecessary door cycling and preserving durable manual fallback |
| `harm_risk` | 0.11 | Residual risk concerns sensor placement, installation geometry, controller failure, and untested environmental conditions; redundancy and fail-safe handling reduce exposure |
| `accessibility_impact` | 0.99 | The design centers anonymous access, mobility-aid compatibility, manual controls, safe egress, equivalent alternatives, and assistive-technology neutrality |
| `rights_alignment` | 0.99 | The system rejects biometric surveillance, identity-based eligibility, device dependence, telemetry coercion, and essential-service restrictions |
