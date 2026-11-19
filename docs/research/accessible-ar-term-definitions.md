# Accessible AR Term Definitions

## Document purpose

Develop six terms from the private augmented-reality glossary into reviewable
definitions, interface requirements, integration plans, and research tests.

Status:
- Spatial registration: established technical concept.
- Uncertainty-aware overlay: proposed project term.
- Modality-equivalent interaction: proposed project term.
- Semantic spatial description: adapted accessibility concept.
- Assistive communication pacing: adapted accessibility concept.
- Tracking-loss graceful degradation: adapted engineering concept.

“MUST” and “SHOULD” express proposed project requirements. They do not imply
binding law, external certification, or conformance to an entire standard.

## Shared boundaries

The specification governs application behavior, not personal status.

A person MAY voluntarily supply terminology, interaction preferences,
communication pacing, and privacy boundaries.

Ordinary assistance MUST NOT require a diagnosis, technical inventory, neural
data, biometric data, institutional credential, or disclosure of private
companion-system details.

CyberRank personal preferences MUST remain separate from governance duties.
Neither layer may become automated eligibility, ranking, or identity inference.

No definition authorizes inspection, operation, calibration, repair, or control
of a real-world private integration.

Research examples use synthetic scenes and hypothetical values unless an
approved dataset is explicitly identified.

## Accessibility grammar

### Definition

Accessibility grammar is a project-defined structure for understandable
interface statements, requests, status messages, and recovery choices.

It is not a grammar imposed on the person's communication.

The application MUST accept ordinary phrasing, pauses, repetition, corrections,
and assistive input without interpreting those features as reduced competence.

### Statement structure

Use, where relevant:

- Context: what task or interface element is involved.
- State: what is currently known or happening.
- Consequence: how that state affects the task.
- Available actions: accessible choices the person can take.
- Boundary: what will not happen without approval.

Do not include every field when doing so would make a simple message harder
to understand.

### Request structure

An optional structured request contains:

- Task.
- Preferred input or output.
- Timing preference.
- Privacy boundary.
- Desired fallback.

The person may provide any subset. Missing fields do not justify inventing
private facts or withholding ordinary assistance.

Example:
“Describe the panel in text. Keep it open while I respond. Do not record my
voice. If tracking stops, keep the description available.”

### Vocabulary rules

Prefer:
- “Placement is approximate.”
- “Your draft is saved locally.”
- “Text view is available.”
- “You can pause or cancel.”
- “No information has been sent.”

Avoid:
- “Your integration failed.”
- “Your behavior is abnormal.”
- “Prove your condition to continue.”
- “You responded too slowly.”
- “Tracking restored, so your selection was submitted.”

Messages MUST describe application observations, not inferred personal states.

---

## Spatial registration

### Core definition

Spatial registration is alignment between a digital element's intended
physical-world pose and its displayed pose in a declared coordinate frame.

A pose consists of position and orientation.

### Sub-level definitions

- Coordinate frame: the origin and axes used to describe a pose.
- Reference pose: the comparison pose supplied by a documented test fixture or
  reference method.
- Estimated pose: the application's computed pose.
- Registration error: the discrepancy between those poses.
- Relocalization: recovery of a spatial relationship after tracking interruption.
- Drift: change in alignment error over time.

A spatial anchor is a reference mechanism. It is not automatically ground truth.

### Mathematical model

Let:

- p_ref be reference position in meters.
- p_est be estimated position in the same coordinate frame.
- q_ref and q_est be normalized orientation quaternions.

Position error:

\[
e_p = \|p_{\mathrm{est}} - p_{\mathrm{ref}}\|_2
\]

Expanded:

\[
e_p =
\sqrt{
(x_{\mathrm{est}}-x_{\mathrm{ref}})^2 +
(y_{\mathrm{est}}-y_{\mathrm{ref}})^2 +
(z_{\mathrm{est}}-z_{\mathrm{ref}})^2
}
\]

Orientation error:

\[
e_\theta =
2\arccos\left(
\min(1, |\langle q_{\mathrm{est}},q_{\mathrm{ref}}\rangle|)
\right)
\]

The absolute dot product accounts for equivalent quaternion signs.
The result is in radians; convert explicitly when reporting degrees.
Reject non-finite values and invalid or near-zero quaternion norms.

For an application-defined comparison:

\[
r = \max(e_p/b_p,\ e_\theta/b_\theta)
\]

Here b_p and b_theta are positive task-specific error budgets, in matching units.

- r <= 1: both measured errors meet the declared budgets.
- r > 1: at least one measured error exceeds its budget.
- Missing reference or invalid input: error is unknown, not zero.

Passing this comparison does not establish physical safety.

