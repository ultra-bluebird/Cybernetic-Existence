# ECO-01 and ECO-02 Methodology

## Purpose

This specification provides a rigorous basis for two ecological-accounting functions.

- ECO-01: Verified avoided-impact claims for restorative, energy-aware, and ecological workloads.
- ECO-02: Aggregate Heat-Island Recovery Index reporting for urban cooling interventions.

The standard distinguishes:

\[
\text{observed improvement}
\ne
\text{causally verified avoided impact}
\]

A workload may report observed conditions, model outputs, or provisional estimates. It may use the phrase `verified avoided impact` only when it satisfies every required causal, uncertainty, data-quality, temporal, and independent-review condition.

## ECO-01 Claim Classes

| Claim class | Permitted statement | Minimum evidence |
|---|---|---|
| `verified_avoided_impact` | “Verified avoided impact of at least \(C_{\text{avoided,lower}}\) units over the stated period.” | Accepted causal design, pre-registration, conservative lower confidence bound above zero, independent review, minimum observation period, complete data-quality controls |
| `provisional_estimate` | “Provisional modeled or measured estimate; not verified avoided impact.” | An explicit baseline, a reproducible method, uncertainty disclosure, and limitations statement |
| `no_credit_claimed` | “No avoided-impact credit is claimed.” | Required when evidence is missing, causal identification is unsupported, or the lower confidence bound is zero |

No project may convert `provisional_estimate` or `no_credit_claimed` values into offsets, credits, performance guarantees, procurement claims, or public marketing statements that imply verification.

## Verified Avoided Impact

The conservative claimable amount is:

\[
C_{\text{avoided,lower}}
=
\max \left(
0,
\hat{C}_{\text{avoided,adjusted}}
-
z_{\alpha}\sigma_{\text{avoided}}
\right)
\]

Where:

\[
\hat{C}_{\text{avoided,adjusted}}
=
\hat{C}_{\text{gross}}
\cdot
(1-d_{\text{additionality}})
\cdot
(1-d_{\text{leakage}})
\cdot
(1-d_{\text{rebound}})
\cdot
(1-d_{\text{reversal}})
\cdot
(1-d_{\text{data}})
\]

Terms are defined as follows.

| Symbol | Meaning |
|---|---|
| \(\hat{C}_{\text{gross}}\) | Estimated intervention effect before conservatism discounts |
| \(d_{\text{additionality}}\) | Discount for the likelihood that observed benefit would have occurred without the intervention |
| \(d_{\text{leakage}}\) | Discount for displaced impacts outside the measured project boundary |
| \(d_{\text{rebound}}\) | Discount for behavior, operational, or market effects that offset the benefit |
| \(d_{\text{reversal}}\) | Discount for future loss of a claimed ecological benefit |
| \(d_{\text{data}}\) | Discount for incomplete coverage, calibration limits, data gaps, or measurement uncertainty beyond the modeled standard error |
| \(z_{\alpha}\) | One-sided normal critical value; minimum \(1.645\) for a 90 percent lower confidence bound |
| \(\sigma_{\text{avoided}}\) | Standard error or equivalent uncertainty measure from a pre-specified analytic method |

The lower bound is never negative. If the lower bound is zero, the system reports zero verified avoided impact even when the point estimate is positive.

This structure operationalizes the conservative-counterfactual discipline used in avoided-emissions reporting: a baseline must be documented, comparable by functional unit and boundary, and adjusted for whether the effect is genuinely attributable to the intervention rather than expected anyway. [79]

## Required Evidence

| Requirement | Minimum standard | Verification result if absent |
|---|---|---|
| Causal identification | Randomized, stepped-wedge, difference-in-differences, interrupted time series, regression discontinuity, pre-specified matched control, or externally validated mechanistic model | No verified claim |
| Counterfactual baseline | Same functional unit and lifecycle or project boundary, with conservative selection rule | No verified claim |
| Additionality | Evidence that the improvement was not mandated, inevitable, or already fully adopted in the counterfactual | No verified claim |
| Leakage and rebound | Pre-specified assessment and conservative discount where relevant | No verified claim |
| Uncertainty bound | One-sided 90 percent lower confidence bound or more conservative bound | No verified claim |
| Pre-registration | Protocol, outcome, covariates, exclusion rules, uncertainty approach, and stopping rule set before outcome analysis | No verified claim |
| Independent review | Methods, calibration, data quality, and results reviewed by an external party with disclosed conflicts | Provisional only |
| Temporal scope | At least 90 observed days unless the protocol explicitly requires a longer ecological maturation interval | Provisional only |
| Data completeness | At least 90 percent planned coverage, at least 90 percent calibration coverage, and no more than 10 percent unaddressed missingness | No verified claim |
| Public limitations | Plain-language account of causal assumptions, exclusions, uncertainty, and non-measured harms | No verified claim |

