# Augmented Rights — October 31, 2026

## Status and purpose

Document date: October 31, 2026
Status: proposed project-governance baseline
Scope: Augmented-Hub and Skynet research, documentation, schemas,
service interfaces, and institutional interpretation review
Operational authority: none conferred by this document

This document establishes a rights-centered baseline for accessible,
privacy-preserving, accountable services involving augmented citizens,
cybernetic hosts, assistive-technology users, and other community members.

Its central principle is:

> Evaluate the institution's duties, reasoning, and delivered service.
> Do not turn uncertainty about a system, request, or record into an
> adverse judgment about the person.

The document distinguishes:

- Applicable law.
- Project-governance commitments.
- Proposed technical requirements.
- Research hypotheses.
- Mathematical results.
- Executed implementation evidence.
- Observed service outcomes.

These categories must not substitute for one another.

This document does not establish legal personhood, medical status,
institutional recognition, technical certification, or authority to
operate any real-world system.

## Dignity, self-description, and equal access

Project services must respect voluntary self-descriptions and
communication preferences without requiring technical verification as
a condition of acknowledgment or respectful treatment.

Communication differences—including repetition, pacing, latency,
nonstandard grammar, AAC use, and fatigue-related variation—must not
be treated as evidence of reduced competence, credibility, autonomy,
dangerousness, agreement, or withdrawal.

Project requirements include:

- Equal service access and nondiscrimination.
- Accessible communication and sufficient interaction time.
- Privacy, autonomy, and minimal disclosure.
- Cognitive liberty and bodily integrity.
- Respect for psychological continuity and non-interference concerns.
- Accessible correction, explanation, and grievance routes.
- Meaningful human fallback.
- Repair, maintenance, interoperability, and offline continuity
  where relevant to the service.

These are project commitments. Their scope may be broader than a
particular legal provision.

Do not condition ordinary access on unnecessary disclosure of neural,
physiological, biometric, medical, companion-system, or operational data.

Where a process genuinely requires additional information, identify the
specific purpose, applicable basis, minimum necessary information, and
available alternative.

## CyberRank: personal and governance layers

CyberRank has two separated layers.

### Personal layer

The personal layer concerns voluntary self-description, communication
preferences, privacy boundaries, continuity needs, and non-interference
concerns.

It must not become a public registry, verification credential, diagnosis,
eligibility label, or automated decision criterion.

### Governance layer

The governance layer concerns system duties:

- Equal access.
- Minimal disclosure.
- Accessible communication.
- Human fallback.
- Correction.
- Appeal or escalation.
- Material-change review.
- Accountable handling of uncertainty.

Governance assessment evaluates institutional conditions and behavior,
not whether a participant is acceptable or sufficiently augmented.

Within project schemas and architectures, CyberRank invariants must not
be weakened by silently translating personal descriptions into public
status or machine-actionable eligibility.

Acknowledgment is not verification.
Verification is not authorization.
Prediction is not consent.
Reviewability is not permission to execute.

## Legal foundation: ADA Title II communication access

### Bounded legal setting

The legal discussion concerns U.S. ADA Title II requirements for state
and local government services.

The reference scenario is hypothetical:

> A person using augmentative and alternative communication asks a
> municipal information service for meeting information in text and
> sufficient time to communicate.

The scenario does not describe an adjudicated incident or determine
any particular person's legal coverage.

### Effective communication

Under 28 CFR § 35.160(a)(1), public entities must take appropriate steps
to ensure that communications with applicants, participants, members
of the public, and companions with disabilities are as effective as
communications with others.

Section 35.160(b)(1) requires appropriate auxiliary aids and services
where necessary to provide an equal opportunity to participate in and
enjoy a public service, program, or activity.

Section 35.160(b)(2) requires attention to:

- The individual's method of communication.
- The nature, length, and complexity of the communication.
- The context of the interaction.

Aids and services must be timely, accessible, and protective of privacy
and independence.

### Primary consideration

Public entities must give primary consideration to the requests of
individuals with disabilities when determining necessary auxiliary aids
and services.

DOJ effective-communication guidance explains that the person's choice
must be honored unless another equally effective means is available or
the requested means would cause a fundamental alteration or undue burden.

An alternative's effectiveness must be assessed in context. Merely
naming another channel does not establish equal effectiveness.

### Communication time

DOJ guidance identifies additional time as potentially necessary when
communicating with a person using a communication board or device.

No universal number of additional minutes follows from that guidance.

The institution should consider whether the person can:

- Receive the information.
- Formulate and convey responses.
- Ask questions.
- Clarify misunderstandings.
- Complete the interaction without an avoidable timing barrier.