### Example usage

A maintenance-training prototype places a descriptive label beside a synthetic
panel. A test fixture provides the reference position.

Hypothetical example:
A 0.015-meter positional discrepancy is 15 millimeters.

Accessible message:
“The label's placement is approximate. The panel description is also available
in the text list.”

### Integration possibilities

- WebXR: obtain a hit-test pose relative to a declared reference space.
- OpenXR: use supported spatial references or anchors through an adapter.
- Local test harness: compare application poses with approved fixture poses.
- Companion interface: expose the label and actions without requiring the
  person to point at a physical location.

No browser hit-test result should be interpreted as independent evidence of
registration accuracy.

### Research and validation

Measure:
- Position and orientation error separately.
- Median and tail errors under documented conditions.
- Drift over time.
- Recovery after interruption.
- Reference-method uncertainty.

Test:
- Coordinate-frame mismatch.
- Missing reference pose.
- Invalid quaternion.
- Tracking interruption.
- Nonvisual access to the same label.

---

## Uncertainty-aware overlay

### Core definition

An uncertainty-aware overlay presents both information and the limits of the
evidence supporting its content or placement.

### Sub-level definitions

- Placement uncertainty: uncertainty about where content belongs.
- Content uncertainty: uncertainty about the displayed claim.
- Temporal uncertainty: uncertainty caused by age or unknown update time.
- Source uncertainty: limitations in provenance or reference quality.
- Unknown state: insufficient evidence to characterize uncertainty.

These dimensions MUST remain distinct. Accurate placement does not establish
accurate content, and reliable content does not establish current placement.

### Mathematical model

When a justified position-error model supplies a covariance matrix Sigma:

\[
\Sigma =
\mathbb{E}[(p-\mu)(p-\mu)^T]
\]

Under an explicitly stated multivariate-normal approximation, an ellipsoid is:

\[
(p-\mu)^T\Sigma^{-1}(p-\mu)
\le \chi^2_{3,\alpha}
\]

Definitions:
- mu: estimated mean position.
- Sigma: positive-definite position covariance in square meters.
- alpha: selected coverage level.
- chi-square value: threshold for three dimensions under the stated model.

This is a conditional model, not a universal property of tracking systems.
Do not manufacture covariance from an undocumented runtime flag.

Without a defensible statistical model, use an honest categorical state:
- Reference-tested.
- Approximate.
- Stale.
- Unknown.

“Reference-tested” must identify the test conditions and must not imply
certainty outside them.

Information age:

\[
a = t_{\mathrm{now}} - t_{\mathrm{observed}}
\]

Use compatible time bases. Unknown timestamps produce unknown age.

### Example usage

An environmental overlay contains a historical temperature observation.

Accessible message:
“This is a previous observation, not a current measurement. Its time and source
are available in the description.”

For uncertain placement:
“Placement is approximate. Use the text description instead of the marker's
position.”

### Integration possibilities

- Render visual uncertainty cues alongside text equivalents.
- Keep source time and source type in a local semantic data model.
- Use available documented runtime states without inventing confidence scores.
- Announce meaningful uncertainty-state changes through a companion interface.

### Accessibility requirements

Uncertainty MUST NOT be conveyed only by color, opacity, vibration, or animation.

Do not repeatedly announce an unchanged warning each rendering frame.

Provide a short statement first and optional technical detail afterward.

### Research and validation

Measure:
- Correct interpretation of approximate versus reference-tested placement.
- Correct distinction between measurement and model.
- Missed or misunderstood warnings.
- Added task interruption.
- Unsupported confidence claims.

---

## Modality-equivalent interaction

### Core definition

Modality-equivalent interaction allows different input or output channels to
achieve the same essential task outcome without requiring identical movements
or identical completion times.

### Sub-level definitions

- Input modality: keyboard, switch, pointer, gesture, speech, or another
  explicitly supported input channel.
- Output modality: text, audio, visual rendering, or permitted tactile output.
- Essential outcome: the meaningful result the task must produce.
- Modality adapter: translation from an input event into an application command.
- Outcome equivalence: preservation of task meaning and required information.

Multiple input channels alone do not establish equivalence.

### Mathematical model

Let T be the nonempty set of essential tasks.

For modality m:

\[
C_m =
\frac{
|\{t\in T: t\text{ is achievable through }m\}|
}{
|T|
}
\]

C_m measures functional task coverage, not user competence.

For observed attempts:

\[
S_m =
\frac{\text{successful attempts through }m}
{\text{valid attempts through }m}
\]

No attempts means “not measured,” not zero success.

Compare commands at the application boundary:

