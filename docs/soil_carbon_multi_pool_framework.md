# Soil Carbon Multi-Pool Framework

## Purpose

This framework defines a mass-balanced, multi-pool approach for studying soil
organic-carbon inputs, transfers, processing, emissions, exports, and
disturbance-conditioned persistence.

It does not establish permanent sequestration, create carbon-credit claims,
replace direct measurement, certify restoration outcomes, or authorize
financial, land-use, or policy decisions.

## State Vector

\[
\mathbf C(t)
=
[
C_{\mathrm{lab}},
C_{\mathrm{mic}},
C_{\mathrm{slow}},
C_{\mathrm{maom}}
]^\top.
\]

Every pool must have a documented operational definition, measurement relation,
unit, depth interval, and uncertainty treatment.

## General Model

\[
\frac{dC_i}{dt}
=
I_i(t)
+
\sum_{j=1}^{m}
a_{ij}(t,\mathbf z)
k_j(t,\mathbf z)
C_j(t)
-
k_i(t,\mathbf z)C_i(t)
-
\ell_i(t,\mathbf z)C_i(t).
\]

Where:

- `C_i` is carbon stock in pool `i`;
- `I_i` is external carbon input allocated to pool `i`;
- `k_i` is gross processing or turnover rate;
- `a_ij` transfers processed carbon from donor pool `j` to recipient pool `i`;
- `ℓ_i` is explicitly documented non-respiratory export;
- `z` contains documented environmental and ecological drivers.

## Carbon Conservation Constraint

For every donor pool `j`:

\[
0
\le
\sum_{i=1}^{m}a_{ij}(t,\mathbf z)
\le1.
\]

Respiratory or untransferred loss is:

\[
R_j(t)
=
\left[
1-\sum_{i=1}^{m}a_{ij}(t,\mathbf z)
\right]
k_j(t,\mathbf z)C_j(t).
\]

A model must not transfer more carbon than it processes.

## Environmental Rate Modifiers

\[
k_i(t,\mathbf z)
=
k_{i,0}
\phi_{i,T}(T(t))
\phi_{i,W}(W(t))
\phi_{i,O}(O(t))
\phi_{i,M}(M(t)).
\]

Every modifier must state its unit conventions, parameter source, valid range,
and uncertainty. Do not assume equal climate sensitivity across all pools.

## Persistence Metric

For an additional-carbon intervention, report retained fraction:

\[
P(T\mid s,\theta)
=
\frac{
C_{\mathrm{additional}}(T\mid s,\theta)
}{
C_{\mathrm{additional}}(0\mid s,\theta)
}.
\]

Where:

- `T` is a declared time horizon;
- `s` is a documented disturbance scenario;
- `θ` is model structure and parameters.

Do not describe a pool or modeled stock as permanent. Report scenario-specific
retention intervals instead.

## Required Scenarios

At minimum assess:

1. Baseline climate and management
2. Warming or heat stress
3. Drying or water deficit
4. Wet-dry cycling
5. Erosion or lateral export where relevant
6. Disturbance or management reversal
7. Input cessation
8. Parameter uncertainty

## Validation Requirements

- Compare modelled stocks and fluxes against available measurements.
- Report identifiability limits for pools, transfer fractions, and decay rates.
- Use independent observations when available.
- Separate direct measurements from modeled latent pools.
- Publish negative, mixed, and non-persistent outcomes.
- Do not convert model outputs into carbon claims without additional,
  independently governed verification processes.

## Governance Requirements

- Use minimum necessary site detail.
- Protect sensitive habitat and community information.
- Prohibit use for human, community, landholder, or service ranking.
- Do not use modeled carbon persistence as a sole basis for funding,
  enforcement, displacement, or access decisions.
- Require ecological, soil-science, and community review before external use.
