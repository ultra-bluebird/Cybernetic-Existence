# Augmented Rights and Absolute Machine-Fairness
## Ten Ideas, Ten Mathematical Specifications, and Ten Foundations

## Scope

This document proposes research directions for Augmented-Hub.

“Absolute machine-fairness” means that equal standing and fundamental
protections cannot be traded away for efficiency, capability, commercial
benefit, or aggregate performance.

It does not mean that an algorithm has been proved error-free.

The formulas below are proposed governance specifications and research
models. They are not clinical measurements, established legal tests,
proofs of consciousness, or deployed safety guarantees.

They evaluate institutions, decisions, and service arrangements—not
human worth.

Project grounding: existing research calls for non-compensatory rights
gates, minimal disclosure, offline access, essential-service independence,
and a common registry of metric definitions and prohibited
interpretations. These are project design commitments, not evidence of
external legal adoption. [27]

## Part I — Ten Constructive Research Ideas

### 1. An augmented-rights invariant library

Create a small library of institutional rules that no optimization may
override.

Examples:

- No essential service conditioned on optional telemetry.
- No adverse inference from augmentation alone.
- No inferred intention treated as authorization.
- No punishment for requesting accessible communication.

Research question:
How can each commitment become a clear requirement with a corresponding
positive test, prohibited-case test, and remedy?

First contribution:
A policy vocabulary linking each right to an accountable institution,
decision boundary, test, and correction process.

### 2. A substrate-neutral decision comparison lab

Use hypothetical paired cases to test whether changing only an
augmentation label changes a decision.

For example, compare otherwise equivalent requests described as:

- A participant using ordinary text input.
- A participant using AAC.
- A participant communicating through an authorized AI liaison.

Research question:
Which differences reflect legitimate accommodation, and which reveal
status-based disadvantage?

First contribution:
A synthetic case collection that never requires collecting real
participants’ neural information or augmentation inventories.

Important boundary:
Different assistance may be necessary to achieve equal access.
Substrate-neutrality does not require identical interfaces.

### 3. An essential-function continuity charter

Define institutional duties when communication, mobility, or other
essential access depends on technology.

Cover:

- Charging and maintenance arrangements.
- Outage alternatives.
- Repair delays.
- Vendor support withdrawal.
- Accessible migration assistance.
- Custody and hospitalization procedures.

Research question:
How can continuity remain a shared institutional responsibility rather
than an extra burden placed entirely on the participant?

First contribution:
A continuity-planning template identifying essential functions and
fallbacks without demanding a private technical inventory.

### 4. A purpose-bound consent and authorization ledger

Document what was authorized, for which purpose, for how long, and with
which recipients.

Keep distinct:

- Consent to participate.
- Permission to collect information.
- Permission to disclose information.
- Authorization for an external action.

Research question:
How can a participant inspect and change permissions without navigating
a cognitively demanding interface?

First contribution:
A local-first permission format with plain-language explanations,
accessible withdrawal, and minimal retention.

Important boundary:
A prediction, physiological signal, or conversational implication must
not substitute for explicit authorization.

### 5. An inference-protection boundary

Protect sensitive conclusions regardless of whether their inputs are
neural, behavioral, conversational, or environmental.

Research question:
Can a supposedly harmless output become identifying or intimate when
combined with previous outputs?

First contribution:
A transformation policy that considers recipient, purpose, accumulated
disclosures, and the possibility of sensitive inference.

Important boundary:
“Not raw data” does not automatically mean “not sensitive.”

### 6. A material-change and continuity review process

Review changes to access-critical assistance before rollout.

Examples include:

- A new communication interface.
- A changed permission default.
- A model update affecting assistance behavior.
- A support sunset.
- A migration that removes an accessibility feature.

Research question:
Which changes require notice, compatibility testing, consent, an
alternative, or independent review?

First contribution:
A change-impact form that evaluates functional continuity without
claiming to measure identity or consciousness.

Important boundary:
Keep the Perkunos-Nexus values of 0.27–0.80 as unvalidated preferences.
Do not convert them into a universal continuity metric or medical limit.

