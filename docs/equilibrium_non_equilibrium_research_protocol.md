# Equilibrium and Non-Equilibrium Ecosystem Research Protocol

## Scope and non-claims

This protocol governs a compact research package that separates **equilibrium
reference models** from **non-equilibrium thermodynamic diagnostics** for
ecosystem research, restoration monitoring, ecological risk assessment, and
method validation. It connects both to trophic-shock research
(`docs/levy_trophic_dynamics_spec.md`) and functional-redundancy research
(`schemas/functional_redundancy_assessment.schema.json`).

Explicit non-claims:

- No model, document, or metric in this package provides a universal definition
  of ecosystem health, restoration success, or ecological value.
- High entropy production is not inherently evidence of ecological health.
- Maximum-entropy-production reasoning is treated as a hypothesis-generating
  constraint argument, not as a settled universal ecological law.
- This protocol is not an automated decision system. Outputs must not be used
  for human, household, community, landholder, or access ranking, nor for
  enforcement, benefit eligibility, or land-displacement decisions.
- All outputs are research and decision support subject to human scientific
  review and, where affected communities exist, community-governance review.

## Research questions

Primary question: under matched environmental constraints, do estimated
entropy-production patterns improve explanation or prediction of documented
ecological stress, recovery, and functional continuity beyond conventional
climate, hydrology, vegetation, and biodiversity indicators?

Supporting questions:

1. Which observed dynamics are adequately described by equilibrium-reference
   models, and which require non-equilibrium thermodynamic treatment?
2. How should measurement, parameter, boundary, and missing-process uncertainty
   propagate into derived thermodynamic diagnostics?
3. How do thermodynamic diagnostics relate to trophic shock propagation,
   quasi-extinction risk, and response/functional-effect diversity?

Three falsifiable hypotheses anchor the program:

```text
H1: Constraint-matched thermodynamic diagnostics improve held-out prediction
of documented ecological stress or recovery outcomes.

H2: The diagnostic adds explanatory value beyond climate-only,
vegetation-only, biodiversity-only, and hydrology-only baselines.

H3: Different ecosystem contexts may have different valid feasible envelopes;
a universal optimum is not presumed.
```

## Equilibrium reference models

Equilibrium-reference models describe how population-level dynamics relax
toward stationary states when conditions are held fixed. The canonical
deterministic form used here is a generalized Lotka–Volterra interaction model:

```text
\[
\frac{dN_i}{dt}
=
N_i
\left(
r_i+\sum_j A_{ij}N_j
\right)
\]
```

Plain-language interpretation: the rate of change of the abundance `N_i` of
population `i` equals its current abundance multiplied by a per-capita growth
term. That term combines an intrinsic growth or decline rate `r_i` with the sum
of signed interaction effects `A_ij` from every other population `j` weighted by
that population's abundance. Positive `A_ij` means population `j` helps
population `i`; negative `A_ij` means it suppresses it (predation, competition,
mutualism).

Equilibria satisfy:

```text
\[
N_i^*
\left(
r_i+\sum_j A_{ij}N_j^*
\right)
=0.
\]
```

Plain-language interpretation: at an equilibrium state `N*`, no population's
abundance changes over time. For each population, either its abundance is zero
(it is absent) or the bracketed per-capita growth term vanishes (gains and
losses balance exactly).

Local stability of an equilibrium is assessed through the Jacobian `J(N*)` of
the growth function evaluated at the equilibrium:

```text
\[
\max\{\operatorname{Re}(\lambda):
\lambda\in\operatorname{eig}(J(N^*))\}<0.
\]
```

Plain-language interpretation: compute all eigenvalues of the Jacobian matrix at
the equilibrium; if the largest real part among them is strictly negative, small
perturbations decay and the equilibrium is locally stable. If any eigenvalue has
a positive real part, perturbations grow and the equilibrium is locally unstable
— a signal that non-equilibrium methods are needed.

