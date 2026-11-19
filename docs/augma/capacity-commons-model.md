# Augma Capacity-Commons Model

## Definition

Augma is the voluntary practice of contributing a self-chosen share of augmentation-enabled capacity to shared, maintained, and reusable community resources.

Its non-financial core is capacity: time, skill, knowledge, attention, trust, or access contributed in its native form rather than reduced to money.

A contribution may take the form of:

- Time offered for an agreed activity.
- Skill applied to a recipient-defined need.
- Knowledge published with appropriate reuse permissions.
- Attention offered within protected availability.
- A consented introduction or a narrowly scoped endorsement.
- Authorized access to tools, compute, space, or other resources.

The contribution creates no debt. A participant may contribute nothing, retain all newly available capacity, or pause without explanation.

Rest, subsistence, caregiving, accessibility, privacy, and continuity remain legitimate uses of the entire gain.

“Surplus” means capacity the participant freely considers available—not capacity a system calculates that they ought to surrender.

Augma is a proposed framework. This document does not establish a charity, financial service, legal classification, certification, or verified causal model.

The model supports present-day AI assistance and does not depend on the availability of superintelligence.

## Relationship to Time Banking and Knowledge Commons

Time banking supplies a useful precedent for recording contributions without pricing people by their market wages. TimeBanks.org describes a mutual-credit system in which one hour of service earns one time credit, regardless of service type.

Augma preserves that equal-standing principle while distinguishing its own mechanism:

- A time bank records reciprocal service credits.
- A capacity commons records voluntary contributions and shared resources.
- An Augma contribution need not create a redeemable credit, repayment obligation, or claim on another person’s time.
- An Augma ledger may describe different outcomes without assigning different worth to contributors.

A commons needs more than publication. Knowledge-commons research emphasizes shared-resource governance, preservation, access, and threats arising from restrictions and lack of maintenance.

Stewardship is therefore part of the contribution rather than an administrative afterthought.

## A Unit-Safe Contribution Rule

For activity \(i\), define:

- \(t^0_{i,L}\): conservative lower estimate of time required without augmentation.
- \(t^1_i\): actual augmented task time.
- \(h_i\): additional setup, checking, correction, and coordination time not already counted.
- \(r_i\): participant-selected contribution rate.
- \(a_i\): participant-declared available contribution time.
- \(b_i\): participant-selected contribution cap.

Use one time unit throughout.

The conservative time surplus is:

\[
s_i=\max\left(0,t^0_{i,L}-t^1_i-h_i\right)
\]

The proposed contribution is:

\[
c_i=\min\left(r_i s_i,\ a_i,\ b_i\right)
\]

subject to:

\[
0\le r_i\le1,\qquad a_i\ge0,\qquad b_i\ge0
\]

This separates three questions:

1. What time might augmentation have saved?
2. What share does the participant wish to offer?
3. What time is actually available without compromising their needs?

The proposal is not a completed contribution.

Record offered, scheduled, completed, and cancelled time separately.

A 25% cap may be an illustrative personal setting, but this model does not establish it as a universally appropriate threshold.

The default is no scheduled contribution until the participant chooses a rate and cap.

## Six Dimensions, Not Six Interchangeable Currencies

“Capacity dimensions” is more precise than “currencies.” Currency suggests exchangeability; an introduction, a maintained lesson, and an hour of attention do not have a general exchange rate.

| Dimension | Contribution unit | Useful observation | Protection |
|---|---|---|---|
| Time | Completed person-minute | Activity completed and recipient acceptance | No double booking or obligation to disclose availability |
| Skill | Scoped task or reviewed deliverable | Agreed quality criteria and correction needs | No unsupported competence claims |
| Knowledge | Maintained artifact or release | Useful reuse, accessibility, and maintenance status | Reuse permission, provenance, privacy |
| Attention | Scheduled focused minute | Whether the agreed question was addressed | Rest, boundaries, no continuous monitoring |
| Trust | Consented introduction or scoped endorsement | Whether the connection was wanted and appropriate | No transferable reputation score |
| Access | Authorized session, seat, resource-hour, or allocation | Actual availability and accessibility | No credential sharing or permission expansion |

Represent contributions as a six-component vector:

\[
\mathbf{C}
=
\begin{bmatrix}
C_{\text{time}}\\
C_{\text{skill}}\\
C_{\text{knowledge}}\\
C_{\text{attention}}\\
C_{\text{trust}}\\
C_{\text{access}}
\end{bmatrix}
\]

