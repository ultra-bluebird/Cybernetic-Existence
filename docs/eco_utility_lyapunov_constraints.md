# Eco-Utility Lyapunov Constraints

## Scope

This specification defines constraints under which eco-utility can be used as a
bounded optimization signal within a restoration decision-support loop.

It does not prove ecological stability, environmental benefit, machinery safety, or
regulatory compliance. A Lyapunov claim requires a validated state model, defined
operating domain, calibrated measurements, and review of the specific control policy.

## Eco-utility

`U_eco = (E_restored * W_ecosystem) / (E_compute + E_machine)`

The denominator MUST satisfy:

`E_compute + E_machine >= E_min > 0`

where `E_min` is a declared positive metering floor that prevents division by zero
and prevents a low-energy or failed-machine state from producing undefined utility.

## Restoration error state

The control loop MUST define a finite-dimensional normalized ecological error state:

`x = [x_1, x_2, ..., x_m]^T`

Each `x_j` MUST have:

- an explicit physical meaning;
- a declared unit before normalization;
- a target or safe operating range;
- a source-quality and uncertainty record;
- a declared valid range;
- a documented action boundary.

Example state components may represent bounded deviation in contaminant concentration,
water temperature, hydraulic residence time, dissolved oxygen, salinity, habitat
indicator, or process nuisance. Selection is deployment-specific.

## Lyapunov candidate

The candidate storage function is:

`V(x) = x^T P x`

where `P` is symmetric positive definite.

The implementation MUST verify, for every selected `P`:

- symmetry;
- positive definiteness;
- stable unit normalization;
- no use of personal, biometric, neural, identity, or governance-status inputs.

## Ecosystem weight constraints

`W_ecosystem(x)` MUST:

- be finite for all admissible states;
- be bounded: `0 < W_min <= W_ecosystem(x) <= W_max < infinity`;
- depend only on documented ecological state, uncertainty, and approved community or
  environmental-priority parameters;
- use non-negative weights for ecological-deviation penalties;
- be independent of operator identity, public status, private governance references,
  communication mode, or eligibility attributes;
- be versioned and reviewed when its component weights or normalizers change;
- include a measurement-quality gate so uncertain or missing observations cannot
  inflate the claimed ecological benefit.

A valid bounded form is:

`W_ecosystem(x) = clip(W_min + sum_j(a_j * x_j^2), W_min, W_max)`

with `a_j >= 0`.

## Required descent condition

The control-policy analysis MUST establish, for all admissible states and bounded
disturbances:

`V(x_next) - V(x) <= -alpha * ||x||^2 + gamma * ||w||^2`

where:

- `alpha > 0`;
- `gamma >= 0`;
- `w` represents explicitly bounded disturbance;
- the admissible region is stated.

The controller MUST reject or escalate a proposed action when the estimated upper
bound fails this descent condition.

## Relationship to eco-utility

`U_eco` is an optimization objective, not the Lyapunov function.

A proposed action may be considered only when all conditions hold:

1. `E_restored` is measured or estimated with declared uncertainty.
2. The energy denominator is measured and exceeds `E_min`.
3. `W_ecosystem` satisfies the bounded and provenance requirements.
4. The action preserves the declared Lyapunov descent condition.
5. The action complies with independent process, safety, consent, and human-review
   gates.

No maximization of `U_eco` may override a failed descent, safety, legal, privacy,
or human-review gate.

## Reporting rule

Reports MUST separately state:

- observed restoration measurement;
- modeled restoration estimate;
- compute energy;
- machine energy;
- ecosystem-weight version;
- uncertainty;
- Lyapunov candidate revision;
- controller decision;
- rejected actions and their reason.

The phrase “Lyapunov-stable” MUST NOT be used unless the deployment-specific descent
condition, model domain, measurement assumptions, and disturbance bounds are retained
with the result.
