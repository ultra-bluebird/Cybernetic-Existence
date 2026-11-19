# Hero at Rest Service Continuity Guarantee

## Purpose

This policy establishes a technical and governance mechanism for recording `hero-at-rest` status in a voluntary CyberRank recognition system.

A Hero at Rest is a recognized recipient who is not currently contributing at the activity level associated with the recognized deed or body of work. Rest, retirement, reduced connectivity, care needs, changed priorities, refusal of publicity, or inactivity do not invalidate the recognized achievement.

The policy protects continuity of the underlying CyberRank tier and the associated documented institutional access rights against reduction caused solely by inactivity.

This policy does not create a legal entitlement, external platform guarantee, clinical status, medical authorization, financial claim, or authority over another institution. It governs only the participating institution’s own recognition and service-continuity records.

## Core Invariant

\[
\operatorname{HeroAtRest}
\land
\operatorname{InactivityOnly}
\Rightarrow
\operatorname{TierPreserved}
\land
\operatorname{AccessRightsPreserved}
\]

In plain language: if a recognized Hero at Rest is inactive, the system must preserve the underlying tier and associated rights unless a separate, documented, due-process event establishes a permitted reason for a change.

## Status Model

The recognition record has two independent dimensions:

| Dimension | Allowed values | Meaning |
|---|---|---|
| Recognition state | `candidate`, `hero-active`, `hero-at-rest` | Describes institutional recognition and activity presentation |
| Tier continuity state | `preserved`, `review-pending`, `corrected` | Describes the protected status of the underlying CyberRank tier and associated access rights |

`hero-at-rest` must not automatically change `tier_continuity_state` from `preserved`.

## Permitted Change Grounds

A change to a preserved tier or associated access right may be considered only when the institution records one or more of the following grounds:

- Material evidence fraud.
- Material authorship misrepresentation.
- Material consent violation directly connected to the recognized work.
- Serious rights-violating conduct inseparable from the recognized deed.
- Correction of an objectively erroneous institutional record.
- A narrowly required lawful or safety action, with documented authority, scope, necessity, duration, notice, and review.

The following are prohibited grounds:

- Inactivity.
- Rest or retirement.
- Loss of continuous internet access.
- Declining public attention or publicity.
- Declining unrelated telemetry collection.
- Using assistive technology.
- Requiring accessibility accommodation.
- Declining to disclose augmentation, health, neural, biometric, device, or identity information.
- Changing personal focus, work type, communication preference, or availability.
- Refusing unpaid ongoing labor.

## Signed Continuity Assertion

A Hero at Rest continuity event produces a signed assertion:

```text
record_type: hero_at_rest_continuity_assertion
recognition_state: hero-at-rest
tier_continuity_state: preserved
inactivity_is_not_change_ground: true
underlying_tier_preserved: true
associated_access_rights_preserved: true
change_requires_separate_due_process_record: true
appeal_path_available: true
```

The assertion is signed by the authorized institutional signer and linked to the immediately prior recognition record hash.

\[
h_t
=
\operatorname{SHA256}
(
\operatorname{canonicalize}(r_t)
\parallel
h_{t-1}
)
\]

\[
\sigma_t
=
\operatorname{Sign}_{k_{\mathrm{institution}}}(h_t)
\]

A properly implemented digital signature supports origin authentication, integrity protection, and signatory non-repudiation. [189][192]

## No-Silent-Downgrade Rule

A system must reject any transition that attempts to reduce tier or access rights without a valid, signed, human-reviewed change record.

\[
\operatorname{DowngradeAllowed}
=
\operatorname{PermittedGround}
\land
\operatorname{EvidenceAttached}
\land
\operatorname{HumanReview}
\land
\operatorname{NoticeDelivered}
\land
\operatorname{AppealAvailable}
\land
\operatorname{SignedChangeRecord}
\]

If any condition is false:

\[
\operatorname{DowngradeAllowed}
=
\operatorname{false}
\]

The service layer must fail closed:

```text
If a request reduces tier, disables associated access, or changes Hero-at-Rest continuity:
    reject the request unless the signed due-process record passes verification.
```

A transition from `hero-active` to `hero-at-rest` is not a downgrade. It is a transparency state change that retains the achievement recognition and preserved tier.

## Append-Only Audit Chain

Every lifecycle event is appended to the continuity ledger:

- Recognition issuance.
- Hero at Rest declaration.
- Tier-preservation affirmation.
- Access-rights preservation affirmation.
- Consent revision.
- Human review request.
- Correction request.
- Due-process review opening.
- Due-process decision.
- Appeal filing.
- Appeal decision.
- Key rotation.
- Export or migration receipt.

The audit chain must preserve cryptographic linkage, event time, signer role, action type, policy version, and prior-record hash.

It must not include augmentation details, neural data, biometric data, health data, private research contents, unrelated personal identifiers, or unnecessary activity telemetry.

Digital signatures can protect audit trails against undetected modification, though the governance system should separately protect availability through replicated, exportable records and regular integrity verification. [201]

## Status Verification

A verifier evaluates continuity with:

\[
\operatorname{ContinuityValid}
=
\operatorname{SignatureValid}
\land
\operatorname{HashChainValid}
\land
\operatorname{StatusNotRevoked}
\land
\operatorname{NoUnresolvedDowngrade}
\]

The record may use a privacy-preserving credential-status mechanism for published status information. W3C credential-status specifications describe efficient status lists for credential revocation or suspension; this protocol uses such mechanisms only to publish status state, not sensitive identity or augmentation details. [188][191][194]

## Human Oversight and Appeal

The institution must provide:

- Accessible notice before a proposed reduction takes effect.
- A plain-language statement of the asserted grounds.
- Access to the non-sensitive evidence summary.
- An accessible correction and appeal channel.
- A human reviewer who is independent of the initiating decision where feasible.
- A documented conflict-of-interest process.
- An interim continuity-preserving default while review is pending, unless a narrowly scoped emergency safety action is authorized and documented.
- A final signed decision record.

## Access-Rights Registry

Associated access rights must be recorded as explicit scopes, not inferred from a tier label alone.

Examples may include:

```text
accessibility_review
privacy_minimization
offline_service_pathway
human_decision_review
record_export
record_correction
appeal_access
institutional_recognition_display
```

The registry must not grant access to systems, accounts, public services, physical facilities, or other people’s data beyond what the participating institution has authority to provide.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.92 | Uses status separation, append-only records, hash chaining, digital signatures, allowed-change grounds, and auditable verification |
| eco_impact_value | 0.36 | Supports durable, low-duplication institutional records and reduces unnecessary activity-monitoring infrastructure |
| harm_risk | 0.16 | Reduced through no-silent-downgrade enforcement, due process, appeals, minimized data, and human review |
| accessibility_impact | 0.99 | Protects continuity through rest, offline access, accommodation, human review, and accessible appeals |
| rights_alignment | 0.99 | Centers dignity, recognition continuity, consent, privacy, non-discrimination, correction, and institutional accountability |
