# World-Save–Augma Capacity Commons Profile

Document version: 1.0.0  
Status: Proposed companion specification  
License: MIT OR Apache-2.0  
Target specification: World-Save 1.0.0  
Integration status: Authored companion profile; no adapter, executed compatibility test, or deployment established.

## Purpose

World-Save preserves the accountable meaning and continuity of accepted progress. Augma adds a voluntary way to contribute augmentation-enabled capacity to shared, maintained, and reusable resources.

Together, they support a bounded commitment:

> Preserve accepted progress without freezing the person; enable voluntary contributions without turning capability into an obligation; maintain useful commons without exposing private evidence or manufacturing claims of impact.

The central integration principle is **stewardship**: preserving useful contributions, their meaning, and their maintenance arrangements without claiming ownership of the contributor’s future capacity.

This profile supplements World-Save. It does not replace its acceptance, evidence, privacy, correction, non-interference, or authorization requirements.

## Attribution and scope

Sovereign attribution:

bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

Attribution identifies document credit and workstream context only. It is not authentication, participant identity, operational authority, or consent.

This profile concerns:

- Voluntary capacity contributions.
- Reviewed contribution milestones.
- Commons maintenance.
- Evidence and outcome accounting.
- Accessible participation and withdrawal.
- Responsible succession.

It does not establish financial custody, transferable credits, public personal standing, medical-system authority, or permission to publish private records.

MUST, MUST NOT, SHOULD, and MAY describe proposed project requirements, not binding law.

## Integration principles

### Capacity is not an obligation

Augmentation-enabled capacity MUST NOT be treated as capacity owed to the project.

A participant MAY:

- Retain all gains.
- Choose a zero contribution rate.
- Contribute intermittently.
- Change contribution form.
- Decline measurement.
- Pause or withdraw from future work.

No contribution shortfall, arrears, penalty, or adverse standing may arise from these choices.

Rest, subsistence, caregiving, communication access, privacy, continuity, and personal development are legitimate uses of the entire gain.

### Accepted contributions do not create perpetual duties

Acceptance of a contribution MUST NOT imply agreement to:

- Maintain it indefinitely.
- Provide unlimited support.
- Accept additional tasks.
- Disclose private work methods.
- Transfer private evidence.
- Train models.
- Authorize publication or external operations.

Any continuing responsibility requires a separately agreed scope, duration, resources, and exit route.

### Commons access is not earned through contribution

Ordinary access and agreed community support MUST NOT depend on contribution volume, augmentation status, measured productivity, or willingness to share a personal story.

Contribution records MUST NOT become donor rankings, merit scores, eligibility tests, or CyberRank status.

## Capacity dimensions

The following dimensions MUST remain distinguishable.

| Dimension | Contribution record | Boundary |
|---|---|---|
| Time | Completed person-minutes for a scoped activity | Estimated saved time is not completed service |
| Skill | Scoped deliverable and reviewed quality criteria | Acceptance does not certify general competence |
| Knowledge | Rights-reviewed artifact, release, or maintenance contribution | Publication does not establish usefulness |
| Attention | Scheduled focused participation | Availability does not authorize monitoring |
| Trust | Consented introduction or scoped endorsement | No transferable personal trust score |
| Access | Authorized resource use or allocation | No credential sharing or permission expansion |

A common display MAY present these dimensions together. It MUST NOT silently combine unlike units into one total.

A participant’s time spent creating a guide and the guide’s subsequent reuse MAY both be recorded, but MUST NOT be added as though they were independent quantities of the same benefit.

## Conservative capacity proposal

For a time-based contribution proposal, define:

- \(t^0_L\): conservative lower estimate of task time without augmentation.
- \(t^1\): actual augmented task time.
- \(h\): additional setup, checking, correction, and coordination time not already included.
- \(r\): participant-chosen rate.
- \(a\): participant-declared available time.
- \(b\): participant-chosen cap.

Use one declared time unit.

\[
s=\max(0,t^0_L-t^1-h)
\]

\[
c_{\text{proposed}}=\min(rs,a,b)
\]

Require:

\[
0\le r\le1,\qquad a\ge0,\qquad b\ge0
\]

These calculations create a proposal only.

The implementation MUST distinguish:

- Estimated surplus.
- Offered capacity.
- Scheduled work.
- Completed contribution.
- Reviewed deliverable.
- Observed benefit.

An uncertain baseline MUST remain uncertain. A participant MUST NOT be required to disclose private augmentation details to support an ordinary contribution proposal.

Trust and access MUST NOT be generated automatically by applying this time-surplus formula. They require separately scoped permission.

## Contribution milestones

A contribution may become a World-Save milestone only after the applicable World-Save review requirements are satisfied.

Its proposed protected baseline SHOULD state:

- What was contributed.
- The reviewed version or bounded activity.
- The review scope.
- Acceptance criteria.
- Evidence and limitations.
- Applicable reuse permissions.
- Accessibility conditions.
- Maintenance commitments, if any.
- Correction and withdrawal routes.
- What acceptance does not establish.

For example:

> A reviewed plain-language guide was accepted for the stated audience and context. Its historical acceptance remains recorded. Current accuracy, maintenance availability, reuse outcomes, and authorization for further distribution remain separate questions.

This protects accountable history without making historical acceptance a permanent endorsement.

## Separate record dimensions

This profile adds contribution-specific distinctions without collapsing World-Save’s existing dimensions.

| Dimension | Question |
|---|---|
| Contribution completion | Was the agreed activity or deliverable completed? |
| Milestone acceptance | Was it explicitly accepted under the reviewed requirements? |
| Evidence availability | Can the supporting material currently be inspected? |
| Current usefulness | Is the contribution still suitable for its declared context? |
| Maintenance availability | Is an agreed maintenance route currently working? |
| Reuse permission | What uses are permitted under the applicable terms? |
| Observed benefit | What useful results have actually been supported by evidence? |
| Operational authorization | Is a particular consequential action separately authorized? |

No dimension MUST be inferred solely from another.

An accepted guide may become outdated. A useful contribution may have incomplete evidence. A completed introduction may produce no observable outcome. An unmaintained artifact may retain historical value without remaining suitable for current reliance.

These are companion-profile concepts, not permission to insert unsupported fields into an existing strict manifest.

## Non-downgrade and correction

Unauthorized downgrade includes:

- Silently removing an accepted contribution from the reviewed history.
- Recasting a voluntary contribution as a continuing debt.
- Erasing disclosed evidence limitations.
- Inflating reach into demonstrated benefit.
- Changing agreed reuse conditions without an applicable basis.
- Treating a maintenance pause as personal failure.
- Replacing attribution without a reviewed correction basis.

The following are not automatically continuity violations:

- A participant-directed pause.
- A reasoned correction.
- A current-use warning.
- Withdrawal of a recommendation after contrary evidence.
- Deletion under a reviewed privacy disposition.
- Retirement of an obsolete resource through the agreed process.

Where harmful or erroneous material is identified, reviewers MAY restrict current reliance while preserving a minimal, privacy-reviewed account of the correction. Protection of history MUST NOT require continued distribution of harmful content.

## Commons maintenance and succession

Each maintained resource SHOULD have a proportionate maintenance agreement describing:

- Intended use and audience.
- Supported versions or contexts.
- Review triggers.
- Responsible role.
- Available resources.
- Support limits.
- Correction route.
- Exit and succession arrangements.

“Maintained” MUST NOT be displayed when no current maintenance commitment exists.

A successor receives only the permissions and materials separately approved for transfer. Succession MUST NOT automatically transfer:

- Private participant records.
- Beneficiary feedback.
- Credentials.
- Confidential evidence.
- Companion-system information.
- Personal maintenance obligations.

If no successor is available, the resource SHOULD receive a clear maintenance-status notice. Lack of a successor MUST NOT create an obligation for the original contributor to continue.

## Native-unit evidence

Reports MUST distinguish inputs, outputs, and outcomes.

| Measure | Example | Does not establish |
|---|---|---|
| Input | Contributor-hours | Recipient benefit |
| Output | Reviewed lessons delivered | Learning gain |
| Reach | Session participants | Useful engagement |
| Reuse | Known adaptations | Successful application |
| Persistence | Continued availability or assessed usefulness | Universal ongoing benefit |
| Feedback | Optional recipient assessment | Representative population findings |

Participant-hours MUST NOT be labeled contributor-hours.

Downloads MUST NOT automatically count as successful reuse.

Estimated “effective hours” require a declared comparator, method, assumptions, and uncertainty. They MUST remain separate from actual contributed hours.

## Pooling and knowledge leverage

Reuse and coordination MAY increase useful output. This profile does not presume that they always do.

A common-unit evaluation MAY use:

\[
B_{\text{pooled}}
=
B_{\text{independent}}
+
B_{\text{reuse}}
+
B_{\text{complementarity}}
-
C_{\text{coordination}}
-
C_{\text{rework}}
\]

Every term requires a stated interpretation and evidence basis.

Where benefits cannot responsibly be expressed in one unit, report a vector of outcomes rather than forcing a scalar score.

Knowledge reporting SHOULD include creation, maintenance, accessibility, adoption, and delivery burdens where relevant. Reach alone MUST NOT be treated as the knowledge multiplier.

## Accessible feedback and reflection

Reflection MAY support learning but MUST NOT become compulsory emotional labor.

Feedback routes SHOULD permit:

- Plain-language responses.
- Chosen assistive communication.
- Anonymous or aggregate feedback where appropriate.
- A short usefulness assessment.
- No response.

