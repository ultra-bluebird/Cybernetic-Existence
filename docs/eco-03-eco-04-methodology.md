# ECO-03 and ECO-04 Methodology

## Purpose

ECO-03 and ECO-04 create transparent planning metrics for biodiversity connectivity and neighborhood-scale water resilience.

The standards are intentionally designed around aggregate landscape and infrastructure properties:

\[
\text{connectivity assessment}
\ne
\text{individual animal surveillance}
\]

\[
\text{water resilience assessment}
\ne
\text{individual household surveillance}
\]

ECO-03 evaluates whether habitat patches remain connected through a modeled resistance landscape. ECO-04 evaluates whether essential water needs can be supported through quality-adjusted local, redundant, and emergency water pathways.

Neither standard treats ecological benefit as permission to collect biometric data, track persons, monitor individual water behavior, require proprietary equipment, or create privileged service zones.

## ECO-03: Corridor Connectivity

### Core Metric

For any pair of qualifying habitat patches \(a\) and \(b\):

\[
C_{a,b}
=
\frac{1}{R_{\text{effective},a,b}}
\]

Where \(R_{\text{effective},a,b}\) is the effective landscape resistance between patches.

Circuit-theory landscape models represent habitat areas and movement pathways as a network of nodes and resistors. Landscape features influence resistance, and effective resistance provides a measure of functional separation between locations. [84]

For multiple evaluated patch pairs:

\[
C_{\text{corridor}}
=
\sum_{a < b}
\omega_{a,b}
\cdot
\frac{1}{R_{\text{effective},a,b}}
\cdot
S_{a,b}
\]

Where:

| Symbol | Meaning |
|---|---|
| \(R_{\text{effective},a,b}\) | Effective resistance between habitat patches \(a\) and \(b\) |
| \(\omega_{a,b}\) | Publicly documented patch-pair importance weight |
| \(S_{a,b}\) | Seasonal availability factor for the pathway and endpoint habitat |
| \(C_{\text{corridor}}\) | Aggregate corridor-connectivity score |
| \(C_{a,b}\) | Pair-level connectivity score |

For a season \(s\), the seasonal score is:

\[
C_s
=
\sum_{a < b}
\omega_{a,b}
\cdot
\frac{1}
{R_{\text{effective},a,b,s}}
\cdot
A_{a,s}
\cdot
A_{b,s}
\]

Annual or planning-period connectivity is:

\[
C_{\text{annual}}
=
\sum_{s \in \mathcal{S}}
\lambda_s C_s
\]

Subject to:

\[
\sum_{s \in \mathcal{S}} \lambda_s = 1
\]

This framework supports a circuit-theory implementation where a resistance raster is treated as a graph. The supplied TypeScript implementation uses a conservative least-resistance traversal as a dependency-light baseline. A production GIS workflow should replace or complement this baseline with a proper current-flow solver, current-density map, pinch-point analysis, and sensitivity-tested resistance surface.

### Resistance Surface

Each raster cell \(i\) receives a resistance value:

\[
R_i
=
R_{\min}
+
(R_{\max} - R_{\min})
\cdot
\operatorname{clamp}
\left(
w_l L_i +
w_f F_i +
w_d D_i +
w_b B_i +
w_q Q_i,
0,
1
\right)
\]

Where:

| Term | Meaning |
|---|---|
| \(L_i\) | Land-cover movement difficulty |
| \(F_i\) | Infrastructure friction, such as roads, rail corridors, fencing, lighting, or impermeable surface |
| \(D_i\) | Human disturbance intensity, represented only at aggregate landscape level |
| \(B_i\) | Barrier condition, including impassable structures, high-speed roads without crossings, canals without safe passage, or severe fragmentation |
| \(Q_i\) | Water, soil, vegetation, or habitat-condition penalty relevant to the corridor class |
| \(w_l,w_f,w_d,w_b,w_q\) | Non-negative, documented weights that sum to one |
| \(R_{\min},R_{\max}\) | Declared lower and upper resistance bounds |

A resistance surface is a raster representation of landscape movement cost. It assigns cells numerical values that reflect inferred willingness, ability, or success in crossing landscape conditions. [90][91]

### Calibration Without Telemetry

