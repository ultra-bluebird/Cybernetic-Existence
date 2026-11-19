# Urban Heat, Fair Calibration, and Accessible Door Design

## Urban Heat Island Recovery Potential Score

### Purpose

The Urban Heat Island Recovery Potential Score, abbreviated as UHIRPS, is a dimensionless score in the interval from zero to one. It estimates where a district has the strongest measurable potential for heat mitigation through a combination of green infrastructure, shade expansion, cool roofs, reflective pavement, and reduced impervious exposure.

The score is a prioritization metric. It does not claim that an intervention will produce a specific temperature reduction without local engineering, meteorological, hydrological, community, and maintenance review.

### Inputs

For each district \(d\) and assessment period \(t\), collect:

- \(L_{d,t}\): satellite-derived daytime land-surface-temperature anomaly relative to a locally selected cool-reference baseline, in degrees Celsius.
- \(A_{d,t}\): effective surface albedo, bounded from zero to one.
- \(V_{d,t}\): normalized difference vegetation index, bounded from minus one to one.
- \(B_{d,t}\): building-density ratio, expressed as built floor-area or footprint density divided by a locally selected maximum planning density.
- \(I_{d,t}\): impervious-surface ratio, bounded from zero to one.
- \(C_{d,t}\): feasible intervention coverage ratio, bounded from zero to one. This estimates the portion of roofs, parcels, rights-of-way, or public land where a rights-respecting intervention is technically and socially feasible.
- \(Q_{d,t}\): data-quality and uncertainty-confidence value, bounded from zero to one.

The built-environment variables are structurally relevant because hard, dry urban surfaces such as roads, roofs, sidewalks, buildings, and parking areas absorb and re-emit more heat while providing less shade and moisture than vegetated landscapes. Increasing albedo and vegetation can reduce surface heating and support cooling through reflection, shade, and evapotranspiration. [69][70][81]

### Normalization

Use robust local quantiles rather than a citywide raw minimum and maximum. This avoids one extreme district dominating the score.

\[
N_L(d,t) =
\operatorname{clip}
\left(
\frac{L_{d,t}-P_{10}(L_t)}
{P_{90}(L_t)-P_{10}(L_t)+\epsilon},
0,
1
\right)
\]

\[
N_A(d,t) =
1 -
\operatorname{clip}
\left(
\frac{A_{d,t}-P_{10}(A_t)}
{P_{90}(A_t)-P_{10}(A_t)+\epsilon},
0,
1
\right)
\]

\[
N_V(d,t) =
1 -
\operatorname{clip}
\left(
\frac{V_{d,t}-P_{10}(V_t)}
{P_{90}(V_t)-P_{10}(V_t)+\epsilon},
0,
1
\right)
\]

\[
N_B(d,t) =
\operatorname{clip}
\left(
\frac{B_{d,t}-P_{10}(B_t)}
{P_{90}(B_t)-P_{10}(B_t)+\epsilon},
0,
1
\right)
\]

\[
N_I(d,t) =
\operatorname{clip}
\left(
\frac{I_{d,t}-P_{10}(I_t)}
{P_{90}(I_t)-P_{10}(I_t)+\epsilon},
0,
1
\right)
\]

Where:

- \(P_{10}\) and \(P_{90}\) are the tenth and ninetieth percentiles across comparable districts for the same season and time window.
- \(\epsilon\) is a small positive constant such as \(10^{-9}\), preventing division by zero.
- \(\operatorname{clip}(x,0,1)\) limits a value to the interval from zero to one.

Higher normalized values mean higher temperature burden, lower reflectivity, lower vegetation, higher building density, and greater imperviousness.

### Composite Score

\[
H_{d,t}
=
Q_{d,t}
\cdot
\operatorname{clip}
\left(
C_{d,t}
\left[
0.32N_L(d,t)
+
0.18N_A(d,t)
+
0.22N_V(d,t)
+
0.12N_B(d,t)
+
0.16N_I(d,t)
\right],
0,
1
\right)
\]

