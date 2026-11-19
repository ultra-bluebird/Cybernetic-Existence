# `popmath` Build-Readiness Assessment

## Determination

The current Population.Math research is sufficient to begin implementation of `crates/popmath`.

It is sufficient for a foundation release because it already defines:

- The crate’s purpose and non-goals.
- The public-interest and rights-centered computation boundary.
- A typed-unit strategy.
- Data-ingestion and external-standard adapter boundaries.
- Provenance, aggregation, quarantine, and review semantics.
- Scenario, constraint, objective, and result-envelope requirements.
- Deterministic and stochastic reproducibility requirements.
- Solver-neutral optimization architecture.
- Alternative-solution and uniqueness policy.
- Water, energy, ecological, logistics, queueing, access, and lifecycle-cost mathematical primitives.
- Accessibility, service continuity, ecological, and human-review obligations.
- Native and WebAssembly portability goals.
- Research questions, proofs of concept, and acceptance criteria.

The correct next step is not broad additional conceptual research. The correct next step is a controlled implementation program that turns the validated research into a small, testable, production-quality core.

## Build Boundary

The initial stable release must implement a narrow, complete, and independently verifiable calculation kernel.

The first release should include:

| Capability | Initial release decision |
|---|---|
| Typed physical quantities | Include |
| Finite and bounded numeric values | Include |
| Explicit time windows and time-series semantics | Include |
| Provenance and data-quality records | Include |
| Aggregation status and quarantine state | Include |
| Purpose, data-use, review, accessibility, and ecological metadata | Include |
| Immutable scenarios, assumptions, constraints, and objectives | Include |
| Result envelopes and reproducibility digests | Include |
| Deterministic water storage balance | Include |
| Deterministic energy storage balance | Include |
| Hydraulic power primitive | Include |
| Pollutant mass-balance primitive | Include |
| Lifecycle-cost primitive | Include |
| Queue utilization and stability screen | Include |
| Delivery capacity and load-feasibility screen | Include |
| Fuel and emissions estimate primitive | Include |
| Aggregate service-access index | Include |
| Unit, provenance, result, and policy serialization | Include behind feature flag |
| Minimal WebAssembly build verification | Include |
| Full GIS ingestion | Defer |
| GTFS ingestion | Defer to adapter research release |
| OpenStreetMap ingestion | Defer to adapter research release |
| External optimization solver adapter | Defer until solver evaluation gate passes |
| Vehicle-routing optimization | Defer |
| Time-expanded transit optimization | Defer |
| Large-scale stochastic simulation | Defer |
| Discrete-event simulation | Defer |
| Full lifecycle assessment database integration | Defer |
| Direct civic-system integrations | Exclude |
| Automated infrastructure control | Exclude |

This release boundary creates an operationally useful foundation without accepting unverified complexity.

## Usable Research Incorporated

### Mathematical foundation

The research supplies stable formulas and model concepts that can immediately inform the first implementation.

#### Water storage balance

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

The first implementation should represent each term with typed volume quantities over one explicit `TimeWindow`.

The model must:

- Require a non-negative starting storage value.
- Require non-negative inflow, demand, losses, evaporation, and recovered supply.
- Require a positive maximum storage capacity.
- Clamp physical storage to the interval from zero to maximum capacity.
- Report unmet demand separately from ending storage.
- Report spill or overflow separately from ending storage.
- Preserve distinct categories where the caller declares potable, reclaimed, ecological, emergency, or transferred water.
- Return assumptions and source provenance in the result envelope.

#### Hydraulic power

\[
P_{\text{hydro}}
=
\rho g Q H
\]

The first implementation should define:

- Water density.
- Gravitational acceleration.
- Volumetric flow rate.
- Hydraulic head.
- Output power.

The model must ensure dimensional consistency and return power in a canonical energy-per-time unit.

#### Energy storage balance

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

The first implementation should distinguish:

- Starting stored energy.
- Maximum usable capacity.
- Charge energy.
- Discharge demand.
- Charge efficiency.
- Discharge efficiency.
- Curtailed charge energy.
- Unserved demand.
- Critical-load demand, when declared by the caller.

An energy deficit is a resilience result. It is not an authorization to interrupt essential services or deprioritize any group of people.

#### Pollutant mass balance

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

The first implementation should begin with a discrete, constant-interval form:

\[
M_x
=
\left(
C_{\text{in},x}
-
C_{\text{out},x}
\right)
Q \Delta t
\]

The model must preserve:

- Contaminant identity.
- Concentration unit.
- Flow unit.
- Time interval.
- Sampling or measurement method reference.
- Negative-removal interpretation, if outflow concentration exceeds inflow concentration.
- Detection-limit and uncertainty support as a later extension.

#### Queue utilization

\[
\rho
=
\frac{\lambda}{c\mu}
\]

The first implementation should support a first-order capacity screen only.

It must report:

- Arrival rate.
- Service rate per channel.
- Number of channels.
- Utilization.
- Stable or unstable status.
- Minimum channels required for modeled stability.
- Declared assumptions and limitations.

A queue with \(\rho \geq 1\) should produce an instability warning and a capacity-planning result. It must not imply service restriction as a remedy.

#### Lifecycle cost

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

The first implementation should require:

- A declared currency.
- Integer minor-unit representation for all monetary values.
- A positive or zero discount rate under a declared convention.
- An explicit study horizon.
- An explicit base period.
- A declared cost category for every included value.
- A clear list of excluded categories.

#### Aggregate service-access index

\[
SAI_g
=
\frac{
\sum_{i \in g}
w_i
\cdot
\mathbb{1}
[
T_i \leq T_{\max}
\land A_i = 1
\land C_i \leq C_{\max}
]
}{
\sum_{i \in g} w_i
}
\]

The first implementation should accept only verified aggregate or synthetic inputs.

It must:

- Require declared geography or service-area scope.
- Require a declared time threshold.
- Require a declared cost threshold where cost is modeled.
- Require an explicit accessibility-condition definition.
- Record whether the analysis considers full-path accessibility or only an infrastructure segment.
- Reject unknown aggregation status.
- Return an access index, limitations, provenance, and human-review requirement.

#### Delivery capacity screen

The first implementation should not attempt full vehicle routing optimization.

It should compute a deterministic capacity screen from:

- Total material mass.
- Total material volume.
- Vehicle mass capacity.
- Vehicle volume capacity.
- Vehicle count.
- Available operating time.
- Service time per site or task.
- Delivery windows.
- Crew capacity.
- Route-distance estimate.
- Fuel-use factor.
- Emissions factor.
- Site staging capacity.

It should return:

- Minimum load count.
- Mass and volume limiting factor.
- Time capacity.
- Basic feasibility.
- Fuel estimate.
- Emissions estimate.
- Stated constraints.
- Warnings that road safety, work-zone conditions, permits, accessible-path continuity, and emergency access require additional validation.

## Core Architectural Decisions Ready for Implementation

### Internal units and external adapters

The research supports a three-layer model:

| Layer | Implementation role |
|---|---|
| External adapter boundary | Parse source-specific inputs, validate source units, retain raw representation, and create normalized typed values |
| Canonical `popmath` core | Execute calculations using typed, validated, unit-safe quantities |
| External reporting boundary | Convert canonical results into supported standards without altering their internal meaning |

The crate should prioritize maximal internal type safety. Established civic or ecological formats are handled by dedicated adapters rather than by weakening core types.

`uom` is suitable for a prototype because it provides automatic, type-safe, zero-cost dimensional analysis and includes prebuilt SI-oriented systems. The crate should use a proof-of-concept gate before committing it to the stable public API. [68][70][97]

### Provenance and aggregation quarantine

The research supplies a useful and implementable aggregation policy:

| Status | Build behavior |
|---|---|
| `VerifiedAggregate` | Eligible for relevant aggregate scenario models |
| `PublicAggregate` | Eligible after source and quality validation |
| `VerifiedInfrastructureScope` | Eligible for infrastructure, network, asset, facility, and environmental models |
| `Synthetic` | Eligible when clearly labeled as synthetic |
| `Unknown` | Quarantine; inspection and schema profiling only |
| `Insufficient` | Reject until documentation is remediated |
| `Prohibited` | Reject |

Unknown aggregation is not automatically rejected at ingestion. It is quarantined and blocked from model execution that could generate public, operational, resource-allocation, access, parity, or decision-ready results.

This separation between **inspection** and **authorized analysis** is sufficient to protect quality while preserving research usefulness.