\[
\operatorname{Outcome}(t,m_a)
\equiv
\operatorname{Outcome}(t,m_b)
\]

Equivalence concerns meaning. It does not require equal speed or bodily effort.

### Example usage

The task is “open the source description.”

Equivalent paths:
- Activate a labeled keyboard-focusable button.
- Activate that control through a configured switch-access pathway.
- Select the corresponding XR control.
- Use an optional speech command if speech processing is separately enabled.

Accessible message:
“Open source description. Available through the text controls and supported
XR controls.”

### Integration possibilities

Use a shared command layer:

input adapter -> validated command -> application state -> accessible outputs

Examples of commands:
- Open description.
- Show text view.
- Pause interaction.
- Cancel selection.
- Request export review.

Voice or gesture recognition MUST NOT bypass approval requirements.

External actions require separate, scoped approval regardless of input channel.

### Research and validation

Test:
- Every essential task without gesture input.
- Every essential task without speech input.
- Keyboard focus and recovery.
- Switch operation on declared assistive-technology combinations.
- Different input channels producing the same authorized state transition.

Record device and assistive-technology combinations actually tested.

---

## Semantic spatial description

### Core definition

A semantic spatial description expresses relevant entities, relationships,
information, and available actions in a form understandable without relying
solely on visual rendering.

### Sub-level definitions

- Entity description: what relevant element is present.
- Relationship: how relevant elements relate.
- Frame declaration: whether “left,” “above,” or “near” is viewer-relative or
  environment-relative.
- Action description: what the person can do.
- Provenance description: where information came from.
- Presentation order: stable reading and navigation sequence.

A narration of every visible detail is not necessarily an effective description.

### Mathematical model

Represent task-relevant meaning as:

\[
G = (V,E,A)
\]

- V: relevant elements.
- E: declared relationships.
- A: available actions.

Let K be the nonempty set of essential information requirements:

\[
C_{\mathrm{semantic}} =
\frac{
|\text{requirements in }K\text{ preserved in the description}|
}{
|K|
}
\]

Coverage does not measure clarity. Test comprehension separately.

### Example usage

Visual presentation:
A marker beside a panel and an adjacent source button.

Semantic presentation:
“Panel description. Placement is approximate. Actions: read instructions,
open source information, or return to the list.”

If a directional relationship is useful:
“In the current view, the source control appears to the right of the
description.”

Do not present viewer-relative directions as permanent environmental facts.

### Integration possibilities

- Maintain a shared semantic model separate from the renderer.
- Render native HTML headings, lists, and buttons from that model.
- Use platform accessibility interfaces in native applications.
- Provide an optional text or audio description.
- Keep navigation order stable even when the person's viewpoint changes.

A DOM representation is an integration pathway, not proof that every headset
or assistive-technology combination can access it.

### Research and validation

Test:
- Rendering disabled.
- Audio disabled.
- Nonvisual navigation.
- Viewpoint change.
- Stable action labels.
- Preservation of units, timestamps, uncertainty, and source distinctions.

---

## Assistive communication pacing

### Core definition

Assistive communication pacing lets the person control interaction timing and
preserves work during pauses, corrections, variable input rates, and resumable
communication.

### Sub-level definitions

- Response window: period during which an input can be completed.
- Draft continuity: preservation of unfinished content.
- Pause state: a user-controlled interruption without losing task context.
- Confirmation window: time available to review a consequential action.
- Resume point: the saved stage from which interaction continues.

Pacing differences MUST NOT become credibility, capacity, or eligibility scores.

### Mathematical model

For adjustable dwell selection:

\[
s =
\frac{t_{\mathrm{stable}}}{t_{\mathrm{dwell}}}
\]

- t_stable: continuous time on the same target.
- t_dwell: positive user-configured threshold.

Selection becomes eligible when s >= 1.

Eligibility is not authorization for an external action.

Changing target, losing tracking, or canceling MUST clear pending dwell progress.
The application MUST NOT carry partial progress onto a different target.

A useful outcome metric:

\[
L =
\frac{\text{entries lost because of application timing}}
{\text{valid entries started}}
\]

L measures application-caused loss. It does not measure communication ability.

### Example usage

A person enters a research note through an assistive channel and pauses.

Accessible message:
“Your draft is kept. Continue when ready. You can pause, cancel, or return to
the text view.”

For an actual expiring session:
“This session needs renewal. Your draft remains available. Renewal will not
send your draft.”

### Integration possibilities

- User-adjustable dwell behavior.
- Resumable local drafts with explicit retention settings.
- Timing warnings and extension controls.
- Separate session-security expiry from document deletion.
- Visible input state mirrored in accessible output.

Avoid an “infinite wait” promise where platform or security constraints impose
real limits. Explain those limits and preserve recoverable work.