Electronic validation and verification checks are a useful operational model for reproducible reporting controls, though this standard extends those checks with causal, ecological, and rights-centered requirements. [69]

## Causal Designs

### Experimental designs

The strongest designs are randomized, cluster-randomized, or stepped-wedge deployments when they are ethically appropriate and do not deny essential protections or ecological safeguards.

- A stepped-wedge design is useful when a cooling intervention is installed in phases, because all participating sites can ultimately receive the intervention while rollout timing produces a measurable comparison.
- Cluster randomization may work for voluntary non-essential pilot programs, such as distribution of reflective surface materials, but must not condition access to essential services or environmental protections on study assignment.
- Randomized encouragement designs can evaluate participation supports while keeping core environmental benefits available to all eligible communities.

### Quasi-experimental designs

Where randomization is not suitable, credible alternatives include:

- Difference-in-differences with pre-specified treated and comparison areas, parallel-trend diagnostics, and spatial spillover analysis.
- Interrupted time series with enough pre- and post-intervention observations to distinguish intervention change from weather variability, policy changes, or long-term trends.
- Regression discontinuity when eligibility follows a pre-existing threshold and manipulation around that threshold is assessed.
- Matched controls using pre-specified covariates, demonstrated balance, and sensitivity analysis for unobserved confounding.
- Mechanistic models only when externally validated against field measurements and uncertainty is propagated through all inputs.

A purely correlational comparison, before-and-after average, unvalidated simulation, or selective photograph cannot support a verified avoided-impact statement.

## Suitable Intervention Classes

| Intervention | Candidate avoided impact | Strongest practical design | Key measurement concerns |
|---|---|---|---|
| Cool roofs and cool pavements | Reduced surface temperature, reduced cooling electricity demand, reduced heat exposure | Difference-in-differences, stepped-wedge, calibrated building or microclimate model | Albedo aging, maintenance, roof geometry, energy rebound, changing occupancy |
| Urban canopy restoration | Avoided heat exposure, reduced cooling demand, avoided stormwater runoff, habitat gains | Phased rollout, matched corridors, interrupted time series | Tree survival, irrigation burden, canopy maturity lag, species suitability, displacement of existing habitat |
| Shade structures and transit cooling | Reduced radiant heat exposure at public waiting areas | Stepped-wedge or matched-stop comparison | Usage is not required for measurement; measure environmental conditions, not people |
| Green roofs and vegetated surfaces | Reduced rooftop temperature, runoff, cooling demand, habitat support | Paired roof comparison plus calibrated energy model | Irrigation, substrate lifecycle, vegetation survival, structural constraints |
| Building retrofits | Avoided electricity demand and associated emissions | Metered treatment-control or pre-registered building model | Weather normalization, occupancy-independent baselines, equipment interactions |
| Water-efficiency and leak reduction | Avoided water withdrawal, pumping energy, treatment energy | Metered before-after with matched pressure zones or interrupted time series | Meter calibration, pressure changes, unobserved leaks, service equity |
| Material recovery and repair | Avoided virgin material demand and waste | Material-flow accounting with a conservative displacement ratio | Functional equivalence, repair durability, transport, rebound purchasing |
| Habitat connectivity restoration | Avoided fragmentation risk and ecological degradation | BACI design, matched reference sites, validated connectivity models | Slow colonization, disturbance history, species-specific response, non-target impacts |
| Wetland, riparian, or bioswale restoration | Avoided pollutant loads, runoff, flood exposure, habitat loss | Flow-weighted paired monitoring, BACI, watershed model validated to observations | Seasonal flows, upstream sources, maintenance, storm-event sampling |

