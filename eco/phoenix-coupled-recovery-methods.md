# Phoenix Coupled Thermal Recovery and Food-Web Disturbance

## Purpose and research status

Treat wet-bulb bridge-effects, heat-island-recovery mapping, and food-web disturbance as one coupled system:

environmental exposure
→ physiological and behavioral constraints
→ altered interaction opportunities
→ demographic and network responses
→ recovery or persistent disturbance.

The immediate deliverable is a reproducible research specification, not a verified Phoenix forecast or an assertion that a particular species has already crossed a physiological limit.

The supplied summer and November trajectories are scenario narratives. Their reported collapse times, abundance changes, light-attribution percentages, and intervention benefits remain scenario outputs pending a complete parameter set, executable model, and reproducible run.

No new numerical simulation is claimed in this document.

## 1. The central modeling decision

Keep wet-bulb temperature as an environmental exposure variable, but do not use it interchangeably with organism temperature, ecological performance, or population growth.

Use the state:

\[
S(x,y,t)=
\left\{
T_a,q,p,u,T_s,T_r,E_\lambda,
A,D_i,N_i,F
\right\}.
\]

Definitions:

- \(T_a\): air temperature, degrees Celsius.
- \(q\): specific humidity, kilograms of water vapor per kilogram of moist air.
- \(p\): atmospheric pressure, pascals.
- \(u\): wind speed at the relevant exposure height, meters per second.
- \(T_s\): land-surface temperature, degrees Celsius.
- \(T_r\): mean radiant temperature, degrees Celsius.
- \(E_\lambda\): spectral irradiance, with documented wavelength and radiometric units.
- \(A\): urban–reference thermal anomaly, degrees Celsius.
- \(D_i\): accumulated exposure memory for ecological group \(i\).
- \(N_i\): abundance or biomass, using a consistently defined unit.
- \(F\): floral, nectar, fruit, or other explicitly measured resource state.

Compute wet-bulb temperature as a diagnostic:

\[
T_w=\mathcal{P}(T_a,q,p).
\]

Organism-level thermal exposure is a separate quantity:

\[
T_{e,i}=
\mathcal{M}_i(T_a,T_r,u,q,\text{microhabitat},\text{traits}).
\]

A reduced model may use air temperature as an explicitly labeled proxy
when organism-level exposure cannot be estimated.

Do not silently substitute wet-bulb temperature into thermal-performance
curves calibrated using body temperature, chamber temperature, or
dry-bulb air temperature.

Species traits and microhabitat can strongly alter the relationship
between environmental and internal temperatures. [70]

## 2. Operational meaning of a bridge-effect

Define a bridge-effect as a reduction in viable interaction opportunity,
rather than assuming that every exceedance produces irreversible
population damage.

For group \(i\), define heat-related closure:

\[
b_{H,i}(t)=
\frac{1}{
1+\exp[-k_{H,i}(T_{e,i}(t)-T_{H,i})]
}.
\]

Define cold-related closure:

\[
b_{C,i}(t)=
\frac{1}{
1+\exp[k_{C,i}(T_{e,i}(t)-T_{C,i})]
}.
\]

Here:

- \(T_{H,i}\): fitted high-temperature transition parameter.
- \(T_{C,i}\): fitted low-temperature transition parameter.
- \(k_{H,i},k_{C,i}\): steepness parameters, inverse degrees Celsius.

Unless calibrated against observed events, these functions are closure
scores, not probabilities of death, extinction, or physiological failure.

Keep light-related opportunity separate:

\[
g_{L,i}(t)\in[0,1].
\]

Estimate this function from species-specific observations. It may
represent avoidance, reduced emergence, or loss of usable dark habitat.

Do not infer that all bats or all insects respond identically.
Artificial light can attract some organisms and displace others,
changing spatial overlap and interactions. [57]

Define pairwise opportunity:

\[
g_{ij}(t)=
g_{\mathrm{phen},ij}(t)
\sqrt{
[1-b_{H,i}(t)]
[1-b_{C,i}(t)]
[1-b_{H,j}(t)]
[1-b_{C,j}(t)]
}
g_{L,i}(t)g_{L,j}(t).
\]

The phenology term represents overlapping activity and resource
availability. Estimate it independently rather than treating every
seasonal decline as thermal damage.

## 3. Separate urban cooling from ecological recovery

### Urban thermal anomaly

Choose one temperature variable for each anomaly:

\[
A_a(t)=T_{a,\mathrm{urban}}(t)
      -T_{a,\mathrm{reference}}(t),
\]

