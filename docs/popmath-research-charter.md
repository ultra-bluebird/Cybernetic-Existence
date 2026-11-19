# Population.Math and `popmath` Research Charter

## Purpose

This charter defines the initial research program for Population.Math and the Rust crate `crates/popmath`.

Population.Math is a mathematical foundation for transparent, reproducible, privacy-preserving civic and ecological scenario analysis. The crate will support calculations involving transportation, transit, construction logistics, water supply, energy resilience, maintenance capacity, aggregate growth, public-service demand, lifecycle cost, ecological accounting, accessibility, and uncertainty.

`popmath` is an analysis kernel. It does not determine a person’s eligibility, civic standing, public-service access, health outcome, housing status, employment status, or worthiness. It does not implement surveillance, social scoring, behavioral manipulation, identity inference, or autonomous operational control.

The research program must produce implementation-ready evidence for each dependency, algorithm, data boundary, model assumption, and validation method before those capabilities enter the stable crate API.

## Research Principles

- Use explicit units, bounded values, time scopes, and model assumptions.
- Accept public, synthetic, aggregate, or independently consent-authorized inputs only.
- Reject sensitive person-level data by default, including neural, biometric, health, augmentation, persistent location-history, and identity-linked mobility data.
- Treat accessibility, offline access, service continuity, equal treatment, ecological constraints, and human review as mathematical and governance requirements.
- Keep the mathematical core deterministic by default.
- Require explicit seeds for stochastic simulation and report seeds in all stochastic outputs.
- Retain alternatives and tradeoffs in optimization instead of exposing a single lowest-cost answer.
- Distinguish measurement, forecast, simulation, scenario assumption, and policy choice.
- Make every material output reproducible through provenance, configuration, and result digests.
- Keep external solver, geospatial, serialization, and WebAssembly integrations optional.
- Do not represent a model outcome as a binding civic decision or legal conclusion.

## Research Deliverables

Every research workstream must produce the following artifacts before implementation is accepted:

| Deliverable | Required content |
|---|---|
| Research note | Question, scope, sources, findings, limitations, and recommendation |
| Decision record | Chosen approach, alternatives considered, rationale, risks, compatibility, and review date |
| Threat and misuse analysis | Privacy risks, accessibility risks, equity risks, ecological risks, and prohibited-use checks |
| Interface specification | Typed inputs, outputs, units, error conditions, provenance requirements, and serialization boundary |
| Validation plan | Unit tests, property tests, reference cases, range tests, and reproducibility checks |
| Benchmark plan | Dataset class, input scale, latency target, memory target, and deterministic-output check |
| Integration contract | Optional feature flags, dependency surface, target compatibility, and downgrade behavior |
| Rights and ecology assessment | `knowledge_factor`, `eco_impact_value`, `harm_risk`, `accessibility_impact`, and `rights_alignment` with a documented basis |

No dependency, solver, external data adapter, or computation path should be introduced solely because it is popular or convenient. Each must earn inclusion through compatibility with the crate’s safety, reproducibility, portability, licensing, and audit requirements.

## Priority One: Units and Numerical Foundation

### Research objective

Select and validate the dimensional-analysis approach for `src/units.rs`, `src/bounds.rs`, and their relationship to domain modules.

This is the highest-priority work because every later model depends on correct units, conversions, finite values, range validation, interval semantics, and numerical behavior.

### Candidate direction

The leading candidate is `uom`, a Rust crate providing type-safe, zero-cost dimensional analysis with predefined SI and ISQ quantity systems and numerous conversion factors. Its design directly addresses the core risk of mixing incompatible physical dimensions such as length, mass, time, energy, flow, and power. [68][70]

`popmath` should evaluate `uom` as a foundation for physical quantities while retaining its own public wrappers for:

- Data validation.
- Civic and ecological domain naming.
- Financial quantities.
- Currency codes and integer minor units.
- Carbon-dioxide-equivalent accounting boundaries.
- Provenance-aware conversion factors.
- Serialization shapes.
- Human-readable units.
- Bounded ratios, probabilities, and intervals.
- Public API stability.

