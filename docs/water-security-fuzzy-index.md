# Water Security Index with Community-Adjustable Fuzzy Logic

## Purpose

The Water Security Index, abbreviated as WSI, is a zero-to-one-hundred community resilience score that combines:

- Water quality.
- Supply reliability.
- Physical, financial, informational, and emergency accessibility.
- Community self-governance capacity.

The index is a decision-support instrument. It does not certify drinking-water safety, replace regulatory monitoring, override public-health directives, or determine whether a person may receive water.

The system must preserve a non-compensation rule:

> Strong governance, high supply reliability, or good accessibility cannot compensate for an unsafe water-quality condition.

Water-quality indicators require local and source-specific interpretation. Turbidity is a measure of water cloudiness and can indicate filtration effectiveness and a possible association with disease-causing microorganisms; regulatory and operational treatment limits vary by treatment system and jurisdiction. [115][117][118] pH also affects treatment effectiveness, corrosion control, and possible leaching in a distribution system. [118]

## Inputs

For community \(c\) and period \(t\), gather:

- \(pH_{c,t}\): measured pH.
- \(T_{c,t}\): turbidity in NTU.
- \(M_{c,t}\): microbial-risk indicator or validated microbial monitoring result.
- \(X_{c,t}\): chemical-contaminant risk ratio, using a community-approved maximum of normalized contaminant ratios.
- \(R_{c,t}\): supply-reliability fraction, representing the share of scheduled service time delivered within approved pressure, quality, and continuity conditions.
- \(A_{c,t}\): water-accessibility score.
- \(G_{c,t}\): community self-governance capacity score.
- \(Q_{c,t}\): measurement quality and evidence confidence.

The contaminant-risk ratio can be represented as:

\[
X_{c,t}
=
\max_{x \in \mathcal{X}}
\left(
\frac{C_{x,c,t}}
{L_{x,c}}
\right)
\]

Where:

- \(C_{x,c,t}\) is the measured concentration of contaminant \(x\).
- \(L_{x,c}\) is the locally applicable health, regulatory, or community-adopted action level.
- \(\mathcal{X}\) is the community-approved contaminant set.

The maximum operator is intentionally conservative: one severe contaminant risk must remain visible rather than being averaged away.

## Fuzzy Linguistic Variables

All input dimensions use the common linguistic labels:

- Very Low.
- Low.
- Moderate.
- High.
- Very High.

The output WSI uses:

- Critical.
- Fragile.
- Stressed.
- Secure.
- Resilient.

Each community may adjust membership-function breakpoints through an approved governance process, provided that:

- Regulatory or health-protective limits cannot be relaxed below applicable requirements.
- Every change is versioned, dated, explained, and publicly reviewable.
- Historical results retain the membership-function version used at the time.
- A change must not hide a known health hazard or reduce an existing service obligation.
- Public-health, water-utility, environmental-justice, and affected-community review occurs before activation.

## Default Membership Functions

### pH Adequacy

pH adequacy is centered on the community’s designated operational range, rather than treating lower or higher pH as universally better.

\[
\mu_{\mathrm{adequate\_pH}}(pH)
=
\operatorname{trap}(pH; 6.8, 7.1, 8.4, 8.7)
\]

\[
\mu_{\mathrm{poor\_pH}}(pH)
=
\max(
\operatorname{left\_shoulder}(pH; 6.0, 6.8),
\operatorname{right\_shoulder}(pH; 8.7, 9.5)
)
\]

### Turbidity Safety

\[
\mu_{\mathrm{low\_turbidity}}(T)
=
\operatorname{left\_shoulder}(T; 0.3, 1.0)
\]

\[
\mu_{\mathrm{high\_turbidity}}(T)
=
\operatorname{right\_shoulder}(T; 1.0, 5.0)
\]

These are default operational anchors only. A water-treatment system must use the applicable source, treatment, and regulatory requirements rather than a generic numeric rule.

