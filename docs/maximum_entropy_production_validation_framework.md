# Maximum Entropy Production Validation Framework

## Purpose

This framework defines a constrained, falsifiable method for evaluating whether
Maximum Entropy Production improves ecological prediction under documented
physical, ecological, and boundary constraints.

It does not assume that ecosystems universally maximize entropy production or
that high entropy production establishes ecosystem health, resilience,
restoration success, ecological value, or decision authority.

## Observable Entropy Production

\[
\widehat\Sigma_{\mathrm{obs}}(t)
=
\sum_{k=1}^{q}
J_k(t)X_k(t).
\]

Where:

- `J_k` is a measured or modelled flux;
- `X_k` is its conjugate thermodynamic force;
- every contribution must use dimensionally consistent units;
- measurement, model, and boundary uncertainty must be propagated.

## Constraint Vector

\[
C(t)
=
[
R_{\mathrm{in}},
T_{\mathrm{boundary}},
W_{\mathrm{availability}},
S_{\mathrm{soil}},
V_{\mathrm{vegetation}},
H_{\mathrm{hydrology}},
N_{\mathrm{nutrients}},
D_{\mathrm{disturbance}},
B_{\mathrm{boundary}}
].
\]

Every MEP analysis must specify which constraints are measured, estimated,
assumed, or omitted.

## MEP Hypothesis

The testable hypothesis is:

\[
\widehat\Sigma_{\mathrm{obs}}(t)
\approx
\arg\max_{\Sigma\in\mathcal F(C(t))}
\Sigma.
\]

This is a conditional research hypothesis, not a universal ecological law.

## Flux-Coverage Statement

Define:

\[
\Gamma_\Sigma
=
\frac{
\text{estimated material entropy-production categories}
}{
\text{materially relevant categories identified}
}.
\]

A low `Γ_Σ` requires a partial-estimate label. It must not be reported as a
whole-ecosystem entropy-production maximum.

## Feasible Envelope

\[
\Sigma_{\min}^{\mathcal F}(C)
=
\inf\mathcal F(C),
\qquad
\Sigma_{\max}^{\mathcal F}(C)
=
\sup\mathcal F(C).
\]

\[
\Phi_{\mathcal F}
=
\frac{
\Sigma_{\max}^{\mathcal F}(C)
-
\widehat\Sigma_{\mathrm{obs}}
}{
\Sigma_{\max}^{\mathcal F}(C)
-
\Sigma_{\min}^{\mathcal F}(C)
}.
\]

Only interpret `Φ_F` when:

\[
\Sigma_{\max}^{\mathcal F}(C)
>
\Sigma_{\min}^{\mathcal F}(C).
\]

Do not clip out-of-range values. Treat them as possible evidence of boundary
mismatch, omitted processes, measurement uncertainty, or model failure.

## Required Comparator Models

Compare MEP closure against:

1. Mechanistic process model
2. Empirical statistical model
3. Null or persistence baseline
4. Hybrid constrained model

Use held-out or forward-time validation for declared targets.

## Permitted Prediction Targets

- sensible and latent heat flux;
- evapotranspiration;
- carbon uptake or respiration;
- runoff partitioning;
- soil-water dynamics;
- vegetation-state dynamics;
- recovery time after documented disturbance;
- functional-process continuity.

## Prohibited Inferences

Do not infer from MEP results that:

- high entropy production is inherently beneficial;
- an ecosystem is healthy, restored, or resilient;
- a site, person, community, landholder, or species has greater worth;
- a modeled result authorizes land use, funding, enforcement, displacement, or
  service restriction;
- a partial flux estimate establishes a universal maximum.

## Governance Requirements

- Use minimum necessary data and protect sensitive habitat locations.
- Separate ecological data from personal, household, biometric, medical,
  assistive-technology, and identity data.
- Preserve provenance for instruments, transformations, parameters, and models.
- Require ecological, thermodynamic, and community review before external use.
- Publish uncertainty, failed model comparisons, and negative findings.