Cool roofs are a particularly tractable early class because solar reflectance, or albedo, has a direct thermophysical relationship to absorbed solar energy, and EPA notes that cool roofs can reduce roof, indoor, and surrounding air temperatures while reducing air-conditioning use. [67][72]

EPA also identifies trees, vegetation, green roofs, cool roofs, and cool pavements as established urban heat-island mitigation strategies. [70][74]

## Decades-Scale Impacts

Long-lived effects require separation between measurement and projection.

\[
C_{\text{claimable}}(t)
=
C_{\text{observed,lower}}(0,t_0)
+
\sum_{\tau=t_0+1}^{T}
\delta(\tau)
\cdot
p_{\text{persistence}}(\tau)
\cdot
C_{\text{projected,lower}}(\tau)
\]

Where:

| Term | Meaning |
|---|---|
| \(t_0\) | End of the directly observed period |
| \(T\) | Projection horizon |
| \(\delta(\tau)\) | Declared temporal discount or conservatism factor |
| \(p_{\text{persistence}}(\tau)\) | Probability or lower-bound persistence factor for the intervention benefit |
| \(C_{\text{projected,lower}}(\tau)\) | Lower-bound projection from a validated model |

The reporting rule is:

- Directly observed benefits may be reported as verified only for the observed period.
- Future benefits must be labeled `modeled future estimate` until they are observed and independently reviewed.
- A long-horizon verified claim requires an explicit reversal-risk model, maintenance plan, monitoring schedule, and periodic re-verification.
- No benefit beyond the last verified monitoring interval may be counted as current verified credit.
- Ecological maturation should be reported as a trajectory with uncertainty, not as an immediate full-performance assumption.

For example, newly planted canopy may create early shade benefits, but mature-canopy projections over decades must include mortality, drought, irrigation, heat stress, pests, maintenance failure, replacement rates, and land-use change. A conservative system therefore credits initial observed cooling separately from modeled mature-canopy potential.

## Minimum Data Quality

A claim qualifies for verified avoided impact only when all of the following apply:

- At least 90 percent of pre-specified temporal observations are available after quality control.
- At least 90 percent of instruments, remote-sensing products, or modeled inputs have documented calibration, validation, or traceability evidence appropriate to the metric.
- Unresolved missingness is no more than 10 percent of planned observations.
- Units, timestamps, spatial reference, sensor placement, maintenance history, and quality flags are preserved.
- The uncertainty method reflects serial correlation, clustering, spatial autocorrelation, and model-input uncertainty where applicable.
- Data-quality degradation can only reduce or eliminate ecological credit; it cannot increase a claim.

The data-quality discount is:

\[
D_{\text{data}}
=
\min
\left(
1,
d_{\text{coverage}}
+
d_{\text{calibration}}
+
d_{\text{missingness}}
+
d_{\text{model}}
\right)
\]

And the claim adjustment is:

\[
\hat{C}_{\text{adjusted}}
=
\hat{C}_{\text{gross}}
(1-D_{\text{data}})
\]

This preserves a fail-conservative invariant:

\[
\frac{\partial C_{\text{avoided,lower}}}
{\partial \sigma_{\text{avoided}}}
\leq 0
\]

More uncertainty cannot increase verified avoided impact.

## ECO-02: HIRI Definition

HIRI measures progress toward a publicly declared urban heat-recovery target. It is not a measure of individual resilience, personal behavior, health status, economic value, property value, or service eligibility.

\[
\text{HIRI}
=
w_c C
+
w_a A
+
w_w W
+
w_v V
+
w_t T
\]

Subject to:

\[
w_c+w_a+w_w+w_v+w_t=1
\]

\[
0 \leq C,A,W,V,T \leq 1
\]

\[
0 \leq \text{HIRI} \leq 1
\]

Each component is normalized against a baseline and a target:

\[
S_x
=
\operatorname{clamp}
\left(
\frac{x_{\text{current}}-x_{\text{baseline}}}
{x_{\text{target}}-x_{\text{baseline}}},
0,
1
\right)
\]

Where \(x\) is the raw metric for the component and `clamp` restricts results to the closed interval \([0,1]\).