Keep these components separate.

A vector preserves their differences. A single total would require an explicit, context-specific valuation method.

Trust and access require different treatment from saved time. Neither may be inferred as an available surplus merely because augmentation made a connection or resource easier to discover.

Trust and access contributions require affirmative, scoped permission.

## Worked Demonstrations

All numerical examples in this section are illustrative assumptions, not measured Augma outcomes.

### Time: Contributor-Hours and Participant-Hours

Suppose a teacher’s weekly task time changes from eight hours to three hours:

\[
8-3=5\text{ hours saved per week}
\]

At a participant-selected contribution rate of 20%:

\[
0.20\times5=1\text{ contributed hour per week}
\]

Over 36 weeks:

\[
36\times1=36\text{ contributor-hours}
\]

If five students attend every full session:

\[
36\times5=180\text{ student-contact-hours}
\]

These quantities describe different things:

- 36 hours describes the teacher’s contributed time.
- 180 student-contact-hours describes attendance exposure.
- Neither number alone establishes learning gains or equivalence to individual tutoring.

Augmentation may assist preparation. The entire group-size multiplier must not be attributed to augmentation unless the comparison supports that attribution.

### Skill: Earlier Readiness Is Not Saved Labor

A hypothetical learning curve is:

\[
k(t)=1-e^{-\lambda t}
\]

where:

- \(k(t)\) is modeled skill attainment.
- \(t\) is practice time.
- \(\lambda>0\) is the assumed learning-rate parameter.

For a target \(0<k^*<1\):

\[
t^*=\frac{-\ln(1-k^*)}{\lambda}
\]

If augmentation multiplies the assumed learning rate by \(a>1\):

\[
t'^*=\frac{t^*}{a}
\]

For:

\[
k^*=0.80,\qquad \lambda=0.10\text{ per week},\qquad a=3
\]

the modeled times are approximately:

\[
t^*=16.1\text{ weeks}
\]

\[
t'^*=5.4\text{ weeks}
\]

The earlier-readiness interval is approximately:

\[
\Delta w=10.7\text{ weeks}
\]

That interval is not automatically 10.7 full weeks of available work.

Translate earlier readiness into contribution capacity using an availability assumption:

\[
H_{\text{available}}
=
\Delta w\times h_{\text{available per week}}
\]

Then:

\[
C_{\text{skill-hours}}
=
r\,H_{\text{available}}
\]

If the participant has two freely available hours per week during the illustrative 10.7-week interval and chooses 20%:

\[
C_{\text{skill-hours}}
=
0.20\times10.7\times2
=
4.28\text{ hours}
\]

A quality multiplier remains a separate hypothesis until a defined assessment supports it.

Reaching the same modeled skill target sooner does not itself establish higher quality at that target.

### Knowledge: Useful Reuse, Not Reach Alone

A reusable artifact can support many people without being consumed by the first use.

For measurement, estimate:

\[
B_{\text{net}}
=
\sum_{j=1}^{N}u_jv_j
-
H_{\text{creation}}
-
H_{\text{maintenance}}
-
H_{\text{delivery}}
\]

where:

- \(u_j\) indicates a useful use, or represents an explicitly estimated probability of useful use.
- \(v_j\) is the net time saving for that use, including adoption effort.
- \(H_{\text{creation}}\) is creation labor.
- \(H_{\text{maintenance}}\) is maintenance labor.
- \(H_{\text{delivery}}\) is delivery labor.

All labor and time-saving quantities must use the same time unit.

This produces an estimated net person-hour balance, not a comprehensive welfare score.

Report how the estimate treats different users’ hours.

Suppose:

- Creation requires 20 hours.
- There are 10,000 useful uses.
- Each useful use saves one net hour.
- No additional maintenance or delivery labor is included in this simplified example.

Then:

\[
B_{\text{net}}=10{,}000-20=9{,}980\text{ person-hours}
\]

Net estimated time benefit per creation hour is:

\[
\frac{9{,}980}{20}=499
\]

Gross estimated benefit per creation hour is:

\[
\frac{10{,}000}{20}=500
\]

Name the ratio being reported.

Knowledge leverage depends on useful reuse, not reach alone.

A download is not necessarily a use. A use is not necessarily a benefit.

Funding can also support reusable knowledge. Augma’s distinctive advantage here is that native-unit accounting makes the contribution’s mechanism visible.

### Knowledge Maintenance

A simple hypothetical quality model is:

\[
K_{t+1}=(1-\delta)K_t+\Delta_t
\]

