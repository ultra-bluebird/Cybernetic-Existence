# Architecting Safety: A Unified Corridor Ontology for Concurrently Protecting Human Health and Ecological Integrity at Contaminated Sites

## Purpose

This document specifies a dual-track corridor ontology for:

- PFAS fate, transport, exposure-pathway, treatment, and residual accounting.
- Indoor-outdoor environmental quality, comfort, ventilation, particle, heat, humidity, and operational-condition assessment.
- Shared evidence, provenance, uncertainty, accessibility, privacy, ecological integrity, and accountable-review controls.

The ontology supports evidence collection, environmental interpretation, uncertainty-aware planning, and human review. It does not grant authority to control treatment equipment, ventilation equipment, doors, pumps, relays, valves, or any other machinery.

## Core Decision Principle

A corridor conclusion is only as strong as its least-supported required boundary.

```text
A corridor may be observed when evidence is incomplete.
A corridor may be modeled when its assumptions and uncertainty are explicit.
A corridor may be reviewed when it has accountable provenance and applicable limits.
A corridor may not be accepted when a required boundary is unmodeled, expired, unsupported, or beyond its uncertainty limit.
A corridor conclusion may not issue a machinery command.
```

## Dual-Track Architecture

```text
PFAS Fate and Exposure Track
    source
    → transport
    → storage
    → transformation
    → receptor
    → treatment residual

Indoor-Outdoor Environmental Quality Track
    outdoor condition
    → intake, opening, or transition zone
    → indoor condition
    → occupant-facing or habitat-facing receptor
    → filtration, maintenance, or residual pathway

Shared Evidence Layer
    provenance
    calibration
    uncertainty
    data freshness
    KER accountability
    privacy classification
    accessibility explanation
    human review
```

The tracks share evidence infrastructure but retain their scientific identities.

```text
PFAS mass residuals are not thermal-comfort metrics.
CO2, temperature, humidity, PM, and VOC screening signals are not PFAS concentration measurements.
A favorable comfort value does not eliminate a PFAS pathway.
A PFAS detection does not diagnose an individual or determine a person’s health status.
```

## Corridor Definition

A corridor is a directed, bounded, evidence-linked graph:

\[
\mathcal{C}
=
(
\mathcal{S},
\mathcal{B},
\mathcal{X},
\mathcal{O},
\mathcal{U},
\mathcal{P},
\mathcal{R}
)
\]

Where:

- \(\mathcal{S}\) is the set of segments.
- \(\mathcal{B}\) is the set of directed boundaries.
- \(\mathcal{X}\) is the set of materials, stressors, energy flows, or environmental variables.
- \(\mathcal{O}\) is the set of observations and estimates.
- \(\mathcal{U}\) is the uncertainty record set.
- \(\mathcal{P}\) is the provenance and accountability record set.
- \(\mathcal{R}\) is the receptor and protection-objective set.

Each boundary is:

\[
B_{i \rightarrow j}
=
(
S_i,
S_j,
X,
m,
p,
\tau,
q,
\Pi,
U,
L,
D
)
\]

Where:

- \(S_i\) is the upstream segment.
- \(S_j\) is the downstream segment.
- \(X\) is the tracked material, stressor, energy flow, or environmental variable.
- \(m\) is the medium.
- \(p\) is the relevant phase.
- \(\tau\) is the time-validity interval.
- \(q\) is the quantity, rate, concentration, or state value.
- \(\Pi\) is the provenance record.
- \(U\) is the uncertainty model.
- \(L\) is a site-approved limit, threshold, or decision boundary.
- \(D\) is the resulting evidence status and review decision.

## Segment Vocabulary

### SOURCE

A source is a segment where a material, stressor, energy flow, or precursor enters the modeled corridor.

```text
Examples:
- legacy PFAS-affected soil
- aqueous film-forming foam use area
- drinking-water source
- imported fill
- stormwater inlet
- indoor cleaning product use
- outdoor traffic-adjacent particulate source
- heat-emitting paved surface
```