The W3C PROV model is a useful compatibility reference because it supplies a domain-agnostic vocabulary for entities, activities, agents, and derivations. `popmath` can map its source, transformation, and derived-result records to this conceptual structure without becoming dependent on a single provenance serialization format. [79][84][86]

### Result-envelope contract

Every material result can use a common structure from the beginning:

| Result component | Required in foundation release |
|---|---|
| Calculation identity and version | Yes |
| Scenario and purpose | Yes |
| Input provenance | Yes |
| Units | Yes |
| Time and geographic scope | Yes |
| Assumptions | Yes |
| Constraints | Yes |
| Validation status | Yes |
| Feasibility status | Where applicable |
| Uncertainty declaration | Yes, including “not assessed” where appropriate |
| Sensitivity declaration | Yes, including “not assessed” where appropriate |
| Accessibility impact | Yes for public-service, mobility, logistics, and access calculations |
| Rights-impact summary | Yes |
| Ecological-impact summary | Yes where ecological or material impact is relevant |
| Human-review requirement | Yes |
| Warnings and limitations | Yes |
| Reproducibility digest | Yes |

This result format is build-ready because it can be applied to closed-form calculations before solver or simulation support exists.

### Solver-neutral design

The research contains enough material to implement solver-neutral types now, but not enough evidence to select a required external solver backend.

The initial crate should therefore implement:

- Decision variable declarations.
- Variable-domain declarations.
- Objective declarations.
- Hard and soft constraints.
- Constraint-relaxation policy declarations.
- Solver configuration record.
- Solver status representation.
- Feasibility and uniqueness status.
- Alternative-analysis status.
- Optimization result envelope.
- Infeasibility explanation structure.
- Post-solve validation interfaces.

The first release should not promise an external solver adapter.

`good_lp` is appropriate for evaluation as a Rust modeling abstraction because it provides a typed API for linear and mixed-integer problem modeling and supports solver selection through feature flags. This makes it a candidate adapter, not a mandatory part of the core. [94][95]

### Alternative-analysis policy

The research supports a precise initial policy:

- All optimization results require an alternative-analysis status.
- Multi-objective, routing, integer, scheduling, allocation, siting, and public-facing planning problems require materially distinct alternatives when computationally feasible.
- A result with an analytically or numerically supported unique optimum may return one solution, but it must include uniqueness or stability evidence.
- A solver status of `Optimal` is not automatically a uniqueness proof.
- Every alternative must preserve hard accessibility, safety, privacy, ecological, and continuity constraints.
- A cost-minimal result cannot be described as categorically best without a stated tradeoff analysis.

The first release can define the data structures and validation rules for this policy without implementing a full Pareto solver.

### WebAssembly boundary

The research supports a conservative WebAssembly target.

`wasm32-unknown-unknown` is Rust’s minimal WebAssembly target and does not import standard-library host functions, making it an appropriate compatibility target for an offline and browser-oriented calculation kernel. [92][93]

The first WebAssembly compatibility profile should include:

- Bounded numeric values.
- Units.
- Time windows.
- Provenance validation.
- Scenario validation.
- Governance validation.
- Water balance.
- Energy storage balance.
- Hydraulic power.
- Pollutant mass balance.
- Queue capacity screen.
- Lifecycle-cost calculation.
- Delivery capacity screen.
- Aggregate service-access calculation.
- Result envelope serialization.
- Reproducibility digest generation.

No full solver, native geographic engine, network data ingestion, file-system dependency, or network dependency belongs in this profile.

## Work Still Required Before Stable Publication

The research is sufficient to **build**, but the following work is required to **publish a stable release**:

| Work item | Status | Required completion evidence |
|---|---|---|
| Cargo workspace and crate manifest | Ready to implement | Reproducible build with minimal features |
| Public API naming review | Ready to implement | API review record and compatibility notes |
| `uom` proof of concept | Required before dependency lock-in | Native and WebAssembly build, unit tests, conversion tests |
| Canonical serialization schema | Required | JSON examples, schema version, round-trip tests |
| Reproducibility digest algorithm | Required | Canonicalization specification and stable test vectors |
| Provenance schema | Required | Valid, quarantine, rejected, and derived-aggregate fixtures |
| Governance schema | Required | Permitted, review-required, and prohibited-use fixtures |
| Scenario schema | Required | Baseline and alternative scenario fixtures |
| Error taxonomy | Required | Structured errors and no-sensitive-content tests |
| Core deterministic formula test suite | Required | Hand-calculated reference values and property tests |
| Currency representation policy | Required | Integer minor-unit rules and base-period rules |
| Emissions-factor record schema | Required | Boundary, validity, source, unit, and uncertainty fixtures |
| Accessibility requirement schema | Required | Full-path and unknown-condition test cases |
| WebAssembly build test | Required | Compiled core target and behavioral equivalence checks |
| Benchmark suite | Required before release candidate | Time, memory, input scale, compiler profile, target |
| Dependency license review | Required before release candidate | License and maintenance record |
| Security review | Required before release candidate | Parsing, serialization, panic-safety, and dependency review |
| Documentation examples | Required before stable publication | Synthetic, non-sensitive, reproducible examples |

