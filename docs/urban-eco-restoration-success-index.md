# Urban Eco-Restoration Success Index

## Purpose

The Urban Eco-Restoration Success Index, abbreviated as UERSI, measures the condition and recovery trajectory of an urban green-space restoration project using citizen-science observations, remote sensing, field samples, and community participation records.

The score is bounded from zero to one hundred.

It is a decision-support measure, not a substitute for ecological field assessment, Indigenous or local ecological knowledge, regulatory compliance, land-management authority, or long-term restoration stewardship.

## Design Principles

- Measure change against a documented baseline and a locally appropriate reference condition.
- Keep species richness, native cover, soil organic matter, pollinator abundance, and community engagement separately visible.
- Prefer repeated observations and uncertainty reporting over single “success” claims.
- Use citizen science as a meaningful evidence source when protocols, coverage, and validation are stated.
- Do not require volunteers to reveal identity, health, disability, augmentation status, precise home location, or device telemetry to contribute.
- Do not use restoration monitoring to profile visitors, residents, or community participants.
- Treat community engagement as an essential stewardship outcome, while not allowing it to compensate for ecological harm.

Urban green infrastructure can support biodiversity and pollinators, particularly when projects use native vegetation and protect habitat functions. [231][232][236] Citizen science and community engagement are also recognized as important inputs to urban green-infrastructure planning, implementation, and monitoring. [233][237]

## Inputs

For site \(s\) at observation period \(t\), define:

- \(R_{s,t}\): species richness recovery score.
- \(N_{s,t}\): native plant coverage recovery score.
- \(O_{s,t}\): soil organic matter recovery score.
- \(P_{s,t}\): pollinator abundance recovery score.
- \(G_{s,t}\): community engagement and stewardship score.
- \(Q_{s,t}\): evidence quality and coverage confidence.
- \(H_{s,t}\): residual ecological harm-risk score.

All component scores except UERSI are normalized to the interval \([0,1]\).

## Composite Formula

\[
UERSI_{s,t}
=
100
\cdot
Q_{s,t}
\cdot
\left[
0.24R_{s,t}
+
0.24N_{s,t}
+
0.18O_{s,t}
+
0.20P_{s,t}
+
0.14G_{s,t}
\right]
\cdot
(1-H_{s,t})
\]

The component weights sum to one.

| Component | Weight | Reason |
|---|---:|---|
| Species richness recovery | 0.24 | Captures multi-taxa ecological recovery and habitat use |
| Native plant coverage | 0.24 | Represents restoration of locally appropriate vegetation, habitat quality, and long-term ecological integrity |
| Pollinator abundance | 0.20 | Captures a visible, monitorable ecosystem-response indicator linked to flowering resources and habitat structure |
| Soil organic matter | 0.18 | Represents longer-lived soil recovery, water retention, nutrient cycling, and plant-support capacity |
| Community engagement | 0.14 | Captures stewardship, local knowledge, monitoring continuity, and durable public value |
| Evidence quality | Multiplier | Prevents low-coverage or uncertain observations from being treated as high-confidence success |
| Residual harm risk | Penalty | Prevents a project from scoring well while retaining material ecological, access, displacement, or maintenance harm |

## Baseline and Reference Normalization

For ecological indicator \(X\), use:

\[
X^{*}_{s,t}
=
\operatorname{clip}
\left(
\frac{
X_{s,t} - X_{s,0}
}{
X_{s,\mathrm{reference}} - X_{s,0} + \epsilon
},
0,
1
\right)
\]

Where:

- \(X_{s,0}\) is the documented project baseline.
- \(X_{s,\mathrm{reference}}\) is a locally appropriate target or reference condition.
- \(\epsilon\) prevents division by zero.
- \(\operatorname{clip}(x,0,1)\) constrains a value to the interval from zero to one.

If the baseline exceeds the selected reference for a particular variable, the project must document why a different reference is appropriate rather than silently reversing the formula.

## Species Richness Recovery

Let \(S_{s,t}\) be observed richness, adjusted for observation effort and detection confidence.

\[
R_{s,t}
=
\operatorname{clip}
\left(
\frac{
S_{s,t}^{\mathrm{adjusted}} - S_{s,0}^{\mathrm{adjusted}}
}{
S_{s,\mathrm{reference}}^{\mathrm{adjusted}} - S_{s,0}^{\mathrm{adjusted}} + \epsilon
},
0,
1
\right)
\]

The score should use locally relevant taxa, such as native plants, birds, pollinators, amphibians, reptiles, soil invertebrates, or aquatic organisms, rather than treating raw species count as sufficient ecological quality.

## Native Plant Coverage Recovery

Let \(A_{s,t}^{\mathrm{native}}\) be native vegetated area and \(A_{s,t}^{\mathrm{vegetated}}\) be all vegetated area.

\[
N_{s,t}
=
\operatorname{clip}
\left(
0.60
\frac{
A_{s,t}^{\mathrm{native}}
}{
A_{s,t}^{\mathrm{vegetated}}+\epsilon
}
+
0.40
\operatorname{NDVIRecovery}_{s,t},
0,
1
\right)
\]

Remote-sensing inputs can include NDVI, fractional vegetation cover, canopy cover, multispectral classification, or LiDAR-derived vegetation structure. High-resolution imagery and LiDAR can support monitoring of vegetation structure and habitat complexity, which can be relevant to urban biodiversity outcomes. [239]

## Soil Organic Matter Recovery

Let \(SOM_{s,t}\) be measured soil organic matter percentage.

