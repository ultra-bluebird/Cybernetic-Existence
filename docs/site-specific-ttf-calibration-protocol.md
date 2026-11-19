# Site-Specific TTF Calibration Protocol

## Status and purpose

**Document status:** Draft protocol  
**Protocol version:** 1.0.0  
**Applies to:** `mk-bluebird/Augmented-Hub` and `mk-bluebird/Skynet`

This protocol defines the minimum governance conditions for a future site-specific TTF calibration proposal.

A site-specific TTF calibration must not begin, be represented as valid, or be used for an applicability claim unless free, prior, and informed consent processes are applicable and complete for the stated scope, and rights-holder-defined terms have been recorded through a bounded governance process.

This protocol supports internal planning, documentation, schema design, review preparation, and non-actuating calibration governance. It does not authorize site access, data collection, measurement, sampling, monitoring, field deployment, environmental intervention, model deployment, public reporting, external communication, or action on behalf of any person, community, institution, ecosystem, or government.

## Non-authorization notice

This protocol does not authorize:

- Entering, surveying, sampling, monitoring, photographing, mapping, measuring, or otherwise accessing a site.
- Collecting, receiving, using, retaining, transferring, publishing, or training on site-specific information.
- Contacting, representing, negotiating for, or speaking on behalf of any rights holder, community, steward, government, land manager, institution, or organization.
- Declaring that FPIC applies, does not apply, has been obtained, remains valid, or is sufficient for a particular use.
- Determining land rights, water rights, Indigenous rights, representation, title, legal status, institutional status, or regulatory compliance.
- Operating hardware, sensors, drones, vehicles, infrastructure, ecological systems, restoration systems, water systems, or environmental controls.
- Releasing material, altering habitat, managing wildlife, modifying soil or water, or conducting any ecological intervention.
- Publishing a calibration result, issuing a public claim, providing decision support, or authorizing any external action.

\[
\text{site-specific calibration protocol}
\not\Rightarrow
\text{site access, data use, field authority, or operational permission}
\]

Any future action with external effects requires separately scoped, explicit authority from the applicable rights holders and governance processes.

## Core rule

A proposed site-specific TTF calibration must satisfy the following gate before it may move beyond internal planning:

\[
\mathrm{TTF\ calibration\ eligible}
=
\mathrm{FPIC\ applicable\ and\ complete}
\land
\mathrm{rights\ holder\ terms\ recorded}
\land
\mathrm{purpose\ bounded}
\land
\mathrm{data\ governance\ accepted}
\land
\mathrm{privacy\ and\ access\ review\ complete}
\land
\mathrm{non\text{-}authorization\ boundary\ preserved}
\]

If any condition is unknown, absent, disputed, expired, withdrawn, structurally blocked, or outside the stated purpose, the calibration proposal must remain `structural_block` or `not_eligible_for_site_specific_calibration`.

## Definitions

| Term | Meaning |
|---|---|
| **TTF** | A project-specific research model family or analytical framework. This protocol does not assert that any TTF model is validated, calibrated, deployed, or applicable at a real site. |
| **Site-specific calibration** | A future bounded process for evaluating or adjusting a TTF model against a defined site context under applicable governance and rights-holder terms. |
| **FPIC** | A process for free, prior, and informed consent where applicable. This protocol does not determine applicability, legal meaning, or completion of FPIC. |
| **Rights holder** | A person, community, collective, steward, organization, or other party with a relevant self-asserted or institutionally recognized relationship to the proposed calibration context. This term does not require public identity disclosure or external verification through this protocol. |
| **Rights-holder-defined terms** | Terms supplied, confirmed, or otherwise governed by the relevant rights holder or applicable process, including purpose, access, privacy, retention, withdrawal, correction, attribution, benefit commitments, communication access, and non-interference boundaries. |
| **Calibration proposal** | An internal governance record describing a possible future calibration process. It is not permission to begin work. |
| **Calibration evidence** | A bounded record describing methods, uncertainty, data governance, and review conditions. It does not contain raw protected content unless independently governed. |
| **Structural block** | A non-permissive state caused by missing required fields, missing or conflicting terms, unknown consent applicability, unresolved rights concerns, unsupported data handling, missing review evidence, or an invalid purpose-to-data relationship. |
| **External action** | Any activity that changes a system, contacts a party, accesses a site, collects or transfers data, publishes information, or otherwise has effects outside internal documentation and local validation. |

