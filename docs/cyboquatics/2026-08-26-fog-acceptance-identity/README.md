# Deterministic FOG, Voluntary Acceptance, and Identity Protection

This artifact set is advisory-only. It does not track people, infer identity, rank social worth, manipulate behavior, determine legal status, authenticate a person, make eligibility decisions, or authorize physical action.

## FOG-Router Determinism

All implementations must use the same predicate order and integer-scaled values.

### Canonical input units

- `confidence_milli`: integer from 0 to 1000.
- `completeness_milli`: integer from 0 to 1000.
- `knowledge_factor_milli`: integer from 0 to 1000.
- `harm_risk_milli`: integer from 0 to 1000.
- `uncertainty_flag`: boolean.
- `hazard_flag`: boolean.
- `media_class`: ASCII token from the approved taxonomy.

### Predicate order

1. Reject structurally invalid input, unknown media, or any integer outside 0–1000.
2. Route `FOG_REVIEW` when `hazard_flag = true`.
3. Route `FOG_REVIEW` when `uncertainty_flag = true`.
4. Route `FOG_REVIEW` when `confidence_milli < 700`.
5. Route `FOG_REVIEW` when `completeness_milli < 900`.
6. Route `FOG_REVIEW` when `knowledge_factor_milli < 700`.
7. Route `FOG_REVIEW` when `harm_risk_milli > 300`.
8. Otherwise route `KNOWN_MEDIA_REVIEWABLE`.

No implementation may reorder predicates, round a value, parse locale-specific decimals, generate random values, use wall-clock time, or fetch external state during routing.

### Cross-language verification

Each language implementation must consume the same line-oriented test-vector file and emit exactly:

`test_id|route|reason_code`

CI must compare output bytes from each implementation. Integer inputs avoid cross-platform floating-point accumulation and evaluation-order differences.

## Acceptance Pattern Without Surveillance

Measure system conditions, not personal influence or social conformity.

Permitted aggregate indicators:

- Opt-in anonymous survey response distribution.
- Aggregate policy-compliance ratio.
- Aggregate accessible-appeal availability and resolution ratio.
- Aggregate participation in voluntary, non-identifying feedback channels.
- Aggregate service-access improvement documented by an independent reviewer.

Prohibited inputs and uses:

- Individual tracking, social graphs, device identifiers, biometrics, neural data, message content, location histories, persuasion profiles, or behavioral scoring.
- Inferring whether an individual was influenced.
- Targeting a person for messaging, benefits, penalties, or surveillance.
- Treating a low response rate or appeal rate as evidence of approval.

A published aggregate requires a minimum cohort size of 30, opt-in participation, small-cell suppression, accessible response options, and clear explanation that participation does not affect services.

## Identity Protection Rule

The system must not test whether a person’s identity, cybernetic existence, augmented-citizen status, assistive-technology use, or non-augmentation status is “real enough” for dignity, protection, or public access.

Minimum logic:

`PROTECTED_SELF_ASSERTED_IDENTITY` when a person self-describes an identity or chooses not to disclose one.

`NO_IDENTITY_ELIGIBILITY_DECISION` applies in all cases.

The system may assess a specific, concrete action only when there is an independent, documented safety or conduct process with notice, accessible human review, evidence standards, and appeal. It must not infer harmful intent or unlawful conduct from identity, device use, appearance, augmentation, or refusal to disclose information.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.90 | Integer predicate contract and shared test vectors |
| eco_impact_value | 0.70 | Reduces rework and supports rights-preserving participation |
| harm_risk | 0.10 | No tracking, profiling, actuation, or identity eligibility |
| accessibility_impact | 0.94 | Self-assertion, opt-in feedback, and accessible appeal |
| rights_alignment | 0.98 | Equal protection, autonomy, privacy, and human review |