### Microbial-Risk Safety

Let \(M\) be normalized so zero represents no detected or validated microbial concern and one represents a community-defined critical microbial action state.

\[
\mu_{\mathrm{microbial\_safe}}(M)
=
\operatorname{left\_shoulder}(M; 0.05, 0.20)
\]

\[
\mu_{\mathrm{microbial\_unsafe}}(M)
=
\operatorname{right\_shoulder}(M; 0.20, 0.60)
\]

### Chemical-Contaminant Safety

\[
\mu_{\mathrm{chemical\_safe}}(X)
=
\operatorname{left\_shoulder}(X; 0.50, 0.80)
\]

\[
\mu_{\mathrm{chemical\_unsafe}}(X)
=
\operatorname{right\_shoulder}(X; 0.80, 1.00)
\]

Where a value at or above one indicates that the normalized contaminant ratio has reached the selected action threshold.

### Supply Reliability

\[
\mu_{\mathrm{reliable}}(R)
=
\operatorname{right\_shoulder}(R; 0.80, 0.97)
\]

\[
\mu_{\mathrm{unreliable}}(R)
=
\operatorname{left\_shoulder}(R; 0.50, 0.80)
\]

### Accessibility

Accessibility includes:

- Distance or travel burden to safe water.
- Affordability.
- Accessible physical collection points.
- Safe hours and emergency continuity.
- Language and information access.
- Disability and assistive-technology compatibility.
- Non-digital access.
- Freedom from discriminatory or identity-based barriers.

\[
\mu_{\mathrm{accessible}}(A)
=
\operatorname{right\_shoulder}(A; 0.65, 0.85)
\]

\[
\mu_{\mathrm{inaccessible}}(A)
=
\operatorname{left\_shoulder}(A; 0.30, 0.55)
\]

### Self-Governance Capacity

Self-governance capacity includes:

- Community participation in water decisions.
- Accessible public information.
- Maintenance and repair capability.
- Emergency response and mutual-aid capacity.
- Grievance, correction, and accountability pathways.
- Local authority over priorities and data use.
- Ability to inspect and adapt the index.

\[
\mu_{\mathrm{strong\_governance}}(G)
=
\operatorname{right\_shoulder}(G; 0.60, 0.82)
\]

\[
\mu_{\mathrm{weak\_governance}}(G)
=
\operatorname{left\_shoulder}(G; 0.25, 0.50)
\]

## Fuzzy Operators

For a trapezoidal membership function:

\[
\operatorname{trap}(x;a,b,c,d)
=
\max
\left(
0,
\min
\left(
\frac{x-a}{b-a},
1,
\frac{d-x}{d-c}
\right)
\right)
\]

For a left-shoulder membership function:

\[
\operatorname{left\_shoulder}(x;a,b)
=
\begin{cases}
1, & x \le a \\
\frac{b-x}{b-a}, & a < x < b \\
0, & x \ge b
\end{cases}
\]

For a right-shoulder membership function:

\[
\operatorname{right\_shoulder}(x;a,b)
=
\begin{cases}
0, & x \le a \\
\frac{x-a}{b-a}, & a < x < b \\
1, & x \ge b
\end{cases}
\]

Use Mamdani inference:

- Logical AND: minimum.
- Logical OR: maximum.
- Rule activation: minimum.
- Rule aggregation: maximum.
- Defuzzification: centroid.

## Explainable Rule Base

### Health and Quality Rules

- If microbial risk is unsafe, then WSI is Critical.
- If chemical contamination is unsafe, then WSI is Critical.
- If turbidity is high and microbial risk is moderate or high, then WSI is Critical.
- If pH is poor and chemical safety is low, then WSI is Fragile.
- If pH is adequate, turbidity is low, microbial safety is high, and chemical safety is high, then water quality is Secure.

### Supply and Access Rules

