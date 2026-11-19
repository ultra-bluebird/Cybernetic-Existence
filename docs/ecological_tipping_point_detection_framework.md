# Ecological Tipping-Point Detection Framework

## Purpose

This framework defines an uncertainty-aware method for detecting statistical
patterns consistent with declining ecological resilience and possible critical
transitions.

It does not claim that an early-warning signal proves a tipping point, predicts
collapse with certainty, establishes ecological value, or independently
authorizes restoration, land-use, enforcement, or service decisions.

## Local Recovery-Rate Model

\[
dx_t
=
\lambda(\theta_t)
\left(
x_t-x^\star(\theta_t)
\right)dt
+
\sigma(\theta_t,x_t)dW_t
+
dJ_t.
\]

Where:

- `x_t` is an observed or latent ecological state;
- `θ_t` is a documented control variable or forcing vector;
- `x*(θ_t)` is a moving reference state;
- `λ(θ_t)` is the local recovery rate;
- `W_t` represents continuous stochastic forcing;
- `J_t` represents abrupt shock processes when supported by evidence.

Critical slowing down is represented by:

\[
\lambda(\theta)\uparrow0^-.
\]

## Candidate Indicators

Assess indicators as a vector, not as a single universal threshold:

\[
\mathbf E(t)
=
[
\widehat\lambda(t),
\widehat{AR}_1(t),
\widehat{\operatorname{Var}}(t),
\widehat{\operatorname{Skew}}(t),
\widehat{\operatorname{Kurt}}(t),
\widehat P_{\mathrm{low}}(t),
\widehat T_{\mathrm{rec}}(t)
].
\]

Potential patterns consistent with critical slowing down include:

- reduced estimated recovery rate;
- rising lag-one autocorrelation;
- rising variance under matched forcing conditions;
- spectral reddening;
- increasing distributional asymmetry;
- increased tail weight;
- flickering between candidate states;
- longer recovery after comparable perturbations.

No individual indicator is sufficient on its own.

## Indicator Constraints

Do not assume:

\[
\operatorname{Var}(x)\rightarrow\infty
\]

in finite field data.

Do not assume:

\[
\operatorname{Skew}(x)\rightarrow0
\]

or:

\[
\operatorname{Kurt}(x)\rightarrow3.
\]

Skewness direction and kurtosis behavior are context-dependent and must be
reported with uncertainty.

## Alert Definition

Define a documented risk target:

\[
\mathcal R_{\mathrm{loss}}(t).
\]

Issue an advisory only when:

\[
\Pr(
\mathcal R_{\mathrm{loss}}(t)>r_\star
\mid
\mathcal D
)
\ge p_\star.
\]

Where `r_star` and `p_star` must be selected before interpreting current
results and documented with the decision context.

## Required Null Comparisons

Every analysis must compare candidate signals against at least:

- seasonality;
- linear and nonlinear trend;
- changing forcing variance;
- autocorrelated external forcing;
- observation error;
- sampling-interval change;
- spatial aggregation or mixing;
- abrupt external shocks;
- intervention timing.

## Evidence Tiers

0. Descriptive pattern
1. Robust multi-indicator signal
2. Mechanistic-model-supported signal
3. Prospectively validated context-specific predictor
4. Reviewed precautionary restoration advisory

Every report must state its evidence tier and must not imply a higher tier.

## Governance Requirements

- Use minimum necessary ecological data.
- Protect sensitive habitat and species-location information.
- Keep alerts advisory, uncertainty-explicit, and reviewable.
- Do not use alerts for human, household, community, landholder, or access
  ranking.
- Do not use alerts as sole justification for displacement, enforcement, or
  service restriction.
- Require ecological and community review before external decision use.