## Eligibility states

```text
draft
  -> internal_review_pending
  -> rights_terms_pending
  -> fpic_applicability_pending
  -> not_eligible_for_site_specific_calibration
  -> structural_block
  -> eligible_for_separately_authorized_calibration
  -> superseded
  -> withdrawn
```

`eligible_for_separately_authorized_calibration` means only that the internal proposal has documented prerequisites for seeking separate authority. It does not grant site access, consent, data use permission, field authorization, or external-action approval.

No transition may occur solely because of elapsed time, silence, unavailable feedback, an incomplete record, a model output, or a technical readiness claim.

## Required proposal record

A site-specific calibration proposal must include:

```json
{
  "record_type": "site_specific_ttf_calibration_proposal",
  "record_id": "ttf-site-calibration-example-001",
  "proposal_status": "internal_review_pending",
  "ttf_model_reference": "models/ttf-model-reference.json",
  "site_context_reference": "manifests/site-context-reference.json",
  "calibration_purpose": "Bounded internal research purpose.",
  "intended_use_limitations": [
    "No external decision support.",
    "No field activity without separate authorization.",
    "No transfer or publication of protected information."
  ],
  "fpic": {
    "applicability_status": "unknown",
    "applicability_assessment_reference": null,
    "process_status": "not_started",
    "consent_reference": null,
    "withdrawal_reference": null
  },
  "rights_holder_terms": {
    "terms_status": "pending",
    "terms_reference": null,
    "purpose_limitations": [],
    "data_access_scope": "unknown",
    "retention_and_deletion_terms": "unknown",
    "attribution_terms": "unknown",
    "benefit_commitment_reference": null,
    "communication_access_requirements": [],
    "non_interference_requirements": []
  },
  "data_governance": {
    "data_classification_reference": null,
    "minimum_necessary_data_statement": "No site-specific data is authorized by this proposal.",
    "collection_authorized": false,
    "transfer_authorized": false,
    "model_training_authorized": false,
    "publication_authorized": false
  },
  "review_bundle": {
    "governance_review_reference": null,
    "rights_and_accessibility_review_reference": null,
    "privacy_and_security_review_reference": null,
    "methodology_and_uncertainty_review_reference": null,
    "calibration_plan_review_reference": null
  },
  "external_action_authorized": false,
  "non_authorization": {
    "statement": "This proposal is an internal planning artifact only. It does not authorize site access, data collection, field activity, external communication, publication, model deployment, or environmental intervention.",
    "external_action_requires_separate_approval": true,
    "does_not_verify_identity_or_status": true,
    "does_not_verify_repository_state": true
  }
}
```

## Required rights-holder-defined terms

Before a proposal can become eligible for separately authorized calibration, the applicable rights-holder-defined terms must be recorded through the appropriate process. At minimum, the terms record must address:

| Term category | Required bounded decision |
|---|---|
| Purpose | The exact calibration purpose and prohibited secondary uses |
| Site context | Bounded description sufficient for the agreed purpose without unnecessary sensitive location or ecological detail |
| Data scope | Minimum necessary data categories, collection limits, access limits, sharing limits, and reuse limits |
| Retention | Retention period, deletion or return pathway, and supersession handling |
| Withdrawal | How withdrawal is requested, recorded, propagated, and reviewed |
| Correction and appeal | How a correction, disagreement, or appeal is raised and handled |
| Attribution | Whether attribution is desired, restricted, omitted, collective, or otherwise governed |
| Benefit commitments | Any benefit commitment, accountability basis, milestone, and completion evidence path |
| Communication access | Plain-language, translation, pacing, assistive-communication, human-fallback, or other access requirements |
| Non-interference | Boundaries against unwanted monitoring, disclosure, contact, inference, operational action, or secondary use |
| Review and material change | Who reviews material changes to method, purpose, model, data scope, audience, retention, or publication route |