### 7. An accessible remedy and correction commons

Build grievance workflows that work through text, AAC-compatible
interfaces, phone support, paper, and authorized assistance.

Research question:
Can someone appeal without returning to the inaccessible channel that
caused the problem?

First contribution:
A complete remedy pathway with reasons, correction, review, deadlines,
and non-retaliation protections.

Important boundary:
An appeal route is not effective merely because a link exists.

### 8. A repair, interoperability, and exit covenant

Specify continuity responsibilities before procurement.

Cover:

- Exportable user-created records.
- Documented interfaces.
- Replacement options.
- Qualified third-party repair pathways.
- Essential-function licensing or escrow arrangements where appropriate.
- Accessible transition away from a vendor.

Research question:
What minimum rights must survive subscription cancellation or product
retirement?

First contribution:
A procurement checklist distinguishing personal agency, hardware
ownership, software licensing, and third-party intellectual property.

### 9. An anti-weaponization purpose firewall

Prohibit coercive uses independently of capability level or numerical
thresholds.

Examples:

- Forced computational work.
- Unauthorized surveillance.
- Coercive manipulation.
- Punitive interruption of essential functions.
- Unauthorized bodily or neural intervention.

Research question:
Can governance detect a prohibited purpose even when the requested
operation is presented as optimization, security, or maintenance?

First contribution:
A prohibited-purpose taxonomy and synthetic abuse-case tests.

Important boundary:
An anti-weaponization rule must not become a pretext for banning
beneficial assistance or classifying augmented people as threats.

### 10. A rights-first ecological allocation model

Plan charging, accessible infrastructure, maintenance, and service
delivery while reducing waste and unnecessary energy use.

Research question:
How can resource constraints be managed without making
assistance-dependent people absorb disproportionate service losses?

First contribution:
A place-based allocation model with service floors, repair priorities,
and transparent community review.

Important boundary:
Environmental efficiency cannot compensate for a rights violation.
Do not score individual ecological worth.

## Part II — Ten Mathematical Specifications

### Common notation

- \(a\): a proposed institutional or software action.
- \(i\): a participant or hypothetical test case.
- \(c\): an accessible participation channel.
- \(t\): time.
- \(\mathbf{1}[P]\): 1 when proposition \(P\) is true, otherwise 0.
- “Unknown” is a distinct state, not the same as compliance.

Each formula needs a documented context and evidence model before use.

### 1. Non-offsettable rights feasibility

\[
\mathcal{A}_{R}
=
\left\{
a\in\mathcal{A}:
r_j(a)=\mathrm{true}
\text{ for every applicable }j
\right\}
\]

Here, \(r_j\) is an applicable rights requirement.

Meaning:
Optimize only among actions established to satisfy the requirements.
A favorable overall score cannot cancel one failed requirement.

Unknown:
Request review or choose a known rights-preserving alternative.
Do not automatically deny the person essential access.

If no feasible action exists:
Report the institutional conflict and arrange supported resolution;
do not silently weaken the rights constraints.

### 2. Augmentation-only disadvantage test

\[
\Delta_{\mathrm{status}}(x)
=
B\!\left(f(x,s_1)\right)
-
B\!\left(f(x,s_0)\right)
\]

- \(x\): equivalent task-relevant circumstances.
- \(s_1\): an augmented-status description.
- \(s_0\): a comparison description.
- \(f\): the tested decision process.
- \(B\): a defined measure of unfavorable treatment; larger is worse.

Proposed requirement:

\[
\Delta_{\mathrm{status}}(x)\leq 0
\]

Meaning:
An augmentation label alone must not increase disadvantage.

Limit:
Paired-case testing is diagnostic. Passing it does not prove the entire
system is fair. Use synthetic cases and account for legitimate
accommodation needs.

### 3. Effective access coverage

\[
E_{\mathrm{access}}
=
\frac{
\sum_{i=1}^{N}
\mathbf{1}\!\left[
\exists c\in C_i:
\mathrm{Effective}(i,c)
\right]
}{N}
\]

