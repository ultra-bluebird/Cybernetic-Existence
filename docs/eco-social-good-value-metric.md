# Eco-Social Good Value Metric for Public Project Ranking

## Purpose

The Eco-Social Good Value Metric, abbreviated as ESGV, ranks public projects by their documented contribution to ecological restoration, climate resilience, equitable benefit distribution, universal accessibility, and community governance.

The metric is intended for transparent decision support. It does not replace public deliberation, environmental review, disability-access review, Indigenous or local community governance, procurement law, budget authority, or jurisdiction-specific legal obligations.

The score is bounded from zero to one.

## Design Principles

- A project should be evaluated by verified or transparently modeled outcomes, not promotional claims.
- Ecological benefit and social equity are both necessary.
- A large total benefit cannot justify severe exclusion, rights violations, privacy harms, habitat destruction, displacement, or inaccessible design.
- Community participation must be meaningful, accessible, compensated where appropriate, and capable of changing decisions.
- Benefits must be measured across income, disability, augmentation-related access needs, language, transit access, geography, and other locally relevant access dimensions without profiling individuals.
- The metric should use aggregate groups and community-governed categories, never a registry of disabled people, cybernetic hosts, or other sensitive identities.
- Missing or weak evidence lowers confidence; it does not become a favorable score.

Green infrastructure and nature-based projects can provide multiple ecosystem services, including stormwater retention and reduced discharge, carbon sequestration, flood mitigation, habitat value, and climate adaptation benefits. [135][138][139]

## Core Dimensions

For project \(p\), define:

- \(C_p\): carbon benefit score.
- \(W_p\): stormwater and water-resilience score.
- \(B_p\): biodiversity and habitat-connectivity score.
- \(D_p\): equitable benefit-distribution score.
- \(A_p\): universal accessibility score.
- \(P_p\): community participation and governance score.
- \(K_p\): evidence and knowledge-confidence score.
- \(R_p\): residual harm-risk score.

All scores are normalized to \([0,1]\).

## Ecological Value

\[
E_p
=
0.30C_p
+
0.35W_p
+
0.35B_p
\]

Stormwater and biodiversity are each assigned substantial weight because public restoration projects often require locally durable water-cycle and habitat outcomes, while carbon benefit remains essential but should not dominate all local ecological conditions.

## Social Value

\[
S_p
=
0.35D_p
+
0.40A_p
+
0.25P_p
\]

Accessibility receives the highest social weight because a public project cannot be considered broadly beneficial if people are structurally unable to use, reach, understand, maintain, or participate in it.

## Composite Value

\[
ESGV^{\mathrm{base}}_p
=
K_p
\cdot
\left[
0.55E_p
+
0.45S_p
\right]
\cdot
(1-R_p)
\]

The ecological and social dimensions remain separately visible in every ranking report.

## Non-Offsettable Gates

Before a project can receive a deployable ranking, it must pass all gates:

\[
G_p
=
G^{\mathrm{rights}}_p
\cdot
G^{\mathrm{access}}_p
\cdot
G^{\mathrm{community}}_p
\cdot
G^{\mathrm{ecology}}_p
\cdot
G^{\mathrm{evidence}}_p
\]

Each gate is either zero or one.

A project is blocked when any of the following is true:

- It lacks a credible accessibility plan with funded implementation and maintenance.
- It creates a material exclusion risk for disabled people, cybernetic hosts, assistive-technology users, or people without continuous connectivity.
- It conditions essential service access on telemetry, proprietary devices, external identity verification, or unrelated data consent.
- It creates a material privacy, surveillance, discrimination, displacement, or coercion risk without an approved mitigation and review path.
- It causes an unmitigated breach of a protected ecological corridor, including biodiversity, water quality, habitat continuity, or carbon-accounting integrity.
- It lacks meaningful, accessible, documented community participation.
- Its claimed outcome evidence is materially incomplete, fabricated, or not reviewable.

\[
ESGV_p
=
G_p
\cdot
ESGV^{\mathrm{base}}_p
\]

A blocked project may be listed as `ResearchOnly` with the failed gates and the required evidence or design conditions clearly displayed. It must not be ranked as deployable.

## Normalization

### Carbon Benefit

\[
C_p
=
\operatorname{clip}
\left(
\frac{
\operatorname{VerifiedNetCO2e}_p
}{
\operatorname{ReferenceCO2e} + \epsilon
},
0,
1
\right)
\]

Where verified net benefit includes project lifecycle emissions, maintenance, material replacement, and uncertainty-adjusted sequestration or avoided emissions.

### Stormwater and Water Resilience

\[
W_p
=
0.50
\operatorname{clip}
\left(
\frac{\operatorname{AnnualRunoffRetained}_p}
{\operatorname{ReferenceRunoff}+\epsilon},
0,
1
\right)
+
0.30
\operatorname{clip}
\left(
\frac{\operatorname{PeakFlowReduction}_p}
{\operatorname{ReferencePeakFlow}+\epsilon},
0,
1
\right)
+
0.20
\operatorname{WaterQualityProtection}_p
\]

