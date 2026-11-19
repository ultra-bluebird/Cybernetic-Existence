# Inter-Nation Watershed Coordination Template

## Document Status

**Template only — not an agreement, authorization, consent record, treaty, legal opinion, consultation record, or representation instrument.**

This template may be prepared as administrative scaffolding for review by each
participating sovereign nation, rights holder, community governance process, and
authorized institution. It does not approve a project, determine jurisdiction,
interpret law, bind a nation, represent a rights holder, or resolve disagreement.

## 1. Coordination Context

### 1.1 Watershed or Shared-System Description

- Watershed or shared-system name:
- Geographic scope:
- Ecological scope:
- Data classes under consideration:
- Proposed research or stewardship purpose:
- Known cross-boundary dependencies:
- Current project phase:
  - [ ] Concept only
  - [ ] Internal research design
  - [ ] Information-sharing preparation
  - [ ] Separate consent process pending
  - [ ] Other:

### 1.2 Participating Jurisdictions and Governance Contexts

For each potentially affected sovereign nation, rights-holder governance process,
or authorized institution, record only the minimally necessary reference:

| Participant reference | Jurisdiction or governance scope | Designated process reference | Contact-disclosure class | Separate consent status |
|---|---|---|---|---|
| [Not publicly disclosed unless agreed] | [Describe scope] | [Reference] | [Internal/restricted/public by agreement] | [Not initiated / pending / active / refused / withdrawn] |

Do not infer authority, identity, representation, affiliation, or consent from
geography, historical material, language, metadata, or absence of a response.

## 2. Procedural Commitments

### 2.1 Notification Gate

The coordination process may proceed only after each identified participant has
received accessible, purpose-specific notification through the participant's
designated or appropriate process.

Notification package requirements:

- Plain-language project summary.
- Purpose, methods, data classes, and uncertainty limits.
- Expected benefits, burdens, risks, and alternatives.
- Proposed data governance and retention terms.
- Proposed attribution and publication options.
- Proposed benefit commitments.
- Contact and correction pathway.
- Time for deliberation determined by the applicable process.
- Statement that participation, refusal, and withdrawal are respected.

### 2.2 Separate Consent Gate

Each sovereign nation or rights-holder process retains independent authority over
its own consent determination. A consent record from one participant does not
supply consent for any other participant.

For each participant, record:

- Consent lifecycle reference.
- Purpose scope.
- Data and knowledge scope.
- Geographic and temporal scope.
- Conditions and restrictions.
- Expiry and review date.
- Withdrawal and correction process.
- Attribution requirements.
- Benefit commitment references.

### 2.3 Least-Permissive Common Scope Gate

The joint scope is limited to the intersection of all currently active,
purpose-compatible, review-satisfied consent scopes:

\[
S_{\mathrm{joint}} =
\bigcap_{i=1}^{n} S_i
\]

If any participant has no active consent, has a refusal, has withdrawn consent,
or has an incompatible scope, the affected joint activity remains blocked.

The system MUST NOT broaden joint scope by averaging, majority vote, inference,
silence, or presumed consent.

## 3. Inter-Nation Gate Record

\[
G_{\mathrm{inter\text{-}nation}} =
G_{\mathrm{notification}}
\land
G_{\mathrm{separate\ consent}}
\land
G_{\mathrm{least\ permissive\ common\ scope}}
\]

| Gate | Required evidence | State | Blocking condition |
|---|---|---|---|
| Notification | Accessible notification record for each participant | [Pending / satisfied / blocked] | Missing or inaccessible notification |
| Separate consent | Active, purpose-compatible consent record for each participant | [Pending / satisfied / blocked] | Refusal, withdrawal, expiry, missing review, or incompatible purpose |
| Least-permissive common scope | Documented intersection of allowed scope | [Pending / satisfied / blocked] | Any requested use exceeds one participant's allowed scope |

**Overall gate state:**  
- [ ] Blocked  
- [ ] Pending review  
- [ ] Eligible for internal coordination planning only  

Eligibility for internal coordination planning does not authorize field activity,
data transfer, publication, public alerting, infrastructure control, operational
system control, government representation, or rights-holder representation.

## 4. Shared Data and Knowledge Governance