\[
A_s(t)=T_{s,\mathrm{urban}}(t)
      -T_{s,\mathrm{reference}}(t).
\]

Report surface and air anomalies separately.

A positive urban anomaly that benefits a cold-limited organism is a
potential thermal refuge. It is not an inverse heat island unless the
urban–reference temperature contrast actually reverses sign.

### Conditional cooling model

For a suitable cooling interval:

\[
\frac{dA}{dt}
=
-\frac{A}{\tau_U}
+
F_A(t).
\]

Here:

- \(\tau_U>0\): fitted urban-anomaly relaxation time, hours.
- \(F_A\): unresolved or explicitly modeled forcing, degrees Celsius
  per hour.

The exponential model

\[
A(t)=A_0e^{-(t-t_0)/\tau_U}
\]

is a restricted case with negligible additional forcing.

Fit it only over intervals that support that assumption. Report
uncertainty, residuals, reference-site sensitivity, and rejected fits.

Prefer fitting the original temperature-anomaly observations with an
explicit error model. Log-linear fitting is permissible only for
positive anomalies and an appropriate transformed-error assumption.

### Ecological exposure memory

For each group, retain the original disturbance-memory structure:

\[
D_i(t)=
\int_{t_0}^{t}
q_i(s)
e^{-(t-s)/\tau_{D,i}}
\,ds,
\]

with, for a heat-exceedance model,

\[
q_i(t)=
\max[0,T_{e,i}(t)-T_{H,i}].
\]

The equivalent differential equation is:

\[
\frac{dD_i}{dt}
=
q_i(t)-\frac{D_i(t)}{\tau_{D,i}}.
\]

If time is measured in hours, \(D_i\) has units of degree-hours.

Use a distinct parameter \(\tau_{D,i}\) for exposure-memory decay.
It may represent an ecological recovery hypothesis; it is not
automatically equal to the urban cooling parameter \(\tau_U\).

The coupling is:

urban cooling
→ subsequent exposure
→ exposure-memory accumulation and clearance.

It is not an assumed equality of physical and biological time constants.

For piecewise-constant \(q_i\), the exact update is:

\[
D_{i,n+1}
=
D_{i,n}e^{-\Delta t/\tau_{D,i}}
+
q_{i,n}\tau_{D,i}
\left(1-e^{-\Delta t/\tau_{D,i}}\right).
\]

This provides a nonnegative update for nonnegative initial exposure
memory and forcing.

## 4. Keep light out of the temperature equation

Do not calculate:

\[
T_{w,\mathrm{night}}
=
T_w+\text{light penalty}\times\text{lux}
\]

unless a separately justified physical model supplies a temperature
conversion. Optical exposure and temperature are different quantities.

Instead, pass thermal and lighting variables separately into activity,
interaction, or mortality models.

Record, where available:

- Spectral distribution.
- Irradiance at the habitat or organism exposure plane.
- Illuminance in lux as a supplementary human-weighted measurement.
- Exposure duration and timing.
- Fixture direction and shielding.
- Background illumination and moon conditions.

Amber lighting is not an assumption of invisibility or zero ecological
effect. Published insect evidence includes behavioral suppression
under sufficiently bright yellow or green illumination. [58]

Do not assume lighting has the same effect as heat, or that it contributes
a fixed percentage of total disturbance. Artificial light affects
physiology, activity timing, and life-history traits through multiple
pathways. [52]

## 5. Use a seasonal resource–consumer model

Separate plant standing biomass from food production.

A plant can retain biomass while producing fewer accessible flowers,
less nectar, or less fruit. The model must represent those quantities
before interpreting biomass growth as successful reproduction.

For a reduced model:

\[
\frac{dF}{dt}
=
\Phi(T_{e,P},M,\ell,P)
-
\delta_F F
-
c_{FL}(t)FL,
\]

\[
\frac{dL}{dt}
=
L\left[
e_Lc_{FL}(t)F
-
m_L(T_{e,L},D_L)
-
d_LL
\right]
-
c_{LB}(t)LB,
\]

\[
\frac{dB}{dt}
=
B\left[
e_Bc_{LB}(t)L
+
s_B(t)
-
m_B(T_{e,B},D_B)
-
d_BB
\right].
\]

Definitions:

- \(F\): accessible resource abundance.
- \(L\): focal pollinator or prey abundance.
- \(B\): focal consumer abundance.
- \(P\): standing plant biomass.
- \(M\): soil-moisture state.
- \(\ell\): photoperiod.
- \(\Phi\): resource production.
- \(c_{FL}\): resource-consumption coefficient.
- \(c_{LB}\): predation coefficient.
- \(e_L,e_B\): conversion efficiencies.
- \(d_L,d_B\): density-dependent regulation.
- \(s_B\): explicitly modeled alternative-food contribution.

