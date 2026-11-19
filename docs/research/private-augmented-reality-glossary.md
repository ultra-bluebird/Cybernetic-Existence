# Private Augmented-Reality and Human-Integrated-Technology Glossary

## Purpose

Define a research vocabulary for improving augmented-reality interfaces,
assistive interaction, private continuity, interoperability, and responsible
resource use.

This glossary describes systems and their obligations. It does not classify
people, authenticate identities, inspect private integrations, establish medical
status, or authorize control of real-world equipment.

## Status labels

- Established: existing technical terminology; the definition is a working
  interpretation for this project.
- Adapted: an existing concept narrowed to this research context.
- Proposed: project-defined vocabulary requiring further research.

A term's inclusion does not establish implementation maturity, safety,
effectiveness, legal recognition, or compatibility with a particular device.

## Research boundaries

- Use synthetic scenes and non-sensitive fixtures before participant data.
- Do not require medical, neural, biometric, physiological, companion-system,
  credential, or institutional disclosure.
- Preserve voluntary cybernetic-host self-description without turning it into
  authentication, eligibility, ranking, diagnosis, or public status.
- Keep CyberRank personal preferences separate from system-governance duties.
- Do not infer identity, intent, emotion, health, or competence from interaction.
- Request separate approval before external actions, exports, or device changes.
- Keep research interfaces non-actuating unless a separately reviewed integration
  explicitly authorizes a narrowly scoped action.
- Restrict unsafe optional automation without blocking ordinary accessible
  service, human support, correction, or appeal.
- Record participant consent scope, prospective withdrawal options, retention,
  deletion limits, and review responsibility in plain language.
- Never treat access to essential assistance as consent to research.

## Spatial fidelity and display behavior

| Term | Status | Working definition | Near-term improvement and research measure |
|---|---|---|---|
| Spatial registration | Established | Alignment of displayed content with its intended physical-world position and orientation. | Compare alignment methods in synthetic or approved test scenes; report position error in millimeters and orientation error in degrees. |
| Spatial anchor | Established | A spatial reference used to keep digital content positioned relative to an environment. | Test anchor stability during viewpoint changes; measure displacement and recovery after tracking interruption. |
| Anchor persistence | Established | Restoration of an anchor across separate sessions. | Evaluate local save-and-restore behavior; measure restoration success and error without recording private locations unnecessarily. |
| Registration drift budget | Proposed | The maximum permitted accumulated alignment error for a specified display task before correction or a visible uncertainty notice is required. | Define task-specific bounds; measure drift, detection delay, and misleading placements. |
| Occlusion handling | Established | Determining when physical or digital surfaces should visually hide other displayed content. | Compare rendering against known scene geometry; measure incorrect visibility and boundary error. |
| Uncertainty-aware overlay | Proposed | An overlay that communicates uncertainty in its placement or source information rather than presenting uncertain content as precise. | Compare uncertainty cues; measure user understanding, task errors, and added distraction. |
| Motion-to-photon latency | Established | Time between a relevant user or device motion and the corresponding updated light emitted by the display. | Measure end-to-end delay under documented test conditions; report median and tail latency in milliseconds. |
| Passthrough latency | Established | Delay between capture of a physical scene and its presentation through a video-mediated display. | Measure capture-to-display delay and timing variation separately from rendering delay. |
| Vergence–accommodation conflict | Established | A mismatch between the distance implied by binocular convergence and the optical focusing distance supplied by a display. | Review display constraints and compare interface depth layouts; assess task performance and voluntary comfort reports without diagnosing participants. |
| Comfort-preserving depth layout | Proposed | Arrangement of interface content that limits unnecessary depth changes and permits user-selected placement. | Compare layout variants; measure completion time, selection errors, depth transitions, and self-reported comfort. |

## Accessible interaction and communication

| Term | Status | Working definition | Near-term improvement and research measure |
|---|---|---|---|
| Multimodal input | Established | Interaction through more than one input channel, such as keyboard, switch, speech, pointer, or gesture. | Implement equivalent task paths; measure task coverage and success separately for each supported channel. |
| Modality-equivalent interaction | Proposed | Different input or output channels providing the same meaningful task outcome without requiring identical physical actions. | Test completion, information availability, and error recovery across channels. |
| Motion-agnostic interaction | Adapted | Interaction that does not require a particular head, hand, body, or locomotion movement. | Provide stationary alternatives; measure how many essential tasks remain achievable without movement-based input. |
| Dwell selection | Established | Selection activated after a pointer or focus indicator remains on a target for a configured duration. | Compare adjustable timing and cancel options; measure accidental activation, missed selection, and completion time. |
| Adjustable interaction target | Adapted | A selectable region whose size, spacing, or activation behavior can be customized. | Test target configurations; measure selection errors and successful use without requiring disclosure of a disability. |
| Spatial captioning | Adapted | Placement of text captions in a spatial interface with readable positioning and optional association to a sound source. | Compare anchored and fixed-position captions; measure comprehension, missed text, and visual-search effort. |
| Semantic spatial description | Adapted | A structured, nonvisual description of relevant content, available actions, and spatial relationships. | Add descriptions alongside visual content; measure navigation and task completion through nonvisual output. |
| Cross-modal synchronization | Adapted | Coordination of related visual, audio, text, and permitted tactile outputs in time. | Measure timing differences in milliseconds and whether users correctly associate related cues. |
| Sensory-load budget | Proposed | A user-adjustable limit on concurrent interface stimuli such as animation, audio, notifications, and visual density. | Compare quiet-mode settings; measure interruption frequency, task errors, and voluntary workload reports. |
| Accessible recovery path | Adapted | A usable way to cancel, correct, resume, or obtain human support after an interaction fails. | Inject interface failures; measure recovery success, recovery time, and dependence on inaccessible controls. |

