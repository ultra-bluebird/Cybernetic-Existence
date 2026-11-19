# Scientific Computing Without Requiring MATLAB

## Purpose

Advanced environmental mathematics does not require a proprietary or
math-specialized language. The scientific requirement is a transparent model:

    output = f(inputs, assumptions, units, uncertainty)

A model becomes useful evidence when it preserves units, validates measurement
ranges, records assumptions, propagates uncertainty, compares alternatives, and
reports both favorable and unfavorable outcomes.

The Augmented-Hub approach uses a language-independent scientific kernel:

1. Define the physical system.
2. Define measurable quantities and units.
3. State conservation laws and constraints.
4. Encode the model in a reviewable language.
5. Run deterministic and uncertainty-aware scenarios.
6. Publish inputs, assumptions, outputs, limitations, and audit records.
7. Keep human and community review outside automated decision output.

## Language-Independent Pattern

A scientific function should have five layers.

### Inputs

Every input has:

- a physical meaning;
- a unit;
- a valid range;
- a source or measurement method;
- an uncertainty estimate;
- a timestamp and calibration state where applicable.

Example:

    specific_humidity: kg water / kg air
    east_wind: m / s
    north_wind: m / s
    pressure_depth: Pa
    pumping_head: m
    flow_rate: m^3 / s
    electric_carbon_intensity: kg CO2e / kWh

### Equations

Integrated vapor transport is represented as:

    IVT_x = (1 / g) * sum(q_k * u_k * delta_p_k)

    IVT_y = (1 / g) * sum(q_k * v_k * delta_p_k)

    IVT_magnitude = sqrt(IVT_x^2 + IVT_y^2)

Pumping power is represented as:

    P_hydraulic = rho * g * Q * H

    P_electric = P_hydraulic / eta

Delivered volume is represented as:

    V_delivered = V_sent * (1 - leakage_fraction)

A model must state that IVT is an observation of natural atmospheric moisture
transport. It is not a mechanism for commanding clouds, creating rainfall, or
redirecting wind.

### Constraints

A valid computation has boundaries:

    0 <= specific_humidity <= physical_upper_bound
    0 < pressure_depth
    0 < pump_efficiency <= 1
    0 <= leakage_fraction < 1
    delivered_volume > 0

When an invariant fails, the model must return an explicit invalid state rather
than inventing a plausible-looking result.

### Uncertainty

For a measurement model:

    Y = f(X_1, X_2, ..., X_n)

inputs are represented as uncertain quantities rather than perfect facts:

    X_i ~ distribution(mean_i, uncertainty_i)

Monte Carlo uncertainty propagation estimates output distributions:

    For each simulation:
        sample X_1, X_2, ..., X_n
        compute Y = f(X_1, X_2, ..., X_n)

    Report:
        median(Y)
        lower_quantile(Y)
        upper_quantile(Y)
        probability_of_constraint_violation

The result should never be reduced to one precise-looking value when measurements
or model assumptions are uncertain.

### Decision-support output

A scientific model may recommend investigation or preparation. It must not
automatically authorize water diversion, public release, ecological discharge,
weather modification, or restriction of essential services.

## General-Purpose Implementation Options

### Lua

Lua is suitable for:

- embedded sensors and controllers;
- bounded arithmetic;
- safety corridors;
- field-device logic;
- compact local calculations;
- auditable policy gates.

Use `math.huge` only as an explicit unreachable, invalid, or unbounded sentinel.
Never treat it as a valid physical measurement.

### Python

Python is suitable for:

- data cleaning;
- reproducible notebooks;
- scenario ensembles;
- statistical analysis;
- geospatial data processing;
- report generation.

A project can use only the standard library for small kernels or established
scientific libraries when a reproducible environment is documented.

### Rust

Rust is suitable for:

- type-safe physical-unit models;
- high-assurance simulation kernels;
- long-running services;
- signed provenance;
- memory-safe field and edge applications;
- formal or property-based testing.

### JavaScript or TypeScript

TypeScript is suitable for:

- accessible public dashboards;
- interactive scenario explorers;
- client-side visual explanations;
- offline-first community information tools.

### SQL

SQL is suitable for:

- immutable measurement ledgers;
- water and energy balance aggregation;
- audit queries;
- data-quality enforcement;
- reproducible reporting.

## Evidence Ladder

A robust earth-saving concept develops through stages:

1. Conceptual model
   - Defines mechanism, boundaries, harms, benefits, and falsifiable hypotheses.

2. Dimensional and conservation validation
   - Checks that all equations preserve units and mass-energy accounting.

3. Synthetic-data simulation
   - Tests edge cases, impossible conditions, missing data, and extreme weather.

4. Bench measurement
   - Validates one physical subsystem under controlled conditions.

5. Field pilot
   - Measures real outcomes against a matched baseline.

6. Independent replication
   - Tests whether measured results generalize beyond one site or operator.

7. Public-interest deployment review
   - Compares benefit, cost, equity, ecological effect, accessibility, and
     uncertainty before any scale decision.

A model is valuable before final proof because it makes assumptions visible,
finds failure modes early, and produces testable predictions. It becomes
evidence only through measurement and replication.

## Metrics

knowledge_factor: 0.88
Basis: the methodology uses established conservation laws, numerical analysis,
measurement uncertainty, and reproducibility practices.

eco_impact_value: 0.87
Basis: it prevents unsupported scale claims and prioritizes comparative,
measured ecological benefit.

harm_risk: 0.18
Basis: remaining risk arises from wrong assumptions, incomplete data, and
misuse of simulations; explicit uncertainty and review gates reduce this risk.

accessibility_impact: 0.90
Basis: general-purpose languages and transparent documents lower barriers to
participation and can support accessible public interfaces.

rights_alignment: 0.93
Basis: the framework minimizes data collection, prohibits autonomous high-impact
action, and requires transparent, reviewable decision support.
