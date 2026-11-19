# Pacing and Emergency Access Completion Protocol

Protocol version: 1

## Scope

Complete and integrate:
- Age-neutral assistive communication pacing.
- Emergency access without private-system disclosure.

## Planned files

| Topic | Source | Test |
|---|---|---|
| Pacing | kotlin/continuity/AssistivePacing.kt | tests/kotlin/continuity/AssistivePacingTest.kt |
| Emergency access | kotlin/accessibility/EmergencyAccess.kt | tests/kotlin/accessibility/EmergencyAccessTest.kt |

Packages:
- augmentedhub.continuity
- augmentedhub.accessibility

## Dependencies

Shared foundation and applicable validation patterns.

Domain scaffolding:
- PacingVocabulary.
- EmergencySeparationContract.

## Exact sequence

### Establish scope

- Bind work to the exact existing implementation.
- Identify response-window, selection, authentication, and draft lifecycles.
- Keep emergency access independent of those lifecycles.

### Implement pacing

- Offer the six settings without age declaration or inference.
- Define pause/resume semantics explicitly.
- Preserve accumulated active time where the contract requires it.
- Distinguish response-window continuation from restarting a selection.
- Do not auto-submit when timing ends or resumes.
- Bound configurable timing and presentation values.
- Define draft ownership, retention, and public-device handover.
- Keep user-facing errors typed and accessible.
- Preserve direct assistance.

### Implement emergency access

- Keep contact instructions and local contact controls independent of audit,
  profile import, account checks, and research consent.
- Separate access, responder communication, and follow-up.
- Inspect direct and transitive blocking dependencies.
- Keep failed audit results away from the access prerequisite chain.
- State location-specific pathway limitations.
- Do not claim that a local interface intent contacted a responder.
- Do not automatically transmit profiles, traces, maps, or private inventories.

### Deliver tests

Pacing:
- Initial state, pause/resume, no-limit mode, and timing changes.
- Exact expiry boundary.
- Clock faults and stale selection evidence.
- Draft retention and explicit clearing.
- Invalid settings and post-close operations.
- No age-dependent gate or automatic submission.

Emergency access:
- Access available while audit fails or is missing.
- Indirect audit/profile/account dependency.
- Unavailable communication alternatives.
- Separation of preconnection forms from responder questions.
- No live contact in synthetic tests.

### Complete integration

- Specify native focus, switch, screen-reader, localization, and timing behavior.
- Specify actual contact adapters and failure presentation.
- Arrange any live emergency test through a separately authorized process.
- Do not substitute nearby assistance for a usable direct contact pathway.

### Close the batch

- Supply both complete sources and tests.
- Update coordination records.
- Report actual execution separately from supplied test code.
- End with the fixed session-state declaration.

## Completion boundary

Neither a pacing enum nor a contact instruction is an implemented accessible UI.
Integrated platform testing remains required.