Required fields:

```text
release mechanism
source strength estimate or range
source strength unit
source activity or condition
measurement or estimate method
source time interval
provenance reference
uncertainty record
```

### TRANSPORT

A transport segment represents movement through media, equipment, openings, or environmental pathways.

```text
Examples:
- groundwater advection
- surface-water flow
- soil-to-dust entrainment
- tracked-in dust
- outdoor-to-indoor infiltration
- supply-air intake
- door opening exchange
- drainage conveyance
- pipe flow
```

Required fields:

```text
transport mechanism
transport direction
flow, velocity, or exchange estimate
unit
travel-time estimate
medium
phase
environmental conditions
provenance reference
uncertainty record
```

### STORAGE

A storage segment is a location or medium that retains, accumulates, sorbs, settles, delays, or concentrates material.

```text
Examples:
- sediment bed
- soil matrix
- indoor dust reservoir
- HVAC filter
- granular activated carbon
- ion-exchange media
- membrane concentrate tank
- equalization basin
- green-wall substrate
```

Strict interpretation:

```text
Storage is not destruction.
Sorption is not mineralization.
Capture is not final disposition.
A stored material remains in the corridor until transfer, verified destruction, or another separately modeled endpoint is evidenced.
```

### TRANSFORMATION

A transformation segment represents a material changing chemical form, physical form, mobility, availability, or measurement identity.

```text
Examples:
- PFAS precursor conversion
- parent-to-product transformation
- partitioning between water and sediment
- photochemical transformation
- biological transformation
- thermal treatment process
- indoor pollutant dilution or reactive loss
```

Required fields:

```text
parent material or prior state
product material or subsequent state
mechanism
rate estimate or bounded range
method reference
evidence quality
uncertainty record
```

Strict interpretation:

```text
Transformation must not be inferred from disappearance alone.
A declining parent concentration may represent transport, dilution, sorption, sampling variability, or conversion to another compound.
```

### RECEPTOR

A receptor is a protected ecological, community, infrastructure, or public-service endpoint.

```text
Examples:
- wetland habitat
- aquatic habitat
- soil organism community
- drinking-water fixture
- food-preparation area
- community hub entrance
- indoor gathering space
- accessible rest area
- maintenance worker access zone
- ventilation intake
```

Required fields:

```text
receptor category
potential exposure or contact pathway
protection objective
time horizon
accessibility relevance
review authority
evidence status
```

Strict interpretation:

```text
Receptors are protected endpoints, not eligibility categories.
Receptor records must not infer identity, diagnosis, disability, behavior, or demographic characteristics.
```

### TREATMENT_RESIDUAL

A treatment residual is a material that remains, concentrates, separates, is captured, or is generated after treatment or maintenance.

```text
Examples:
- spent granular activated carbon
- used ion-exchange resin
- membrane concentrate
- spent filter cartridge
- filter dust
- vacuum bag contents
- sludge
- regeneration brine
- contaminated wash water
```

Required fields:

```text
upstream treatment process
residual form
residual quantity or bounded estimate
residual quantity unit
containment status
handling route
transfer evidence
final disposition evidence
review status
```

Strict interpretation:

```text
Treatment residuals are active corridor segments.
The material remains accountable after capture.
No system may report PFAS destruction from adsorption, ion exchange, filtration, settling, or storage alone.
```

## PFAS Corridor Priority Rules

PFAS corridors are prioritized by pathway completeness, source-to-receptor plausibility, uncertainty, evidence freshness, and availability of protective action.

\[
P_c
=
w_1 C_c
+
w_2 R_c
+
w_3 X_c
+
w_4 U_c
+
w_5 T_c
\]

Where:

- \(C_c\) is pathway completeness or plausibility.
- \(R_c\) is receptor protection urgency.
- \(X_c\) is source strength or potential loading evidence.
- \(U_c\) is uncertainty burden.
- \(T_c\) is time sensitivity.
- \(w_i\) are transparent site-governed weights with \(\sum_i w_i = 1\).