Where timing procedures themselves create barriers, reasonable
modification requirements under 28 CFR § 35.130(b)(7)(i) may also be
relevant and should be analyzed separately.

### Cost and interpreter responsibility

Section 35.130(f) prohibits surcharges for measures required to provide
nondiscriminatory treatment.

Section 35.160(c) prohibits requiring a person to bring an interpreter
and limits reliance on accompanying adults and minor children to the
specified circumstances.

Do not collapse these provisions into a single rule or erase the
conditions governing permitted reliance.

### Claimed limitations

Under 28 CFR § 35.164, the public entity bears the burden of demonstrating
a fundamental alteration or undue financial and administrative burdens.

The decision must:

- Be made by the entity's head or designee.
- Consider all resources available for funding and operating the
  relevant service, program, or activity.
- Include a written statement of reasons.

Even when the limitation is established, the entity must take other
action that avoids the alteration or burdens while ensuring access to
the benefits or services to the maximum extent possible.

An unverified exception claim is not an established exception.

### Review and grievance provisions

Section 35.164 specifies decision authority and written reasons for the
limitations it addresses. It does not create a universal appeal procedure
for every communication decision.

Section 35.107 separately requires public entities employing 50 or more
persons to designate a responsible employee and adopt and publish
grievance procedures providing prompt and equitable resolution of
covered complaints.

The project requires an accessible correction and escalation route
more broadly as a governance commitment.

## Four-criterion institutional interpretation review

### Review target

The target is an institutional interpretation record.

The framework does not rate the participant, establish legal compliance,
or prove that an accommodation was delivered effectively.

### Criteria

| Criterion | Review question |
|---|---|
| Documented rule basis | Is the relevant duty or limitation identified and correctly connected to the circumstances? |
| Functional request consideration | Were the requested communication method and the interaction's functional demands meaningfully considered? |
| Supported arrangement | Does the available record support the proposed arrangement's effectiveness? |
| Reasoned review pathway | Is there an accessible correction or escalation route with appropriate responsibility and authority? |

These are proposed project-review criteria, not verbatim statutory
elements or a complete statement of ADA liability.

### Evidence states

Each criterion receives exactly one substantive state:

| State | Meaning |
|---|---|
| met | Available evidence affirmatively supports the criterion within scope. |
| not_met | Evidence establishes a failure to satisfy the criterion. |
| unresolved | Available evidence establishes neither satisfaction nor failure. |

Missing evidence is not automatically proof of failure.

Examples:

- A reviewer has not received a document and does not know whether it
  exists: unresolved.
- An applicable documentation duty is established and evidence confirms
  the required document was not prepared: not_met.

Malformed inputs are validation errors. Any conversion of missing input
to unresolved must be explicit and recorded.

### Dispositions

For interpretation record \(a\), let:

\[
s_j(a)\in\{\mathrm{met},\mathrm{not\_met},\mathrm{unresolved}\},
\quad j=1,\ldots,4.
\]

Define:

\[
\mathcal A_{\mathrm{documented}}
=
\{a:\forall j,\ s_j(a)=\mathrm{met}\}.
\]

\[
\mathcal A_{\mathrm{nonconforming}}
=
\{a:\exists j,\ s_j(a)=\mathrm{not\_met}\}.
\]

\[
\mathcal A_{\mathrm{review}}
=
\{a:
\neg\exists j,\ s_j(a)=\mathrm{not\_met}
\land
\exists j,\ s_j(a)=\mathrm{unresolved}
\}.
\]

Interpretations:

- documented: all four project-review criteria are supported.
- nonconforming: at least one criterion has an established deficiency.
- review: no established deficiency is present, but uncertainty remains.

None of these labels is a participant classification.

A review disposition must not be used as an automatic reason to
withhold available assistance.

### Preservation of composite findings

The primary disposition must retain every criterion's state, reason,
supporting evidence, and uncertainty.

For example:

- Functional request consideration: not_met.
- Exception-authority evidence: unresolved.

The primary disposition is nonconforming under this framework, while
the unresolved finding remains visible.

Do not replace these findings with a judgment about the participant.

## Synthetic verification obligations

The four-criterion, three-state domain contains:

\[
3^4=81
\]

valid combinations.

The mathematically derived disposition counts are:

| Disposition | Count |
|---|---:|
| documented | 1 |
| nonconforming | 65 |
| review | 15 |
| Total | 81 |

The partition is exhaustive and mutually exclusive because every valid
vector either contains not_met, contains only met and unresolved with
at least one unresolved, or contains only met.

Implementation testing must verify:

- Exactly one primary disposition per valid vector.
- No unresolved criterion can produce documented.
- No met criterion compensates for not_met.
- Criterion order does not change the disposition.
- Criterion labels remain associated with their evidence.
- All unmet and unresolved findings remain visible.
- Malformed inputs do not receive favorable defaults.
- Outputs contain no participant score or eligibility inference.