- If supply reliability is unreliable, then WSI is at most Stressed.
- If accessibility is inaccessible, then WSI is at most Stressed.
- If reliability is high but accessibility is low, then WSI is Stressed.
- If accessibility is high but quality is unsafe, then WSI is Critical.
- If supply reliability and accessibility are both high, then service access is Secure.

### Governance and Resilience Rules

- If self-governance is weak and supply reliability is low, then WSI is Fragile.
- If self-governance is strong, accessibility is high, and supply reliability is high, then resilience is Resilient.
- If self-governance is strong but water quality is unsafe, then WSI remains Critical and governance is reported as a recovery capacity, not as compensation.
- If data quality is low, output confidence is low and the system recommends measurement, inspection, or community review rather than a strong security claim.

## Non-Compensation Gate

Calculate quality safety:

\[
WQ
=
\min
(
\mu_{\mathrm{adequate\_pH}},
\mu_{\mathrm{low\_turbidity}},
\mu_{\mathrm{microbial\_safe}},
\mu_{\mathrm{chemical\_safe}}
)
\]

Calculate service reliability:

\[
WS
=
\min
(
\mu_{\mathrm{reliable}},
\mu_{\mathrm{accessible}}
)
\]

Calculate governance resilience:

\[
WG
=
\mu_{\mathrm{strong\_governance}}
\]

The baseline score is:

\[
WSI_{\mathrm{base}}
=
100
\left(
0.50WQ
+
0.30WS
+
0.20WG
\right)
\]

Then apply a safety cap:

\[
WSI
=
Q_{c,t}
\cdot
\min
(
WSI_{\mathrm{base}},
\operatorname{SafetyCap}
)
\]

\[
\operatorname{SafetyCap}
=
\begin{cases}
20, & \mu_{\mathrm{microbial\_unsafe}} \ge 0.50 \\
20, & \mu_{\mathrm{chemical\_unsafe}} \ge 0.50 \\
40, & \mu_{\mathrm{high\_turbidity}} \ge 0.75 \land \mu_{\mathrm{microbial\_safe}} < 0.50 \\
100, & \text{otherwise}
\end{cases}
\]

This gate ensures that the score communicates a real public-health or water-quality concern even where reliability, access, and governance are strong.

## Score Bands

| WSI interval | Interpretation | Community-safe action |
|---|---|---|
| 0–20 | Critical | Activate public-health and emergency water protocols; publish accessible notice; do not rely on governance or access scores to downplay quality risk |
| 21–40 | Fragile | Increase monitoring, repair, treatment review, mutual-aid capacity, and accessible distribution planning |
| 41–60 | Stressed | Target the lowest components through a documented community action plan |
| 61–80 | Secure | Maintain monitoring, infrastructure upkeep, affordability, and accessible governance |
| 81–100 | Resilient | Sustain protections, publish lessons, and preserve community control and emergency readiness |

## Community Adjustment Process

A community can adapt the fuzzy system without losing comparability by maintaining two configurations:

- **Community profile:** locally selected membership breakpoints, indicators, and priorities.
- **Reference profile:** a stable regional or watershed profile used for cross-community comparison.

Every score report should include:

- Community profile version.
- Reference profile version.
- Input observations and units.
- Input data quality.
- Fired rules and their strengths.
- Safety-cap status.
- Component scores for quality, service access, and governance.
- Uncertainty and missing-data notes.
- Community-approved next actions.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.92 | Uses explicit water-quality, reliability, access, governance, uncertainty, fuzzy-membership, and non-compensation logic |
| eco_impact_value | 0.90 | Supports water safety, resilient distribution, repair prioritization, and community stewardship |
| harm_risk | 0.16 | Reduced through safety caps, explainable rules, local adaptation controls, and prohibition on using the index as a certification or exclusion tool |
| accessibility_impact | 0.96 | Treats affordability, physical access, communication access, emergency continuity, and non-digital access as core water-security conditions |
| rights_alignment | 0.98 | Protects community governance, data transparency, public health, non-discrimination, and meaningful local control |