\[
O_{s,t}
=
\operatorname{clip}
\left(
\frac{
SOM_{s,t}-SOM_{s,0}
}{
SOM_{s,\mathrm{reference}}-SOM_{s,0}+\epsilon
},
0,
1
\right)
\]

Soil sampling should identify depth, method, laboratory or field protocol, moisture condition, and uncertainty. The system must never report a remote-sensing proxy as if it were a direct soil-organic-matter measurement.

## Pollinator Recovery

Let \(A_{s,t}^{\mathrm{pollinator}}\) be effort-adjusted pollinator observations and \(F_{s,t}^{\mathrm{floral}}\) be flowering-resource availability.

\[
P_{s,t}
=
0.70
\operatorname{clip}
\left(
\frac{
A_{s,t}^{\mathrm{pollinator}}-A_{s,0}^{\mathrm{pollinator}}
}{
A_{s,\mathrm{reference}}^{\mathrm{pollinator}}
-
A_{s,0}^{\mathrm{pollinator}}
+\epsilon
},
0,
1
\right)
+
0.30
\operatorname{clip}
\left(
\frac{
F_{s,t}^{\mathrm{floral}}
}{
F_{s,\mathrm{reference}}^{\mathrm{floral}}
+\epsilon
},
0,
1
\right)
\]

Pollinator inventories should be repeated across seasons and time windows; EPA guidance encourages monitoring pollinator conditions over time and noting changes in habitat and pollution conditions. [236]

## Community Engagement and Stewardship

\[
G_{s,t}
=
0.30V_{s,t}
+
0.25C_{s,t}
+
0.20A_{s,t}^{\mathrm{participation}}
+
0.15M_{s,t}
+
0.10Y_{s,t}
\]

Where:

- \(V_{s,t}\) is volunteer or resident stewardship continuity.
- \(C_{s,t}\) is documented community influence on decisions.
- \(A_{s,t}^{\mathrm{participation}}\) is accessibility of participation pathways.
- \(M_{s,t}\) is maintenance and care-plan continuity.
- \(Y_{s,t}\) is public transparency and feedback responsiveness.

Participation must remain voluntary. A high participation count does not justify environmental degradation, inaccessible site design, displacement, or use of unpaid labor in place of required maintenance resources.

## Evidence Quality

\[
Q_{s,t}
=
0.30Q_{s,t}^{\mathrm{coverage}}
+
0.25Q_{s,t}^{\mathrm{repeatability}}
+
0.20Q_{s,t}^{\mathrm{protocol}}
+
0.15Q_{s,t}^{\mathrm{validation}}
+
0.10Q_{s,t}^{\mathrm{uncertainty}}
\]

Evidence quality includes:

- Spatial and seasonal observation coverage.
- Number and consistency of repeated observations.
- Use of a stated citizen-science or remote-sensing protocol.
- Expert, automated, or cross-observer validation.
- Documentation of missing data and uncertainty.

Citizen-science monitoring is strongest when the ecological question, spatial and temporal coverage, expected sample size, and feasible volunteer protocol are specified in advance. [233]

## Residual Harm Risk

\[
H_{s,t}
=
\max
\left(
h_{s,t}^{\mathrm{ecological}},
h_{s,t}^{\mathrm{water}},
h_{s,t}^{\mathrm{accessibility}},
h_{s,t}^{\mathrm{displacement}},
h_{s,t}^{\mathrm{maintenance}}
\right)
\]

The maximum operator ensures that a severe unresolved concern stays visible.

A project must be marked `ResearchOnly` or `HoldForReview` if it causes or risks:

- Material habitat destruction.
- Pollution or water-quality degradation.
- Inaccessible public paths or facilities.
- Displacement without effective protections.
- Loss of community governance.
- Unfunded maintenance that predictably undermines restoration outcomes.

## Interpretation

| UERSI score | Interpretation | Appropriate action |
|---|---|---|
| 0–20 | Critical restoration gap | Investigate ecological harm, access barriers, missing monitoring, and urgent maintenance needs |
| 21–40 | Early or fragile recovery | Strengthen native planting, soil care, pollinator habitat, monitoring coverage, and stewardship support |
| 41–60 | Measurable recovery | Continue adaptive management and close weak-component gaps |
| 61–80 | Strong recovery trajectory | Maintain long-term stewardship, monitoring, and equitable public access |
| 81–100 | High documented restoration success | Preserve protections, publish methods, and avoid treating a high score as permission to reduce monitoring |

## Citizen Science Workflow

- Publish a site baseline, map, observation protocol, and accessibility information.
- Offer accessible participation options: paper, offline, mobile, phone, staff-assisted, and multilingual pathways.
- Collect observations without requiring personal identity, health status, augmentation disclosure, or precise home location.
- Validate observations through photo-independent checks, expert review, repeated observations, and structured uncertainty flags.
- Combine community observations with remote-sensing products and periodic soil samples.
- Publish aggregate trends, uncertainty, and actions taken.
- Maintain the project as a community-governed restoration record, not a volunteer-surveillance system.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.93 | Uses baseline/reference normalization, repeatable citizen-science inputs, remote sensing, uncertainty, and visible component scores |
| eco_impact_value | 0.95 | Directly measures biodiversity, native vegetation, soil recovery, pollinator habitat, and stewardship outcomes |
| harm_risk | 0.15 | Reduced through evidence-quality multiplier, residual-harm maximum, access and anti-displacement review, and non-compensation rules |
| accessibility_impact | 0.95 | Requires accessible monitoring participation and treats physical access and stewardship as explicit conditions |
| rights_alignment | 0.98 | Protects community governance, voluntary participation, privacy, transparency, non-discrimination, and public access |