None of these missing items require a new broad conceptual architecture. They are the normal evidence and implementation tasks needed to convert research into a dependable crate.

## Recommended Implementation Sequence

### Foundation milestone

Implement:

- `error.rs`
- `bounds.rs`
- `time.rs`
- `units.rs`
- `provenance.rs`
- `governance.rs`
- `scenario.rs`
- `result.rs`
- `lib.rs`
- `README.md`

Foundation exit criteria:

- All public inputs use validated constructors.
- All material outputs use `ResultEnvelope<T>`.
- Unknown aggregation is quarantined.
- Prohibited purposes are rejected.
- Typed units compile and serialize.
- Every result has a reproducibility digest.
- The crate builds with a minimal native profile and minimal WebAssembly profile.

### Deterministic civic-math milestone

Implement:

- `water.rs`
- `energy.rs`
- Initial functions in `ecology.rs`
- Initial functions in `queues.rs`
- Initial functions in `economics.rs`
- Initial functions in `logistics.rs`
- Initial functions in `access.rs`

Exit criteria:

- All core formula results match independently calculated reference cases.
- Conservation and bound properties are property-tested.
- Results distinguish measurement, scenario assumption, and modeled estimate.
- Relevant results preserve accessibility, ecological, rights, and review metadata.
- All examples use public, aggregate, or synthetic data.

### Optimization-contract milestone

Implement:

- `optimization.rs`
- Objective and constraint representations.
- Hard and soft constraint semantics.
- Alternative-analysis metadata.
- Uniqueness metadata.
- Infeasibility explanation types.
- Post-solve validation interfaces.

Exit criteria:

- Optimization types compile without requiring a solver backend.
- A synthetic hand-built solution can be post-solve validated.
- Hard constraints cannot be silently relaxed.
- Alternative-analysis status is required for every optimization result.

### Adapter and solver research milestone

Implement only after targeted evaluation:

- One source-specific unit adapter.
- One public aggregate data adapter.
- One network-data adapter.
- One optional optimization solver adapter.
- Solver compatibility, licensing, and determinism tests.

Exit criteria:

- Adapter input errors are structured.
- Adapters preserve original units and conversion provenance.
- Solver outputs are independently validated.
- Solver output includes status, gap, tolerance, and configuration.
- The adapter does not bypass governance, provenance, or result-envelope requirements.

## Quality Assurance Matrix

| Quality dimension | Required control |
|---|---|
| Mathematical correctness | Typed quantities, reference calculations, property tests, conservation tests |
| Numerical correctness | Finite-value checks, range checks, tolerance declarations, overflow and underflow tests |
| Time correctness | Explicit windows, resolution semantics, time-series ordering, missing-data policy |
| Data quality | Source provenance, aggregation status, quality flags, transformation records |
| Privacy | Aggregate, synthetic, or authorized input policy; quarantine for unknown aggregation |
| Accessibility | Explicit requirements, full-path conditions where applicable, unknown-condition reporting |
| Ecological integrity | Accounting boundary, factor provenance, mass and energy balance, uncertainty reporting |
| Governance | Purpose declaration, prohibited use, decision boundary, review requirement |
| Optimization transparency | Constraint reporting, alternatives, uniqueness status, post-solve validation |
| Reproducibility | Canonical input representation, configuration record, deterministic seed handling, digest |
| Portability | Native and WebAssembly build checks, optional native dependencies, no network requirement |
| Security | Safe parsing, panic avoidance, dependency review, no secrets in errors or digests |

## Test Fixture Program

The crate should begin with a controlled fixture corpus containing only synthetic or clearly public aggregate values.

### Units fixtures