The crate should not expose a dependency’s entire type system as an unqualified permanent public contract unless compatibility and maintenance evaluation supports that commitment.

### Required research questions

- Does `uom` support all initial physical dimensions needed by `popmath`, including mass, volume, flow, area, distance, speed, time, power, energy, temperature, pressure, density, and concentration?
- Can the crate preserve ergonomic model APIs while avoiding excessive generic complexity?
- Does the selected approach compile successfully for the expected native and WebAssembly targets?
- What binary-size and compile-time costs arise under default, serialization, and WebAssembly profiles?
- How will units serialize in a stable and explicit form?
- How will currency be represented separately from physical unit arithmetic?
- How will emissions be represented so that `kgCO2e` cannot be silently confused with physical carbon mass?
- Which values permit negative quantities, and which must remain finite, non-negative, positive, or within the unit interval?
- How will conversion factors that depend on location, date, policy, or methodology carry provenance?
- How can typed quantities interoperate with solver APIs that normally consume scalar coefficient arrays?

### Required proof-of-concept

The units study must build a small non-production prototype that demonstrates:

- Volume balance using cubic meters and liters.
- Water flow multiplied by duration producing volume.
- Power multiplied by duration producing energy.
- Concentration multiplied by volume producing mass.
- Hydraulic power using density, gravity, flow, and head.
- Distance divided by time producing speed.
- Rejection of non-finite numeric values.
- Rejection of incompatible dimensions at compile time where supported.
- Explicit currency representation using integer minor units and currency codes.
- Explicit emissions representation using a declared carbon-accounting boundary.
- Stable JSON representation with `value` and `unit` fields.
- A minimal WebAssembly compilation check.

### Acceptance criteria

The selected unit approach is acceptable only when it demonstrates:

- No silent dimension conversion.
- No bare-number representation at the public boundary for physical quantities.
- Explicit and tested unit conversion.
- Clear compiler diagnostics or structured runtime diagnostics for invalid construction.
- Native and WebAssembly compatibility for the required core.
- A stable serialization strategy.
- A documented policy for currency, emissions, ratios, and unit-bearing intervals.
- Property tests covering conservation and conversion behavior.

### Initial implementation boundary

The first stable unit set should support:

| Quantity family | Canonical representation |
|---|---|
| Mass | Kilogram |
| Volume | Cubic meter |
| Flow rate | Cubic meter per second |
| Area | Square meter |
| Distance | Meter |
| Speed | Meter per second |
| Duration | Second |
| Power | Watt |
| Energy | Joule and kilowatt-hour conversion |
| Temperature | Celsius at input boundaries, kelvin for absolute thermodynamic use |
| Pressure | Pascal |
| Density | Kilogram per cubic meter |
| Concentration | Kilogram per cubic meter or explicitly typed alternatives |
| Currency | Integer minor unit with ISO currency code |
| Emissions | Kilogram carbon-dioxide-equivalent plus accounting boundary |
| Population | Integer count and non-negative aggregate weight |
| Probability | Unit interval |
| Ratio | Explicit bounded or unbounded ratio type |

## Priority Two: Governance, Privacy, and Result Integrity

### Research objective

Complete the governance, provenance, scenario, and result-envelope contracts before large domain modules are implemented.

The relevant foundational modules are:

- `src/provenance.rs`
- `src/governance.rs`
- `src/scenario.rs`
- `src/result.rs`
- `src/error.rs`
- `src/time.rs`
- `src/bounds.rs`

### Governance lifecycle

`popmath` should organize its research and implementation lifecycle around the NIST AI Risk Management Framework functions:

- **Govern:** accountability, purpose, policies, review roles, documentation, and prohibited uses.
- **Map:** intended context, affected systems, stakeholders, benefits, risks, data scope, assumptions, and boundaries.
- **Measure:** data quality, validation, uncertainty, sensitivity, accessibility effects, ecological effects, and harm indicators.
- **Manage:** mitigation, scenario alternatives, human review, monitoring, correction paths, and restrictions on downstream use.

NIST describes the AI RMF as a framework for managing risks to individuals, organizations, and society, and its core structure uses the Govern, Map, Measure, and Manage functions. [53][55]