A generic project policy, technical readiness assertion, public-interest claim, funding condition, or model objective cannot substitute for rights-holder-defined terms where such terms are required.

## FPIC and consent safeguards

Where FPIC or another consent process is applicable, the following safeguards apply:

1. The proposal must record an `fpic.applicability_status` of `applicable`, `not_applicable`, `unknown`, or `structural_block`.
2. `unknown` must remain explicit and blocks a site-specific calibration eligibility claim.
3. If applicable, the FPIC process must be completed under the terms required by the relevant rights holders and applicable governance process before any site-specific use claim.
4. A consent reference must be purpose-specific, time-bounded where applicable, reviewable, revocable, and linked to withdrawal handling.
5. A consent reference must not be treated as transfer of identity, representation authority, institutional authority, land or resource rights, or permission for purposes not recorded in its scope.
6. Expired, withdrawn, disputed, superseded, missing, or structurally blocked consent cannot be treated as valid calibration permission.
7. Silence, unavailable feedback, delayed response, or inaccessible communication must not be treated as consent, denial, waiver, or closure.
8. The protocol must not demand private health, neural, biometric, credential, telemetry, institutional, or technical information to determine whether a person or community can request a review or set terms.
9. A future calibration may require additional community, legal, institutional, scientific, privacy, security, or environmental review. This protocol does not replace those processes.

## Data governance and minimization

A site-specific proposal must use metadata-first planning.

Until separately authorized:

- Do not collect site measurements, samples, imagery, audio, video, coordinates, maps, sensor feeds, environmental observations, personal information, community knowledge, operational data, or protected records.
- Do not request access to accounts, repositories, databases, devices, sensors, drones, vehicles, infrastructure, field notebooks, or institutional systems.
- Do not infer site membership, rights, identity, authority, environmental conditions, ecological sensitivity, community position, or consent status from communication style, metadata, location hints, device context, or absence of disclosure.
- Do not create a persistent site profile, identity registry, technical inventory, community registry, or augmentation registry.
- Do not use data supplied for one purpose to train, validate, publish, transfer, or operationalize a model for another purpose without separately applicable terms and review.

When a future calibration is separately authorized, use only the minimum data necessary for the recorded purpose and preserve declared access, retention, correction, deletion, withdrawal, attribution, and non-interference conditions.

## Calibration-method requirements

A future separately authorized calibration plan must specify:

- The TTF model version, model assumptions, evidence class, uncertainty contract, and checkpoint-chain binding.
- The bounded calibration objective and success criteria.
- The measurement or data categories authorized for use.
- The sampling or observation method only after applicable site and data authority exists.
- Unit definitions, data-quality conditions, uncertainty sources, OOD criteria, and abstention conditions.
- The calibration validation method and limitations.
- The local or contextual applicability conditions.
- The review path for material changes.
- The withdrawal, correction, appeal, retention, deletion, and supersession pathways.
- The accessibility and communication plan.
- The method for reporting limitations without exposing protected information.
- The non-authorization boundary for all planning outputs.

A calibration plan must not claim that a site is calibrated solely because a general TTF model has been tested elsewhere, because a similar site exists, because a model fit is numerically strong, or because a requested data source is available.

## Eligibility gate

A proposal may be labelled `eligible_for_separately_authorized_calibration` only if all of the following are true:

- The calibration purpose is specific, bounded, and documented.
- Applicable FPIC or consent status is explicitly recorded and no longer unknown or structurally blocked.
- Required rights-holder-defined terms are recorded and reviewable.
- The proposed data scope is minimum necessary and consistent with the recorded purpose.
- Collection, transfer, model-training, and publication permissions are separately and explicitly addressed.
- Rights and accessibility review, privacy and security review, governance review, methodology and uncertainty review, and calibration-plan review references are present.
- Withdrawal, correction, appeal, retention, deletion, attribution, benefit-commitment, and material-change paths are documented.
- The model’s evidence class, checkpoint binding, uncertainty contract, OOD assessment, and applicability limitations are recorded.
- The proposal is not blocked by a provenance cycle, unresolved consent issue, unresolved correction or appeal, unknown audience where an audience-sensitive action is proposed, or missing non-authorization constraint.
- No external action is inferred from the eligibility label.