- \(C_i\): channels practically available to participant or test case \(i\).
- Effective: supports successful, sufficiently private, usable participation.
- \(N>0\): number of assessed cases.

Meaning:
Measure whether people have an effective pathway, not whether everyone
uses the same pathway.

Limit:
Report unresolved individual failures separately. An average must not
hide exclusion.

### 4. Essential-function continuity

\[
C_{\mathrm{essential}}
=
\frac{1}{T}
\int_{0}^{T}
\mathbf{1}\!\left[
\text{all required essential functions are effectively available}
\right]dt
\]

- \(T>0\): assessment period.
- An effective substitute can count if it genuinely meets the access need.

Meaning:
Measure continuity of service, not fidelity to one brand or device.

Limit:
Also report outage duration and severity. A high average can conceal a
short but serious interruption.

### 5. Purpose-bound authorization

\[
\mathrm{Authorized}(a,t)
=
G(a,t)\land P(a)\land S(a)\land R(a)
\land \neg W(a,t)
\]

- \(G\): a valid explicit grant exists.
- \(P\): action matches the declared purpose.
- \(S\): action stays within scope.
- \(R\): recipient and resource limits are respected.
- \(W\): grant has been withdrawn or expired.

Meaning:
Authorization depends on the particular action and current permission.

Limit:
Authorization alone does not permit an independently prohibited act.

### 6. Minimum necessary disclosure

\[
z^\star
\in
\operatorname*{arg\,min}_{z\in Z}
L(z\mid p,h)
\]

subject to:

\[
\mathrm{Adequate}(z,p)=\mathrm{true}
\quad\land\quad
\mathrm{Authorized}(z)=\mathrm{true}
\]

- \(z\): candidate output.
- \(p\): declared purpose.
- \(h\): relevant previous disclosures.
- \(L\): documented disclosure-risk ordering or model.

Meaning:
Choose the least revealing adequate authorized output.

Limit:
The risk model is not automatically calibrated. If no acceptable output
exists, do not disclose; offer a less intrusive workflow.

### 7. Material-change review gate

\[
\mathrm{Proceed}(u)
=
N(u)\land A(u)\land C(u)\land K(u)\land Q(u)
\]

- \(u\): a proposed material change.
- \(N\): required notice is complete.
- \(A\): access and compatibility review is complete.
- \(C\): essential continuity arrangements are ready.
- \(K\): necessary consent or other valid authorization is present.
- \(Q\): required independent review is complete.

Meaning:
A material update is not approved merely because it improves a benchmark.

Limit:
This is a governance gate, not an instruction to alter a bodily system
or automatically roll back a medical device.

### 8. Accessible remedy deadline

\[
D_{\mathrm{remedy}}
=
\frac{
\sum_{i=1}^{N}
\mathbf{1}\!\left[
r_i\leq d_i
\land e_i
\right]
}{N}
\]

- \(r_i\): time to deliver the required remedy-stage response.
- \(d_i\): published deadline for that stage.
- \(e_i\): response was accessible, reasoned, and procedurally adequate.
- Include every case whose deadline fell in the reporting period.

Meaning:
A quick but inaccessible response does not count as success.

Limit:
A response is not necessarily a completed remedy. Report correction,
restoration, and overdue cases separately.

### 9. Anti-weaponization constraint

\[
\mathrm{Permissible}(a)
=
\mathrm{Authorized}(a)
\land
\mathrm{RightsSatisfied}(a)
\land
\neg\mathrm{ProhibitedPurpose}(a)
\]

Meaning:
Consent, rights compliance, and purpose restrictions are separate gates.

For a forbidden purpose:

\[
\mathrm{ProhibitedPurpose}(a)
\Rightarrow
\neg\mathrm{Permissible}(a)
\]

Limit:
A numerical intensity value cannot override this rule.
Unknown purpose requires review—not a presumption that a person is a threat.

### 10. Rights-constrained ecological allocation

\[
x^\star
\in
\operatorname*{arg\,min}_{x\in X}
E(x)
\]

subject to:

