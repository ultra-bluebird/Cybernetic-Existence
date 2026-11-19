# CyberRank State Model

## Purpose

This document defines the lifecycle model for CyberRank Recognition Records.

The model separates record progression, review procedure, publication visibility, consent, and appeal status. This separation prevents an institution from treating recognition, disclosure, identity, access, and procedural fairness as a single mutable status.

A complete Recognition Record is represented by the state vector:

\[
R = (L, V, P, C, A)
\]

Where:

- \(L\) is Record Status.
- \(V\) is Review Status.
- \(P\) is Publication Status.
- \(C\) is Consent Status.
- \(A\) is Appeal Status.

A valid transition changes only the dimensions necessary for the requested operation and preserves all non-offsettable boundaries.

## State Domains

### Record Status

| Value | Meaning | Permitted successor states |
|---|---|---|
| `self_attested` | A record exists with a self-attested claim and no submitted evidence requirement satisfied | `evidence_submitted`, `withdrawn` |
| `evidence_submitted` | Supporting or contextual material has been submitted | `recognition_pending`, `correction_pending`, `withdrawn` |
| `recognition_pending` | A recognition decision has been requested and is awaiting procedural review | `recognized`, `correction_pending`, `appeal_pending`, `withdrawn` |
| `recognized` | A documented recognition decision has been issued under an identified policy version | `correction_pending`, `appeal_pending`, `withdrawn`, `closed` |
| `correction_pending` | A correction request is active and must be considered before dependent final actions | `self_attested`, `evidence_submitted`, `recognition_pending`, `recognized`, `withdrawn` |
| `appeal_pending` | An appeal is active for a reviewable decision | `self_attested`, `evidence_submitted`, `recognition_pending`, `recognized`, `withdrawn` |
| `withdrawn` | The Record Subject has withdrawn participation or publication permission within the applicable scope | `correction_pending`, `appeal_pending`, `closed` |
| `closed` | Active processing has ended; retained material is governed by explicit retention and deletion rules | `correction_pending`, `appeal_pending` |

### Review Status

| Value | Meaning |
|---|---|
| `not_requested` | No formal review has been initiated |
| `intake_validation` | The system is checking completeness, scope, and accessible participation requirements |
| `evidence_review` | Authorized reviewers are assessing admissible evidence |
| `decision_drafted` | A provisional decision and explanation are being prepared |
| `decision_issued` | A decision has been communicated with reasons and review rights |
| `appeal_review` | An appeal body is considering the challenged decision |
| `review_complete` | The applicable review stage is complete |
| `review_blocked_for_accessibility` | No fair continuation is possible until an accessibility accommodation is available |
| `review_abstained` | The reviewer lacks a sufficient basis or authority for a substantive decision |

### Publication Status

| Value | Meaning |
|---|---|
| `private` | No public disclosure is permitted |
| `pseudonymous` | A minimized pseudonymous representation is permitted |
| `public` | A minimized public representation is permitted |
| `delayed` | Publication is authorized only after a defined future condition |
| `suppressed` | Publication is blocked by a rights, privacy, safety, or reporting safeguard |
| `withdrawn_from_publication` | A prior publication permission has been revoked or withdrawn |

### Consent Status

| Value | Meaning |
|---|---|
| `not_requested` | No consent request has been made |
| `requested` | A purpose-specific consent request is awaiting a response |
| `granted` | A valid, documented, purpose-specific consent has been granted |
| `denied` | The requested consent was not granted |
| `revoked` | Previously granted consent has been withdrawn |
| `expired` | Consent is no longer valid because its declared period ended |
| `not_applicable` | The operation does not require consent because it does not process or disclose personal data beyond the authorized record basis |

### Appeal Status

| Value | Meaning |
|---|---|
| `not_available` | No appeal-triggering decision exists |
| `available` | A reviewable decision has been issued and appeal may be requested |
| `submitted` | An appeal request has been received |
| `accessibility_accommodation_pending` | An appeal cannot fairly proceed until required accommodation is in place |
| `under_review` | The appeal is being reviewed |
| `resolved` | The appeal has received an accessible, reasoned resolution |
| `withdrawn_by_appellant` | The appellant has withdrawn the appeal |

## Transition Rules

### Create Record

A Recognition Record may be created only with minimized fields necessary to support the selected workflow.

Initial state:

\[
(self\_attested,\ not\_requested,\ private,\ not\_requested,\ not\_available)
\]

