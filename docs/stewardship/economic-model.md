# Economic Stewardship Model

## Purpose

This document describes a rights-centered, anti-enclosure stewardship model for
Augmented-Hub. It gives adopters a concrete governance and sustainability
framework without claiming that funding, legal authority, institutional backing,
or future maintenance already exists.

The project’s public-good value depends on durable maintenance of:

- The Rust crate and feature surface.
- Schemas and versioned contracts.
- Security and dependency review.
- Accessibility and plain-language documentation.
- Independent audit artifacts.
- Community governance interfaces.
- Evidence/reliance boundary maintenance.
- Conformance vectors and formal/property-test contracts.
- Repair, decommissioning, retention, deletion, and portability documentation.

## Stewardship Principles

1. **Public-interest continuity:** Core governance and ecological safety
   artifacts should remain available for public-interest use.
2. **Anti-enclosure:** No maintainer, funder, vendor, host, or downstream
   adopter should obtain exclusive control over community governance artifacts,
   local ecological knowledge, or public-benefit interfaces through funding,
   licensing, hosting, or technical lock-in.
3. **No pay-to-participate governance:** Community review, grievance,
   correction, appeal, and accessibility channels must not require purchase,
   subscription, credential, identity disclosure, CyberRank disclosure, or
   technical inventory.
4. **Local control:** Community-governed data, sensitive ecology, and
   rights-holder processes retain their own access, retention, and sharing
   boundaries.
5. **Transparency:** Funding categories, material conflicts, maintenance
   commitments, and significant feature changes should be disclosed in
   accessible form.
6. **Non-compensation:** Funding, carbon claims, commercial benefit, or
   technical contribution cannot offset water, heat, privacy, accessibility,
   community, rights, or ecological failure.
7. **Repair and exit:** Stewardship includes portability, dependency tracking,
   succession, decommissioning, and safe exit—not only feature development.

## Maintainer Roles

Roles are scoped responsibilities, not personal rank, public identity, legal
authority, or eligibility class.

| Role | Core responsibility | Required safeguards |
|---|---|---|
| Crate maintainer | Public API stability, release discipline, feature gates, dependency surface | Change log, semver policy, review, rollback path |
| Schema steward | Schema versioning, migration compatibility, machine-readable contract review | Explicit deprecation, no silent field removal, public limitations |
| Security and supply-chain reviewer | Dependency review, canonicalization/crypto boundary, vulnerability triage | Conflict disclosure, reviewed lockfile, no private-key authority |
| Accessibility steward | Doctest/document accessibility, plain language, non-digital alternatives, feedback routes | No mandatory identity/health/CyberRank disclosure |
| Audit and assurance steward | Property tests, conformance vectors, formal-model result records, CI obligations | No fabricated test/pass claim, independent review |
| Community governance liaison | Charter/interface compatibility and accessible grievance handoff | No proxy authority claim, local process boundary |
| Evidence and reliance steward | Source metadata, retention, access, uncertainty, downstream-use restriction | No raw-data public release by default |
| Lifecycle steward | Portability, exit, decommissioning, recovery, deletion/reopening review | Funding/successor path, no indefinite abandoned obligation |

A single person may temporarily cover multiple roles only with documented
conflict review and a succession plan. High-consequence review should not
depend permanently on one unavailable person.

## Funding Categories

Funding sources may include:

| Category | Legitimate use | Required boundary |
|---|---|---|
| Foundation support | Accessibility, maintenance, public-interest research, audit | No exclusive governance or data rights |
| Cooperative/member support | Shared maintenance, documentation, local tool hosting | Voluntary participation; no service-access discrimination |
| Public-interest grant | Research, restoration, open tooling, conformance work | Grant conditions cannot override community/rights/privacy safeguards |
| Public funding | Civic resilience, open standards, accessibility, environmental accountability | Public accountability and procurement review |
| Institutional partnership | Reviewed research or implementation support | Explicit conflict and downstream-use controls |
| Service/support revenue | Optional implementation, training, migration, or audit support | Core rights/safety interfaces remain non-coercive and portable |
| In-kind contribution | Documentation, test vectors, review, translation, accessibility work | Contribution credit does not create governance entitlement |

Unacceptable or restricted funding conditions include:

- Exclusive rights to community governance artifacts.
- Forced data sharing, model training, or telemetry.
- Requirements to disclose CyberRank, identity, health, disability, private
  systems, or sensitive ecological locations.