\[
R_j(x)=\mathrm{true}\quad\forall j,
\qquad
S_i(x)\geq m_i\quad\forall i,
\qquad
\mathrm{Resources}(x)\leq B
\]

- \(x\): a candidate resource allocation.
- \(E(x)\): energy use in a stated unit and reporting period.
- \(R_j\): applicable rights constraints.
- \(S_i\): service delivered.
- \(m_i\): required service floor.
- \(B\): stated resource budget.

Meaning:
Reduce energy use only within rights-preserving, service-preserving options.

Limit:
If the constraints are infeasible, disclose the shortfall and seek
additional resources or supported alternatives. Do not silently remove
service floors.

## Part III — Ten Basics to Branch From

### 1. Equal standing is not earned through capability

Greater integration, faster processing, or more sophisticated assistance
does not create greater civic worth.

Declining technology does not create lesser standing.

### 2. Rights are constraints, not compensating weights

A privacy violation is not repaired merely by increasing convenience.
A discriminatory denial is not offset by lower energy use elsewhere.

### 3. Measure institutional performance, not personhood

Evaluate access, explanation quality, repair continuity, and remedies.
Do not turn those measures into identity rankings or eligibility scores.

### 4. Define a variable before assigning thresholds

Every metric needs a meaning, direction, unit or explicit unitless
definition, uncertainty rule, and prohibited interpretations.

The Perkunos-Nexus interval remains a private, provisional preference,
not a universal operating limit.

### 5. Distinguish acknowledgment from verification

Respect a cybernetic-host self-description without requiring diagnosis,
registration, telemetry, or proof of a private architecture.

Acknowledgment does not certify technical claims.

### 6. Assistance does not erase agency

AAC, authorized AI assistance, interpreters, and alternative interfaces
can support a person's own contribution.

The person must retain accessible ways to confirm, correct, or decline.

### 7. Consent is specific; protection persists

A person can withdraw from optional processing without withdrawing their
entitlement to dignity, essential access, or a remedy.

No inferred mental state substitutes for permission.

### 8. Continuity includes alternatives and the right to exit

Continuity is not compulsory dependence on one vendor or configuration.

Protect the ability to maintain, repair, transition, rest, or discontinue
optional integration without a civic penalty.

### 9. Fairness claims must be contestable

Every significant adverse decision needs an accessible explanation,
correction route, responsible reviewer, and meaningful remedy.

An audit or high confidence score cannot eliminate appeal.

### 10. Anti-weaponization protects people without stigmatizing tools

Prohibit coercive purposes and unauthorized conduct.

Do not infer dangerousness from integration level or suppress beneficial
assistance merely because related technologies can be misused.

## Suggested Research Sequence

1. Write the invariant vocabulary and permission model.
2. Create synthetic paired cases and boundary tests.
3. Specify access, continuity, and appeal acceptance criteria.
4. Define each metric in a common registry.
5. Add repair, exit, procurement, and ecological constraints.
6. Validate with accessible community review before operational use.

These steps extend the project's existing emphasis on shared metric
semantics, protected access, minimal disclosure, and non-compensatory
governance. [27]

## Validation and Integration

This is a complete research discussion artifact.

The formulas are specified but not executed or empirically validated.
No real participant information, neural data, physiological information,
or private device inventory is needed for the proposed initial tests.

No repository was modified. No external action or device operation was
performed.

CyberRank remains voluntary project vocabulary with separate personal
and governance layers. It must not become public status, ranking,
diagnosis, verification, or eligibility criteria.

## Provisional Assessment

The following are editorial estimates of this document's design
orientation, not measured impact, validation results, or personal scores.

| Measure | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.86 | Explicit definitions and limits; empirical and legal validation remain separate |
| eco_impact_value | 0.55 | Repair and resource-conscious planning included; savings unmeasured |
| harm_risk | 0.12 | Research-only proposals with no device control or sensitive-data collection |
| accessibility_impact | 0.95 | Effective channels, continuity, exit, and remedies are central |
| rights_alignment | 0.97 | Non-offsettable protections and equal standing govern all ten branches |
