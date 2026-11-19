# INF-03 and INF-04 Methodology

## Purpose

INF-03 defines the minimum repair-relevant telemetry needed to diagnose and maintain sensors and public-infrastructure actuators. INF-04 defines a signed update, health-check, recovery, rollback, and audit protocol that works during intermittent or absent network connectivity.

The combined principle is:

\[
\text{repair observability}
\ne
\text{person surveillance}
\]

\[
\text{secure update}
=
\text{verified package}
+
\text{atomic installation}
+
\text{health validation}
+
\text{offline rollback}
+
\text{accountable audit}
\]

Repair telemetry is limited to device state, component condition, calibration condition, repair compatibility, and tamper-evident maintenance evidence. It does not collect worker productivity, worker identity, resident identity, personal location, video, audio, biometric data, neural data, assistive-technology telemetry, cybernetic status, or behavioral activity records.

## INF-03: Repairability Telemetry

### Minimum telemetry

The repairability minimum is:

\[
T_{\text{repair,min}}
=
\{
F,
D,
V,
C,
K,
H
\}
\]

Where:

| Symbol | Field | Repair purpose |
|---|---|---|
| \(F\) | Fault code | Identifies standardized detected failure class |
| \(D\) | Diagnostic state | Indicates normal, degraded, faulted, safe-mode, or unknown condition |
| \(V\) | Firmware version | Determines update and component compatibility |
| \(C\) | Cycle count | Supports wear and lifecycle maintenance estimation |
| \(K\) | Calibration status | Indicates current, due soon, overdue, or verification-required state |
| \(H\) | Repair-history digest | Provides tamper-evident repair-chain integrity without exporting a detailed behavior history |

Useful optional non-personal repair fields are:

- Battery or power-health scalar.
- Sensor signal-quality scalar.
- Communication-link quality scalar.
- Actuator position feedback.
- Environmental enclosure state, such as suspected water ingress, thermal stress, or physical damage.
- Compatible replacement-part class.
- Local log integrity state.
- A bounded calibration-due estimate.
- Configuration-schema version.

The telemetry should report **state**, not a continuous narrative of activity.

For example:

```text
fault code: sensor_signal_out_of_range
diagnostic state: degraded
firmware version: 2.4.1
cycle count: 1200
calibration status: verification_required
enclosure condition: thermal_stress_suspected
repair history digest: available
```

This record can guide a technician toward inspecting the sensor face, enclosure seal, connector, power source, temperature exposure, reference comparison, and calibration need without reporting who visited the site, when a worker was present, who used nearby public infrastructure, or what a person was doing.

### Remote diagnosis boundary

Remote diagnosis may answer narrowly bounded questions:

| Diagnostic question | Allowed telemetry |
|---|---|
| Is power healthy? | Battery, input-voltage, or power-health scalar |
| Is the device running compatible firmware? | Firmware version and hardware revision |
| Is calibration due or verification required? | Calibration status and bounded uncertainty state |
| Has wear exceeded a planning threshold? | Cycle count and component class |
| Is the sensor signal degraded? | Signal-quality scalar, range flag, drift alert, or communication-quality scalar |
| Is a valve or actuator reporting its expected position? | Position feedback and fault state |
| Is the enclosure possibly damaged? | Environmental enclosure-condition code |
| Is the repair record intact? | Repair-history digest and local-log integrity result |

Remote diagnosis must not:

- Remotely actuate a safety-critical device merely because a diagnostic state is available.
- Collect or transmit worker identity, productivity, route history, personal devices, biometric information, neural data, or augmentation telemetry.
- Record or inspect audio, video, keystrokes, free-text narratives, or unrelated user interactions.
- Treat the presence, absence, timing, or movement of a worker or resident as maintenance telemetry.
- Use device diagnostic data to determine public-service eligibility, surveillance priority, employee discipline, housing status, or social scoring.

The standard requires local physical confirmation before completing a safety-critical repair. This preserves an accountable boundary between device condition reporting and interventions that can affect water, air, cooling, transit, environmental, or other essential systems.

### Repair-history digest

A repair-history digest permits integrity checks without transmitting a detailed repair log:

\[
H_t
=
\operatorname{Hash}
\left(
H_{t-1}
\Vert
E_t
\right)
\]

Where:

| Term | Meaning |
|---|---|
| \(H_{t-1}\) | Previous local maintenance digest |
| \(E_t\) | Canonical non-personal repair event record |
| \(H_t\) | New tamper-evident digest |