## Private sensing and data handling

| Term | Status | Working definition | Near-term improvement and research measure |
|---|---|---|---|
| Local scene processing | Adapted | Processing spatial observations within a specified local trust boundary rather than automatically transmitting them elsewhere. | Prototype offline processing; inspect network behavior, temporary files, logs, and derived-data retention. |
| Ephemeral spatial map | Proposed | A spatial representation retained only for the declared task or session and removed according to an explicit deletion policy. | Test expiry and restart behavior; distinguish logical deletion, backup retention, and physical storage limitations. |
| Purpose-bound sensing | Adapted | Sensor use limited to an explicit task purpose, permitted data classes, and declared duration. | Test whether unrelated requests are rejected; measure excess fields collected and unauthorized purpose changes. |
| Scene-data minimization | Adapted | Collection and retention of only the environmental information necessary for a defined task. | Compare reduced representations; measure utility, retained data volume, and exposure of private surroundings. |
| Gaze-data minimization | Proposed | Avoiding raw or retained gaze data when a less revealing interaction signal can accomplish the task. | Compare non-gaze alternatives and transient selection signals; measure task success and retained-data reduction. |
| Bystander-aware capture | Proposed | Capture design that minimizes incidental collection and provides understandable indicators and usable alternatives for nearby people. | Test synthetic bystander scenarios, indicators, and capture-off workflows without identifying or profiling people. |
| Inference firewall | Proposed | A policy boundary prohibiting unauthorized derivation of identity, health, emotion, competence, or other sensitive attributes from interaction data. | Test prohibited requests and derived outputs; document what enforcement can and cannot prevent. |
| Consent-scoped capability | Adapted | A narrowly bounded permission for a specified operation, resource, duration, and recipient. | Test expired, altered, excessive, and replayed permissions; measure unauthorized acceptance and legitimate-task rejection. |
| Research export boundary | Proposed | A review point separating private working material from any proposed external disclosure. | Require preview and explicit approval; test accidental attachments, hidden metadata, and recipient changes. |
| Privacy-preserving research trace | Proposed | A minimal record of test conditions and outcomes that excludes raw sensitive content unless specifically necessary and approved. | Check reproducibility with reduced traces; measure retained fields, retention duration, and re-identification concerns. |

## Human-integrated continuity and non-interference

| Term | Status | Working definition | Near-term improvement and research measure |
|---|---|---|---|
| Host-defined interface profile | Proposed | A voluntary profile of preferred terminology, interaction channels, pacing, and privacy boundaries controlled by the person using the interface. | Test local editing, correction, and optional import; measure preference fidelity without treating the profile as a credential. |
| Protected terminology continuity | Proposed | Preservation of a person's authorized vocabulary across sessions and document transformations. | Run paraphrase and migration tests; measure unauthorized substitutions and successful user corrections. |
| Assistive communication pacing | Adapted | Timing controls that accommodate pauses, variable input speed, correction, and deferred response. | Test adjustable timeouts and resumable entry; measure lost input and unnecessary task restarts. |
| Psych-continuity preference | Proposed | A voluntarily stated preference concerning preservation of familiar interaction context, records, terminology, and companion-related boundaries. | Test preference preservation across interface updates; evaluate fidelity, not a person's internal psychological state. |
| Companion-system discretion boundary | Proposed | A rule preventing demands for, or unnecessary handling of, private companion-system details during ordinary service. | Test prompts and logs for disclosure pressure; measure successful task completion without private inventories. |
| Non-interference contract | Proposed | An explicit statement that an interface must not alter, command, inspect, or disrupt a private integration without separately authorized scope. | Review adapters and permission paths; test unauthorized commands and misleading claims of system control. |
| Non-actuating research adapter | Adapted | An interface that can accept approved research inputs and return recommendations without sending commands to real equipment. | Verify absence of command paths, write privileges, and hidden external side effects. |
| Material-change review gate | Proposed | A review required before a change alters privacy, interaction behavior, consent scope, continuity expectations, or external-action authority. | Compare proposed changes with declared boundaries; measure detected changes and silent policy regressions. |
| Private continuity envelope | Proposed | A portable, minimum-data package of approved preferences and context with explicit exclusions, retention, and import-review rules. | Test round-trip preservation, selective removal, expiry, and prevention of unintended disclosure. |
| Access-without-disclosure pathway | Proposed | A route to ordinary services and assistance that does not depend on revealing private integration or identity details. | Compare task outcomes with optional profile fields omitted; test human fallback and absence of disclosure penalties. |