## Structural blocks

The proposal must enter `structural_block` if any of the following occurs:

- Required FPIC applicability status is absent or malformed.
- FPIC applicability is `unknown` when the proposal claims eligibility.
- Applicable consent or rights-holder terms are missing, expired, withdrawn, disputed, superseded, or outside the stated purpose.
- A rights-holder-defined term is missing for purpose, data scope, access, retention, withdrawal, correction, appeal, attribution, benefit commitments, communication access, or non-interference.
- The proposal implies site access, data collection, field activity, publication, transfer, training, or operational action without separate authority.
- A required review reference is absent.
- A material model, data, method, audience, retention, access, or purpose change has not been reviewed.
- A required non-authorization declaration is missing or conflicting.
- A withdrawal, correction, provenance-cycle, or checkpoint-chain issue remains unresolved.
- The proposal relies on identity inference, inaccessible communication, silence, or non-response as a substitute for governance evidence.

A structural block is a visible governance condition, not a judgment about a rights holder, community, or contributor.

## Material-change review

A new review is required before continued calibration planning if there is a material change to:

- Calibration purpose or intended use.
- TTF model family, version, evidence class, checkpoint chain, uncertainty contract, or OOD assessment.
- Proposed site context or authorized data category.
- FPIC applicability or consent scope.
- Rights-holder-defined terms.
- Access, retention, deletion, withdrawal, correction, appeal, attribution, benefit, or non-interference terms.
- Audience, publication route, external communication plan, or reporting format.
- Privacy, security, accessibility, environmental, ecological, legal, institutional, or community risk.

The review must preserve the predecessor record and identify whether the change requires a new proposal, an amendment, a supersession record, or withdrawal.

## Review roles

| Review role | Required focus |
|---|---|
| Governance reviewer | Purpose, scope, non-authorization boundary, material-change handling, and accountability |
| Rights and accessibility reviewer | Rights-holder-defined terms, accessible communication, human fallback, correction, appeal, and non-interference |
| Privacy and security reviewer | Data minimization, access, retention, deletion, transfer, security boundaries, and sensitive-information protection |
| Methodology and uncertainty reviewer | Model suitability, uncertainty contract, OOD assessment, calibration method, and abstention conditions |
| Calibration-plan reviewer | Bounded plan coherence, unit definitions, quality conditions, validation approach, and limitations |
| Applicable rights-holder or community process | Terms, permissions, boundaries, review expectations, and any applicable FPIC or consent process |

A role designation describes a required review perspective. It does not prove that a particular person, community, institution, or rights holder has approved anything.

## Required tests

Future schema or implementation work should test at least:

1. A proposal with `fpic.applicability_status: "unknown"` cannot become eligible.
2. A proposal claiming eligibility without a rights-holder terms reference is rejected.
3. A proposal with a withdrawn or expired consent reference is rejected.
4. A proposal cannot set collection, transfer, training, publication, or external action authorization to `true` without separately governed evidence.
5. Missing accessibility, privacy, governance, methodology, or calibration-plan review references block eligibility.
6. A material change to model version, purpose, data scope, access, retention, or terms requires renewed review.
7. Silence or deadline passage cannot create FPIC, consent, approval, denial, or eligibility.
8. A provenance cycle, withdrawal impact, correction appeal, or checkpoint-chain structural block prevents an applicability claim.
9. A calibration output preserves uncertainty, OOD, abstention, and non-authorization constraints.
10. Test fixtures use synthetic metadata only and do not contain real site coordinates, identities, protected ecological locations, private institutional data, or sensitive technical details.

## Revision triggers

Review this protocol when:

- TTF model structure, evidence class, checkpoint binding, uncertainty contract, OOD process, or calibration method changes.
- FPIC, consent, rights-holder governance, withdrawal, correction, appeal, retention, deletion, attribution, benefit, accessibility, or non-interference requirements change.
- A new site-specific calibration context is proposed.
- A privacy, security, ecological, accessibility, community, legal, or governance risk is identified.
- A structural block, correction, appeal, withdrawal, or material change affects a calibration proposal.