### Biodiversity and Habitat Connectivity

\[
B_p
=
0.35H_p
+
0.35L_p
+
0.30N_p
\]

Where:

- \(H_p\) is habitat quality improvement.
- \(L_p\) is connectivity improvement.
- \(N_p\) is native-species or ecological-integrity benefit.

All biodiversity indicators should be locally calibrated and should not rely only on species-count totals.

### Benefit Distribution

Let \(g \in \mathcal{G}\) represent aggregate, community-approved benefit groups or geographic service areas.

\[
D_p
=
0.50
\left(
\frac{
\min_{g \in \mathcal{G}} b_{p,g}
}{
\operatorname{mean}_{g \in \mathcal{G}} b_{p,g}+\epsilon
}
\right)
+
0.30
\operatorname{PriorityBenefitShare}_p
+
0.20
\operatorname{AntiDisplacementProtection}_p
\]

Where \(b_{p,g}\) is a normalized benefit level for group or area \(g\).

The first term is a max-min fairness ratio. It prevents a project from receiving a high distribution score when its least-served area receives little benefit relative to the average.

### Universal Accessibility

\[
A_p
=
0.22F_p
+
0.18T_p
+
0.18I_p
+
0.16O_p
+
0.14M_p
+
0.12Z_p
\]

Where:

- \(F_p\) is physical accessibility.
- \(T_p\) is accessible transportation and route access.
- \(I_p\) is information and communication accessibility.
- \(O_p\) is offline and non-digital access.
- \(M_p\) is maintenance, repair, and interoperability access.
- \(Z_p\) is accommodation for assistive and augmentative technology use without mandatory disclosure.

### Community Participation and Governance

\[
P_p
=
0.30U_p
+
0.25Y_p
+
0.20V_p
+
0.15J_p
+
0.10X_p
\]

Where:

- \(U_p\) is early, accessible, and compensated participation.
- \(Y_p\) is documented influence of community input on decisions.
- \(V_p\) is shared oversight and governance capacity.
- \(J_p\) is accessible grievance, correction, and appeal process.
- \(X_p\) is transparent publication of data, uncertainty, tradeoffs, and implementation status.

### Knowledge Confidence

\[
K_p
=
\exp
\left(
\frac{
w_m\ln m_p
+
w_s\ln s_p
+
w_r\ln r_p
+
w_u\ln u_p
}{
w_m+w_s+w_r+w_u
}
\right)
\]

Where:

- \(m_p\) is measurement quality.
- \(s_p\) is source provenance and reproducibility.
- \(r_p\) is independent review quality.
- \(u_p\) is uncertainty characterization quality.

Each term is clamped to a small positive lower bound before the logarithm.

### Harm Risk

\[
R_p
=
\max(
r^{\mathrm{ecological}}_p,
r^{\mathrm{rights}}_p,
r^{\mathrm{privacy}}_p,
r^{\mathrm{accessibility}}_p,
r^{\mathrm{displacement}}_p
)
\]

Using a maximum preserves visibility of the highest serious residual risk. It prevents low risk in one dimension from averaging away high risk in another.

## Ranking Procedure

- Collect evidence and normalize each dimension using published local references.
- Calculate ecological and social sub-scores.
- Evaluate non-offsettable gates.
- Calculate evidence confidence and residual harm risk.
- Publish the complete component table, gate outcomes, uncertainty ranges, and community-review record.
- Rank only projects with \(G_p=1\).
- For projects with overlapping confidence intervals, use a deliberative tie-break based on community governance, accessibility improvement, and lower residual harm risk.
- Recalculate annually and whenever material design, cost, location, benefit distribution, ecological conditions, or rights impacts change.

## Example Interpretation

A large stormwater project may have high \(W_p\) and moderate \(C_p\), but receive a low or blocked ESGV result if it excludes wheelchair users, displaces residents, requires app-based access to essential services, lacks community governance, or harms habitat connectivity.

Conversely, a smaller community-led shade, bioswale, accessible-route, and water-reuse project may have a strong ESGV result where it produces measurable local water and biodiversity benefit, reaches historically underserved areas, is accessible to people using assistive or augmentative technologies, and has durable community oversight.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.94 | Uses explicit ecological, equity, accessibility, governance, evidence, risk, and gate calculations |
| eco_impact_value | 0.95 | Directly ranks carbon, stormwater, water-quality, biodiversity, connectivity, and lifecycle ecological outcomes |
| harm_risk | 0.15 | Reduced through non-offsettable rights, access, ecology, evidence, and anti-displacement gates |
| accessibility_impact | 0.99 | Makes physical, digital, offline, repair, transit, and assistive-technology access measurable and non-compensable |
| rights_alignment | 0.99 | Requires participation, privacy protection, non-discrimination, grievance access, and prevention of essential-service exclusion |
