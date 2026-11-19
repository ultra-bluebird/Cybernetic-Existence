# Fairness-Aware Resource Allocation for Public Services

## Purpose

This model allocates limited public resources—such as safe water during shortage, cooling-center capacity, accessible transport support, emergency charging, or public-service appointments—using transparent fairness constraints and a computationally tractable convex optimization.

The model is public decision support. It does not determine human worth, create a social score, require disclosure of cybernetic-host status, infer disability or health information, or replace accountable public decision-making.

## Rights and Data Invariants

The allocation system must:

- Provide baseline essential service without requiring disclosure of identity, disability, augmentation, health, neural, biometric, device, immigration, or financial information unrelated to the service.
- Use aggregate planning groups or voluntary, privacy-preserving audit cohorts rather than a registry of cybernetic hosts or other protected people.
- Never use self-attested cybernetic-host status as a negative allocation feature.
- Treat lack of smartphone access, continuous connectivity, proprietary technology, external identity verification, or unrelated consent as non-grounds for denying essential service.
- Offer offline, in-person, phone, paper, and human-assisted access paths.
- Publish a plain-language explanation, constraints, uncertainty, service floor, and appeal route.
- Route material infeasibility to human emergency management rather than silently lowering a group’s service floor.

The model’s central fairness principle is:

\[
\forall g \in \mathcal{G}:
\quad
\operatorname{ServiceLevel}_g
\ge
\operatorname{BaselineFloor}_g
\]

Where groups are privacy-preserving planning areas or voluntary service-access cohorts, not mandatory identity classifications.

## Inputs

For each planning group \(g \in \mathcal{G}\):

- \(n_g\): aggregate need units.
- \(x_g\): allocated resource units.
- \(b_g\): baseline guaranteed allocation.
- \(m_g\): maximum useful or absorptive allocation.
- \(a_g\): accessible delivery capacity.
- \(q_g\): evidence quality and confidence.
- \(w_g\): equity weight, based on documented unmet need, service burden, and community-governed priorities.
- \(c_g\): delivery cost per resource unit.

For the overall system:

- \(B\): available resource budget.
- \(C\): total service-delivery budget.
- \(\epsilon\): small positive fairness constant.

The allocation must satisfy:

\[
0 \le x_g \le \min(n_g,m_g,a_g)
\]

\[
x_g \ge b_g
\]

\[
\sum_{g \in \mathcal{G}}x_g \le B
\]

\[
\sum_{g \in \mathcal{G}}c_gx_g \le C
\]

If the baseline floors are infeasible:

\[
\sum_{g \in \mathcal{G}}b_g > B
\]

the optimizer must return `human_emergency_review_required`. It must not silently set \(b_g\) to zero for less visible or lower-resource areas.

## Accessible Service Utility

Define group utility:

\[
u_g(x_g)
=
q_g
\cdot
\min
\left(
1,
\frac{
a_gx_g
}{
n_g+\epsilon
}
\right)
\]

This formulation recognizes that physical delivery, accessible transportation, language access, staffing, and repair capacity can limit whether nominal allocation becomes usable service.

## Nash Social Welfare Allocation

After all baseline floors are feasible, maximize weighted Nash social welfare:

\[
\max_{x}
\sum_{g \in \mathcal{G}}
w_g
\log
\left(
u_g(x_g)+\epsilon
\right)
\]

Subject to all resource, cost, delivery, and baseline-floor constraints.

This objective is computationally tractable for continuous allocations because it is concave when \(u_g(x_g)\) is concave and constraints are linear.

Nash social welfare balances efficiency and fairness by rewarding allocations that improve the least-served group’s utility without ignoring total service improvement. It remains a decision-support objective rather than a substitute for procedural equity, accessibility, community governance, or rights protections. [27][258][266]

## Minimax Fairness Alternative

For emergency settings, use a minimax shortfall objective:

\[
\min_{x,z}
z
\]

Subject to:

\[
1-u_g(x_g) \le z
\quad
\forall g \in \mathcal{G}
\]

This minimizes the largest service shortfall across planning groups.

A weighted version is:

\[
w_g
\left[
1-u_g(x_g)
\right]
\le z
\quad
\forall g \in \mathcal{G}
\]

This gives priority to documented high-burden groups while retaining visible service floors for every group.

## Lexicographic Allocation Rule

The system uses three stages:

1. **Essential floor:** satisfy baseline safety and access floors.
2. **Minimax protection:** minimize the highest weighted shortfall.
3. **Nash refinement:** maximize weighted log utility among allocations that preserve the minimax result.

This avoids a common failure mode where an aggregate utility objective allocates heavily to easy-to-serve groups while leaving another group with severe unmet need.

## Identity and Cybernetic-Host Protection

The model may include an aggregate, opt-in service-capacity indicator for accessibility or augmentative-technology support:

\[
a_g^{\mathrm{support}}
\]

Examples include:

- Reliable low-heat charging availability.
- Step-free cooling-center capacity.
- Quiet or sensory-adjusted service capacity.
- Human-assisted communication availability.
- Accessible transportation capacity.
- Device-safe environmental conditions.

This is a service-planning variable. It must not become an identity registry or a proxy for who is a cybernetic host.

## Output Requirements

Every allocation run must emit:

```text
allocation_run_version
resource_category
planning_period
total_available_resource
baseline_floor_feasible
allocation_by_group
estimated_service_level
estimated_unmet_need
minimax_shortfall
nash_utility
accessible_delivery_capacity
evidence_quality
binding_constraints
uncertainty_summary
human_review_status
plain_language_explanation
appeal_path
```

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.94 | Uses baseline floors, accessible delivery capacity, minimax fairness, Nash social welfare, convex constraints, and transparent infeasibility handling |
| eco_impact_value | 0.82 | Supports equitable water, cooling, transit, and emergency-resource distribution while minimizing wasted delivery capacity |
| harm_risk | 0.17 | Reduced through non-discrimination constraints, privacy-preserving groups, hard service floors, infeasibility escalation, and human review |
| accessibility_impact | 0.99 | Makes accessible delivery, non-digital access, human assistance, and support capacity explicit allocation conditions |
| rights_alignment | 0.99 | Preserves dignity, equal access, privacy, accountability, community governance, and accessible appeals |