A canonical repair event can contain:

```text
event type: calibration_verification_completed
firmware compatibility class: declared
replacement part class: declared
diagnostic state before repair: degraded
diagnostic state after repair: normal
calibration result class: passed
local timestamp bucket: declared maintenance period
```

The record excludes technician name, employee identifier, exact worker location, biometric evidence, camera imagery, personal device data, free-text commentary, and resident information.

A full local audit log can be retained under bounded maintenance governance. The remote service receives only the current digest, bounded state, and repair outcome class needed for diagnosis.

## INF-04: Secure Update and Rollback

### Trust chain

The device accepts firmware only through an authenticated chain:

\[
K_{\text{root}}
\rightarrow
K_{\text{release}}
\rightarrow
\operatorname{Sign}(H(\text{image}))
\]

Where:

| Component | Role |
|---|---|
| Root trust key | Anchors release-key authorization and controlled key rotation |
| Release key | Signs ordinary device-class or hardware-class update packages |
| Firmware image digest | Verifies that the complete image is unchanged |
| Signature | Verifies that an authorized signing key approved that exact image |
| Secure boot | Verifies an authorized executable image before execution |
| Rollback floor | Blocks installation of known-vulnerable versions below the approved minimum |
| Recovery key quorum | Permits controlled root rotation or emergency recovery without unilateral control |

NIST firmware-resiliency guidance focuses on mechanisms to protect firmware and critical data against unauthorized change, detect unauthorized modifications, and recover securely following corruption or attack. [185][188][190]

NIST’s IoT update capability catalog calls for updates by authorized entities through secure, configurable mechanisms, including the ability to validate an update before installation and to support locally delivered updates where needed. [191][195]

### Update phases

| Phase | Required operation | Fail-closed result |
|---|---|---|
| Package preparation | Build a complete immutable image, compatibility manifest, digest, signature, rollback floor, and health-check manifest | Package is not distributable |
| Distribution | Deliver the complete signed package through network, removable media, local maintenance terminal, or other approved channel | Incomplete transfer is not installable |
| Pre-install verification | Verify target device class, hardware revision, digest, signature chain, bootloader version, version floor, authorization, and local availability | Reject package before modifying any active firmware |
| Staging | Write only to inactive firmware slot | Preserve active verified slot |
| Atomic activation | Change boot selection only after full staged-image verification | Maintain current slot if any staging step fails |
| Post-install health checks | Verify secure boot, image integrity, storage, configuration, sensor sanity, calibration state, and actuator safe state | Roll back, safe-mode, or hold according to declared check rule |
| Commit | Mark new slot verified only after required checks pass | Do not destroy previous verified image |
| Rollback | Restore a previously verified slot locally, without a network request | Enter safe mode if no verified rollback image remains |
| Audit | Append a non-personal tamper-evident lifecycle event | Record outcome without worker or resident surveillance |

The secure boot and firmware image must use modern, independently reviewed cryptographic implementations. This specification supports Ed25519, ECDSA P-256 with SHA-256, or RSA-PSS with SHA-256 based on platform and compatibility constraints. Key and algorithm choices require implementation-specific cryptographic review.

### Atomic A/B installation

The required storage design is dual-slot:

```text
active slot: known-good firmware image
inactive slot: candidate firmware image
boot metadata: authenticated selection and confirmed-boot state
recovery partition: minimal verified rollback and diagnostic capability
```

The sequence is:

1. Acquire a complete package locally or from an approved distribution source.
2. Verify the package digest and signature before writing.
3. Verify device class, hardware revision, bootloader compatibility, and version floor.
4. Write the image to the inactive slot.
5. Verify the written inactive image digest.
6. Change authenticated boot metadata atomically to request a one-time candidate boot.
7. Perform declared post-boot health checks.
8. Commit the candidate slot only when all required checks pass.
9. Roll back automatically if a required rollback-triggering check fails.
10. Preserve an accessible human-maintenance and non-digital support route throughout the process.

An interrupted network transfer cannot create a valid candidate image because installation requires a complete locally verified package. A completed package may be transferred through removable media or a local maintenance interface and verified independently of network availability.

### Key rotation without bricking

Key rotation must be **additive before subtractive**:

\[
K_{\text{trusted,next}}
=
K_{\text{trusted,current}}
\cup
K_{\text{new}}
\]

Only after successful verification, a defined transition period, and an independent recovery quorum may the old key be removed:

\[
K_{\text{trusted,final}}
=
K_{\text{trusted,next}}
-
K_{\text{retired}}
\]