- Cubic meters, liters, gallons, acre-feet, and conversion rejection cases.
- Joules, kilowatt-hours, watts, and duration conversion cases.
- Kilograms, pounds, metric tonnes, short-ton ambiguity rejection, and concentration cases.
- Currency minor-unit and base-currency mismatch cases.
- Carbon dioxide equivalent accounting-boundary fixtures.

### Provenance fixtures

- Valid public aggregate source.
- Valid synthetic scenario source.
- Valid verified infrastructure source.
- Unknown aggregation quarantine source.
- Insufficient aggregation rejection source.
- Invalid transformation chain.
- Missing time coverage.
- Purpose mismatch.

### Water fixtures

- Balanced storage period.
- Shortage period.
- Overflow period.
- Reclaimed-supply contribution.
- Ecological-flow constraint warning.
- Invalid negative volume.
- Irregular interval rejected until time-series support is active.

### Energy fixtures

- Fully served load.
- Curtailed charging.
- Unserved demand.
- Critical-load reserve.
- Invalid efficiency.
- Capacity overflow.
- Explicit time-window mismatch.

### Queue fixtures

- Stable capacity.
- Unstable capacity.
- Near-boundary utilization.
- Zero service-rate rejection.
- Required-channel calculation.

### Logistics fixtures

- Feasible mass and volume delivery.
- Mass-limited delivery.
- Volume-limited delivery.
- Time-window conflict.
- Crew-capacity conflict.
- Emissions-factor provenance requirement.
- Accessibility and emergency-access warning.

### Access fixtures

- Full access.
- Partial access.
- Inaccessible shortest route with an accessible longer alternative.
- Unknown access condition.
- Unknown aggregation rejection.
- Offline or manual fallback declared and absent.

## Data Contamination Controls

The research has a strong contamination-prevention foundation. The implementation must preserve it through the following rules:

- Treat all external schemas, columns, unit labels, and data values as untrusted until a named adapter validates them.
- Never infer units, aggregation level, purpose, geographic scope, time basis, currency, carbon-accounting boundary, or accessibility condition.
- Preserve raw source representation at the adapter boundary only when needed for audit, and never elevate it to trusted canonical data without validation.
- Maintain source and transformation provenance through every derived calculation.
- Quarantine unknown aggregation rather than defaulting to a safe-looking value.
- Reject incompatible units and ambiguous conversion labels.
- Keep synthetic data visibly labeled at every downstream stage.
- Prevent unverified or quarantined data from producing decision-ready outputs.
- Prevent solver adapters from bypassing hard constraints, policy checks, or post-solve validation.
- Include uncertainty and limitations rather than replacing missing information with false precision.
- Use canonical serialization before hashing inputs and results.
- Do not place secrets, raw sensitive records, credentials, or hidden identifiers into result envelopes, provenance exports, logs, errors, or digests.
- Preserve independent reference values and test vectors outside implementation-specific logic.

## Build Readiness Verdict

`popmath` is ready to enter implementation as a staged Rust crate.

The foundation and deterministic civic-math milestones have sufficient specification and research support to begin immediately. The solver, routing, geospatial, transit ingestion, advanced simulation, and full ecological-factor integrations should remain behind research and feature gates until they satisfy the stated validation, portability, licensing, performance, and explainability criteria.

This approach creates a practical core that can calculate useful city-scale scenarios early while preserving the evidence quality needed for later expansion.

## Initial Metrics

- `knowledge_factor`: 0.96  
  Basis: the research defines concrete formulas, architecture, governance contracts, release scope, tests, adapters, reproducibility expectations, and acceptance gates.

- `eco_impact_value`: 0.93  
  Basis: the initial scope directly supports water balance, energy resilience, emissions accounting, material logistics, ecological constraints, pollutant mass balance, and lifecycle costing.

- `harm_risk`: 0.09  
  Basis: risk is controlled through source validation, aggregation quarantine, purpose restrictions, explicit uncertainty, human review, hard-constraint preservation, and exclusion of direct system control.

- `accessibility_impact`: 0.97  
  Basis: service access, accessible-path conditions, continuity, explicit unknowns, alternative analysis, and review requirements are embedded in the calculation design.

- `rights_alignment`: 0.98  
  Basis: the crate is purpose-limited, privacy-preserving, non-discriminatory, reviewable, explainable, interoperable, and designed to preserve meaningful access to civic services.