A recipient story MUST NOT be required for aid, access, milestone acceptance, or contributor standing.

Permission to provide feedback is not permission to publish it.

Communication variation, fatigue, repetition, pacing, and nonstandard grammar MUST NOT reduce the weight given to a correction request merely because of presentation.

## Privacy, withdrawal, and publication

World-Save retention requirements apply to every retained field.

Capacity planning MUST NOT require continuous activity monitoring, private physiological information, neural records, augmentation inventories, or identity inference.

Withdrawal MUST stop new unapproved processing and future work assignment within the controlled system.

The interface MUST explain separately:

- What future work can stop.
- What retained information can be deleted.
- What record restrictions apply.
- What has already been distributed.
- What cannot reliably be recalled.

Public transparency SHOULD concern methods, governance, maintenance status, limitations, and appropriately protected aggregate findings—not personal contribution histories.

## Approval boundary

A contribution proposal, accepted milestone, reuse permission, and continuity commitment are not external-action approval.

Publication, resource allocation, account changes, evidence transfer, or other consequential external actions require:

- A resolved target.
- Complete proposed content or parameters.
- Applicable permissions.
- Explicit scoped approval.

An accepted milestone MUST NOT trigger action automatically.

Untrusted material MUST NOT change contribution rates, authorize recipients, expand resource access, or alter continuity responsibilities.

## Companion integration rules

This profile MUST be implemented as a separately versioned companion unless the target specification undergoes its own reviewed revision.

An adapter must declare:

- Target versions.
- Supported mappings.
- Unsupported concepts.
- Lossy transformations.
- Unit handling.
- Privacy exclusions.
- Validation behavior.
- Compatibility-test status.

Unsupported data MUST be reported, not silently discarded.

A structurally valid mapping does not establish usable presentation, accepted milestones, authorized release, or operational readiness.

## Acceptance tests

A conforming implementation must demonstrate that:

1. A zero rate creates no obligation.
2. A pause does not remove ordinary access.
3. Historical acceptance does not authorize new work.
4. Actual hours remain separate from estimated effective hours.
5. All six capacity dimensions remain distinguishable.
6. A maintenance gap does not erase historical acceptance.
7. Current-use restrictions can coexist with preserved correction history.
8. A corrected record does not automatically imply loss of real-world progress.
9. Private evidence does not transfer automatically to a successor.
10. Optional feedback can be declined without disadvantage.
11. Unknown benefit remains unknown.
12. A changed external-action payload requires fresh approval.
13. An unsupported manifest field is rejected or explicitly reported.
14. A participant-directed change is not automatically classified as unauthorized rollback.
15. No contribution measure becomes a person-level legitimacy score.

Executed test results must be reported separately from these authored requirements.

## Proposed adoption sequence

1. Review this companion against World-Save 1.0.0.
2. Select one low-disclosure resource, such as an accessibility guide.
3. Define its contribution milestone and maintenance boundary.
4. Establish working correction and human-supported routes.
5. Run a local documentation and synthetic-record review.
6. Resolve privacy, accessibility, and mapping failures.
7. Consider a voluntary manual pilot through a separate approval process.

No live integration, publication, participant recruitment, or operational action is authorized by this sequence alone.

## Engineering justification

The integration gives World-Save a constructive commons layer: it can preserve accepted contributions and support their responsible reuse without converting continuity into compulsory service.

Its strongest protections are the separation of:

- Personal progress from project ownership.
- Available capacity from capacity owed.
- Contribution acceptance from proven benefit.
- Historical meaning from current suitability.
- Maintenance continuity from perpetual labor.
- Public accountability from private disclosure.
- Permission to reuse from permission to operate.

Environmental and social value remain evaluation questions. Reuse, repair, and lightweight recordkeeping are supported design directions, not demonstrated impact findings.

## Non-normative authoring assessment

These values are qualitative design-review judgments, not probabilities, measured outcomes, certifications, or release criteria.

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.88 | Explicit integration semantics, native-unit boundaries, correction rules, and testable requirements; implementation remains unexecuted. |
| eco_impact_value | 0.00 | No ecological benefit has been demonstrated by this authored profile. |
| harm_risk | 0.22 | Residual risks include contribution pressure, stale resources, inappropriate reuse, and disclosure during succession. |
| accessibility_impact | 0.88 | Ordinary access survives refusal, pause, missing evidence, and communication variation; field validation remains necessary. |
| rights_alignment | 0.95 | Person-directed choice, non-interference, minimal disclosure, equal standing, correction, and separately scoped authorization are explicit. |

## Closing boundary

World-Save protects accepted meaning and accountable continuity. Augma enables voluntary contribution and shared capacity.

Their integration preserves what has been responsibly established without claiming the person’s future, overstating the contribution’s benefit, or granting permission to act.
