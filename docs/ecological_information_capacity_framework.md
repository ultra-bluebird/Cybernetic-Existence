# Ecological Information Capacity Framework

## Purpose

This framework defines information-theoretic measures for studying statistical
coupling, environmental encoding, predictive association, redundancy, and
synergy in ecological systems.

It does not attribute consciousness, intelligence, intention, cognition,
agency, moral status, ecosystem worth, or human-like decision-making to an
ecosystem. It does not use information measures to rank communities, people,
species worth, landholders, or service access.

## Environmental and System State

Let:

\[
E_t
=
[
T_t,
P_t,
W_t,
R_t,
N_t,
D_t
]
\]

be a documented environmental-state vector.

Let:

\[
S_t
=
[
V_t,
B_t,
\mathbf N_t,
F_t,
Q_t
]
\]

be a documented system-state vector.

Every variable must document units, sampling interval, spatial boundary,
measurement method, missing-data treatment, and uncertainty.

## Environmental Encoding Measure

\[
C_{\mathrm{enc}}(\ell)
=
I(E_{t-\ell};S_t).
\]

\[
C_{\mathrm{enc}}^\star
=
\max_{\ell\in\mathcal L}
I(E_{t-\ell};S_t).
\]

`C_enc` measures statistical environmental encoding at a declared lag. It does
not, by itself, establish adaptation, causality, ecological health, or
functional success.

## Conditional Environmental Encoding

For declared confounders \(Z_t\):

\[
C_{\mathrm{enc}\mid Z}(\ell)
=
I(E_{t-\ell};S_t\mid Z_t).
\]

Potential confounders include seasonality, site class, observation method,
management period, spatial aggregation, and unmodeled shared drivers.

## Predictive and Functional Association

For a declared future ecological outcome \(Y_{t+\Delta}\):

\[
C_{\mathrm{pred}}(\ell,\Delta)
=
I(E_{t-\ell};Y_{t+\Delta}\mid S_t,Z_t).
\]

\[
C_{\mathrm{use}}(\ell,\Delta)
=
I(S_t;Y_{t+\Delta}\mid E_{t-\ell},Z_t).
\]

These quantities are associational unless supported by a causal design or
mechanistic model.

## Normalized Reporting

When \(H(S)>0\), report:

\[
\widetilde C_{E\to S}
=
\frac{I(E;S)}{H(S)}.
\]

Also report:

- raw mutual information with units of bits or nats;
- marginal entropies;
- estimator and discretization or embedding settings;
- sample size;
- lag set;
- uncertainty interval;
- surrogate or permutation null-model result;
- all condition variables.

## Interpretation Safeguards

Do not interpret high mutual information as universally beneficial. It may
reflect adaptive tracking, passive forcing, stress sensitivity, shared
seasonality, or measurement artifacts.

Pair information measures with:

- recovery-time indicators;
- functional effect diversity;
- response diversity;
- water-balance indicators;
- disturbance history;
- quasi-extinction or low-condition risk;
- uncertainty and null-model checks.

## Governance Requirements

- Use minimum necessary ecological data.
- Do not include personal, household, biometric, medical, assistive-technology,
  neural, or identity data.
- Protect sensitive habitat and species-location information.
- Keep outputs as research and stewardship decision support.
- Require ecological and community review before external decision use.