A no-tracking corridor model is calibrated through convergent evidence rather than individual movement histories.

| Evidence source | Permitted use | Privacy and ecological safeguard |
|---|---|---|
| Land cover and vegetation structure | Estimate habitat suitability, permeability, shade, food-web support, and restoration maturity | Use public, licensed, or community-governed spatial layers with provenance |
| Infrastructure and barrier inventories | Identify road, rail, canal, fence, lighting, and development barriers | Report at corridor or segment scale; do not map sensitive dens or nesting sites publicly |
| Local natural-history literature | Define movement-relevant landscape features for a target guild or ecological community | State applicability limits and uncertainty |
| Expert elicitation | Produce documented resistance ranges and scenario weights | Record assumptions, disagreement, and sensitivity bounds |
| Noninvasive occupancy survey | Validate relative use of habitat classes without identifying individuals | Use presence/absence or aggregated encounter counts |
| Environmental DNA | Confirm species or community occurrence in water or soil sampling areas | Aggregate reporting; protect sensitive locations |
| Acoustic monitoring | Validate broad presence patterns through aggregate detection rates | Do not publish raw sensitive-location coordinates |
| Remote camera summaries | Validate habitat use at aggregate intervals | Do not retain or publish person-identifying imagery; configure exclusion zones and retention limits |
| Habitat-condition field survey | Validate vegetation, water, substrate, shelter, and disturbance assumptions | Use repeatable protocols and quality flags |

The model must publish a resistance range rather than a single unstated “true” value when biological certainty is incomplete:

\[
R_i \in
[
R_i^{\text{low}},
R_i^{\text{high}}
]
\]

The resulting connectivity uncertainty interval is:

\[
C_{\text{corridor}}
\in
[
C_{\text{lower}},
C_{\text{upper}}
]
\]

Where \(C_{\text{lower}}\) is calculated from the more restrictive plausible resistance scenario and \(C_{\text{upper}}\) from the less restrictive scenario.

This avoids presenting expert judgment as hidden fact. It also allows restoration prioritization to favor actions that improve connectivity under both optimistic and conservative assumptions.

USGS research has applied circuit-theory structural connectivity using habitat and non-habitat thresholds and noninvasive feather-sample evidence, illustrating that connectivity evaluation can use noninvasive evidence rather than tracking every animal. [86]

### Minimum Habitat Patch Qualification

There is no universal minimum patch area because habitat value depends on ecosystem type, focal guild, edge sensitivity, food resources, water availability, connectivity role, and local conservation objectives.

ECO-03 therefore requires a documented local qualification rule:

\[
\text{qualifies}(p)
=
\mathbb{1}
[
A_p \ge A_{\min}
\land
A_{\text{core},p} \ge A_{\text{core,min}}
\land
H_p \ge H_{\min}
]
\]

Where:

| Term | Meaning |
|---|---|
| \(A_p\) | Total patch area |
| \(A_{\min}\) | Locally declared minimum qualifying area |
| \(A_{\text{core},p}\) | Area remaining after declared edge-buffer exclusion |
| \(A_{\text{core,min}}\) | Minimum core habitat area |
| \(H_p\) | Habitat quality score |
| \(H_{\min}\) | Minimum habitat-quality threshold |

A local plan must identify the ecological class for which the threshold is used, such as riparian bird habitat, pollinator stepping stones, desert wash connectivity, amphibian refuge, or a multi-species terrestrial permeability network.

A small patch may fail as a self-sustaining habitat block yet still qualify as a stepping stone. ECO-03 supports this distinction through separate patch classes:

- Core habitat: larger, high-quality, potentially persistent habitat area.
- Stepping-stone habitat: smaller, high-quality habitat that provides rest, refuge, food, water, or shelter between core areas.
- Corridor matrix: permeable landscape that supports passage but does not independently satisfy habitat-patch criteria.
- Barrier: landscape condition that is impassable or assigned very high resistance.

### Seasonal Migration Without Tracking

Seasonality changes the resistance surface, patch availability, and corridor importance:

\[
R_{i,s}
=
R_i
\cdot
m_{i,s}
\]

\[
C_{\text{annual}}
=
\sum_s \lambda_s C_s
\]