Priority ranking is a resource-allocation tool only. It must not be used to deny protection to lower-ranked receptors or to treat unmeasured pathways as absent.

### Priority 1: Source-to-Indoor Dust

Activate when PFAS-affected soil, construction dust, outdoor dust, tracked-in material, indoor dust reservoirs, or particulate-bearing entry pathways are plausible.

```text
Required evidence:
- source and land-use history
- soil and dust pathway map
- entryway, floor, and cleaning review
- HVAC filter maintenance record
- surface-wipe or dust sampling plan where authorized
- treatment-residual branch for captured dust and spent filters
```

### Priority 2: Source-to-Water-to-Use

Activate when drinking water, food preparation, handwashing, irrigation, on-site wells, cisterns, storage tanks, or treatment devices could connect a source to hub use.

```text
Required evidence:
- water-source inventory
- fixture and use map
- point-of-use and point-of-entry treatment map
- analyte and method plan
- water-use exposure pathway classification
- treatment-residual branch for all captured materials
```

### Priority 3: Outdoor Particle to Indoor Environment

Activate when outdoor particle sources, contaminated dust, intakes, doorways, windows, traffic, industrial activity, dust events, wildfire smoke, or construction create a plausible transport path.

```text
Required evidence:
- outdoor PM measurement or screening plan
- wind direction and speed evidence
- intake, door, and opening map
- indoor-outdoor time-aligned comparison
- HVAC filter type and maintenance state
- meteorological and event record
```

### Priority 4: Short-Chain Mobility

Activate when site evidence supports dissolved-phase mobility, groundwater transport, surface-water transport, irrigation, wash-water, or water-treatment pathways involving relevant compounds.

```text
Required evidence:
- target analyte list appropriate to known source history
- water, soil, sediment, and groundwater pathway evidence
- vertical and temporal sampling plan where relevant
- transport-model assumptions
- treatment-media performance evidence
- uncertainty interval for travel-time and concentration estimates
```

### Priority 5: Cold-Survival Residual

Activate only when low temperature materially affects a declared PFAS fate, transport, storage, treatment, or residual mechanism.

```text
Required evidence:
- water, sediment, soil, or equipment temperature record
- seasonal hydrology or operational temperature state
- cold-period sampling or model-validation plan
- site-specific explanation of why temperature affects the declared pathway
```

Cold-survival analysis remains separate from routine human thermal comfort unless a physical corridor explicitly connects a cold system to the relevant environmental medium.

### Priority 6: Transformation and Precursor

Activate when source history, analytical results, or environmental conditions support precursor transformation or a changing PFAS profile.

```text
Required evidence:
- parent and product analyte list
- target-plus-precursor analytical design
- method limitation statement
- transformation pathway hypothesis
- time-series or spatial evidence
- uncertainty declaration
```

A Total Oxidizable Precursor assay may be a useful supplementary line of evidence because it converts oxidizable precursors into measurable terminal compounds. It does not replace targeted PFAS analysis, and its design, matrix effects, recovery behavior, and interpretation must be disclosed.

### Priority 7: Treatment Residual

Activate for every treatment, filtration, separation, dust capture, or maintenance process.

```text
Required evidence:
- influent quantity or concentration
- treated effluent quantity or concentration
- captured or separated residual quantity
- residual containment status
- transport and transfer record
- final disposition evidence
- residual uncertainty statement
```

## PFAS Mass and Residual Accounting

For a declared PFAS segment:

\[
R_{t+1}
=
R_t
+
L_t
+
X_t
+
B_t
-
A_t
-
M_t
+
\varepsilon_t
\]

Where:

- \(R_t\) is the retained PFAS inventory at time \(t\).
- \(L_t\) is mass loading received from an upstream segment.
- \(X_t\) is a separately evidenced additional source or transformation-product input.
- \(B_t\) is a bounded correction term with explicit physical definition.
- \(A_t\) is an evidenced transfer from the segment to another modeled segment.
- \(M_t\) is verified destruction or irreversible removal only when supported by appropriate evidence.
- \(\varepsilon_t\) is the unresolved mass-balance residual.