The resulting \(H_{d,t}\) is the Urban Heat Island Recovery Potential Score.

| Component | Weight | Rationale |
|---|---:|---|
| Land-surface-temperature anomaly | 0.32 | Directly identifies observed surface heat burden and anchors the score in measured thermal conditions |
| Vegetation deficit | 0.22 | Captures missing shade and evapotranspiration capacity, central mechanisms of green-infrastructure cooling |
| Low albedo | 0.18 | Identifies candidate surfaces for cool roofs and reflective materials |
| Imperviousness | 0.16 | Represents heat-storing, low-infiltration surface coverage and redevelopment opportunity |
| Building density | 0.12 | Represents urban geometry, roof area, limited ventilation, and implementation complexity |
| Feasible intervention coverage | Multiplier | Prevents ranking a district as highly recoverable when interventions cannot reasonably be installed or maintained |
| Data quality | Multiplier | Prevents uncertain or sparse data from being treated as a high-confidence investment signal |

### Interpreting the Score

| UHIRPS interval | Interpretation | Appropriate institutional action |
|---|---|---|
| 0.00–0.24 | Low presently observed recovery priority | Maintain observation, preserve existing cooling assets, and avoid disinvestment |
| 0.25–0.49 | Moderate recovery potential | Conduct site-specific feasibility and accessibility planning |
| 0.50–0.74 | High recovery potential | Prioritize co-designed green-infrastructure, cool-roof, and shade interventions |
| 0.75–1.00 | Very high recovery potential | Trigger urgent equity review, community engagement, and technically validated intervention planning |

The score must never be used by itself to reduce services, deny resources, profile residents, predict individual behavior, or justify surveillance. A low score can indicate that a district already has cooling assets, that the available data are insufficient, or that feasible intervention coverage is limited; it must not be interpreted as low community need.

### Real-Time Update

Satellite observations are periodic and may be obscured by cloud cover. Real-time sensors can update the temperature component while preserving the slower-changing land-cover components.

Let:

- \(T^{air}_{d,t}\): district near-surface air temperature.
- \(T^{ref}_{t}\): same-time reference temperature selected from a stable, lower-impervious, locally comparable site.
- \(N_R(d,t)\): normalized real-time air-temperature anomaly.
- \(\lambda_{d,t}\): sensor-data trust coefficient, bounded from zero to one.

\[
N_R(d,t) =
\operatorname{clip}
\left(
\frac{
(T^{air}_{d,t} - T^{ref}_{t}) - P_{10}(\Delta T_t)
}
{
P_{90}(\Delta T_t) - P_{10}(\Delta T_t) + \epsilon
},
0,
1
\right)
\]

\[
N_L^{*}(d,t)
=
(1-\lambda_{d,t})N_L(d,t)
+
\lambda_{d,t}N_R(d,t)
\]

\[
H^{*}_{d,t}
=
Q^{*}_{d,t}
\cdot
\operatorname{clip}
\left(
C_{d,t}
\left[
0.32N_L^{*}(d,t)
+
0.18N_A(d,t)
+
0.22N_V(d,t)
+
0.12N_B(d,t)
+
0.16N_I(d,t)
\right],
0,
1
\right)
\]

Set \(\lambda_{d,t}\) using sensor calibration state, uptime, local representativeness, and uncertainty. A failed, stale, or uncalibrated sensor receives \(\lambda_{d,t}=0\), so satellite-derived evidence remains the fallback.

### Equity Guard

For each service-planning cycle, calculate the district coverage ratio:

\[
E_{\mathrm{coverage}} =
\frac{\min_{d \in D} M_d}
{\operatorname{mean}_{d \in D} M_d + \epsilon}
\]

Where \(M_d\) is the effective monitoring coverage for district \(d\), adjusted for uptime, sensor quality, and time spent in the district’s relevant microclimates.

The city should define a minimum equity floor. No new discretionary deployment may be approved if it lowers the coverage ratio below that floor or leaves a district without a reasonable calibration and maintenance path.