Negative controls must deliberately introduce defects such as:

- Treating unresolved as met.
- Allowing compensation for an unmet criterion.
- Returning early on unresolved before examining later criteria.
- Dropping criterion-level findings.
- Accepting invalid states as favorable defaults.

A proposed test is not an executed test.
A passing self-test is not proof of legal compliance or fairness.

No runtime execution is established by this document.

## Open standards and interoperability

### Minimum useful profiles

Use task-level interoperability profiles rather than universal models
of a person's body, mind, augmentation, or private architecture.

Candidate exchanges include:

- Communication preferences.
- Accessible-format requests.
- Correction requests.
- Permission withdrawal.
- Support requests.
- Export of agreed settings and records.

JSON Schema may describe data structure.
OpenAPI may describe service operations and security schemes.
Relevant W3C standards may support accessible interaction and exchange.

None of these tools alone proves secure authorization, semantic
compatibility, or effective service delivery.

### Required profile contents

A profile must specify:

- Version and compatibility rules.
- Field meanings and permitted values.
- Required and optional fields.
- Unknown-field behavior.
- Accessibility requirements.
- Purpose and permission scope.
- Withdrawal behavior.
- Error and unresolved states.
- Retention and disclosure boundaries.
- Export and import tests.
- Material-change review.
- Human-support route.

Do not silently discard a field when doing so would weaken a protection.

### Semantic preservation

Interoperability testing must check that exchanges preserve:

- Refusal as refusal.
- Unknown authorization as unknown.
- Withdrawn permission as withdrawn.
- Private visibility as private.
- Corrections and their relationship to disputed material.

Imported settings are not automatically current execution authority.

Open standards do not require publication of private data, credentials,
security secrets, or a participant's integration architecture.

## Consent, authorization, and withdrawal

### Separate permission from execution

A prediction, preference, historical approval, or imported record is not
automatically authorization for a new external action.

Before a consequential action, identify:

- The action.
- The recipient or affected service.
- The information involved.
- The purpose.
- The scope and duration of authorization.
- Material limitations and irreversible effects.

Silence, latency, and communication difficulty must not be interpreted
as authorization.

### Irreversibility explanations

Before a consequential disclosure, explain concretely:

- What will leave the service.
- Who will receive it.
- Whether it can be recalled.
- Whether copies may remain.
- What withdrawal can stop.
- What it cannot reliably reverse.
- Available correction and remedy routes.

Avoid vague warnings when a specific explanation is possible.

### Withdrawal lifecycle

Distinguish:

- Request received.
- Relevant grant identified.
- Enforcement pending.
- Future activity stopped under that grant.
- Dependent-service confirmation pending.
- Residual-copy status unresolved.
- Remedy required.

A receipt is not proof that downstream processing stopped.
An access revocation is not erasure.
A deletion request is not proof of deletion.

The project requirement is that effective withdrawal prevents new
activity from being authorized by the withdrawn grant.

Any claimed alternative basis requires its own review and explanation.
It must not be invented merely to preserve the same optional activity.

An irreversible past disclosure does not eliminate future autonomy.

## Meaningful human fallback

A contact link alone is not an effective alternative to automation.

Fallback must provide:

- An accessible intake route.
- A genuinely available support function.
- Appropriate training.
- Authority to resolve or escalate.
- Access to necessary information.
- Privacy boundaries.
- Continuity arrangements.
- Correction and grievance routes.

Support must not require reuse of the inaccessible channel that failed.

Human involvement does not authorize bypassing legitimate safety,
privacy, or authorization requirements.

For service-restoration cases, evaluate separately:

- Human support reached.
- Communication effective.
- Authority sufficient.
- Required action completed.
- Restoration effective.

Ticket closure is not restoration.
Participant satisfaction is informative but does not replace outcome
evidence.

Report unresolved cases and the relevant denominator rather than
measuring only successful closures.

## Privacy, retention, and accountable records

Collect only information needed for the stated task.

Document:

- Data class.
- Purpose.
- Permitted use.
- Access conditions.
- Retention and deletion rules.
- Responsible function.
- Disclosure boundaries.
- Correction route.
- External-action approval requirements.

Accountability records must not become public identity profiles or
augmentation registries.

Distinguish:

- Current access restrictions.
- Retention obligations.
- Deletion requests.
- Verified deletion evidence.
- Backup-restoration behavior.
- Downstream-copy uncertainty.

Restoration procedures must account for corrections, withdrawn grants,
and applicable deletion restrictions rather than silently reviving
superseded authority.