The seasonal multiplier \(m_{i,s}\) can encode aggregate conditions such as:

- Monsoon flow and wash passability
- Dry-season water availability
- Vegetation phenology and cover
- Extreme-heat refuge value
- Breeding-period disturbance buffers
- Seasonal road-use intensity
- Restoration maintenance windows
- Floodplain inundation or disconnection

The analysis does not require identifying any animal, collecting individual movement traces, or publishing sensitive occurrence locations. It measures landscape permeability by season and validates assumptions with aggregate, noninvasive evidence where available.

### Restoration Prioritization

For candidate restoration action \(j\):

\[
P_j
=
\frac{
\Delta C_{\text{lower},j}
\cdot
H_j
\cdot
F_j
}
{
K_j
+
R_j
}
\]

Where:

| Term | Meaning |
|---|---|
| \(\Delta C_{\text{lower},j}\) | Conservative lower-bound connectivity gain |
| \(H_j\) | Habitat-quality co-benefit |
| \(F_j\) | Feasibility and maintenance-readiness factor |
| \(K_j\) | Resource, implementation, and lifecycle-maintenance cost |
| \(R_j\) | Ecological, social, and displacement risk |

A project should not prioritize a corridor solely because the model returns a high score. It must also evaluate land stewardship, community effects, water availability, invasive-species risk, maintenance commitments, cultural governance, and uncertainty.

## ECO-04: Urban Water Autonomy Index

### Purpose

The Water Autonomy Index measures whether a neighborhood or service area can continue essential water functions through safe, quality-adjusted, locally diversified pathways during a disruption.

It is not a household ranking, a service-eligibility score, a surveillance system, or a justification to reduce universal utility obligations.

\[
\text{WAI}_{\text{essential}}
=
\frac{
D_{\text{harvest,q}}
+
D_{\text{greywater,q}}
+
D_{\text{recharge,q}}
+
D_{\text{redundancy,q}}
+
D_{\text{storage,q}}
}
{
D_{\text{essential,peak}}
}
\]

Where:

\[
D_{\text{essential,peak}}
=
D_{\text{essential}}
\cdot
f_{\text{peak}}
\]

For each source \(x\):

\[
D_{x,q}
=
D_x \cdot q_x
\]

Where \(q_x\) is a fit-for-purpose quality factor:

\[
0 \leq q_x \leq 1
\]

No source contributes to a potable or other essential-use autonomy claim unless its treatment, monitoring, storage, cross-connection control, and use class are verified as fit for that declared purpose.

### Source-Quality Factors

| Source | Example permitted role | Quality factor considerations |
|---|---|---|
| Rainwater harvesting | Irrigation, toilet flushing, cooling, cleaning, or potable use only under applicable treatment and verification conditions | Roof material, first-flush management, storage integrity, microbial controls, turbidity, chemical contamination, treatment reliability |
| Greywater recycling | Toilet flushing, irrigation, cooling, or other non-potable uses under applicable controls | Pathogen reduction, chemical constituents, salinity, storage duration, cross-connection controls, signage, operational reliability |
| Managed recharge | Aquifer replenishment, drought buffering, source diversification | Source-water quality, pretreatment, infiltration performance, groundwater quality, recovery pathway, ecological safeguards |
| Distribution redundancy | Alternate pressure zone, interconnection, backup source, emergency conveyance | Independence, isolation capability, pressure, energy availability, source quality, emergency operating capacity |
| Emergency storage | Short-duration essential continuity | Storage turnover, disinfection, container integrity, accessible distribution, replenishment logistics |

Water reuse can provide a reliable local source that augments groundwater and helps a community respond to drought, but the source and treatment requirements must remain fit for purpose. [82][92]

EPA’s reuse resources include rainwater, stormwater, air-conditioning condensate, greywater, and wastewater-derived sources, while applicable local and state rules govern the allowed end uses and treatment expectations. [87]

### Minimum Continuity Threshold

ECO-04 uses a two-tier public planning threshold.

