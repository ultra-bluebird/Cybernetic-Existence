# Ecological Multi-Scale Coupling Framework

## Purpose

This framework defines criteria for choosing between averaged, homogenized,
coupled, and regime-aware ecological models.

It does not assume that macro-scale models are always sufficient, that a small
parameter establishes valid scale separation, or that a reduced model replaces
site-specific ecological review.

## Fast-Slow Model

\[
\dot X^\varepsilon(t)
=
F(X^\varepsilon(t),y^\varepsilon(t)).
\]

\[
\dot y^\varepsilon(t)
=
\frac{1}{\varepsilon}
G(X^\varepsilon(t),y^\varepsilon(t)),
\qquad
0<\varepsilon\ll1.
\]

Where:

- `X` is the slow ecological state;
- `y` is the fast ecological state;
- `ε` is the declared time-scale ratio;
- `F` is the slow update function;
- `G` is the fast update function.

## Averaged Model

If a relevant unique invariant measure \(\mu_X\) exists for the fast dynamics
at fixed `X`, define:

\[
\bar F(X)
=
\int F(X,y)\mu_X(dy).
\]

The averaged model is:

\[
\frac{d\bar X}{dt}
=
\bar F(\bar X).
\]

Do not replace \(\bar F(X)\) with
\(F(X,\mathbb E_{\mu_X}[y])\) unless the required linearity or approximation
conditions are documented.

## Required Validity Conditions

A reduced model requires evidence for all of the following:

1. Clear time-scale separation
2. Fast conditional mixing or decorrelation
3. A unique relevant invariant measure across the modeled slow-state region
4. Regular dependence of fast statistics on slow variables
5. Sufficient observation resolution to evaluate fast-process assumptions
6. Acceptable held-out prediction error relative to the coupled model or data
7. No unresolved regime switching that materially changes slow dynamics

## Time-Scale Diagnostic

\[
\rho(X)
=
\frac{\tau_{\mathrm{mix}}(X)}
{\tau_{\mathrm{slow}}(X)}.
\]

Averaging is plausible only when:

\[
\rho(X)\ll1.
\]

The operational threshold must be selected through documented predictive
validation; it is not universal.

## Scale-Separation Diagnostic Record

\[
D_{\mathrm{sep}}
=
(
\rho,
U_{\mathrm{inv}},
E_{\mathrm{pred}},
S_{\mathrm{regime}},
Q_{\mathrm{obs}}
).
\]

Where:

- `ρ` is mixing-time divided by slow-change time;
- `U_inv` records evidence for invariant-measure uniqueness;
- `E_pred` is held-out reduced-model prediction error;
- `S_regime` records evidence of multistability or switching;
- `Q_obs` documents observation adequacy.

## Failure Conditions

Do not use a single averaged closure without additional treatment when the fast
subsystem exhibits:

- multiple invariant measures;
- alternative stable microstates;
- metastability;
- long memory;
- slow mixing;
- strong state-dependent variance;
- intermittent bursts;
- stochastic regime switching;
- rare high-impact events;
- nonstationary forcing that changes the fast-process distribution.

## Regime-Aware Alternative

For fast regimes \(Z(t)\in\{1,\ldots,m\}\):

\[
\dot X(t)
=
F_{Z(t)}(X(t)).
\]

\[
\Pr[
Z(t+\Delta t)=b
\mid
Z(t)=a,X(t)
]
=
q_{ab}(X(t))\Delta t+o(\Delta t).
\]

Use this representation only when regime definitions, transition assumptions,
and uncertainty are documented.

## Governance Requirements

- Use minimum necessary data and protect sensitive habitat locations.
- Do not infer people, households, protected attributes, health, biometric,
  assistive-technology, or identity information from ecological observations.
- Document the measurement grain, extent, missingness, and aggregation choices.
- Keep outputs as research and stewardship decision support.
- Require ecological and community review before external decision use.
- Publish model limitations, uncertainty, and failure conditions.
