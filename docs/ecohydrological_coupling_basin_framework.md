# Ecohydrological Coupling and Basin Framework

## Purpose

This framework defines a coupled vegetation–soil-water model for researching
long-term ecohydrological feedbacks, alternative stable states, basin
boundaries, hysteresis, and restoration scenarios.

It does not establish universal dryland behavior, guarantee bistability,
determine restoration eligibility, or replace local ecological, hydrological,
community, or land-governance review.

## State Variables

\[
V(t)\ge0
\]

is documented vegetation biomass, cover, or another defined vegetation-state
measure.

\[
W(t)\ge0
\]

is plant-available soil-water storage in a documented depth interval.

## Coupled Model

\[
\frac{dV}{dt}
=
V
\left[
r_w\psi(W)
\left(
1-\frac{V}{K_V}
\right)
-
d
-
m(V,W,T)
\right].
\]

\[
\frac{dW}{dt}
=
P(t)
+
I(V,W,\mathcal H)
-
ET(V,W,T)
-
Q(V,W,\mathcal H)
-
D(W)
-
U(V,W).
\]

Where:

- `r_w` is a water-use response parameter;
- `ψ(W)` is a bounded water-response function;
- `K_V` is a context-specific vegetation-capacity scale;
- `d` is a documented baseline loss parameter;
- `m` is stress or mortality;
- `P` is precipitation input;
- `I` is infiltration or runon contribution;
- `ET` is evapotranspiration;
- `Q` is runoff or lateral export;
- `D` is deep drainage;
- `U` is vegetation water uptake;
- `H` is a documented hydrologic-connectivity context.

A permitted bounded response function is:

\[
\psi(W)
=
\frac{W}{W+W_{1/2}},
\qquad
W_{1/2}>0.
\]

## Feedback Documentation

Every model must identify whether each vegetation effect is:

- local or landscape-scale;
- positive or negative;
- direct or mediated;
- observed, inferred, or hypothetical;
- stationary or seasonally varying.

Do not combine infiltration, runoff, drainage, uptake, and evapotranspiration
into an undocumented single loss term.

## Equilibria

Equilibria satisfy:

\[
F(V^\star,W^\star;\theta)=0,
\qquad
G(V^\star,W^\star;\theta)=0.
\]

The bare-state equilibrium has:

\[
V^\star=0.
\]

For a vegetated equilibrium where \(V^\star>0\):

\[
r_w\psi(W^\star)
\left(
1-\frac{V^\star}{K_V}
\right)
-
d
-
m(V^\star,W^\star,T)
=
0.
\]

## Local Stability

For:

\[
J(V,W)
=
\begin{bmatrix}
\frac{\partial F}{\partial V} &
\frac{\partial F}{\partial W}
\\
\frac{\partial G}{\partial V} &
\frac{\partial G}{\partial W}
\end{bmatrix},
\]

a two-dimensional equilibrium is locally asymptotically stable when:

\[
\operatorname{tr}(J)<0,
\qquad
\det(J)>0.
\]

Local stability does not establish resilience to large shocks, extreme events,
spatial heterogeneity, nonstationary climate, or model uncertainty.

## Basin Analysis

The vegetated basin is:

\[
\mathcal B_{\mathrm{veg}}
=
\left\{
(V_0,W_0):
(V(t),W(t))
\to
(V^\star_{\mathrm{veg}},W^\star_{\mathrm{veg}})
\right\}.
\]

Every basin claim must report:

- parameter values and units;
- climate and forcing assumptions;
- spatial boundary;
- model structure;
- uncertainty treatment;
- validation evidence;
- whether the basin boundary is numerically inferred or analytically derived.

## Restoration Scenarios

Represent an action as:

\[
(V_0,W_0,\theta)
\mapsto
(V_0+\Delta V,
W_0+\Delta W,
\theta+\Delta\theta).
\]

Assess state interventions and parameter interventions separately.

Do not claim restoration feasibility solely because a simulated vegetated
equilibrium exists. Evaluate whether the equilibrium exists, its basin is
reachable, uncertainty is acceptable, and the intervention is appropriate to
local ecological and community conditions.

## Required Scenario Comparisons

At minimum, compare:

1. Baseline forcing
2. Drought or water-deficit pulse
3. Sustained drying or heat press
4. Changed rainfall variability
5. Altered infiltration or runoff feedback
6. State-only restoration action
7. Parameter-changing restoration action
8. No-intervention counterfactual

## Governance Requirements

- Use minimum necessary spatial resolution.
- Protect sensitive habitat-location information.
- Do not use basin outputs to rank people, communities, landholders, or access
  to services.
- Do not treat a modelled basin as a land-use authorization.
- Require ecological, hydrological, and community review before external use.
- Document uncertainty, negative results, and model-failure conditions.