- Mandatory proprietary lock-in for a public-good interface.
- Funding conditions that suppress grievances, appeals, independent review, or
  negative findings.
- Pay-to-play access to essential corrections, safety documentation, or
  public-interest schemas.

## Anti-Enclosure License Review

The crate currently declares:

```text
MIT OR Apache-2.0
```

That license expression supports broad reuse, but license choice alone does not
prevent enclosure of hosted services, data, governance processes, or
community-generated knowledge.

A license review must therefore assess:

- Source-code license compatibility.
- Patent grant and contribution terms.
- Trademark and project-name stewardship.
- Schema/document licensing.
- Parameter-catalog and evidence-source licensing.
- Data access and community-governance boundaries.
- Hosting/managed-service lock-in.
- API/export portability.
- Dependency licensing.
- Downstream public-summary and audit-artifact reuse limits.
- Whether additional agreements are needed for sensitive ecology or
  community-governed knowledge.

No license review may treat community knowledge as freely reusable merely
because source code is open.

## Free-Rider Mitigation

Public-good software may be used by entities that do not contribute resources.
The project should address this without restricting essential public-interest
use or creating exclusionary access barriers.

Permitted approaches:

- Publish transparent maintenance needs and contribution pathways.
- Offer optional paid support, training, migration, audit, or hosted
  assistance without making core rights/safety access conditional on payment.
- Recognize non-financial contributions such as accessibility review,
  translation, testing, evidence review, community liaison work, and
  documentation.
- Maintain a public roadmap that distinguishes funded, unfunded, and
  community-prioritized work.
- Ask high-resource adopters for voluntary maintenance sponsorship.
- Use cooperative support arrangements that preserve exit and portability.
- Require attribution and preservation of reliance-boundary notices in
  downstream reuse where compatible with the governing license.
- Maintain compatibility and export formats so contributors are not trapped
  by a single host.

Prohibited approaches:

- Withholding critical safety fixes from non-paying users.
- Conditioning grievance, correction, appeal, accessibility, or safety
  documentation on payment.
- Creating a paywalled identity, CyberRank, or eligibility layer.
- Selling sensitive ecological, community-governed, or private data to fund
  maintenance.
- Using public-good contributions as a basis for governance rank or control.

## Public-Good Provisioning

The project should prioritize funding and effort in this order:

1. Correctness and fail-closed safety invariants.
2. Privacy, data minimization, retention/deletion, and reliance boundaries.
3. Accessibility, grievance, correction, appeal, and community governance.
4. Security, supply-chain review, canonicalization, and auditability.
5. Environmental measurement integrity, uncertainty, and local applicability.
6. Portability, exit, decommissioning, recovery, and successor obligations.
7. Optional convenience features.

This ordering prevents visible dashboards or advanced models from consuming the
resources needed for rights, repair, and accountability foundations.

## Conflict and Capture Controls

- Funding sources and material conditions are disclosed at an appropriate
  aggregate level.
- Funders do not unilaterally select independent reviewers.
- A funder may not suppress a dispute, negative audit, correction, or
  parameter withdrawal.
- Community governance and rights-holder processes retain their own
  authority boundaries.
- High-resource adopters cannot use contribution volume as a claim to
  priority service, reviewer selection, governance control, or data access.
- Maintainer changes require a documented transition and succession process.
- A project dependency on a single funder, maintainer, host, or proprietary
  service is a lifecycle risk requiring mitigation planning.

## Economic Continuity Checklist

Before a downstream adopter depends on the crate for a material pilot:

- [ ] Named maintainer/succession roles are documented.
- [ ] Dependency and security-review responsibilities are assigned.
- [ ] Accessibility and grievance maintenance paths are funded or explicitly
  risk-labeled.
- [ ] Schema/export portability is available.
- [ ] Community-governance boundaries are documented where relevant.
- [ ] Parameter/evidence maintenance path is identified.
- [ ] Independent review and audit capacity is identified.
- [ ] Exit/decommissioning support path is identified.
- [ ] No funding condition requires identity, CyberRank, private data, or
  rights waiver.
- [ ] No critical safety or accessibility feature is paywalled.
- [ ] Material conflicts are disclosed and reviewable.

## Limits

This document is a stewardship model, not a funding commitment, grant
agreement, cooperative charter, legal opinion, tax advice, fiduciary
agreement, or guarantee of project continuity. Each deployment needs its own
funding, authority, rights, accessibility, privacy, community-governance, and
lifecycle review.