Strict invariants:

```text
B_t must have a physical definition, unit, evidence reference, and uncertainty basis.
A_t must identify the downstream segment and transfer evidence.
M_t must not include adsorption, filtration, ion exchange, storage, dilution, sedimentation, or transfer.
A non-zero residual ε_t remains an evidence gap or model discrepancy until investigated.
A mass balance must not be closed by silently assigning residual mass to destruction.
```

The mass-balance closure test is:

\[
\left|
\varepsilon_t
\right|
+
U_{\varepsilon,t}
\le
L_{\varepsilon,t}
\]

Where:

\[
U_{\varepsilon,t}
=
k
\cdot
u_c
\left(
\varepsilon_t
\right)
\]

If the residual exceeds the approved limit:

```text
HOLD_FOR_REVIEW
```

## Uncertainty Model

For an output measurand:

\[
y
=
f
\left(
x_1,
x_2,
\ldots,
x_n
\right)
\]

The general first-order propagation model is:

\[
u_c^2(y)
=
\sum_{i=1}^{n}
\left(
\frac{\partial f}{\partial x_i}
\right)^2
u^2(x_i)
+
2
\sum_{i=1}^{n-1}
\sum_{j=i+1}^{n}
\left(
\frac{\partial f}{\partial x_i}
\right)
\left(
\frac{\partial f}{\partial x_j}
\right)
u(x_i,x_j)
\]

Where:

- \(u(x_i)\) is the standard uncertainty for input \(x_i\).
- \(u(x_i,x_j)\) is covariance between inputs \(x_i\) and \(x_j\).
- Correlation must be considered when shared calibration, shared source assumptions, synchronized sensors, common environmental forcing, or reused model parameters create dependence.

When inputs are demonstrably independent and all sensitivity coefficients equal one:

\[
u_c
=
\sqrt{
u_{\mathrm{measurement}}^2
+
u_{\mathrm{sampling}}^2
+
u_{\mathrm{model}}^2
+
u_{\mathrm{spatial}}^2
+
u_{\mathrm{temporal}}^2
}
\]

Expanded uncertainty is:

\[
U
=
k
\cdot
u_c
\]

The coverage factor \(k\), intended coverage probability, distributional assumptions, and degrees-of-freedom method must be reported.

Required uncertainty fields:

```text
measurement uncertainty
sampling uncertainty
calibration uncertainty
model uncertainty
spatial representativeness uncertainty
temporal alignment uncertainty
data-processing uncertainty
covariance or independence assumption
coverage factor
coverage probability
method reference
calculation timestamp
evidence expiry
```

## Boundary Acceptance Rule

A boundary is eligible for an evidence-supported conclusion only when:

\[
\left|
\varepsilon_{ij,t}
\right|
+
U_{ij,t}
\le
L_{ij}
\]

And:

\[
\mathrm{EvidenceCurrent}
\land
\mathrm{CalibrationCurrent}
\land
\mathrm{ProvenancePresent}
\land
\mathrm{RequiredFieldsPresent}
\land
\mathrm{ReviewAvailable}
\]

The final state is:

\[
\mathrm{BoundaryStatus}
=
\begin{cases}
\texttt{ACCEPT}, &
\text{if all evidence and conservative residual conditions hold} \\
\texttt{OBSERVE\_WITH\_UNCERTAINTY}, &
\text{if data are current but insufficient for acceptance} \\
\texttt{HOLD\_FOR\_REVIEW}, &
\text{if a required boundary is unmodeled, expired, incomplete, or exceeds its limit} \\
\texttt{ESCALATE\_TO\_ACCOUNTABLE\_AUTHORITY}, &
\text{if an applicable health, environmental, safety, accessibility, or community protection condition requires review}
\end{cases}
\]

## Indoor-Outdoor Environmental Quality Track