The framework is an engineering and governance reference point. It does not transform `popmath` into a legal authority or make model outputs legally enforceable.

### Required governance research questions

- What minimum provenance fields are necessary to decide whether an input is public, synthetic, aggregate, consent-authorized, restricted, sensitive, or prohibited?
- What aggregation declaration is required before a model may calculate public-service access, demand, or parity outcomes?
- How should the crate represent data transformations without retaining secrets or raw personal records?
- Which result classes require technical, accessibility, ecological, community, data-stewardship, or authorized human review?
- How should the crate distinguish an analytical result from a planning recommendation and an approved operational action?
- What prohibited-use declarations should be immutable in serialized results?
- How should the crate record correction and appeal references supplied by a consuming application?
- How should confidence intervals, scenario ranges, prediction intervals, and qualitative uncertainty be represented without conflation?
- What digest inputs are necessary for reproducibility while avoiding leakage of sensitive content?
- How will consumer applications prevent an optimization result from bypassing human review or a hard accessibility constraint?

### Required policy contract

Each material scenario must be capable of declaring:

- A specific purpose.
- Permitted downstream uses.
- Prohibited downstream uses.
- Data classes allowed.
- Data classes prohibited.
- Minimum aggregation or privacy condition.
- Geographic scope.
- Time scope.
- Retention and deletion policy reference.
- Accessibility requirements.
- Continuity requirements.
- Ecological boundaries.
- Review requirements.
- Decision boundary.
- Correction or appeal route reference supplied by the application.

### Non-negotiable prohibited uses

The governance research must preserve explicit prevention of:

- Resident-level social scoring.
- Behavioral scoring.
- Predictive enforcement.
- Identity inference.
- Biometric, neural, health, or augmentation profiling.
- Persistent personal mobility tracking.
- Automated denial of public services.
- Automated eligibility adjudication.
- Housing, employment, credit, healthcare, education, immigration, voting, or public-participation determination.
- Mandatory biometric identity for ordinary public-service access.
- Mandatory device telemetry for essential service access.
- Silent constraint relaxation.
- Hidden model weights or undocumented optimization objectives.
- Autonomous control of civic infrastructure without externally governed approval.

### Result integrity requirements

Every material `popmath` result must include:

- Calculation name and semantic version.
- Scenario name, scope, and purpose.
- Source and transformation provenance.
- Time basis.
- Geographic and accounting boundary.
- Units.
- Inputs digest.
- Assumptions.
- Constraints.
- Solver configuration if applicable.
- Validation status.
- Feasibility status.
- Uncertainty method and interval where applicable.
- Sensitivity summary.
- Accessibility impact.
- Rights-impact summary.
- Ecological-impact summary.
- Review requirement.
- Warnings and limitations.
- Reproducibility digest.

### Acceptance criteria

The governance and result foundation is ready only when:

- A public aggregate water-balance scenario is accepted and produces a fully attributed result.
- A synthetic accessible-transit scenario is accepted and preserves hard access constraints.
- A person-level persistent mobility input is rejected.
- A neural, biometric, health, or augmentation-telemetry input is rejected.
- A social-scoring purpose is rejected.
- A hard accessibility constraint cannot be silently relaxed.
- An uncertain result cannot be reported as certain.
- A stochastic result includes an explicit random seed.
- A result changes its reproducibility digest when a material assumption changes.
- Error outputs remain useful without exposing sensitive values.

## Priority Three: Optimization and Solver Architecture

### Research objective

Define a solver-neutral optimization layer before selecting or integrating solver backends.

The crate must be capable of describing routing, delivery assignment, transit allocation, water dispatch, energy storage dispatch, maintenance scheduling, service capacity, and construction staging problems without permanently binding all downstream users to one solver.

### Design decision to research

The default research direction is:

1. Define a `popmath` solver-neutral model representation.
2. Implement direct deterministic algorithms for small or closed-form cases.
3. Add optional solver adapters only after validating licensing, platform support, determinism, numerical behavior, maintenance quality, and result explainability.
4. Preserve common `OptimizationResult`, `SolverStatus`, `InfeasibilityExplanation`, and `AlternativeSet` structures independent of backend.

