# Ecological Network Resilience Framework

## Purpose

This framework defines a scenario-based, multidimensional approach for studying
ecological-network resilience under species loss, interaction weakening,
phenological mismatch, heat, drought, and restoration scenarios.

It does not claim that a single network metric predicts persistence, ecosystem
health, restoration success, conservation priority, or the value of species,
communities, or places.

## Network Representation

Let:

\[
\mathcal G_t
=
(
V,
E_t,
W_t,
K_t,
\Delta_t
).
\]

Where:

- \(V\) is a documented set of ecological entities;
- \(E_t\) is the time-indexed interaction set;
- \(W_t\) contains interaction magnitudes;
- \(K_t\) contains interaction types and signs;
- \(\Delta_t\) contains phenological or temporal support.

Every analysis must declare whether the network is:

- directed or undirected;
- weighted or unweighted;
- signed or unsigned;
- bipartite, multipartite, or unipartite;
- static or temporal;
- species-level, guild-level, functional-group-level, or spatial-patch-level.

## Local Interaction Entropy

For node \(i\), with nonnegative interaction magnitudes \(w_{ij}(t)\):

\[
p_{ij}(t)
=
\frac{w_{ij}(t)}
{\sum_{k\in\mathcal N_i}w_{ik}(t)}.
\]

\[
H_i(t)
=
-
\sum_{j\in\mathcal N_i}
p_{ij}(t)\log p_{ij}(t).
\]

For nodes with degree greater than one:

\[
\widetilde H_i(t)
=
\frac{H_i(t)}
{\log d_i(t)}.
\]

Set \(\widetilde H_i(t)=0\) for \(d_i(t)\le1\), and report isolated or
singly connected nodes separately.

## Candidate Topology Signal

\[
T_{\mathrm{disp}}
=
\frac{1}{n}
\sum_{i=1}^{n}
\widetilde H_i(1-c_i).
\]

`T_disp` is a candidate topology signal. It measures distributed local
interaction allocation and reduced local closure under a declared graph
projection. It is not a direct resilience measure.

A high or low value must not be interpreted without scenario outcomes,
interaction strength, temporal coverage, and functional context.

## Resilience Profile

\[
\mathbf R
=
[
R_{\mathrm{local}},
R_{\mathrm{transient}},
R_{\mathrm{press}},
R_{\mathrm{extinction}},
R_{\mathrm{function}},
R_{\mathrm{rewire}},
R_{\mathrm{temporal}}
].
\]

### Local asymptotic stability

For Jacobian \(J(N^*)\):

\[
R_{\mathrm{local}}
=
-\max
\operatorname{Re}
(
\operatorname{eig}(J(N^*))
).
\]

A positive value indicates local asymptotic stability under the stated model
and equilibrium reference only.

### Transient amplification

\[
A_{\max}(T)
=
\max_{0\le t\le T}
\left\|
e^{Jt}
\right\|.
\]

Transient amplification must be reported beside local asymptotic resilience.

### Extinction and interaction-loss outcomes

For scenario \(s\), report:

\[
\mathbf O_s
=
[
\text{surviving taxa},
\text{interaction retention},
\text{functional coverage},
\text{biomass retention},
\text{recovery time},
\text{quasi-extinction probability}
].
\]

## Required Scenario Set

At minimum, evaluate:

1. Random species removal
2. Targeted species removal
3. Random interaction weakening
4. Targeted interaction weakening
5. Phenology mismatch
6. Heat or drought pulse
7. Sustained heat or drought press
8. Rewiring-constrained recovery

Species removal and interaction weakening must be reported separately. Do not
treat binary species loss as an adequate proxy for all disturbance processes.

## Functional and Temporal Safeguards

- Report functional effect diversity and response diversity.
- Report phenological coverage and overlap.
- Document allowable rewiring mechanisms and constraints.
- Do not assume that an observed potential interaction is feasible in every
  season, habitat, abundance state, or climate regime.
- Do not treat static network aggregation as a complete representation of
  temporal resilience.

## Validation Requirements

A topology metric may be described as predictive only after:

- comparison against documented ecological outcomes or declared dynamic-model
  outcomes;
- held-out or forward-time validation;
- comparison with climate-only, hydrology-only, biodiversity-only, and
  conventional network baselines;
- uncertainty analysis for sampling, interaction inference, aggregation,
  threshold selection, and disturbance scenarios;
- publication of negative and mixed findings.

## Governance Requirements

- Use minimum necessary spatial and taxonomic detail.
- Protect sensitive habitat and species-location information.
- Keep outputs as ecological research and decision support.
- Prohibit human or community ranking, automated enforcement, land
  displacement, service-eligibility decisions, and protected-attribute
  inference.
- Require ecological, community, and material-change review before external
  decision use.