A HIRI report also publishes a confidence factor:

\[
\text{HIRI}_{\text{reported}}
=
\text{HIRI}_{\text{raw}}
\cdot
Q_{\text{measurement}}
\cdot
Q_{\text{season}}
\cdot
Q_{\text{spatial}}
\]

This prevents high index scores from being reported with weak measurement evidence.

## HIRI Components

| Component | Raw measurement | Normalized direction | Public reporting guidance |
|---|---|---|---|
| \(C\): Canopy | Percent effective canopy cover, shade coverage, or leaf-area proxy within the reporting unit | Higher canopy toward locally declared target increases score | Report canopy survival and seasonal leaf condition; distinguish planted from established canopy |
| \(A\): Albedo | Area-weighted solar reflectance improvement of roofs, pavements, and surfaces | Higher verified reflectance improvement increases score | Include surface aging, soiling, maintenance, and replacement effects |
| \(W\): Water features | Verified cooling-effective water or blue-green infrastructure density adjusted for water stewardship | Higher effective density increases score only when water impacts are acceptable | Do not award net benefit where water loss, water quality, or ecological harm outweigh cooling value |
| \(V\): Ventilation | Corridor continuity, sky-view and obstruction metrics, modeled or measured airflow effectiveness | Higher ventilation effectiveness increases score | Use built-form and meteorological context; avoid one-size-fits-all wind assumptions |
| \(T\): Thermal comfort | UTCI improvement over matched observation periods and locations | Greater reduction in heat stress increases score | Use environmental measurements and modeled exposure fields, not individual tracking |

Canopy-layer urban heat-island monitoring refers to temperature conditions at roughly 1.5 meters above ground, a useful reference height for public-space thermal assessment. [77][80]

## Climate and Morphology Weights

Weights are public policy choices informed by local evidence, not immutable universal constants. Every HIRI publication must disclose:

- Climate-zone basis
- Urban morphology classification
- Baseline dates
- Target dates
- Weight values
- Rationale for weights
- Sensitivity analysis using plausible alternate weights

The following are starting profiles, not universal prescriptions.

| Context | \(w_c\) | \(w_a\) | \(w_w\) | \(w_v\) | \(w_t\) | Rationale |
|---|---:|---:|---:|---:|---:|---|
| Hot-arid low-rise neighborhood | 0.30 | 0.25 | 0.05 | 0.15 | 0.25 | Canopy and albedo are high-value; water receives a constrained weight because water stewardship must remain explicit |
| Dense urban core | 0.20 | 0.25 | 0.05 | 0.25 | 0.25 | Roof and pavement albedo plus ventilation geometry can strongly affect local heat conditions |
| Mixed-use corridor | 0.25 | 0.20 | 0.05 | 0.20 | 0.30 | Public thermal comfort is emphasized because walking, transit, and street activity depend on shade and radiant conditions |
| Humid subtropical district | 0.20 | 0.15 | 0.10 | 0.30 | 0.25 | Ventilation receives greater emphasis because airflow and humidity interact with thermal comfort |
| Industrial or logistics district | 0.15 | 0.35 | 0.05 | 0.20 | 0.25 | Large roof and pavement surfaces make reflectance improvement more measurable and operationally relevant |
| Park and open-space network | 0.35 | 0.10 | 0.15 | 0.15 | 0.25 | Canopy, ecological water stewardship, and comfort effects are prioritized |

A local weighting decision should use a transparent multi-criteria process:

\[
w_i
=
\frac{r_i \cdot q_i}
{\sum_{j=1}^{5} r_j \cdot q_j}
\]

Where \(r_i\) is the community-reviewed importance rating for component \(i\) and \(q_i\) is the local evidence-quality factor for that component.

If a component cannot be measured reliably, its evidence-quality factor declines. The method must then either reduce the component’s weight through a documented reweighting process or mark the report provisional. It must not silently substitute an unmeasured component with a favorable estimate.

## Spatial Resolution

HIRI operates at multiple nested scales.