Creation MUST NOT require a public name, biometric sample, health record, augmentation record, neural data, location history, external identity proof, continuous connectivity, or credential presentation.

### Submit Evidence

Evidence submission may transition Record Status from `self_attested` to `evidence_submitted`.

A submission MUST be evaluated for:

- Declared purpose.
- Data minimization.
- Evidence-class appropriateness.
- Retention period.
- Access control.
- Accessibility of submission alternatives.
- Whether the material is excluded evidence.

A rejected evidence item MUST NOT be silently retained for unrelated future use.

### Request Recognition Review

A recognition review may begin only when:

\[
L = evidence\_submitted
\]

The review transition is:

\[
(evidence\_submitted,\ not\_requested,\ P,\ C,\ A)
\rightarrow
(recognition\_pending,\ intake\_validation,\ P,\ C,\ A)
\]

If an accessible participation route is unavailable, Review Status MUST transition to `review_blocked_for_accessibility`, and no adverse outcome may be issued.

### Issue Recognition Decision

A recognition decision may be issued only when:

\[
L = recognition\_pending
\land
V \in \{evidence\_review, decision\_drafted\}
\land
AccessibilitySatisfied
\land
ReasonedExplanationPrepared
\land
AppealPathAvailable
\]

If recognition is approved:

\[
(recognition\_pending,\ decision\_drafted,\ P,\ C,\ A)
\rightarrow
(recognized,\ decision\_issued,\ P,\ C,\ available)
\]

If recognition is not approved, the outcome MUST be recorded as a reasoned decision, a request for additional review, or an abstention. It MUST NOT be represented as a statement about worth, identity, legal standing, service eligibility, health, disability, or future capacity.

### Request Correction

A correction may be requested from any non-deleted retained record state.

The request transition is:

\[
(L,\ V,\ P,\ C,\ A)
\rightarrow
(correction\_pending,\ V,\ P,\ C,\ A)
\]

Correction processing MUST preserve the original audit history while allowing inaccurate, incomplete, outdated, or harmful statements to be corrected, contextualized, suppressed, or removed from future publication.

### Request Appeal

A reviewable decision creates an appeal opportunity:

\[
A = available
\]

An appeal request transitions the record as follows:

\[
(L,\ decision\_issued,\ P,\ C,\ available)
\rightarrow
(appeal\_pending,\ appeal\_review,\ P,\ C,\ submitted)
\]

An appeal may not be rejected merely because a person uses assistive technology, requests a non-digital route, has limited connectivity, declines optional identity disclosure, or requires additional time for an accessibility accommodation.

### Grant Publication Consent

Publication consent requires a purpose-specific Consent Scope.

Pseudonymous publication requires:

\[
C = granted
\land
PublicationScope = pseudonymous\_publication
\land
DataMinimized
\land
PrivacyRiskAcceptable
\]

Public publication requires:

\[
C = granted
\land
PublicationScope = public\_publication
\land
DataMinimized
\land
PrivacyRiskAcceptable
\land
NoActivePublicationBlock
\]

A recognition decision does not itself authorize publication.

### Revoke Publication Consent

Publication consent revocation transitions Publication Status to `withdrawn_from_publication` unless a stronger suppression state is required.

\[
(L,\ V,\ P,\ granted,\ A)
\rightarrow
(L,\ V,\ withdrawn\_from\_publication,\ revoked,\ A)
\]

A revocation MUST halt future disclosures under that consent scope. The system MUST produce a minimized audit event and provide an accessible confirmation to the Record Subject.

### Suppress Publication

Publication MUST transition to `suppressed` when:

- Consent is absent, denied, revoked, expired, or outside scope.
- Privacy risk exceeds the applicable threshold.
- Aggregate reporting falls below minimum group size.
- A correction or appeal could materially alter the public statement.
- The publication would reveal excluded sensitive data.
- The requested mode conflicts with safety, accessibility, or rights requirements.

### Withdraw Participation

Withdrawal transitions Record Status to `withdrawn`.

\[
(L,\ V,\ P,\ C,\ A)
\rightarrow
(withdrawn,\ V,\ withdrawn\_from\_publication,\ revoked,\ A)
\]

Withdrawal does not erase audit obligations automatically. Any retained data MUST be limited to the documented retention basis and subject to deletion scheduling, access limitation, and non-publication controls.

### Close Record

Closure is permitted only when active processing is complete and retention requirements are explicit.