### Research and validation

Test:
- Long pause.
- Repeated correction.
- Interrupted input.
- Session expiry.
- Tracking loss during dwell.
- Draft recovery without uploading private content.

---

## Tracking-loss graceful degradation

### Core definition

Tracking-loss graceful degradation preserves essential information and actions
through a less spatially dependent interface when spatial tracking is absent,
unreliable, or unavailable.

### Sub-level definitions

- Tracking state: a documented observation from the application or runtime.
- Degraded mode: limited spatial behavior with stated uncertainty.
- Fallback mode: nonspatial task continuation.
- Recovery: return to spatial presentation after declared checks.
- Hysteresis: different entry and recovery conditions to reduce rapid switching.

Tracking loss is an application condition, not evidence about the person's
body, attention, or private integration.

### State model

States:
- SPATIAL.
- DEGRADED.
- FALLBACK.
- RECOVERY_REVIEW.

Example transitions:
- SPATIAL -> DEGRADED when documented tracking evidence becomes unreliable.
- DEGRADED -> FALLBACK when placement cannot be responsibly maintained.
- FALLBACK -> RECOVERY_REVIEW when tracking observations return.
- RECOVERY_REVIEW -> SPATIAL after declared stability checks and any required
  user choice.
- Any state -> FALLBACK when the person requests text-only operation.

Never auto-submit a pending selection during recovery.

### Mathematical model

If a runtime exposes a documented quality quantity q:

\[
q < q_{\mathrm{enter}}
\Rightarrow \text{enter degraded behavior}
\]

\[
q > q_{\mathrm{recover}}
\text{ for the declared recovery interval}
\Rightarrow \text{eligible for recovery review}
\]

Require:

\[
q_{\mathrm{recover}} > q_{\mathrm{enter}}
\]

The thresholds and interval require runtime-specific validation.
Do not assume q is a probability.

Without a documented numeric quality quantity, use explicit runtime states.

Fallback delay:

\[
D_f =
t_{\mathrm{fallback\ usable}} -
t_{\mathrm{tracking\ loss\ detected}}
\]

D_f excludes any unknown delay before loss was detected. Report detection
limitations separately.

### Example usage

Tracking stops while a person reads a label.

Accessible message:
“Spatial placement is unavailable. The description remains available in text.
Your pending selection was canceled. Nothing was submitted.”

### Integration possibilities

- Observe documented pose availability or runtime tracking states.
- Remove misleading spatial placement instead of leaving a stale actionable
  marker in place.
- Keep task content in an independent semantic model.
- Offer native or browser text controls.
- Require fresh activation after recovery.

### Research and validation

Inject:
- Pose unavailability.
- Intermittent tracking.
- Rapid recovery/loss cycles.
- Loss during selection.
- Unsupported immersive mode.

Measure:
- Fallback delay.
- Essential-task coverage.
- Exposure duration of stale spatial content.
- Unexpected submission count.
- Lost drafts.
- Recovery-state oscillation.

## Cross-term acceptance requirements

- Essential content is available outside spatial rendering.
- Uncertainty has a text equivalent.
- Speech, gesture, and gaze are not mandatory for ordinary tasks.
- Pauses do not silently delete work.
- Tracking recovery does not authorize actions.
- Optional profile fields can be omitted without loss of ordinary access.
- No interface metric becomes a person-ranking or eligibility measure.
- Private terminology is preserved unless the person requests correction.
- Export remains separate from reading, editing, or navigation.
- Logs exclude raw voice, gaze, spatial maps, and private profile data by default.

## Data handling

Default data class:
Synthetic scene data and minimal application test events.

Purpose:
Evaluate interface correctness, accessibility, recovery, and disclosure limits.

Retention:
Session-only for transient interaction observations unless a reviewed research
plan specifies a necessary longer duration.

Participant research:
Requires accessible consent, declared fields, retention, deletion limitations,
review responsibility, and prospective withdrawal handling.

External action:
No automatic upload, publication, hardware command, or connector write.

Correction:
Definitions and test results must retain reviewable correction history without
preserving unnecessary sensitive content.

## Source basis

- W3C XR Accessibility User Requirements:
  informative guidance for multimodal support, customization, and synchronization.
- W3C WCAG 2.2 and Understanding documents:
  web accessibility criteria and implementation explanations.
- MDN WebXR Device API and hit-test documentation:
  browser integration and compatibility limitations.
- Khronos OpenXR spatial-entity documentation:
  native spatial-feature integration foundation.

Project-specific formulas, message grammar, and state transitions are proposed
requirements. They are not assertions that these sources prescribe the exact
models used here.