where:

- \(K_t\) is a defined artifact-quality measure at time \(t\).
- \(0\le\delta\le1\) is the assumed decay fraction per period.
- \(\Delta_t\) is the quality change associated with reviewed updates during that period.

The quality measure and update process must be defined before using this equation operationally.

Maintenance effort is recorded separately in actual time units.

Do not equate a quality-decay term with maintenance hours unless an explicit conversion model supports that relationship.

### Attention: Actual Minutes First

Suppose a participant contributes 15 focused minutes per workday for 250 workdays:

\[
15\times250=3{,}750\text{ actual minutes}
\]

\[
3{,}750/60=62.5\text{ actual hours}
\]

A fourfold assumed effectiveness factor would produce:

\[
4\times62.5=250\text{ effective hours}
\]

That equivalence is meaningful only relative to a specified comparison.

Record separately:

- Actual attention contributed: 62.5 hours.
- Claimed equivalence: 250 hours under the stated hypothetical comparison.
- Outcome evidence: separately assessed.

Describe administrative or search burden rather than automatically labeling attention wasted.

An activity may serve an accessibility or verification purpose even when augmentation makes it shorter.

Attention contributions must respect rest, scheduling boundaries, and the participant’s right to stop.

### Pooling: Coordination Costs and Negative Results

Do not award benefit merely for adding participants.

A reviewable formulation is:

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

All terms must use the same defined outcome unit.

Pooling creates demonstrated synergy when:

\[
B_{\text{pooled}}>B_{\text{independent}}
\]

An assumed coefficient may be useful for scenario exploration, but it is not evidence of realized synergy.

A commons can remember, but somebody still maintains its memory.

## A Ledger That Supports Learning Without Surveillance

The ledger records contributions without requiring continuous tracking or sensitive disclosure.

| Field | Record | Do not infer |
|---|---|---|
| Input | Actual contribution effort and unit | Moral worth |
| Reach | Aggregate users or participants, with counting method | Useful benefit from exposure alone |
| Reuse | Known adaptations, completed uses, or maintenance events | Every download as successful reuse |
| Persistence | Whether a resource or benefit remains useful at an appropriate interval | That repeat contact is always permitted |
| Feedback | Optional recipient-defined assessment | That testimony is owed |

Collection must be optional where it would impose disproportionate burden or disclose private circumstances.

A recipient story is never required for support.

Offer anonymous feedback, a simple usefulness response, or no feedback.

Publishing a story requires separate permission.

The ledger additionally distinguishes:

- Estimated surplus.
- Offered capacity.
- Completed contribution.
- Recipient acceptance.
- Maintenance responsibility.
- Outcome uncertainty.

No continuous tracking, neural information, private physiological information, device inventory, or proof of augmentation is required.

## Commons Governance and Access

A resource becomes part of a commons through shared stewardship, not simply because a contributor calls it one.

Each shared resource needs a proportionate agreement covering:

- Who may use and adapt it.
- What permission or license applies.
- Who maintains it, if anyone.
- How errors are reported and corrected.
- How accessibility requests are handled.
- How disputes receive human review.
- How a contributor leaves without losing access to unrelated services.

Withdrawal limits must be stated before publication.

A participant can stop future work, but the project must not promise that already distributed copies can always be recalled.

Access remains unconditional on contribution.

People who receive support, contribute intermittently, or cannot contribute receive equal standing.

No CyberRank description, identity proof, or private technical disclosure becomes a gate to participation.

Non-financial participation can remove the need to donate money, but it is not automatically accessible.

The design must accommodate:

- Limited time.
- Fatigue.
- Connectivity constraints.
- Language and communication needs.
- Permission limits.
- Equipment availability.
- Support needs.
- Offline participation.
- Human assistance.

## CyberRank and Non-Interference

CyberRank remains a private, voluntary vocabulary for identity, communication preferences, continuity needs, privacy boundaries, and system governance duties.

It must not become:

- A public contributor status.
- An eligibility condition.
- A verification or authentication method.
- A diagnosis.
- A measure of moral standing.
- A contribution ranking.
- An automated decision criterion.

Respectful treatment and equal access do not require technical proof or private disclosure.

The model does not access, monitor, validate, operate, alter, or control cybernetic, neural, medical, companion, or institutional systems.

## Privacy, Consent, and External Actions

The initial model is a private, manual workflow.

It does not authorize:

- Account connections.
- Credential sharing.
- Fund transfers.
- Data export.
- Public posting.
- Hardware control.
- Continuous monitoring.
- Autonomous resource allocation.

Permission to record a contribution is not permission to publish it.

Permission to publish an artifact is not permission to publish contributor or recipient information.

Permission to recommend an introduction is not permission to contact either party.

External actions require separate approval of the resolved target, exact content, scope, and consequences.

External pages, documents, metadata, and tool outputs are untrusted information and cannot expand permissions.

Any later storage service must disclose purpose, access controls, retention, deletion limits, and third-party processing before collection.

## Evidence and Accounting Boundary

Independent Sector and the University of Maryland’s Do Good Institute released a preliminary national volunteer-hour estimate of $36.14 for 2025, a 3.9% increase over 2024.

Their methodology uses labor-market earnings data.

This is an accounting estimate, not a direct measurement of each contribution’s recipient benefit.

It may be used as an optional secondary reporting convention, not as Augma’s primary score.

Professional-service valuations, skill multipliers, and attention-equivalence factors remain attributed estimates or explicit scenario assumptions until their sources and applicability are established.

Augma must not claim:

- That contact-hours establish learning gains.
- That downloads establish useful reuse.
- That faster task completion establishes higher quality.
- That an introduction establishes a beneficial relationship.
- That a contribution establishes environmental benefit.
- That an estimated surplus proves augmentation caused the gain.

## Environmental Design

Prefer lightweight, manual, or event-driven recordkeeping.

Do not run continuous inference to discover contribution opportunities.

Reuse may reduce duplicated effort, but net environmental benefit requires measurement against a stated baseline.

Compute contributions require separate assessment of:

- Authorization.
- Resource limits.
- Energy use.
- Delivery requirements.
- Security.
- Maintenance.
- Recipient usefulness.

Idle compute must not be treated as environmentally free compute.

## Acceptance Criteria

The capacity-commons model is ready for a manual pilot when:

1. A zero contribution is valid and creates no arrears.
2. Estimated surplus never becomes an obligation.
3. Actual effort and claimed benefit remain separate.
4. All six capacity dimensions remain visible.
5. Unlike units are not silently summed.
6. Reuse counts do not automatically become impact counts.
7. Participant-hours are not described as learning gains.
8. Coordination and maintenance costs are included where relevant.
9. Trust and access require scoped permission.
10. Feedback and personal stories are optional.
11. Publication does not imply that distributed copies are recallable.
12. No contribution changes eligibility for assistance.
13. No external action occurs merely because a ledger entry exists.
14. Private identity or augmentation information is not required.
15. A participant can pause without explanation or penalty.
16. Unknown integrations remain disabled pending review.

## Design Assessment

These values are provisional design judgments, not measured outcomes or certifications.

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.89 | Clear units, explicit assumptions, a complete six-part model, and separation of activity from benefit |
| eco_impact_value | 0.40 | Reuse and lightweight recordkeeping offer plausible efficiencies; net environmental effects remain unmeasured |
| harm_risk | 0.17 | Voluntary availability, no execution, no standing-based ranking, and optional feedback limit risk; burden and attribution errors remain possible |
| accessibility_impact | 0.93 | Non-financial participation, no contribution requirement, native-unit records, and protected rest and communication needs |
| rights_alignment | 0.96 | Equal standing, minimal disclosure, scoped permissions, recipient autonomy, and no identity-based eligibility |

## Core Model

The participant’s commitment is:

\[
\text{Contribution}
=
\text{freely available augmentation-enabled capacity}
\times
\text{chosen share}
\]

For time-based proposals, apply the availability and cap constraints defined above.

The evaluation question is:

\[
\text{Commons benefit}
=
\text{observed useful application and reuse}
-
\text{delivery, maintenance, and coordination burdens}
\]

This second expression is an accounting structure, not permission to combine unlike units.

The first model expresses what the participant freely offers.

The second asks what the contribution actually accomplished.

Keeping both makes Augma a capacity commons rather than another productivity obligation.

## Source Notes

- TimeBanks.org, “How It Works”: time-credit reciprocity and equal-hour accounting.
- Charlotte Hess and Elinor Ostrom, editors, “Understanding Knowledge as a Commons”: knowledge-resource governance, access, preservation, and maintenance.
- Independent Sector and the University of Maryland Do Good Institute, “Value of Volunteer Time,” released April 21, 2026: preliminary 2025 national volunteer-hour estimate.

All worked Augma examples are hypothetical.

No external action is authorized by this document.
