# Lévy-Driven Trophic Dynamics Specification

## Purpose

Define a reproducible, nonstationary stochastic food-web model for estimating
quasi-extinction risk, recovery behavior, and shock-propagation pathways under
heat, drought, precipitation-pulse, and other environmental forcing.

This specification is decision support for ecological stewardship. It must not
be used as an automated eligibility, enforcement, land-displacement, or
community-ranking system.

## State Variables

For each species or functional population `i` in `1..m`:

- `N_i(t) > 0`: abundance, density, biomass, or a documented proxy
- `X_i(t) = log(N_i(t))`: log-abundance state
- `r_i(t)`: time-varying intrinsic growth component
- `K_i(t) > 0`: time-varying carrying-capacity component
- `A_ij`: signed interaction coefficient from population `j` to `i`
- `W_i(t)`: Brownian component for small, frequent fluctuations
- `L_i(t)`: Lévy jump component for rare, discontinuous forcing

## Model

\[
dX_i(t)
=
\left[
r_i(t)
+
\sum_{j=1}^{m} A_{ij}e^{X_j(t)}
-
\frac{e^{X_i(t)}}{K_i(t)}
\right]dt
+
\sigma_i(t)dW_i(t)
+
\int_{\mathbb{R}\setminus\{0\}}
\gamma_i(t,z)\widetilde{\mathcal N}_i(dt,dz).
\]

The observable abundance is:

\[
N_i(t)=e^{X_i(t)}.
\]

## Nonstationary Environmental Forcing

\[
r_i(t)
=
r_{i,0}
+
\beta_{i,T}T(t)
+
\beta_{i,P}P(t)
+
\beta_{i,D}D(t)
+
u_i(t).
\]

Required documentation:

- Units and source of heat metric `T(t)`
- Units and source of precipitation metric `P(t)`
- Definition of drought or soil-moisture-deficit metric `D(t)`
- Time resolution and missing-data treatment
- Geographic aggregation method
- Ecological justification for each covariate and lag

## Quasi-Extinction Endpoint

\[
\tau_{i,\varepsilon}
=
\inf\{t\ge0:N_i(t)\le\varepsilon_i\}.
\]

The threshold `ε_i` must be documented as one of:

- a monitoring detection limit;
- a pre-specified ecological minimum;
- a recovery or reproductive threshold supported by domain evidence;
- a scenario-analysis value, explicitly labelled as hypothetical.

Do not present `ε_i` as a universal extinction threshold.

## Outputs

For every scenario and posterior draw, calculate:

\[
P_{i,\varepsilon}(T)
=
\Pr(\tau_{i,\varepsilon}\le T).
\]

Also calculate:

- median and credible interval for abundance trajectories;
- time below quasi-extinction threshold;
- recovery time after adverse jump events;
- species-to-species shock-propagation kernel;
- uncertainty attributable to observations, parameters, interaction structure,
  and jump-process selection.

## Model Comparison

Compare at minimum:

1. Deterministic nonstationary model
2. Gaussian diffusion model
3. Diffusion plus compound-Poisson jump model
4. Diffusion plus heavy-tailed Lévy-jump model

Use held-out predictive checks focused on:

- low-abundance events;
- crash magnitude;
- recovery duration;
- threshold crossing;
- observed tail behavior.

## Rights, Privacy, and Governance Constraints

- Use minimum necessary spatial resolution.
- Do not infer household, individual, Indigenous, or protected-community
  attributes from ecological observations.
- Publish only aggregation-safe outputs where site sensitivity could increase
  harvesting, disturbance, or surveillance risk.
- Keep model outputs advisory and subject to ecological and community review.
- Preserve provenance for data transformations, consent conditions, and
  access restrictions.
- Provide accessible plain-language summaries alongside technical outputs.