### 4.1 Data Inventory

| Data or knowledge class | Source reference | Privacy class | Attribution requirement | Consent reference | Retention rule | Transfer rule |
|---|---|---|---|---|---|---|
| [Class] | [Reference] | [Class] | [Mode] | [Reference] | [Rule] | [Rule] |

### 4.2 Non-Disclosure Defaults

Unless an independently documented and reviewed scope permits otherwise:

- Do not publish precise sensitive locations.
- Do not disclose restricted knowledge, identities, governance deliberations, or
  private operational details.
- Do not combine records to infer identity, affiliation, authority, consent, or
  eligibility.
- Do not transfer data outside the approved purpose and access scope.
- Do not use data or knowledge for derivative model training without separately
  documented permission.
- Do not treat participation as endorsement, representation authority, or
  agreement with another participant.

## 5. Benefit Commitments

| Commitment | Beneficiary scope | Delivery milestone | Verification method | Review date | Consent dependency |
|---|---|---|---|---|---|
| [Data return / capacity support / co-authorship / funding / stewardship] | [Scope] | [Milestone] | [Joint review / confirmation / audit] | [Date] | [Reference] |

Benefit commitments are tracked independently from consent. Delivery does not
purchase consent, and consent does not waive benefit obligations.

## 6. Attribution and Publication

### 6.1 Attribution Resolution

For every combined output, apply the least-permissive attribution mode:

\[
\mathrm{exposure}(\mathrm{combined})
\leq
\min_i
\mathrm{exposure}(\mathrm{source}_i)
\]

If attribution requirements differ, public attribution and publication remain
blocked pending documented review.

### 6.2 Publication Review Checklist

- [ ] Purpose-compatible consent remains active.
- [ ] Withdrawal and supersession checks completed.
- [ ] Attribution requirements resolved.
- [ ] Privacy and disclosure review completed.
- [ ] Accessibility review completed.
- [ ] Benefit commitments reviewed.
- [ ] Uncertainty and OOD status disclosed.
- [ ] Community or rights-holder-required review completed.
- [ ] No representation claim is implied.
- [ ] Separate external publication approval exists where required.

## 7. Disagreement, Withdrawal, and Material Change

### 7.1 Disagreement

The template does not assign an arbiter. Disagreement is recorded and routed to
the processes designated by participating sovereign nations and rights holders.

The agent's procedural role is limited to:

- Preparing neutral records and accessible summaries.
- Maintaining versioned scope, consent, benefit, attribution, and provenance
  references.
- Detecting missing gates, conflicts, and unresolved dependencies.
- Producing a blocked status when required evidence is absent or incompatible.
- Supporting correction, appeal, and material-change documentation.

The agent MUST NOT:

- Decide whose interpretation prevails.
- Determine sovereignty, jurisdiction, authority, or legitimacy.
- Treat silence as consent.
- Negotiate for a rights holder or nation.
- Bind any participant.
- Resolve disagreement through majority vote or algorithmic scoring.
- Authorize external activities or operational actions.

### 7.2 Withdrawal

A withdrawal triggers provenance review for every derivative map, model, report,
dataset, and publication:

\[
A^{+}(r) =
\{o :
\exists \text{ a provenance path from } r \text{ to } o
\}
\]

Affected outputs are restricted, withdrawn, corrected, reviewed, or subject to
a post-publication notice according to their dissemination class.

### 7.3 Material Change

A material change includes a new purpose, data class, geographic expansion,
new participant, new attribution mode, changed benefit commitment, changed
publication audience, changed model use, or altered external transfer proposal.

Any material change returns the affected gate to `blocked` or `pending review`
until each applicable process has completed its own review.

## 8. Decision Log

| Date | Issue | Participants or process references | Current state | Required next step | Record reference |
|---|---|---|---|---|---|
| [Date] | [Issue] | [References] | [Blocked / pending / resolved by participant process] | [Step] | [Reference] |

## 9. Non-Authorization Statement

This artifact does not authorize:

- field activity
- environmental release
- weather modification
- infrastructure control
- public alerting
- external data transfer
- rights-holder representation
- government representation
- operational system control

Internal research approval does not create external operational authorization.