`good_lp` is an appropriate candidate for evaluation as a Rust-facing mathematical-programming abstraction, but it must be evaluated as one option among multiple solver strategies rather than adopted by name alone.

### Required solver research questions

- Which problem classes are required in the first two releases: shortest path, min-cost flow, linear programming, mixed-integer linear programming, vehicle routing, scheduling, nonlinear optimization, or simulation-assisted optimization?
- Which classes can be solved directly with in-crate algorithms?
- Which classes need an external solver?
- Can an external solver run in native, offline, and WebAssembly targets?
- What licensing obligations arise from each solver and backend?
- Does a solver provide deterministic output under a fixed seed and fixed configuration?
- Can the crate obtain infeasibility diagnostics, objective gaps, constraint violations, and alternative solutions?
- Can solver results be independently validated using `popmath` typed units and constraints?
- Can a solver preserve hard accessibility, privacy, ecological, and service-continuity constraints?
- How will numerical tolerances be declared and surfaced in outputs?
- How will multi-objective tradeoffs be retained and explained?

### Required optimization abstractions

The optimization research must define stable representations for:

- Decision variable.
- Variable domain.
- Objective function.
- Objective direction.
- Objective priority.
- Hard constraint.
- Soft constraint.
- Constraint relation.
- Constraint source.
- Constraint relaxation policy.
- Solver configuration.
- Solver status.
- Feasibility status.
- Infeasibility explanation.
- Optimality gap.
- Alternative solution.
- Pareto frontier.
- Independent post-solve validation.

### Required proof-of-concept cases

The solver study must model and validate at least these synthetic, non-sensitive cases:

| Case | Required constraints | Required outputs |
|---|---|---|
| Delivery capacity | Vehicle mass, volume, work windows, service time, crew capacity | Feasibility, load count, time capacity, fuel and emissions estimate |
| Accessible route alternative | Network connectivity, declared accessibility edges, closure, travel-time limit | At least one feasible accessible path or a clear infeasibility explanation |
| Water dispatch | Storage capacity, inflow, demand, ecological-flow floor, recovery supply | Shortage, spill, ecological constraint status, scenario alternatives |
| Energy storage | Charge rate, discharge rate, capacity, efficiency, critical-load reserve | Unserved energy, curtailed energy, critical-load continuity |
| Public-service capacity | Arrival rate, service rate, staffing ceiling, service-level floor | Utilization, stability status, minimum capacity gap |

### Acceptance criteria

An optimization adapter or algorithm may enter the crate only when it can:

- Preserve units and constraint metadata.
- Report feasibility separately from optimality.
- Report solver gap or limit status.
- Preserve hard constraints.
- Surface soft-constraint deviations.
- Provide post-solve validation.
- Return an interpretable infeasibility record.
- Return multiple alternatives when the problem class supports them.
- Include a stable configuration record in the result digest.
- Operate within the declared feature and platform boundary.

## Priority Four: Ecological, Water, Energy, and Carbon Accounting

### Research objective

Define physically consistent, auditable methods for water, energy, emissions, materials, heat, and ecological impact before implementing composite eco-impact indicators.

The project’s existing research already identifies a strong foundation: wind and hydraulic power can be compared through shared watt units, and pollutant mass removal can be calculated from concentration difference, flow, and time. These patterns support independently auditable environmental accounting when units, sensor quality, time basis, and boundaries are explicit. [51]

### Core mathematical foundations

Water storage:

\[
S_{t+1}
=
S_t
+
I_t
-
D_t
-
L_t
-
E_t
+
R_t
\]

Where:

- \(S_t\) is stored water volume.
- \(I_t\) is inflow.
- \(D_t\) is demand.
- \(L_t\) is measured or modeled loss.
- \(E_t\) is evaporation or defined environmental loss.
- \(R_t\) is recovered, reclaimed, or transferred supply.

Hydraulic power:

\[
P_{\text{hydro}}
=
\rho g Q H
\]

Where:

- \(\rho\) is water density.
- \(g\) is gravitational acceleration.
- \(Q\) is flow rate.
- \(H\) is hydraulic head.
- \(P_{\text{hydro}}\) is power.

Energy storage:

\[
B_{t+1}
=
\min
\left(
B_{\max},
B_t
+
\eta_c C_t
-
\frac{G_t}{\eta_d}
\right)
\]

Where:

- \(B_t\) is stored energy.
- \(B_{\max}\) is storage capacity.
- \(C_t\) is charge energy.
- \(G_t\) is delivered energy.
- \(\eta_c\) and \(\eta_d\) are charge and discharge efficiencies.

Pollutant mass removal:

\[
M_x
=
\int_0^T
\left(
C_{\text{in},x}(t)
-
C_{\text{out},x}(t)
\right)
Q(t)\,dt
\]

Where:

- \(M_x\) is pollutant mass removed.
- \(C_{\text{in},x}\) and \(C_{\text{out},x}\) are inlet and outlet concentrations.
- \(Q(t)\) is volumetric flow.
- \(T\) is the measurement interval.

Lifecycle cost:

\[
LCC
=
C_0
+
\sum_{t=1}^{T}
\frac{
C_t^{\text{operations}}
+
C_t^{\text{maintenance}}
+
C_t^{\text{replacement}}
+
C_t^{\text{externality}}
}{
(1+r)^t
}
\]

### Required ecological research questions

- Which emissions-factor datasets and lifecycle boundaries are appropriate for an initial general-purpose API?
- How should an emissions factor record include source, version, geography, time validity, fuel or material definition, and uncertainty?
- How should the crate distinguish measured emissions from estimated emissions and avoided emissions?
- How should water-quality concentration units, detection limits, censored observations, and calibration records be represented?
- How should mass balance handle missing telemetry, irregular time steps, and uncertainty propagation?
- How should the crate represent ecological flow as a hard or review-required constraint?
- How should material reuse, recycled content, waste diversion, and end-of-life assumptions be represented?
- Which heat-mitigation models are appropriate for a first release, and which require site-specific calibration before inclusion?
- What claims require field validation rather than only model calculation?
- How should ecological metrics be shown without allowing environmental benefit claims to justify reduced access, surveillance, discrimination, or loss of rights?

### Accounting boundary policy

Every ecological or carbon result must declare:

- Functional unit.
- Geographic scope.
- Time horizon.
- Included lifecycle stages.
- Excluded lifecycle stages.
- Data source or factor source.
- Calculation method.
- Measurement versus model status.
- Uncertainty method.
- Externalities not included.
- Monitoring or field-validation requirement.

### Acceptance criteria

Ecological modules are ready for stable release only when:

- Conservation of mass and energy properties are property-tested.
- Every emissions estimate includes an accounting boundary.
- Every emissions factor has provenance and validity period.
- Water balance distinguishes potable, reclaimed, ecological, emergency, and transfer categories where applicable.
- Pollutant mass balance preserves contaminant identity and measurement units.
- Results distinguish measured, modeled, and avoided impacts.
- Ecological-flow constraints cannot disappear from optimization output.
- Uncertainty and missing-data treatment are reported.
- No composite score hides its component measures, weights, or limitations.

## Priority Five: Mobility, Accessibility, and Infrastructure Logistics

### Research objective

Develop a mathematically credible, accessibility-first foundation for routing, transit, construction delivery, maintenance access, and public-service coverage.

The initial models must use network facts and aggregate demand, not individual mobility surveillance.

Open multimodal routing ecosystems demonstrate the usefulness of open data standards. OpenTripPlanner is an open-source multimodal trip planner that relies on open standard formats including GTFS and OpenStreetMap and provides route-planning APIs. [57][58][66]

### Required mobility research questions