No privacy guarantee follows solely from an attack failing, an aggregate
being published, or a log omitting obvious names.

## Continuity, repair, and ecological responsibility

Prefer designs that reduce avoidable exclusion and replacement:

- Portable settings and records.
- Reviewable interfaces.
- Repair and maintenance support.
- Graceful degradation.
- Accessible offline alternatives where appropriate.
- Clear end-of-support communication.
- Purpose-limited local processing where suitable.

Environmental and continuity benefits must be measured rather than
asserted.

Do not trade away privacy, bodily integrity, access, or community
governance for an unsupported efficiency claim.

Models remain decision support. They do not replace scientific
validation, qualified operational review, or community decision-making.

## Evidence and research discipline

### Evidence categories

Keep distinct:

- Source statement.
- Interpretation.
- Project requirement.
- Mathematical derivation.
- Synthetic execution.
- Independent review.
- Participant evaluation.
- Real-world outcome.

### Completion labels

Use:

- documented_answer
- derived_under_assumptions
- synthetic_test_executed
- specification_complete_not_validated
- unresolved_after_search
- external_validation_required
- superseded_with_reason

Every completion claim must state its scope and remaining limitation.

### Single-session research boundary

An AI-chat research session may:

- Consolidate the supplied conversation.
- Examine authorized sources.
- Derive mathematical properties.
- Complete bounded specifications.
- Execute synthetic tests when a suitable runtime is available.
- Explain unresolved questions.

It must not claim participant research, actual service restoration,
independent acceptance, device inspection, or operational approval
without corresponding evidence.

Runtime availability must be checked before claiming execution.
Reference-model results must not be attributed to an unexecuted
implementation.

### Reporting structure

A substantive research response should contain:

- Selected question and scope.
- Relevant settled premises.
- Source-supported findings.
- Proposed interpretation rule.
- Actual execution results or explicit non-execution.
- Bounded conclusion.
- Completion status and remaining uncertainty.

The response should answer the selected question rather than replace
it with an expanding list of future deliverables.

## Evaluation fields

The project tracks:

- knowledge_factor
- eco_impact_value
- harm_risk
- accessibility_impact
- rights_alignment

Where numerical assessment is approved, values use the interval 0–1
with a stated method, direction, evidence basis, and uncertainty.

Do not invent numerical values to populate a report.

Until the relevant assessment is performed, retain not_scored together
with the evidence required for assessment.

These fields evaluate the work or system conditions, never a person's
worth, identity, competence, or access entitlement.

## Acceptance conditions

This baseline is ready for project review when:

- Legal requirements and project commitments remain distinguishable.
- No personal CyberRank becomes public status or eligibility.
- Unknown evidence remains unknown.
- Established deficiencies remain visible.
- Review outcomes do not become automatic access denial.
- Permission and execution authority remain separate.
- Withdrawal receipts do not overstate enforcement.
- Interoperability preserves protective meaning.
- Human fallback includes authority and outcome evidence.
- Data collection remains purpose-limited.
- Execution claims match actual execution.
- Independent validation is not replaced by self-review.
- No unsupported numerical score or real-world capability claim is made.

## Current evidence status

- Legal foundation:
  documented from the identified ADA provisions and DOJ guidance.
- Four-criterion review method:
  specification_complete_not_validated.
- Eighty-one-case partition:
  derived_under_assumptions.
- Runtime conformance:
  not established by this document.
- Participant accessibility evaluation:
  external_validation_required.
- Actual institutional service outcomes:
  external_validation_required.
- Independent legal acceptance:
  not established.

## Source basis

Binding regulatory provisions discussed:

- 28 CFR § 35.160:
  effective communication, auxiliary aids, primary consideration,
  contextual factors, privacy, independence, and interpreter reliance.
- 28 CFR § 35.164:
  fundamental alteration, undue financial and administrative burdens,
  decision authority, written reasons, and alternative action.
- 28 CFR § 35.130(b)(7)(i):
  reasonable modifications.
- 28 CFR § 35.130(f):
  prohibition on surcharges.
- 28 CFR § 35.107:
  responsible employee and grievance procedures for covered entities.

Explanatory authority:

- U.S. Department of Justice, ADA Requirements: Effective Communication.

Project basis:

- The October 31, 2026 conversation on augmented rights, institutional
  interpretation, interoperability, withdrawal, and human fallback.
- Project governance concerning voluntary self-description, minimal
  disclosure, accessible communication, continuity, and non-interference.

The project basis is not presented as binding public law.

## Governing principle

A sound institutional record explains the duty, the request, the
arrangement, the evidence, and the remaining uncertainty.

A sound service additionally demonstrates that access worked.

Neither task requires converting a person's identity, communication
style, or private architecture into a public score.