Required rotation controls:

- Maintain at least one recovery trust path independent of the ordinary release key.
- Require a threshold quorum of at least two authorized recovery keys for root-key rotation.
- Sign rotation manifests with both current and new trust authority during the transition whenever feasible.
- Keep a verified recovery partition or offline maintenance path that recognizes both keys during the rotation window.
- Test rotation and rollback in representative offline conditions before broad deployment.
- Do not destroy prior trust material until the new trust chain has successfully booted and passed health checks.
- Log rotation outcome as a non-personal, tamper-evident event.
- Provide accessible update notices, public maintenance documentation, and human support without requiring device ownership telemetry or user identity disclosure.

### Rollback triggers

| Trigger | Default response |
|---|---|
| Signature or digest verification failure | Reject before install |
| Hardware or device-class mismatch | Reject before install |
| Firmware version below rollback floor | Reject before install |
| Boot failure, secure-boot failure, or firmware-integrity failure | Automatic rollback to previous verified slot |
| Storage or configuration-schema corruption | Automatic rollback or safe mode, according to recovery policy |
| Safety-critical actuator cannot demonstrate safe state | Enter safe mode and require accountable local review |
| Sensor output fails critical plausibility or calibration integrity check | Roll back or mark degraded; exclude from decision-critical automated use pending verification |
| Communication loss after update | Do not automatically roll back solely for loss of optional network connectivity; preserve local and offline function |
| Required health check times out | Roll back or safe mode according to its declared criticality |
| Partial network distribution failure | Do not install incomplete package; retain current active slot |

The protocol distinguishes **safety-critical local health** from **optional connectivity**. A public sensor or actuator should remain safe and locally diagnosable during network loss. Connectivity failure alone is not a reason to replace a verified local image with a different unknown state.

### Audit record

The audit record is tamper-evident, bounded, and non-personal:

\[
A_t
=
\operatorname{Hash}
\left(
A_{t-1}
\Vert
\text{package digest}
\Vert
\text{verification result}
\Vert
\text{health result class}
\Vert
\text{rollback or commit result}
\right)
\]

The minimum audit event includes:

```text
event class: update_staged, update_committed, rollback_completed, safe_mode_entered, or update_rejected
package version: declared
package digest: declared
signature verification: passed or failed
compatibility verification: passed or failed
post-install health status: passed, failed, timed out, or not run
final device state: active slot, prior slot, or safe mode
non-personal maintenance time bucket: declared
audit digest: available
```

It excludes personally identifying worker or resident information and does not become a performance-monitoring system.

CISA’s Secure by Design guidance emphasizes that security should be built into product design and development rather than transferred onto end users through unsafe defaults or opaque operational burdens. [186][189]

## Testing requirements

The update system must be tested through:

- Valid signed image installation.
- Altered-image digest rejection.
- Invalid signature rejection.
- Unsupported hardware rejection.
- Rollback-floor rejection.
- Interrupted network transfer with no install attempt.
- Offline removable-media installation.
- Offline rollback after a failed post-install health check.
- Secure-boot failure rollback.
- Safety-critical actuator safe-mode transition.
- Root-key rotation using the independent quorum path.
- Failed key rotation with retention of the prior trust chain.
- Audit-digest continuity.
- Confirmation that telemetry contains no worker, resident, biometric, neural, augmentation, audio, video, device-identity, or free-text surveillance data.
- Confirmation that essential public services continue through human, offline, and non-digital paths while infrastructure devices are maintained.

## Metrics

| Metric | Score | Basis |
|---|---:|---|
| `knowledge_factor` | 0.95 | Typed telemetry boundary, cryptographic trust chain, dual-slot state machine, rollback triggers, offline recovery, and deterministic tests provide strong reviewability |
| `eco_impact_value` | 0.91 | Repairable infrastructure extends asset life, reduces premature replacement, supports accurate sensing, and protects water, air, cooling, transit, and ecological operations |
| `harm_risk` | 0.10 | Minimal telemetry, no remote control, local confirmation for safety-critical repair, signature checks, atomic installation, rollback, safe mode, and key quorum constrain operational and surveillance risks |
| `accessibility_impact` | 0.90 | Offline recovery, accessible notices, human support, and continuity planning preserve access when devices or networks are unavailable |
| `rights_alignment` | 0.99 | The standard directly protects privacy, repair, maintenance, interoperability, offline access, accountability, and freedom from surveillance-based service conditions |
