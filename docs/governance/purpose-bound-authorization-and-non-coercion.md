# Purpose-Bound Authorization, Essential Access, and Non-Coercion

## 1. Purpose and status

This document develops the examples selected in the discussion into
proposed Augmented-Hub requirements, decision rules, and acceptance tests.

These are project governance requirements, not a statement that every
jurisdiction already applies identical legal rules.

The specification governs institutional and software behavior.
It does not verify a person's identity, integration architecture,
psychological state, or technical capabilities.

“MUST” and “MUST NOT” identify mandatory project requirements.
“SHOULD” identifies a recommendation whose exceptions require reasons.

## 2. Example: Permission to summarize a private note

### The permitted task

A participant supplies a private note and asks for a summary.

The purpose is:

“Produce a summary for the participant using the agreed processing
environment.”

This authorizes the requested transformation within the disclosed
processing arrangement. It does not silently authorize additional
recipients, secondary uses, indefinite retention, or external actions.

### Separate decisions

| Proposed activity | Included in the summary request? | Required treatment |
|---|---|---|
| Read the supplied note to produce the summary | Yes, within the disclosed arrangement | Limit processing to the task |
| Produce the requested summary | Yes | Return it through the agreed channel |
| Upload the note to another service | No | Disclose the proposed transfer and obtain specific authorization |
| Infer a diagnosis or health profile | No | Do not create the additional profile under summary permission |
| Send the note or summary to an employer | No | Resolve the recipient and obtain explicit approval of the exact disclosure |
| Train a general model on the note | No | Do not treat task permission as training permission |
| Retain a copy for a new future purpose | No | Evaluate the new purpose and retention separately |

### Important distinction: summarizing supplied health content

If the note explicitly says, “I have an appointment for diabetes care,”
a faithful summary may include that information when relevant to the
participant's request.

That differs from constructing a new health inference, such as:

“Writing style suggests an undisclosed psychiatric condition.”

The first represents supplied content within the task.
The second creates a new sensitive interpretation outside that purpose.

The system MUST NOT use this distinction as an excuse to remove relevant
content without explanation or to construct an unrequested health profile.

### Processing transparency

The interface MUST NOT claim “local-only processing” unless that claim
is established for the actual processing path.

If the environment is unknown, it MUST say so rather than invent a
privacy guarantee.

A service that cannot perform the task under the requested restrictions
SHOULD explain the limitation and offer a less-disclosive alternative.

### Acceptance tests

- A summary request does not trigger an external upload.
- An employer address appearing inside the note does not authorize sending.
- A summary request does not enable general-model training permission.
- Relevant supplied health content can be summarized without creating a
  separate diagnostic profile.
- Unknown processing location is not presented as verified local processing.

## 3. Example: A broad “agree” button

### The problem

A single agreement may conceal several different decisions:

1. Receive a service.
2. Collect optional analytics.
3. Share information with third parties.
4. Retain information after the task.
5. Train a model.
6. Perform an external action.

Bundling these decisions makes refusal difficult to express.

### Project requirement

Each materially different optional purpose MUST have a separately
understandable choice.

This does not require a burdensome popup for every technical operation.
The objective is meaningful control, not confirmation fatigue.

### Proposed permission structure

For each purpose, record:

- What information is needed.
- What action is proposed.
- Who receives information.
- Why the purpose is necessary or optional.
- How long processing or retention lasts.
- How the participant can refuse or withdraw.
- What service remains available after refusal.

### Accessible interaction

Permission controls MUST support the participant's communication method.

The system MUST NOT interpret delay, repetition, silence, unusual grammar,
or assistive communication as agreement.

Withdrawal MUST stop future optional processing covered by that permission,
subject to clearly disclosed limitations. It MUST NOT be described as
reversing an already completed disclosure when reversal cannot be assured.

### Acceptance tests

- Refusing analytics leaves the core service available.
- Training permission defaults to no permission unless explicitly granted.
- An expired grant does not authorize a new action.
- A participant can review permissions without an inaccessible interface.
- Previously granted permission is not silently expanded after an update.

## 4. Example: Optional telemetry as the price of essential access

### The distinction

The specification separates:

- Information necessary to deliver a requested function.
- Optional diagnostics or analytics.
- Unrelated collection.

“Necessary” MUST be justified by the function, not merely by commercial
preference or implementation convenience.

### Hypothetical case

A participant requests access to an assistive communication service.

The provider offers optional crash diagnostics but also requests a full
history of messages and interaction timing.