Set:

\[
c_{ij}(t)=c_{ij,0}g_{ij}(t).
\]

Use matching resource-loss and consumer-gain terms for each modeled
feeding flux.

If alternative food is absent from the scenario, set \(s_B=0\).
If it is included, document its resource basis rather than using it as
an unexplained source of predator growth.

Represent pollination benefits through a plant reproduction or recruitment
term if that outcome is studied. Do not assume immediate adult biomass
growth is a proxy for pollination success.

Keep nectar-feeding bats, insectivorous bats, moths, and insectivorous
birds as distinct functional groups unless aggregation is justified.

## 6. Interpret the supplied seasonal scenarios

### Summer hypothesis

Prolonged high thermal exposure and reduced night-time interaction
opportunity can reduce resource access, feeding, or pollination, with
lagged effects on consumers.

Test whether this pattern emerges. Do not encode a required
pollinator-first collapse into all parameter combinations.

### November hypothesis

Lower heat exposure may reopen a heat-limited interaction window.
Cold limitation, photoperiod, phenology, moisture, lighting, and migration
can still constrain activity.

A near-zero heat-closure score does not establish zero mortality,
full activity, or baseline ecological conditions.

Do not interpret a simulated population decline as seasonal senescence
without observations that distinguish mortality, dormancy, emigration,
reduced detectability, and resource limitation.

### Numerical consistency check

Using the supplied Gaussian performance equation at 13 degrees Celsius:

\[
P_L=
\exp\left[
-\frac{(13-28)^2}{2(3.5)^2}
\right]
\approx0.00010,
\]

\[
P_B=
\exp\left[
-\frac{(13-30)^2}{2(4)^2}
\right]
\approx0.00012.
\]

These values are not 0.08 and 0.12.

That discrepancy materially changes the cold-season model. Reconcile
the input temperature variable and performance parameters before
interpreting a November trajectory.

## 7. Observation architecture

### Landsat role

Use Landsat for landscape structure, vegetation indicators, and
acquisition-time surface-temperature patterns.

Landsat 8 and 9 thermal measurements have 100-meter native sampling
and are delivered resampled to 30 meters. Each satellite has a 16-day
repeat cycle, with an 8-day offset between satellites. [73]

Consequently:

- A 30-meter output grid is not proof of independent 30-meter thermal detail.
- Landsat alone does not provide an hourly nocturnal cooling curve.
- Hourly downscaled products must be labeled as modeled estimates.
- Validate air-temperature and humidity fields independently of surface
  temperature.

Landsat 9 has an approximately 10:12 a.m. equatorial crossing time;
its routine observations are not a night-time cooling record. [75]

### Required local exposure series

Use permissioned observations or appropriately licensed existing data:

- Air temperature.
- Humidity.
- Pressure where required for psychrometrics.
- Measurement height and shelter.
- Wind where available.
- Timezone and timestamp convention.
- Instrument uncertainty and missing-data flags.
- Urban and reference-site comparability.

### Ecological observations

Separate ecological state from detection:

\[
Y_{i,t}\sim
\operatorname{ObservationModel}
(N_{i,t},p_{i,t},\text{effort}_{i,t}).
\]

Detection probability may depend on weather, activity, equipment, habitat,
and survey effort.

Do not treat more acoustic detections as a direct abundance increase,
or fewer detections as confirmed mortality.

Use non-attracting observations where practical. Light traps are an
intervention as well as a sampling method and require a separate
disturbance assessment.

## 8. Primary questions and null hypotheses

### Recovery and usable hours

Question:
Does slower urban cooling reduce warm-season usable interaction hours
but increase them under some cold-limited conditions?

Null:
After controlling for weather, habitat, and seasonal resource availability,
the estimated urban recovery parameter does not explain usable hours.

### Lighting and thermal interaction

Question:
Does lighting change ecological activity differently across thermal
conditions?

Null:
The thermal-by-light interaction is zero under a prespecified model.

Do not assume the combined response is additive or multiplicative
without comparing alternatives.

### Food-web propagation

Question:
Do measured interaction losses precede consumer declines after accounting
for resource phenology and observation error?

Null:
Interaction-opportunity metrics do not improve prediction over a model
using resource availability and seasonal covariates alone.

## 9. Vulnerability and refugia outputs

Keep the original vulnerability index as a candidate screening score:

\[
V=
B(\overline{T_w})
\frac{\tau_U}{\tau_{\mathrm{ref}}}
(1-\mathcal{R}).
\]

Document its limitations:

- The recovery ratio can exceed one, so the index is not inherently
  bounded by one.
- A logistic score evaluated at mean temperature loses exposure timing.
- Ecological robustness requires a defined, reproducible calculation.
- The score is not an extinction probability.

Prefer reporting interpretable components first:

- Exceedance degree-hours.
- Longest uninterrupted adverse exposure.
- Urban recovery time with uncertainty.
- Exposure-memory recovery time with uncertainty.
- Dark, thermally suitable activity hours.
- Resource availability.
- Interaction opportunity.
- Abundance estimates with observation uncertainty.

Define usable interaction hours:

\[
U_{ij}
=
\int_{t_0}^{t_1}g_{ij}(t)\,dt.
\]

Define a bounded scenario vulnerability score only when a defensible
reference exists:

\[
V_{ij}^{*}
=
1-
\min\left(
1,
\frac{U_{ij}}{U_{ij,\mathrm{reference}}}
\right).
\]

Require positive reference opportunity. Also report the unbounded
opportunity ratio so improvements above reference are not hidden.

This score describes opportunity loss, not population extinction.

## 10. Validation and reproducibility gates

Before releasing numerical results:

1. Publish all equations, units, parameter values, initial conditions,
   forcing data, solver settings, and random seeds where applicable.
2. Mark every input as observed, literature-derived, fitted, or synthetic.
3. Test that zero forcing causes exposure memory to decay.
4. Test the exact exposure-memory update against a numerical solver.
5. Test nonnegative ecological states and numerical convergence.
6. Check interaction signs and resource–consumer flux consistency.
7. Compare models with and without thermal-memory and lighting effects.
8. Evaluate sensitivity across thresholds, recovery times, resource
   production, mortality, and observation uncertainty.
9. Validate on held-out nights, sites, and seasons.
10. Report uncertainty in both parameter estimates and mapped outputs.
11. Define any functional-extinction threshold before analyzing outcomes.
12. Distinguish temporary inactivity, local absence, and irreversible loss.

Do not predeclare that recovery time and threshold dominate sensitivity.
Temperature-dependent ecological uncertainty can shift among parameters
across temperature regimes. [68]

## 11. Human-safety boundary

Do not describe 35 degrees Celsius wet-bulb as a universal safe/unsafe
boundary or an absolute human survivability threshold.

Controlled human studies identify uncompensable heat stress below that
value, and physiology-based research shows that risk depends strongly
on environmental conditions and individual characteristics. [51][55]

Ecological threshold parameters must not be reused as human health
guidance.

## 12. Intervention research boundaries

Candidate interventions:

- Reduce unnecessary lighting while preserving accessible navigation
  and essential safety functions.
- Maintain dark habitat connections.
- Restore locally appropriate vegetation and soil conditions.
- Assess shade, water demand, maintenance, and seasonal tradeoffs.
- Evaluate habitat structures only with the relevant land manager
  and wildlife specialists.

Do not infer that a specified number of burrows, a lighting color,
or irrigation alone produces a quantified extinction-risk reduction.

Avoid attracting prey with new lighting as a default conservation
strategy; assess effects on the wider interaction network first.

Compare interventions using matched controls or a before–after,
control–impact design where feasible. Record changes in maintenance,
water use, illumination, habitat, and observation effort.

## 13. Governance, privacy, and accessibility

This work is ecological decision support, not automated eligibility,
identity assessment, or public ranking.

- No CyberRank, identity, medical, neural, biometric, or companion-system
  information is required.
- Preserve equal access and human review.
- Do not publish sensitive wildlife locations or private property details
  without appropriate permission.
- Use the minimum spatial precision needed for public outputs.
- Obtain approval before external data transfer, field deployment,
  publication of sensitive observations, or habitat modification.
- Provide text descriptions, units, uncertainty summaries, and
  color-independent map legends.
- Keep research outputs separate from operational control systems.

## 14. Next executable artifact

Build a local MATLAB reference model with:

- Explicitly synthetic forcing.
- Separate air temperature, humidity, lighting, and resource inputs.
- Configurable urban and ecological recovery times.
- Exact exposure-memory updates.
- Resource–consumer dynamics with consistent interaction fluxes.
- Observation-error scenarios.
- Summer and cold-season comparisons.
- Sensitivity analysis and convergence tests.

The first release should demonstrate model behavior and reproducibility.
Phoenix-specific predictive claims require local calibration and
independent validation.