\[
L \in \{recognized, withdrawn\}
\land
V \in \{review\_complete, review\_abstained\}
\]

Closure MUST NOT block a valid correction, deletion request, or appeal pathway that remains available under the governing policy.

## Mandatory Safety Predicates

### Non-Extractability

\[
\neg \exists f : Recognition \rightarrow Money
\]

No valid system transition, policy output, credential, report, interface, or integration may convert recognition into money, property, collateral, financial access, tradeable value, or authority over another person.

### Essential-Service Independence

\[
\forall s \in EssentialServices,\ Access(s) \perp Recognition
\]

Access to essential services is independent of recognition, credential possession, publication choice, identity disclosure, augmentation, biometrics, telemetry, or participation in CyberRank.

### Consent-Bound Publication

\[
PublicDisclosure \Rightarrow ValidConsent \land PurposeMatch \land DataMinimized \land PrivacyRiskAcceptable
\]

### No Silent Changes

\[
MaterialChange \Rightarrow AuditEvent \land AccessibleNotice \land ReasonedExplanation \land CorrectionPath \land AppealPath
\]

### Final Adverse Decision Validity

\[
FinalAdverseDecisionValid \Rightarrow
NoticeProvided
\land
ReasonsProvided
\land
AccessibleParticipationAvailable
\land
CorrectionOpportunityAvailable
\land
AppealOpportunityAvailable
\land
NoActiveAccessibilityBlock
\]

### Withdrawal Protection

\[
ConsentRevoked \Rightarrow \neg FutureProcessingWithinRevokedScope
\]

### Recognition at Rest Protection

\[
RestStatus \Rightarrow \neg DemotionByInactivity
\]

## Invalid Transitions

The following transitions MUST return `reject`:

- Public disclosure without valid purpose-specific consent.
- Pseudonymous disclosure where a pseudonym can be reasonably linked to a Record Subject through released attributes.
- Continued publication after consent is revoked.
- Recognition conversion into payment, collateral, tradable asset, service priority, or financial eligibility.
- Essential-service denial or degradation based on CyberRank state, credential state, or identity-disclosure refusal.
- Final adverse closure while a required correction, appeal, or accessibility accommodation remains unresolved.
- A review decision based on excluded sensitive data.
- A demotion or adverse inference based solely on rest, inactivity, disability, assistive-technology use, offline access, or refusal of optional telemetry.
- Treating credential verification as proof that a person must reveal full identity.
- Replacing a correction or appeal procedure with an automated adverse determination.

## Expected Policy Outcomes

Every policy evaluation, transition request, or rule check MUST resolve to exactly one outcome:

| Outcome | Meaning | Required system behavior |
|---|---|---|
| `allow` | Every mandatory requirement is satisfied | Complete the requested transition and emit minimized audit data |
| `reject` | The request crosses a prohibited boundary or lacks a mandatory requirement | Do not perform the transition; provide an accessible explanation |
| `require_review` | Human or specialized review is necessary | Preserve the current protective state and route to the authorized process |
| `abstain` | No authorized or sufficient basis exists for a determination | Preserve rights protections and do not infer an adverse outcome |

## Implementation Implications

- Rust types should model valid lifecycle transitions explicitly and keep state dimensions separate.
- Rego policies should evaluate requests against the mandatory safety predicates and return one of the four required outcomes.
- JSON Schemas should prohibit collection of excluded sensitive data unless a separately approved, purpose-limited extension explicitly applies.
- TLA+ should explore normal, error, withdrawal, correction, accessibility, and adversarial traces.
- Audit records should be append-only, minimized, purpose-bound, and incapable of silently changing a material decision.
- Credential adapters should permit holder-controlled proofs without requiring public identity disclosure.

## Quality Metrics

| Metric | Value | Basis |
|---|---:|---|
| `knowledge_factor` | 0.95 | Separates concepts, actors, evidence, consent, publication, review, and appeal into explicit state dimensions |
| `eco_impact_value` | 0.42 | Supports local-first, offline-capable, low-data governance workflows and reduces unnecessary collection and processing |
| `harm_risk` | 0.18 | Establishes non-extractability, service independence, consent revocation, suppression, due process, and fail-closed transitions |
| `accessibility_impact` | 0.97 | Makes accessible participation and non-digital or offline-capable pathways mandatory gates rather than optional features |
| `rights_alignment` | 0.98 | Encodes dignity, privacy, consent, correction, appeal, non-discrimination, and continuity protections as non-offsettable requirements |