The indoor-outdoor track may monitor:

```text
air temperature
relative humidity
mean radiant temperature
wind or local air movement
carbon dioxide
particulate matter
VOC screening signals
solar radiation
door and opening state
filter state
noise level where privacy requirements are satisfied
```

It must not infer PFAS concentration, PFAS dose, human diagnosis, disability, identity, behavior, or individual health state without a separate valid evidence pathway.

For normalized environmental state vectors:

\[
\widetilde{x}
=
\operatorname{clamp}
\left(
\frac{x-x_{\mathrm{target}}}
{x_{\mathrm{scale}}},
-1,
1
\right)
\]

The indoor-outdoor discontinuity is:

\[
D_{IO,t}
=
\sqrt{
\sum_{j \in \mathcal{J}}
w_j
\left(
\widetilde{V}_{\mathrm{indoor},j,t}
-
\widetilde{V}_{\mathrm{outdoor},j,t}
\right)^2
}
\]

The transition-zone buffering value is:

\[
G_{\mathrm{transition},t}
=
D_{IO,t}
-
\frac{
D_{\mathrm{indoor}\rightarrow\mathrm{transition},t}
+
D_{\mathrm{transition}\rightarrow\mathrm{outdoor},t}
}{2}
\]

A positive buffering value indicates smoother measured environmental transition under the declared conditions. It does not establish universal comfort, health status, or individual tolerance.

## Receptor Protection Rule

Receptors are protected concurrently. A favorable ecological score cannot offset a human occupancy concern, and a favorable indoor comfort score cannot offset an ecological discharge, residual, or habitat burden.

\[
\mathrm{ProtectiveReviewRequired}
\Longleftrightarrow
\exists r
\in
\{
\mathrm{human},
\mathrm{ecological},
\mathrm{infrastructure},
\mathrm{community}
\}
:
\mathrm{PlausibleOrCompletedPathway}(r)
\land
\mathrm{BoundaryNotAcceptable}(r)
\]

Where applicable, the more protective valid requirement governs the recommendation.

```text
Human occupancy zones are physical and functional receptors, not demographic categories.
Ecological receptors are protected endpoints, not optional co-benefits.
Community governance is an active receptor class for transparency, dignity, accessibility, and review.
```

## KER Accountability Record

Every corridor finding requires:

```text
knowledge_reference
ecological_rationale
review_authority_reference
review_due_utc
evidence_quality
uncertainty_status
privacy_class
accessibility_impact
actionability_status
```

The governance score is:

\[
E_{\mathrm{governed}}
=
K
\cdot
V
\cdot
(1-R)
\]

Where:

- \(K\) is evidence quality, completeness, calibration, freshness, and reproducibility.
- \(V\) is the ecological and community value of the finding.
- \(R\) is residual harm risk from uncertainty, privacy, accessibility, misuse, or operational consequences.

## AI-Chat Research Functions

The following functions can be performed through structured AI-chat reasoning without field actuation.

```text
classify_corridor_pathway(
  source,
  transport,
  storage,
  transformation,
  receptor,
  treatment_residual,
  evidence
) -> COMPLETED | POTENTIAL | ELIMINATED | UNMODELED

identify_missing_boundary_evidence(
  corridor_graph,
  required_fields
) -> evidence_gap_register

propagate_uncertainty(
  measurand_definition,
  input_uncertainties,
  covariance_assumptions,
  coverage_factor
) -> uncertainty_report | NOT_CALCULATED

evaluate_boundary_status(
  residual,
  expanded_uncertainty,
  approved_limit,
  evidence_freshness,
  review_status
) -> ACCEPT | OBSERVE_WITH_UNCERTAINTY | HOLD_FOR_REVIEW

separate_claim_domains(
  pfas_evidence,
  indoor_outdoor_evidence
) -> claim_scope_matrix

construct_treatment_residual_branch(
  treatment_process,
  influent,
  effluent,
  captured_material,
  disposition_evidence
) -> residual_corridor_graph

generate_accessible_summary(
  corridor_status,
  uncertainty,
  evidence_gaps,
  review_route
) -> plain_language_summary

build_research_request_list(
  unverified_requirements,
  source_priority,
  responsible_review_role
) -> ordered_research_plan
```