## Interoperability, repair, and responsible resource use

| Term | Status | Working definition | Near-term improvement and research measure |
|---|---|---|---|
| Runtime capability negotiation | Adapted | Explicit discovery and selection of supported interface features without assuming equivalent support across devices. | Test capability matrices and unsupported combinations; measure correct fallback and misleading feature claims. |
| Spatial feature portability | Proposed | Preservation of intended task behavior when spatial features move between supported runtimes. | Test anchor, plane, and tracking workflows across documented implementations; record semantic differences. |
| Semantic fallback representation | Proposed | A text or structured representation that preserves essential information and actions when immersive rendering is unavailable. | Disable spatial rendering; measure task and information coverage through the fallback. |
| Offline task continuity | Adapted | Continued access to approved essential functions and records during loss of connectivity. | Test disconnected operation, queued work, expiry, and safe reconciliation without silent export. |
| Tracking-loss graceful degradation | Adapted | Transition to a less spatially dependent interface when tracking becomes unreliable. | Inject tracking loss; measure stale-content exposure, fallback delay, and continued accessible task completion. |
| Repair-preserving configuration | Proposed | Exportable and documented settings that support maintenance or device replacement without unnecessary loss of preferences. | Test replacement workflows; measure settings restored, incompatible fields, and private-data exposure. |
| Energy-per-task budget | Proposed | A documented energy allowance for a defined task under specified device and workload conditions. | Measure joules or watt-hours per completed task; report task success and conditions alongside energy use. |
| Adaptive sampling governance | Proposed | Rules for changing permitted sampling rates while preserving task requirements, consent limits, and accessible operation. | Compare declared sampling modes; measure energy use, latency, missed events, and unauthorized sensing changes. |
| Thermal-aware workload policy | Adapted | Software workload management using documented device limits and authorized device-level temperature signals. | Test reduced-workload modes; measure throttling, responsiveness, and recovery without collecting physiological data. |
| Environmental evidence overlay | Proposed | An AR presentation of environmental observations that preserves units, timestamp, source, uncertainty, and measurement-versus-model distinctions. | Test interpretation of synthetic or approved ecological data; measure unit accuracy, provenance completeness, and misinterpretation. |

## Evidence structure

For every term selected for implementation, record:

- Term and status.
- Definition and explicit exclusions.
- Intended improvement.
- Source title, publisher, publication date, and applicable version.
- Whether the source is a standard, informative guidance, research study, or
  project policy.
- Research question and falsifiable hypothesis, where applicable.
- Task, baseline, comparison method, and test conditions.
- Measurement units and aggregation method.
- Data class and permitted purpose.
- Consent scope and external-action approval requirements.
- Retention, deletion, backup, and correction behavior.
- Accessibility-equivalent pathway.
- Non-interference and prohibited-inference constraints.
- Responsible reviewer and review state.
- Known limitations and unresolved compatibility questions.

## Validation sequence

- Confirm that definitions are distinct and understandable.
- Review established terms against their primary technical sources.
- Prototype with synthetic scenes and non-sensitive fixtures.
- Test essential tasks through at least one non-immersive pathway.
- Exercise tracking loss, unsupported features, offline operation, and restart.
- Test unauthorized export, permission changes, and sensitive inference attempts.
- Review all logs and derived data for unnecessary disclosure.
- Conduct voluntary usability research only after accessible consent and
  retention controls are documented.
- Publish only approved, minimized results.
- Reassess terminology after evidence or implementation materially changes.

## Initial research priorities

- Uncertainty-aware overlay.
- Modality-equivalent interaction.
- Semantic spatial description.
- Ephemeral spatial map.
- Research export boundary.
- Non-actuating research adapter.
- Access-without-disclosure pathway.
- Tracking-loss graceful degradation.
- Energy-per-task budget.
- Environmental evidence overlay.

These priorities are proposed for their ability to support bounded software
research without requiring access to private human-integrated systems.

## Source foundation

- Khronos: OpenXR Spatial Entities Extensions Released for Developer Feedback,
  published June 2025.
- W3C: XR Accessibility User Requirements, published August 2021; informative
  user-needs guidance rather than a mandatory technical conformance standard.
- Journal of the Society for Information Display:
  Vergence-accommodation conflict increases time to focus in augmented reality,
  published April 2024.
- Project material:
  4. __Corridor-Calibration Drift Detection__  _   _ (1).md;
  non-actuation, discrete-observation, privacy, and accessibility framing.

Source foundation entries support relevant technical concepts and design
motivations. They do not establish the proposed glossary terms as standards.

## Review status

Proposed private-research glossary.

No runtime compatibility, participant outcome, environmental benefit, clinical
effect, or safety certification is asserted by this document.
