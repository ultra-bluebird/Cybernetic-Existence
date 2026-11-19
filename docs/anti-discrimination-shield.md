# Anti-Discrimination Shield for Automated Municipal Decisions

## Purpose

The Anti-Discrimination Shield is a policy-enforcement and audit layer for automated municipal decision systems.

It applies to systems that recommend, rank, allocate, prioritize, screen, route, approve, deny, defer, or otherwise influence access to public resources, services, infrastructure, information, emergency support, public facilities, permits, transport, cooling, water, housing-related services, maintenance, or civic participation.

The Shield is designed to detect and prevent disparate impact, inaccessible automation, prohibited profiling, and unreviewable high-impact decisions.

It is not a substitute for public authority, community governance, civil-rights enforcement, accessibility review, or jurisdiction-specific legal analysis.

## Protected-Group Model

The Shield protects legally recognized groups where applicable and voluntary, privacy-preserving service categories that a city adopts for equitable access.

Cybernetic-host or augmented-citizen status must be treated as:

- Self-attested when a person chooses to declare it.
- Optional.
- Not required for baseline municipal services.
- Not inferred from device use, body appearance, gait, voice, health data, assistive technology, or public behavior.
- Excluded from policing, surveillance, risk scoring, insurance, employment, immigration, benefit-fraud, and generalized identity systems.

The system may use aggregate, opt-in, community-governed service-access indicators to test whether automated processes create barriers for people who use assistive or augmentative technologies. It must not build a registry of cybernetic hosts.

## Decision Classification

| Decision class | Examples | Required Shield controls |
|---|---|---|
| Informational | Public service directory, generic transit notice | Accessibility and privacy review; no person-level ranking |
| Advisory | Maintenance recommendation, cooling-center planning, staffing suggestion | Fairness audit, uncertainty report, human approval for consequential implementation |
| Consequential | Resource allocation, service-priority ranking, access recommendation | Pre-deployment impact assessment, disparity tests, causal review, explanation, human review, appeal |
| High impact | Housing-related service decision, public-benefit determination, emergency-service triage, access restriction | No solely automated final decision; mandatory human decision authority, documented review, accessible appeal, heightened audit frequency |

## Prohibited Inputs and Uses

The Shield blocks any automated decision that uses or derives:

- Neural data.
- Biometric data.
- Augmentation status or assistive-device telemetry.
- Self-attested cybernetic-host status as an adverse feature.
- Health information unrelated to a lawful, specific, consented service purpose.
- Race, ethnicity, disability, gender identity, religion, immigration status, or other protected characteristics as adverse features.
- Proxy features known to recreate protected-group disadvantage without a compelling, lawful, and reviewed basis.
- Public sentiment, social-media activity, device identity, browser history, or location history as civic-worthiness indicators.
- Lack of continuous connectivity, smartphone access, proprietary device access, or external identity verification as a reason to deny essential service.

## Pre-Decision Policy Gate

Every automation request must contain:

```text
decision_purpose
legal_or_policy_basis
decision_class
affected_service
input_schema_version
feature_inventory
protected_group_review_plan
accessibility_review_plan
human_review_path
appeal_path
retention_limit
model_version
```

The system may proceed only when:

\[
\operatorname{PreDecisionAllowed}
=
\operatorname{PurposeSpecific}
\land
\operatorname{DataMinimized}
\land
\operatorname{FeaturePolicyPassed}
\land
\operatorname{AccessibilityPlanPresent}
\land
\operatorname{HumanReviewPresent}
\land
\operatorname{AppealPresent}
\]

## Statistical Parity Audit

For group \(g\), define a favorable-decision rate:

\[
\operatorname{SelectionRate}_g
=
\frac{
\operatorname{FavorableDecisions}_g
}{
\operatorname{EligibleCases}_g+\epsilon
}
\]

For protected or community-governed comparison groups \(g\) and \(h\):

\[
\operatorname{StatisticalParityRatio}_{g,h}
=
\frac{
\operatorname{SelectionRate}_g
}{
\operatorname{SelectionRate}_h+\epsilon
}
\]

The Shield flags a potential disparate-impact concern when:

\[
\operatorname{StatisticalParityRatio}_{g,h}
<
\tau_{\mathrm{parity}}
\]

Where \(\tau_{\mathrm{parity}}\) is a policy-defined review threshold. The threshold is an audit trigger, not a legal conclusion.

For adverse outcomes, use the corresponding adverse-rate ratio. All comparisons must include confidence intervals, sample-size thresholds, and suppression rules.

## Error-Rate Audit

For systems with verified outcome labels, calculate:

\[
\operatorname{FalseNegativeRate}_g
=
\frac{
\operatorname{FalseNegatives}_g
}{
\operatorname{ActualPositive}_g+\epsilon
}
\]

\[
\operatorname{FalsePositiveRate}_g
=
\frac{
\operatorname{FalsePositives}_g
}{
\operatorname{ActualNegative}_g+\epsilon
}
\]

Flag material differences:

\[
\Delta_{\mathrm{FNR}}
=
\max_{g,h}
\left|
\operatorname{FalseNegativeRate}_g
-
\operatorname{FalseNegativeRate}_h
\right|
\]

\[
\Delta_{\mathrm{FPR}}
=
\max_{g,h}
\left|
\operatorname{FalsePositiveRate}_g
-
\operatorname{FalsePositiveRate}_h
\right|
\]

The audit must not assume a low complaint rate means fairness. Low complaint volume may reflect inaccessible reporting, fear of retaliation, lack of awareness, or lack of trust.

## Causal Review

Statistical parity identifies patterns. Causal review asks whether a policy, feature, or system pathway plausibly creates an unfair barrier.

For a protected or voluntary service-access attribute \(G\), a decision \(Y\), and permissible non-protected context \(X\), define a causal disparity estimate:

\[
\operatorname{CDE}
=
\mathbb{E}
[
Y_{G=1}
-
Y_{G=0}
\mid X
]
\]

The Shield does not require sensitive identity collection to run every causal review. It may use:

- Voluntary, privacy-preserving audit cohorts.
- Synthetic accessibility scenarios.
- Paired counterfactual cases.
- Accessibility conformance tests.
- Community review.
- Feature-path analysis.
- Aggregate service outcome studies.
- Independent civil-rights and accessibility audits.

A paired counterfactual test changes only an impermissible or protected characteristic while holding relevant service facts constant:

\[
\operatorname{CounterfactualDifference}
=
f(X,G=1)
-
f(X,G=0)
\]

If the outcome changes without an approved, necessary, and rights-respecting explanation, the system must flag the rule or model for review.

## Fairness Decision

Define the Shield result:

\[
\operatorname{ShieldStatus}
=
\begin{cases}
\texttt{blocked}, & \text{prohibited feature or prohibited use detected} \\
\texttt{human\_review\_required}, & \text{parity, error, causal, or accessibility concern flagged} \\
\texttt{approved\_with\_monitoring}, & \text{controls and audit conditions pass} \\
\texttt{research\_only}, & \text{evidence is incomplete or system is not ready for consequential use}
\end{cases}
\]

No statistical score can override a prohibited feature or a material accessibility failure.

## Human Review Override

Human review is a safeguard, not a mechanism for undocumented exception-making.

A reviewer may:

- Approve the decision with written reason.
- Modify the decision to provide equitable access.
- Reverse an automated recommendation.
- Request additional evidence.
- Suspend the automated workflow.
- Refer the case to an accessible appeal or grievance pathway.

The reviewer must record:

```text
reviewer_role
decision_basis
automated_recommendation
fairness_audit_summary
accessibility_considerations
human_decision
reason
appeal_path
time_of_decision
```

The reviewer may not use protected status, augmentation status, disability, or self-declared cybernetic identity as a negative factor.

## Audit Frequency and Governance

| Decision class | Minimum audit cadence | Additional trigger |
|---|---|---|
| Informational | Annual accessibility review | Material content or channel change |
| Advisory | Quarterly fairness and performance review | Material model, policy, or data change |
| Consequential | Monthly monitoring and quarterly independent audit | Any disparity, complaint cluster, or accessibility failure |
| High impact | Per-decision human review and quarterly independent audit | Any material rights or service-access concern |

The system must publish aggregate transparency reports with:

- Purpose and decision class.
- Data categories used.
- Disallowed data categories.
- Fairness metrics and confidence intervals.
- Accessibility findings.
- Human-review rate.
- Appeal rate and resolution quality.
- Material changes.
- Known limitations.
- Corrective actions.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.94 | Uses feature controls, parity ratios, error-rate analysis, causal review, counterfactual testing, human review, and audit governance |
| eco_impact_value | 0.55 | Helps ensure equitable allocation of cooling, water, maintenance, transit, and resilience resources |
| harm_risk | 0.18 | Reduced through blocked prohibited uses, privacy minimization, mandatory review, appealability, and transparent audit reporting |
| accessibility_impact | 0.99 | Requires accessibility review, accessible appeals, non-digital alternatives, and explicit protection of access-critical services |
| rights_alignment | 0.99 | Centers dignity, self-assertion, non-discrimination, privacy, due process, and human accountability |
