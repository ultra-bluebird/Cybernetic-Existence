# Constraint-Matched Non-Equilibrium Ecosystem Diagnostic

## Purpose

Define a thermodynamic diagnostic for ecosystem research that is physically
explicit, uncertainty-aware, and paired with ecological indicators.

This diagnostic does not define ecosystem health as a universal scalar and does
not treat maximum entropy production as a settled universal ecological law.

## Research Question

Under matched environmental constraints, do estimated entropy-production
patterns improve explanation or prediction of ecological stress, recovery, and
functional continuity beyond conventional climate, hydrology, and biodiversity
indicators?

## Observed Entropy Production

\[
\widehat{\Sigma}_{obs}(t)
=
\sum_{k=1}^{q} J_k(t)X_k(t).
\]

For each flux `k`:

- `J_k(t)` is a measured or modelled flux;
- `X_k(t)` is its conjugate thermodynamic force;
- units must be documented and dimensionally consistent;
- uncertainty must propagate into `Σ_obs`.

Potential flux categories include radiative exchange, sensible heat, latent
heat, water-vapor transport, carbon exchange, chemical gradients, and nutrient
transport where measurements and physical assumptions are valid.

## Constraint Vector

\[
C(t)=
[
R(t),
W(t),
T(t),
S(t),
V(t),
H(t),
B(t)
].
\]

Where:

- `R(t)`: radiative forcing;
- `W(t)`: water availability;
- `T(t)`: temperature boundary conditions;
- `S(t)`: soil and substrate properties;
- `V(t)`: vegetation structure;
- `H(t)`: hydrologic connectivity;
- `B(t)`: documented management or disturbance boundary conditions.

## Feasible Thermodynamic Envelope

\[
\Sigma_{min}^{\mathcal F}(C)
=
\inf \mathcal F(C),
\qquad
\Sigma_{max}^{\mathcal F}(C)
=
\sup \mathcal F(C).
\]

\[
\Phi_{\mathcal F}(t)
=
\frac{
\Sigma_{max}^{\mathcal F}(C(t))
-
\widehat{\Sigma}_{obs}(t)
}{
\Sigma_{max}^{\mathcal F}(C(t))
-
\Sigma_{min}^{\mathcal F}(C(t))
}.
\]

Interpretation is valid only when:

\[
\Sigma_{max}^{\mathcal F}(C)
>
\Sigma_{min}^{\mathcal F}(C).
\]

Outputs outside `[0, 1]` must be reported as model or measurement diagnostics,
not clipped or silently normalized.

## Required Co-Indicators

Report the thermodynamic diagnostic beside:

- functional effect diversity;
- response diversity under heat and water stress;
- water-balance indicators;
- habitat-structure indicators;
- disturbance history;
- recovery-time indicators;
- uncertainty interval for every derived value.

## Validation Protocol

1. Construct constraint-matched site or time comparisons.
2. Estimate entropy-production components with uncertainty propagation.
3. Test whether `Φ_F` improves held-out prediction of independently observed
   stress or recovery outcomes.
4. Compare against climate-only, vegetation-only, and biodiversity-only models.
5. Publish null, mixed, and negative findings.
6. Do not interpret high entropy production alone as ecological health.

## Prohibited Claims

This diagnostic must not be used to claim that:

- all ecosystems optimize entropy production;
- one thermodynamic value defines universal ecological health;
- high throughput is inherently beneficial;
- a thermodynamic estimate proves restoration success without ecological evidence;
- modeled values justify displacement, exclusion, or automated decisions about
  communities or access to land and services.

## Data Governance

- Use documented, purpose-limited environmental data.
- Apply site-sensitivity protections to vulnerable habitats.
- Retain provenance for instruments, calibrations, transformations, and models.
- Separate ecological observations from personal, household, biometric, or
  assistive-technology data.
- Require human scientific and community-governance review before external use.
