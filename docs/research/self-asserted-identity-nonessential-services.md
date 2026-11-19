# Self-Asserted Identity for Non-Essential Services

## Purpose

This design accepts self-asserted identity declarations for non-essential services without official certification, centralized identity proofing, social ranking, or collection of sensitive personal data.

A declaration may include a chosen name, pronouns, affiliation, cultural identity, assistive-technology preference, or a self-described cybernetic-host status. Such declarations are expressions of self-description and dignity. They are not proof of legal identity, medical status, institutional status, credential eligibility, risk level, service priority, or authority over others.

## Scope Boundary

This policy applies only to non-essential, low-risk uses, such as:

- Display preferences in a voluntary community forum.
- Chosen forms of address.
- Optional peer-group participation.
- Local profile labels controlled by the person.
- Accessibility communication preferences.
- Non-binding collaborative-project roles.

This policy SHALL NOT determine access to:

- Emergency response, cooling, food, shelter, medical care, sanitation, or other essential services.
- Housing, employment, education, public benefits, immigration, voting, legal rights, or law-enforcement interactions.
- Safety-critical equipment, vehicle controls, physical access systems, or hazardous work authorization.
- Services that require a separate, legally applicable authorization process.

No person shall be required to disclose an identity declaration, use a persistent account, provide official identification, disclose assistive technology, disclose a cybernetic-host status, or accept a reputation mechanism in order to receive baseline public or essential services.

## Core Principle

The service accepts self-description without attempting to certify the person behind it.

The system evaluates conduct and service-specific safety constraints rather than making determinations about the truth, legitimacy, medical basis, social acceptability, or institutional recognition of an identity declaration.

## Acceptance Rule

Let:

- \(I\) be a self-asserted identity statement.
- \(A\) be the local set of syntactically supported identity statements.
- \(C\) be the current interaction context.
- \(H(C)\) be verified, context-specific evidence of prohibited harmful conduct.
- \(S(C)\) be a service-specific safety constraint.
- \(R\) be the resulting local handling state.

The identity-acceptance rule is:

\[
R =
\begin{cases}
\text{ACCEPTED} &
\text{if } I \in A
\land \neg H(C)
\land S(C) = \text{satisfied} \\
\text{ACCEPTED\_WITH\_CONDUCT\_BOUNDARY} &
\text{if } I \in A
\land H(C)
\land S(C) = \text{satisfied} \\
\text{SERVICE\_SAFETY\_REVIEW} &
\text{if } S(C) \neq \text{satisfied} \\
\text{UNSUPPORTED\_FORMAT} &
\text{if } I \notin A
\end{cases}
\]

The rule does not calculate a score, confidence value, trust rank, social rank, identity validity probability, or behavioral prediction.

The phrase `ACCEPTED_WITH_CONDUCT_BOUNDARY` does not reject the identity. It means the identity remains acknowledged while a documented, context-specific behavior boundary is applied through accessible due process.

## Harm Standard

A declaration itself is not harmful merely because it is unfamiliar, disputed, unverifiable, unconventional, related to assistive technology, or related to a self-described cybernetic status.

A conduct report may be actionable only when all conditions are met:

- The report identifies a specific interaction and policy-relevant behavior.
- The alleged behavior is linked to a documented non-essential-service rule.
- The report does not rely on protected status, health inference, disability inference, augmentation status, appearance, identity disagreement, or social disapproval.
- The affected person receives an accessible explanation.
- The person has an opportunity to respond, correct, or appeal.
- A reversible, least-restrictive response is available.
- A human reviewer handles any restriction beyond an immediate, narrow safety boundary.

Examples of potentially actionable conduct include credible threats, targeted harassment, non-consensual disclosure of personal data, impersonation intended to deceive a particular service workflow, or attempts to bypass a safety constraint.

Examples that are not actionable identity harms include self-description, chosen pronouns, a voluntary identity label, disagreement about terminology, lack of certification, inability to disclose personal records, or declining to disclose cybernetic or assistive-technology information.

## Conflict Resolution Without Central Authority

Conflicting claims should be treated as a coexistence and boundary-setting problem, not as an identity-adjudication problem.

When two people make incompatible or disputed statements:

1. Preserve each person's self-asserted label in their own local profile or session.
2. Do not force either person to prove, retract, or publicly defend their self-description.
3. Separate factual service requirements from social disagreement.
4. Apply neutral interaction rules: no harassment, no impersonation for deception, no non-consensual disclosure, and no coercive questioning.
5. Offer optional mediation, a block/mute boundary, a separate collaboration space, or a human-facilitated process.
6. Record only the minimum conduct facts needed to resolve a report.
7. Expire and delete conflict records on a defined schedule unless a person requests retention for an active appeal.

For identity-label collisions in one local namespace, the system should use a collision-safe local display convention without deciding whose identity is valid. For example, each person retains their chosen display name and may select an optional local differentiator such as a session color, a user-selected alias suffix, or a device-local profile key.

## No-Ranking Reputation Model

The system SHALL NOT create:

- Reputation scores.
- Trust scores.
- CyberRank tiers.
- Popularity metrics.
- Visibility boosts based on behavior history.
- Identity reliability labels.
- Cross-service behavioral profiles.
- Blacklists shared across unrelated services.
- Predictive risk scores.
- Automated restrictions based on prior reports.

Instead, it may maintain narrow, expiring, context-bound process records:

```json
{
  "recordType": "interaction_boundary",
  "scope": "single_nonessential_service",
  "reasonCategory": "specific_policy_behavior",
  "createdAt": "2026-09-01T00:00:00Z",
  "expiresAt": "2026-10-01T00:00:00Z",
  "reviewStatus": "human_review_available",
  "appealStatus": "available",
  "identityAssertionStored": false,
  "crossServiceSharing": false,
  "automatedRanking": false
}
```

A boundary record is not a reputation record. It has no numerical value, cannot be aggregated across contexts, expires automatically, and cannot be reused to infer a person's character or identity validity.

## Privacy Requirements

- Store identity assertions locally by default.
- Encrypt locally stored declarations at rest when device capabilities permit.
- Use pairwise pseudonymous identifiers for optional service accounts.
- Do not publish declarations to a ledger, directory, public profile, or interoperable registry without explicit, separate consent.
- Do not connect declarations to medical, biometric, neural, augmentation, employment, housing, government, or financial data.
- Do not collect location history as a condition of identity acceptance.
- Permit deletion and export without requiring a reason.
- Use short retention periods for conduct-boundary records.
- Use aggregate, de-identified process metrics only for service-quality review.

## Accessibility Requirements

- Support keyboard-only operation, screen readers, plain-language notices, text resizing, and non-visual error feedback.
- Permit free-text self-description; do not limit people to a fixed taxonomy.
- Do not require voice, facial recognition, handwriting, government identification, or a particular device.
- Provide human-mediated alternatives to digital workflows.
- Ensure moderation and appeal channels are accessible without revealing sensitive identity information.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.82 | Uses identity-minimization, pseudonymity, decentralized-identifier, and self-assertion principles while retaining explicit scope limits |
| eco_impact_value | 0.46 | Local-first storage and limited retention reduce unnecessary cloud processing and data replication |
| harm_risk | 0.31 | Risks include selective harassment, misuse of conduct reports, and covert profiling; bounded records, review, deletion, and non-ranking controls reduce exposure |
| accessibility_impact | 0.93 | Supports self-description, chosen forms of address, accessible alternatives, and no-certification participation |
| rights_alignment | 0.96 | Preserves dignity, self-determination, consent, privacy, non-discrimination, review, and freedom from social scoring |