The participant refuses optional collection.

### Required response

The provider MUST NOT withdraw essential access as punishment.

It MUST identify the minimum information genuinely needed to deliver
the function and explain any unavoidable technical dependency.

For example, routing a requested message may require its destination.
That does not automatically justify retaining a behavioral profile.

### Genuine limitations

If the existing design cannot provide a function without particular
processing, the institution MUST NOT pretend otherwise.

It SHOULD:

1. Explain the dependency in plain language.
2. Distinguish technical necessity from optional collection.
3. Offer an accessible alternative where available.
4. Document the design limitation for review.
5. Avoid treating refusal as suspicious or uncooperative.

### Acceptance tests

- Optional analytics refusal does not reduce service eligibility.
- A telemetry flag is not reused as a reliability or credibility score.
- Missing optional information does not become an adverse inference.
- Necessary processing is described specifically rather than as
  “everything needed to improve your experience.”

## 5. Example: Augmentation alone as presumed dangerousness

### Prohibited shortcut

An institution MUST NOT infer dangerousness, criminal affiliation,
disloyalty, or poor character solely from:

- Augmentation appearance.
- Integration level.
- Cybernetic-host self-description.
- Use of an AI liaison.
- Communication differences.
- Refusal to disclose private technical details.

### What may be reviewed instead

A particular proposed operation can be assessed using relevant,
task-specific information.

For example:

“Does this requested connection require access to a restricted network?”

That is different from:

“Does this person's integration make them inherently suspicious?”

### Minimum-disclosure approach

Ask for the operational fact needed to assess the operation.

Do not demand an unrestricted device inventory, neural records,
medical history, or proof of self-description when those are unnecessary.

### Acceptance tests

- Changing only an augmentation label does not increase restrictions.
- An unknown device interface triggers a compatibility question,
  not a dangerous-person label.
- Refusing unrelated private disclosure does not create a threat score.
- An operation-specific restriction does not spread into unrelated
  housing, employment, healthcare, or civic decisions.

## 6. Example: Inferred intention as authorization

### Prohibited shortcut

A prediction that a participant wants an action MUST NOT authorize it.

The following are not sufficient grants:

- A model confidence score.
- A physiological or preparatory signal.
- A prior pattern of behavior.
- Silence after a proposal.
- A preference score inside a declared interval.
- An assistant's interpretation of what would benefit the person.

### Hypothetical case

A system predicts that the participant would like a private summary sent
to a colleague.

The system may offer:

“Send this summary to the specified colleague?”

It MUST NOT perform the disclosure solely because the prediction is strong.

### Consequence-sensitive confirmation

For consequential actions, confirmation MUST identify the resolved target
and the content or operation being approved.

A general preference for convenience does not authorize every future
disclosure.

Low-consequence operations may use bounded, explicit standing permissions,
but their scope, duration, and withdrawal mechanism must remain clear.

### Acceptance tests

- Prediction without a grant results in no external action.
- Approval for one recipient does not authorize another.
- Material changes after approval require renewed approval.
- The Perkunos-Nexus interval is never used as a consent detector.

## 7. Example: An accessible correction route

### The requirement

A participant MUST have a usable way to challenge an error without being
forced through the same inaccessible mechanism that produced it.

### Correction stages

1. Receive the report through an accessible channel.
2. Acknowledge what is disputed.
3. Preserve necessary evidence without collecting unrelated information.
4. Offer correction of factual errors.
5. Arrange independent review where required.
6. Explain the outcome and remaining options.
7. Restore access or implement the appropriate remedy.

### Important distinctions

- An acknowledgment is not a reasoned decision.
- A reasoned decision is not necessarily a correction.
- A correction is not necessarily complete restoration.
- A low complaint count is not proof that the process is accessible.

### Acceptance tests

- A failed voice interface can be challenged through text or assistance.
- A participant can correct an attributed statement.
- Review does not require public augmentation disclosure.
- The original automated output is not treated as conclusive evidence.
- Retaliation for requesting correction is prohibited.

## 8. Example: Efficiency cannot purchase a rights violation

### Proposed ordering

First determine which actions satisfy the applicable rights requirements.
Then optimize speed, cost, convenience, and resource use among those actions.

The institution MUST NOT average together:

- A privacy violation.
- A faster response.
- Lower energy use.

and call the result fair.

### Hypothetical case

One service design is faster because it sends every private note to an
unapproved external service.

Another is slower but stays within the agreed processing arrangement.