| Use case | Recommended reporting unit | Recommended resolution |
|---|---|---|
| Street and transit thermal conditions | Street segment or grid aggregate | 10 to 50 meters where sensing or imagery supports it |
| Neighborhood intervention planning | Grid or block-scale aggregate | 50 to 250 meters |
| Public dashboard reporting | Neighborhood, district, or city aggregate | 100 to 500 meters with aggregation rules |
| Citywide progress tracking | District and citywide aggregate | 250 meters to 1 kilometer, supplemented by local hotspot analysis |

The implementation requires a 10 to 500 meter resolution for neighborhood-scale HIRI calculations. Finer measurements may be collected for engineering analysis but should be aggregated before public release where needed for privacy, statistical stability, and interpretability.

A coarse grid can conceal street-scale heat hazards. A very fine public grid can exaggerate sensor noise, reveal sensitive site operations, or imply precision that the observation network cannot support. Therefore, publish both:

- A stable aggregate HIRI for accountability.
- A quality-flagged hotspot layer for remediation planning, subject to privacy and safety review.

## Seasonal and Extreme-Heat Treatment

HIRI must not use a single favorable season as a substitute for annual recovery.

The minimum annual reporting structure is:

\[
\text{HIRI}_{\text{annual}}
=
\sum_{s \in \mathcal{S}}
\omega_s
\cdot
\text{HIRI}_s
\]

Where \(\mathcal{S}\) includes spring, summer, autumn, winter, and a locally defined extreme-heat season or heat-event stratum.

At least one of the following is required:

- Complete observations in all seasons and a defined heat season.
- A pre-registered temporal or spatial interpolation method that is visibly flagged in the report.
- A qualified report explicitly identifying missing seasons and reducing the measurement confidence factor.

Extreme-heat days must be reported separately because a neighborhood can show modest annual improvement while retaining dangerous conditions during the hottest periods.

## Privacy and Rights Protections

HIRI is based on environmental observations, surface properties, vegetation, meteorology, remote sensing, public infrastructure, and aggregated sensor readings.

HIRI must not require:

- Individual movement tracking
- Device identifiers
- Biometric, neural, health, or augmentation data
- Personal exposure histories
- Residential identity registration
- Participation in surveillance as a condition of receiving cooling, shade, transit, water, or other essential public services

A person may voluntarily contribute observations through a community science process, but participation must be optional, consent-based, revocable, and unnecessary for access to public benefits.

## Public Output Format

Every HIRI report publishes:

```text
HIRI status: validated, provisional, or not reportable
Reporting period: declared seasonal and heat-event coverage
Spatial unit: declared aggregate unit and resolution
HIRI score: 0.000 to 1.000
Confidence factor: 0.000 to 1.000
Component scores: canopy, albedo, water, ventilation, thermal comfort
Weights: publicly reviewable and summing to one
Observed cooling conditions: aggregate and quality-flagged
Privacy statement: no individual tracking, biometric collection, or precise personal-location collection
Limitations: missing data, interpolation, maintenance uncertainty, and causal limitations
```

## Technical Validation

The TypeScript implementation enforces:

- Non-negative, unit-bounded discounts and HIRI weights.
- A required one-sided 90 percent confidence bound or more conservative uncertainty standard.
- A zero-credit floor for negative or uncertain avoided impact.
- A minimum 90-day observation condition for a verified avoided-impact claim.
- Explicit causal-design validation.
- Data completeness, calibration, and missingness thresholds.
- No HIRI publication when weights are invalid, privacy protections are absent, spatial resolution is out of scope, or seasonal coverage is not reportable.
- A distinction between validated and provisional HIRI outputs.

## Metrics

| Metric | Score | Basis |
|---|---:|---|
| `knowledge_factor` | 0.93 | The methodology combines causal identification, uncertainty propagation, calibration controls, seasonal treatment, and transparent reporting |
| `eco_impact_value` | 0.94 | The standard supports defensible accounting for cooling, restoration, material, energy, water, and habitat interventions |
| `harm_risk` | 0.12 | Conservative lower bounds, independent review, data-quality discounts, and no-credit outcomes reduce greenwashing risk |
| `accessibility_impact` | 0.88 | Aggregate reporting, accessible explanations, and no-surveillance design support public participation without identity barriers |
| `rights_alignment` | 0.96 | The protocol prohibits individual tracking and makes ecological claims reviewable, bounded, and accountable |