## AI-Chat Output Contract

Every AI-generated research response must contain:

```text
decision status
scope and boundaries
evidence versus inference distinction
pathway classification
uncertainty status
missing evidence
applicable receptor classes
treatment-residual status
privacy and accessibility constraints
human-review requirement
specific next research artifact
```

Every calculated output must include:

```text
formula
input values
input units
input evidence source
assumptions
covariance or independence assumption
coverage factor
uncertainty result
validity interval
interpretation limit
```

If inputs are missing:

```text
NOT CALCULATED: required inputs missing.
```

## Strict Invariants

```text
No unmodeled boundary is accepted.
No expired evidence is accepted.
No unknown quantity is assumed favorable.
No sensor-screening value is represented as laboratory confirmation.
No PFAS mass transfer is described as destruction without sufficient evidence.
No treatment residual disappears from the corridor graph.
No comfort metric is represented as a contaminant measurement.
No ecological benefit offsets a human-protection requirement.
No human-protection claim offsets an ecological-residual requirement.
No personal identity, biometric, health, or behavioral telemetry is required.
No optional access profile is required to receive essential services.
No AI-chat output may command or silently control machinery.
No recommendation overrides fire, life-safety, accessibility, minimum-ventilation, or accountable human-review requirements.
```

## Completion Objectives

### Objective A: Corridor Registry

Create a complete registry of corridor segments and boundaries.

Completion evidence:

```text
All segment types validate.
All boundaries have upstream and downstream references.
All boundaries have provenance and uncertainty fields.
All treatment segments have an effluent or treatment-residual branch.
All receptors have protection objectives and review authority.
```

### Objective B: PFAS Evidence Matrix

Create a source-to-receptor evidence matrix.

Completion evidence:

```text
Every PFAS corridor is classified as COMPLETED, POTENTIAL, ELIMINATED, or UNMODELED.
Every classification includes a factual basis and uncertainty statement.
Every potential or completed treatment pathway includes a residual branch.
```

### Objective C: Shared Uncertainty Kernel

Create a common uncertainty model for laboratory, field, sensor, and model outputs.

Completion evidence:

```text
Each calculation states the measurand and inputs.
Each input has a standard uncertainty or a documented unknown status.
Covariance assumptions are declared.
Coverage factor and intended coverage probability are declared.
Outputs fail closed when uncertainty cannot be calculated.
```

### Objective D: AI-Chat Evidence Interface

Create a structured, accessible chat interface for research synthesis.

Completion evidence:

```text
The interface separates facts, estimates, and unknowns.
The interface produces pathway tables and evidence-gap registers.
The interface refuses to overstate unverified PFAS, health, comfort, or treatment claims.
The interface offers a plain-language review summary.
The interface contains no actuator command capability.
```

## Metrics

- knowledge_factor: 0.91
- eco_impact_value: 0.92
- harm_risk: 0.13
- accessibility_impact: 0.94
- rights_alignment: 0.97

## Metric Basis

Knowledge quality is high because the ontology uses explicit pathway, provenance, uncertainty, and residual-accounting structures; site-specific inputs remain required for any location-specific conclusion.

Ecological value is high because the framework prevents treatment-residual disappearance, improves contamination-pathway discovery, and supports accountable restoration decisions.

Residual harm risk is bounded by the non-actuating design, conservative evidence rules, uncertainty propagation, receptor non-tradeoff rule, and required human review.

Accessibility impact is high because status outputs are plain-language, uncertainty-visible, non-identifying, and designed for accessible review pathways.

Rights alignment is high because the ontology prohibits surveillance, identity-based service conditions, opaque actuation, false certainty, and ecological tradeoffs that diminish human dignity or access.