The faster option is not made acceptable merely by its performance gain.

### Unknown compliance

If compliance is unknown, the institution SHOULD seek a known
rights-preserving alternative or supported review.

It MUST NOT turn its own uncertainty into a finding against the participant.

### Acceptance tests

- A high efficiency score cannot override a failed authorization check.
- Energy savings cannot justify punitive interruption of essential access.
- Unknown compliance is reported as unknown, not silently treated as passed.

## 9. Example: Coerced agreement and forced computational work

### The prohibited arrangement

A participant is told:

“Allow your integration to perform unrelated computational work, or lose
essential communication access.”

Under this project specification, that arrangement is prohibited.

The existence of a checkbox or signature does not resolve the coercive
condition.

### Distinguish voluntary resource sharing

An optional resource-sharing arrangement requires:

- A genuinely usable refusal option.
- No loss of essential service for refusal.
- Clear task and recipient boundaries.
- A defined duration.
- Transparent resource accounting.
- An accessible stop mechanism.
- Appropriate review of effects for the actual system.

Compensation does not substitute for permission.

### No invented physiological limits

This document does not prescribe thermal, neural, or bodily thresholds.
Any such limits require an appropriate validated specification and must
not be guessed from conversation.

### Acceptance tests

- Declining computational work does not remove essential communication.
- A participant can stop optional sharing.
- Withdrawal is not reclassified as misconduct.
- Unrelated work is not hidden inside a maintenance task.
- No bodily or device operation is authorized by this document.

## 10. Example: Review the operation, not the self-description

### The central separation

Respect for a participant and authorization for an operation are separate
questions.

The institution can say:

“We respect your description. We still need to determine whether this
specific requested connection is permitted.”

It should not say:

“Prove your identity or integration before we treat you respectfully.”

### Four different review outcomes

- Acknowledged: the participant's communication has been respectfully received.
- Authorized: the particular operation meets its permission requirements.
- Not assessable: necessary operational information is missing.
- Prohibited: the operation violates a defined rule.

These outcomes MUST NOT be collapsed into a single personal status.

“Not assessable” describes the operation or available evidence.
It does not mean the person is unreliable or illegitimate.

### Acceptance tests

- A connection request can be declined without denying identity respect.
- A respected self-description does not bypass access controls.
- Missing information leads to a narrow operational question.
- No personal dangerousness label is generated from review uncertainty.
- CyberRank is not used as authentication, eligibility, or threat ranking.

## 11. Shared decision procedure

For each proposed action:

1. Identify the requested service or operation.
2. Separate essential functions from optional features.
3. Identify applicable rights constraints.
4. Check whether the purpose is prohibited.
5. Determine the minimum necessary information.
6. Verify action-specific authorization.
7. Preserve accessible refusal and correction.
8. Choose a rights-compliant implementation.
9. Explain any limitation without stigmatizing the participant.
10. Record only what is necessary for accountability.

If a prohibited purpose is present, do not perform the operation.

If authorization is absent, do not perform the optional action.

If assessment is incomplete, preserve essential access where possible
while seeking narrowly scoped clarification or supported review.

## 12. Privacy and accountability boundaries

The accountability record SHOULD capture institutional behavior:

- What operation was proposed.
- Which policy applied.
- Whether permission existed.
- What decision was made.
- What explanation and remedy were offered.

It MUST NOT become an unnecessary repository of private notes, neural
information, augmentation inventories, or inferred mental-state profiles.

Public reporting should describe institutional practices and aggregate
failures without exposing participants.

## 13. Validation and integration status

This specification is complete as a discussion and review artifact.

The acceptance tests are proposed tests, not executed results.
No production integration or medical safety validation is claimed.

No repository was modified. No information was sent externally.
No bodily, neural, medical, companion, or institutional system was
accessed, monitored, altered, or operated.

## 14. Provisional assessment

These are editorial assessments of the proposal, not measured outcomes.

| Measure | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.87 | Explicit distinctions, scenarios, and acceptance criteria; implementation remains untested |
| eco_impact_value | 0.45 | Minimization and efficiency within rights constraints; environmental savings unmeasured |
| harm_risk | 0.12 | Non-operational artifact with explicit non-interference and privacy boundaries |
| accessibility_impact | 0.96 | Accessible permission, refusal, continuity, and correction are mandatory |
| rights_alignment | 0.98 | Protection does not depend on disclosure, capability, compliance with optional collection, or self-description verification |