These equilibrium models serve as reference baselines only. They do not capture
sustained flux-driven dynamics, disturbance regimes, or open-system
thermodynamics, which motivates the diagnostic below.

## Non-equilibrium thermodynamic diagnostic

Ecosystems are open, driven systems. The core non-equilibrium quantity is the
observed volumetric entropy-production estimate:

```text
\[
\widehat{\Sigma}_{\mathrm{obs}}(t)
=
\sum_{k=1}^{q}J_k(t)X_k(t).
\]
```

Plain-language interpretation: at time `t`, the estimated total entropy
production is the sum over `q` processes of each measured or modelled flux
`J_k(t)` multiplied by its conjugate thermodynamic force `X_k(t)`. Candidate
processes include radiative exchange, sensible and latent heat flux, water-vapor
transport, carbon exchange, and chemical or nutrient gradients, whenever
measurements and physical assumptions are valid. Every component must carry
documented, dimensionally consistent units and propagated uncertainty.

The entropy-production values recorded in research records use the unit
`W K^-1 m^-2`; energy flux components use `W m^-2`; temperature values use `K`;
water-balance values use an explicitly documented local unit.

Interpretation of raw `Σ_obs` alone is prohibited: it depends on constraints,
boundaries, and included processes, and high throughput is not inherently
beneficial.

## Constraint matching

Diagnostics compare like with like. Each record carries a constraint vector
`C(t)` documenting radiative forcing, water availability, temperature boundary,
soil or substrate, vegetation structure, hydrologic connectivity, and
disturbance boundary conditions.

For a documented class of physically admissible states `F(C)` under constraints
`C`, define a constraint-matched feasible envelope:

```text
\[
\Sigma_{\min}^{\mathcal F}(C)
=
\inf \mathcal F(C),
\qquad
\Sigma_{\max}^{\mathcal F}(C)
=
\sup \mathcal F(C).
\]
```

Plain-language interpretation: given the documented constraints, the feasible
envelope spans from the smallest entropy-production value still physically
achievable (`inf`, the infimum) to the largest achievable value (`sup`, the
supremum). Everything inside the envelope is compatible with the constraints;
everything outside signals a problem with the data, the boundaries, or the model.

The normalized diagnostic compares observation against that envelope:

```text
\[
\Phi_{\mathcal F}(t)
=
\frac{
\Sigma_{\max}^{\mathcal F}(C(t))
-
\widehat{\Sigma}_{\mathrm{obs}}(t)
}{
\Sigma_{\max}^{\mathcal F}(C(t))
-
\Sigma_{\min}^{\mathcal F}(C(t))
}.
\]
```

Plain-language interpretation: `Φ_F(t)` measures how far the observed entropy
production sits below the upper edge of what the constraints allow, scaled by
the full width of the allowed range. A value near `0` means the system operates
close to its constraint-imposed ceiling; a value near `1` means it operates
close to the floor; intermediate values sit within the feasible band.

Binding constraints on use:

- `Φ_F` is valid only when the denominator is strictly positive, i.e.
  `Σ_max^F(C(t)) > Σ_min^F(C(t))`. When the envelope is degenerate the
  diagnostic is undefined and must not be reported as a number.
- Values outside the closed interval from `0` to `1` are diagnostic signals of
  uncertainty, boundary mismatch, missing processes, measurement error, or model
  misspecification; do not clip them. Report them verbatim and flag them for
  review.
- High entropy production is not inherently evidence of ecological health.
- A single universal optimum must not be assumed across desert, riparian,
  urban-green, restoration, or other ecosystem contexts. Envelopes are
  context-specific; H3 makes this an explicit testable claim rather than a
  hidden assumption.
- Outputs must be interpreted with biodiversity, hydrology, habitat,
  disturbance, and recovery indicators; never as a standalone verdict.
- The protocol is not an automated decision system and must not be used for
  human, household, community, landholder, or access ranking.

## Required co-indicators

Every thermodynamic diagnostic must be reported alongside these named
co-indicators, each with status, value description, method description, and
uncertainty description:

- `functional_effect_diversity` — breadth of trait-mediated effects organisms
  have on their environment.
- `response_diversity` — variation in species responses to stressors such as
  heat and water deficit; links directly to the functional-redundancy
  assessment schema.
- `water_balance_indicator` — documented local-unit accounting of inputs,
  outputs, and storage.
- `habitat_structure_indicator` — physical structural complexity relevant to
  refuge, nesting, and microclimate.
- `disturbance_history` — documented fire, flood, drought, grazing, construction,
  and management history within the temporal scope.
- `recovery_time_indicator` — documented time to return to acceptable ranges
  after adverse events.
- `quasi_extinction_risk` — probability that abundance falls below a documented,
  non-universal threshold within a stated horizon, computed under the
  Lévy-driven trophic-dynamics specification (`docs/levy_trophic_dynamics_spec.md`).

Thermodynamic findings that contradict co-indicator evidence must be published
and investigated, not suppressed.

## Uncertainty and falsification

Uncertainty handling requirements:

1. Propagate instrument, retrieval, and model uncertainty into every flux
   component and into `Σ_obs`.
2. Document parameter, measurement, boundary, and missing-process uncertainty
   separately; name the dominant contributor.
3. Report feasible-envelope derivation assumptions (`boundary_assumptions`) so
   reviewers can reproduce `Σ_min^F` and `Σ_max^F`.
4. Acceptable quantification methods: `bootstrap`, `bayesian_posterior`,
   `ensemble`, `sensitivity_analysis`, or a documented other method.

Falsification criteria:

- H1 is falsified if constraint-matched diagnostics fail to improve held-out
  prediction of independently documented stress or recovery outcomes across
  pre-registered comparisons.
- H2 is falsified if climate-only, vegetation-only, biodiversity-only, or
  hydrology-only baselines match or exceed the thermodynamic model's predictive
  or explanatory performance.
- H3 is supported (and universal-optimum claims falsified) when distinct
  ecosystem contexts admit materially different valid feasible envelopes.
- Any out-of-range `Φ_F` persisting after boundary and measurement review is
  evidence against the current model specification and must be published as a
  null, mixed, or negative finding. Null, mixed, and negative results are
  required outputs of this program.

## Data minimization and governance

- Collect only the minimum necessary environmental data for the documented
  purpose.
- Exact sensitive habitat coordinates must not be placed in research records;
  spatial scope is limited to a plain-language `area_reference`, a positive
  `spatial_resolution_meters`, and a `sensitivity_class` of `public`,
  `aggregated_only`, or `restricted`.
- No personal, household, biometric, assistive-technology, neural, medical, or
  identity data fields are permitted in these records, and protected attributes
  must not be inferred from ecological observations.
- Retain provenance for instruments, calibrations, transformations, and models.
- Publish only aggregation-safe outputs where site sensitivity could increase
  harvesting, disturbance, or surveillance risk.
- Keep model outputs advisory; separate ecological observations from any
  person-linked data domains.

## Review and publication requirements

Before any external use:

1. Technical review of units, dimensional consistency, envelope derivation, and
   uncertainty propagation.
2. Ecological review of co-indicator interpretation and alternative explanations.
3. Community-governance review where affected or Indigenous communities have
   stakes in the sites or interpretations.
4. Verification that prohibited uses (ranking, automated enforcement, land
   displacement, benefit or service eligibility, protected-attribute inference,
   unreviewed publication of sensitive locations) are excluded from all
   downstream plans.
5. Material changes to constraints, envelope definitions, or interpretation
   rules require re-review; a record is never self-certifying.

Publication requirements: report the full constraint vector, flux-component
breakdown, envelope bounds, out-of-range diagnostics without clipping, all seven
co-indicators, the falsification outcome, and plain-language summaries
alongside technical outputs. Record lifecycle states are `draft`,
`technical_review`, `ecological_review`, `community_review`,
`approved_for_research_use`, and `withdrawn`.
