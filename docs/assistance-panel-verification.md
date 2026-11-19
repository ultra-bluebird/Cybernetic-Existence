# Assistance Panel Verification

## Scope

This checklist verifies a non-actuating, privacy-preserving assistance panel.
Passing a check does not authorize external actions, device control, surveillance,
identity verification, or a claim of universal compatibility.

## Primary-action responsiveness

- Confirm local focus, selection acknowledgment, and visible state updates target
  completion within 100 milliseconds on the supported reference device class.
- Measure local interaction feedback separately from network, remote API, hardware,
  and text-to-speech startup latency.
- Confirm degraded network status does not block local accessibility settings,
  undo, privacy controls, or human-help instructions.

## Keyboard and switch operation

- Confirm every primary action is reachable and operable with keyboard alone.
- Confirm focus order is visible, predictable, and does not trap the user.
- Confirm Escape closes the settings dialog and restores focus to its opener.
- Confirm a single activation can undo the most recent reversible local setting change.

## Screen-reader and language support

- Confirm every interactive control has an accessible name.
- Confirm status changes are announced through a polite live region.
- Confirm symbol support is supplementary and does not replace text labels.
- Confirm manual language selection is always available and requires no identity sign-in.

## Visual, auditory, and tactile alternatives

- Confirm high-contrast mode has non-color-only status indicators.
- Confirm text scaling remains operable at 200 percent and 400 percent zoom.
- Confirm audio feedback is adjustable and can be disabled.
- Confirm all essential audio or haptic outcomes have visual and text alternatives.

## Privacy and preference storage

- Confirm preferences contain no legal identity, biometric data, neural data, medical
  data, device serial number, augmentation status, or persistent tracking identifier.
- Confirm public or shared-device mode uses session-only or explicitly short-lived storage.
- Confirm clearing preferences removes the local record.
- Confirm expired preference records are deleted rather than reused.
- Confirm interaction logs are ephemeral and not exported by default.

## Assistive adapter boundary

- Confirm connection requires explicit user interaction and consent.
- Confirm denial, timeout, unsupported adapter, and disconnect retain keyboard,
  pointer, switch-compatible, and human-help pathways.
- Confirm the adapter receives or emits only panel-level intents.
- Confirm no raw signals, telemetry, device configuration, identifiers, or
  credentials are recorded by default.

## Human review and correction

- Confirm every consequential workflow exposes a human or non-digital alternative.
- Confirm a correction or appeal path is visible when the panel presents service information.
- Confirm no panel state alone transmits a request, changes a civic-service record,
  initiates a service decision, or triggers physical infrastructure.