| Band | Essential autonomy index | Meaning |
|---|---:|---|
| Insufficient | Below 0.50 | Local quality-adjusted pathways cannot sustain half of declared essential peak demand during the defined disruption window |
| Minimum continuity | 0.50 to below 0.80 | The area has partial continuity capacity but requires universal utility, mutual-aid, or emergency supplementation |
| Resilient | 0.80 to below 1.00 | Most declared essential peak demand can be served through safe diversified pathways, subject to outage duration and quality constraints |
| High resilience | At least 1.00 with redundancy factor of at least 0.80 | Quality-adjusted local and redundant supply can cover declared essential peak demand, with substantial independent-path readiness |

The 0.50 threshold is a planning floor, not a right to ration essential water or reduce universal service. The target for essential-service continuity is:

\[
\text{WAI}_{\text{essential}} \geq 1
\]

A community with lower WAI should receive investment, emergency support, repair, and resilience planning. It should not be categorized as less deserving of service.

### Redundancy

Water volume alone is insufficient. A system can have adequate nominal supply but fail through a single pump, treatment train, power connection, pressure zone, contaminated storage unit, transmission main, or communications dependency.

The redundancy factor is:

\[
F_{\text{redundancy}}
=
\frac{
b_1+b_2+b_3+b_4+b_5
}{5}
\]

Where each \(b_i\) equals one when the following controls are present:

- At least two meaningfully independent supply paths
- Single-point-failure assessment
- Isolation and containment capability
- Backup energy for critical water operations
- Emergency interconnection or mutual-aid pathway

EPA provides preparedness and resilience support for drinking-water and wastewater systems, including natural hazards, emergency response, contamination response, and related operational risks. [83]

### Equity and Universal Access

Water resilience must not create privileged autonomy zones. The following invariants apply:

\[
\text{essential service access}
=
\text{universal}
\]

\[
\text{private ownership}
\not\Rightarrow
\text{exclusive continuity}
\]

\[
\text{optional telemetry refusal}
\not\Rightarrow
\text{loss of water service}
\]

A WAI report is valid only if:

- Essential-service continuity is universal within the declared service area.
- A private rainwater, reuse, or storage system is not required to receive essential public water.
- Tenants, unhoused residents, residents of multifamily housing, non-owners, and people without private capital have equivalent access to resilience benefits.
- Emergency distribution is accessible and non-discriminatory.
- Cost burdens are analyzed and publicly addressed.
- Individual water-use surveillance is not required for access to water, cooling, sanitation, or emergency support.
- No biometric, neural, augmentation, or unrelated identity information is required for water access.

The implementation therefore treats equity failure as a non-reportable result rather than allowing high-resource neighborhoods to claim resilience while adjacent residents lose access.

## Validation and Reporting

### ECO-03 validation

- Preserve land-cover, infrastructure, disturbance, barrier, and habitat-quality provenance.
- Declare resistance classes, weights, uncertainty ranges, and seasonal multipliers before final scoring.
- Run sensitivity analysis across plausible resistance surfaces.
- Use independent ecological review.
- Validate with noninvasive aggregate evidence where feasible.
- Publish only aggregate outputs and protect sensitive habitat-location information.

### ECO-04 validation

- Measure source volumes using traceable aggregate meters or engineering estimates.
- Verify source quality for each declared end use.
- Model peak demand and disruption duration explicitly.
- Test pump, power, treatment, interconnection, storage, and isolation failures.
- Verify that local autonomy supplements rather than displaces universal essential-service duty.
- Publish limitations, expected outage duration, maintenance obligations, and unserved-demand scenarios.

## Metrics

| Metric | Score | Basis |
|---|---:|---|
| `knowledge_factor` | 0.92 | Structured spatial, hydrologic, quality, seasonal, redundancy, and sensitivity requirements support reproducible review |
| `eco_impact_value` | 0.93 | The artifacts guide habitat restoration, water reuse, recharge, redundancy, and climate resilience planning |
| `harm_risk` | 0.14 | Conservative quality factors, fail-closed reporting, no-tracking controls, and equity gates reduce ecological and social harm |
| `accessibility_impact` | 0.91 | Universal essential access, tenant inclusion, accessible outage support, and non-surveillance requirements are explicit |
| `rights_alignment` | 0.96 | The framework protects privacy, avoids exclusive service designs, supports community review, and preserves accountable public infrastructure |