- Which network representation supports roads, sidewalks, bicycle routes, transit links, freight access, and service corridors without conflating their accessibility properties?
- Which infrastructure attributes are necessary for a declared accessible path: step-free continuity, grade, surface, width, curb ramps, crossing availability, lighting, shade, outage or closure status, and service-hour compatibility?
- How should unknown accessibility attributes be represented: unavailable, unknown, assumed, or requires verification?
- How should access requirements be represented as hard constraints rather than merely route penalties?
- What aggregate origin-destination model preserves privacy while supporting service-access calculations?
- How should travel-time uncertainty, closure risk, heat exposure, and transfer reliability be represented?
- What open formats can be accepted at adapters: GTFS, GTFS-Realtime, GeoJSON, OpenStreetMap-derived graphs, and non-identifying road inventories?
- How should construction staging, vehicle load, work zone, accessible-path continuity, emergency access, and delivery windows coexist in one logistics model?
- How should fuel, idle time, emissions, and delay costs be attributed without presenting uncertain estimates as measurement?
- Which outputs are appropriate for public reporting versus internal planning?

### Accessibility rule

For public-service routing and coverage, `popmath` must distinguish:

- A route that exists.
- A route that is traversable.
- A route that is accessible under declared requirements.
- A route that remains accessible through the full journey, including transfers, crossings, payment, information, and fallback support.
- A service that remains reachable during outage, heat, construction, and closure scenarios.

A shortest path is not automatically an accessible path.

### Required proof-of-concept cases

The mobility workstream must produce synthetic examples for:

- A route with a shorter inaccessible path and a longer accessible path.
- A closure that removes step-free continuity and triggers an access warning.
- A transit itinerary with a transfer reliability constraint.
- A construction delivery plan that preserves emergency and accessible pedestrian access.
- An aggregate service-coverage analysis with declared travel-time and cost thresholds.
- A heat-aware walking scenario where exposure is represented as an explicit model factor rather than assumed invisible.

### Acceptance criteria

Mobility and logistics capabilities are ready when they:

- Preserve declared accessibility constraints.
- Treat unknown access conditions as unknown rather than silently accessible.
- Do not require person-level location histories.
- Use aggregate or synthetic demand.
- Report travel-time, cost, emissions, and access tradeoffs.
- Retain alternatives.
- Explain infeasibility.
- Preserve work-zone and emergency-access conditions.
- Support explicit public-data adapter boundaries.
- Keep routing computation separate from vehicle or infrastructure actuation.

## Priority Six: Performance, Portability, and WebAssembly

### Research objective

Establish a performance and portability strategy that allows `popmath` to execute reliably in native services, offline tools, command-line workflows, and browser-based interfaces without weakening validation, privacy, accessibility, or reproducibility.

Rust and WebAssembly are a suitable research direction for local-first scenario tools. `wasm-bindgen` is designed to facilitate high-level interaction between Rust WebAssembly modules and JavaScript, and it generates bindings and glue for exported Rust functions and imports in use. [69][71]

### Required runtime research questions

- Which foundational modules compile cleanly to `wasm32-unknown-unknown`?
- Which dependencies must remain optional because they rely on native libraries, filesystem access, threads, or unsupported runtime features?
- What is the maximum acceptable WebAssembly package size for an accessible public scenario explorer?
- Which calculations can execute locally without exposing data to a server?
- How will serialization and validation behave consistently across native and browser targets?
- How will deterministic result ordering be preserved under parallel execution?
- Which data volumes require chunking, streaming, tiling, or server-side aggregation?
- What is the memory behavior for long water, energy, traffic, and simulation horizons?
- What benchmark sizes represent city, district, corridor, and project-site use cases?
- How will a browser interface present long-running computation without inaccessible timers, hidden state, or blocking interaction?
- How will offline calculations preserve provenance and later synchronize only with explicit user approval?

### WebAssembly boundary

The initial WebAssembly target should include only:

- Units.
- Bounds.
- Time.
- Provenance validation.
- Scenario validation.
- Deterministic water balance.
- Deterministic energy storage balance.
- Queue capacity screen.
- Lifecycle-cost calculation.
- Aggregate service-access calculation.
- Result-envelope serialization.
- Reproducibility digest generation.

Large solvers, native geospatial engines, and heavy simulations should remain optional or run in a separately reviewed environment until compatibility and size requirements are verified.

### Performance acceptance criteria

Performance research is complete for an initial release when:

- Core deterministic calculations compile for native and WebAssembly targets.
- All supported targets return equivalent results for the same inputs.
- WebAssembly builds do not weaken provenance, validation, governance, or result-envelope requirements.
- Benchmarks state dataset size, hardware or browser context, execution time, memory use, and crate version.
- Parallel execution preserves deterministic externally visible output ordering.
- Long-running computations can expose progress through a caller-controlled mechanism without leaking sensitive model inputs.
- The crate continues to operate with no network dependency.

## Prioritized Implementation Roadmap

### Foundation release

Implement and verify:

- `error`
- `bounds`
- `units`
- `time`
- `provenance`
- `governance`
- `scenario`
- `result`
- Deterministic reproducibility digests
- Core validation tests
- Serialization feature
- Minimal WebAssembly compatibility test

### First calculation release

Implement and verify:

- Water storage balance.
- Energy storage balance.
- Hydraulic power.
- Pollutant mass-balance primitive.
- Queue utilization and stability screen.
- Lifecycle-cost primitive.
- Delivery capacity screen.
- Fuel and emissions estimate.
- Aggregate service-access index.
- Accessibility and ecological result metadata.
- Synthetic reference cases and property tests.

### Planning and optimization release

Implement and verify:

- Solver-neutral optimization representation.
- Route and network primitives.
- Capacity and allocation constraints.
- Post-solve validation.
- Infeasibility explanation.
- Alternative set and Pareto frontier representation.
- First optional solver adapter.
- Accessibility-preserving route and logistics scenarios.

### Simulation and scale release

Implement and verify:

- Seeded Monte Carlo interfaces.
- Sensitivity analysis.
- Time-series simulation.
- Discrete-event capacity models.
- Performance benchmarks.
- WebAssembly scenario explorer core.
- Large-scale aggregate scenario fixtures.

## Required Research Register

Every completed research decision must be recorded in a structured register with:

| Field | Description |
|---|---|
| Topic | The component, algorithm, dependency, or policy question |
| Decision | Selected approach |
| Status | Proposed, under evaluation, accepted, deferred, or rejected |
| Evidence | Source references, prototype findings, benchmarks, and tests |
| Alternatives | Options considered and reason for non-selection |
| Compatibility | Rust version, platforms, feature flags, and licensing |
| Risks | Technical, privacy, accessibility, ecological, and governance risks |
| Mitigations | Controls, validation, review, and fallback plans |
| Review date | Date or release condition for reconsideration |
| Owner role | Maintainer, reviewer, accessibility reviewer, ecological reviewer, or community review role |

## Quality Gates

A capability is not ready to move from research into the stable API unless it satisfies all applicable gates:

- Mathematical validity.
- Unit correctness.
- Bounded-input validation.
- Time-basis clarity.
- Provenance requirements.
- Privacy and aggregation requirements.
- Purpose and prohibited-use compatibility.
- Accessibility impact declaration.
- Ecological impact declaration.
- Human-review requirement declaration.
- Reproducibility record.
- Test coverage.
- Error behavior.
- Serialization stability.
- Target compatibility.
- Documentation.
- License compatibility.
- No hidden operational action.

## Initial Research Metrics

- `knowledge_factor`: 0.95  
  Basis: the charter converts broad architectural goals into concrete questions, proof-of-concepts, acceptance criteria, outputs, and quality gates.

- `eco_impact_value`: 0.92  
  Basis: water, energy, emissions, materials, pollution mass, heat, restoration, and ecological-flow constraints are direct research priorities with explicit accounting boundaries.

- `harm_risk`: 0.10  
  Basis: the research boundary rejects person-level sensitive data, social scoring, automated deprivation, hidden optimization tradeoffs, and unreviewed operational control.

- `accessibility_impact`: 0.97  
  Basis: accessible paths, complete journeys, offline and manual alternatives, continuity, and accessibility review are required model properties rather than optional enhancements.

- `rights_alignment`: 0.98  
  Basis: the charter embeds purpose limitation, data minimization, non-discrimination, explainability, reviewability, correction paths, transparency, and human oversight throughout the research and implementation lifecycle.
