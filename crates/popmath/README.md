# popmath

`popmath` is the core Rust crate for Population.Math: a rights-centered, privacy-preserving mathematical foundation for large-scale public-interest calculation.

It provides composable, deterministic calculation primitives for:

- Transportation, transit, delivery, and construction logistics
- Water supply, storage, losses, demand, reclamation, and resilience
- Power demand, storage, dispatch scenarios, and critical-service continuity
- Infrastructure maintenance, dispatch capacity, staffing, queues, and schedules
- Population growth, housing demand, capital planning, and public-service demand
- Ecological mass balance, heat mitigation, material flows, emissions, and restoration metrics
- Lifecycle cost, public-budget scenarios, uncertainty intervals, and sensitivity analysis
- Service-access coverage, accessibility parity, resilience coverage, and transparent tradeoff reporting

The crate is a mathematical and governance-aware foundation. It does not make binding civic decisions, rank people, determine eligibility, enforce policy, or access live public systems.

## Design Position

`popmath` exists to strengthen human, community, and institutional decision-making with verifiable computation.

It is designed for applications that must answer questions such as:

- What delivery plans can serve all sites while respecting vehicle-load, staging-space, crew, road-safety, and accessible-path constraints?
- Under stated climate, demand, loss, and recovery scenarios, what are the projected water-storage ranges?
- Which transit, walking, rolling, or paratransit alternatives maintain meaningful access to public services?
- How many crews, service channels, vehicles, or maintenance windows are required to keep a public system stable?
- What are the likely energy, emissions, cost, accessibility, and resilience tradeoffs among multiple infrastructure plans?
- What ecological mass, energy, water, or carbon outcomes can be physically accounted for from measured inputs?
- Where do a scenario’s benefits or burdens differ across approved aggregate geographies or voluntarily governed community cohorts?

The crate produces calculations and evidence envelopes. A consuming application remains responsible for lawful authority, public process, community engagement, operational approvals, and implementation.

## Scope

### Included mathematical foundations

`popmath` should contain stable, reusable building blocks in the following domains.

| Module family | Mathematical responsibility | Example outputs |
|---|---|---|
| `units` | Typed quantities, dimensions, ranges, conversions, and timestamps | Kilograms, cubic meters, kilowatt-hours, meters, minutes, carbon dioxide equivalent |
| `provenance` | Input lineage, aggregation declarations, source references, time coverage, and validation status | Reproducible input record and evidence summary |
| `bounds` | Intervals, tolerances, confidence ranges, probability bounds, and scenario ranges | Lower, central, and upper planning outcomes |
| `network` | Weighted graphs, paths, flow constraints, route costs, coverage, and reliability inputs | Route cost, accessibility-aware network coverage, flow feasibility |
| `mobility` | Travel-time, route, fleet, delivery, construction staging, and transit primitives | Capacity screens, route alternatives, service reliability inputs |
| `water` | Storage accounting, demand, loss, supply, flow, head, pumping, and mass balance | Shortage risk, overflow, mass removed, hydraulic energy |
| `energy` | Generation, load, storage, efficiency, dispatch inputs, and critical-load separation | Unserved load, curtailed energy, storage duration |
| `queues` | Arrival rates, service rates, utilization, stable-capacity thresholds, and wait-time model inputs | Staffing range, utilization, instability warning |
| `maintenance` | Asset condition, backlog, crew capacity, response-time, and reliability primitives | Backlog projection, required crew-hours, response capacity |
| `population` | Aggregate growth, cohort, service-demand, and scenario projection primitives | Demand bands and infrastructure implications |
| `economics` | Lifecycle cost, cost escalation, discounting, budgets, externalities, and sensitivity | Net present value, cost range, contingency sensitivity |
| `ecology` | Energy balance, mass balance, emissions, water quality, materials, heat, and restoration indicators | Pollutant mass removal, carbon range, ecological performance |
| `access` | Service access, accessibility coverage, parity-gap, continuity, and manual-fallback metrics | Access index, parity flag, offline-service coverage |
| `optimization` | Problem descriptions, constraints, objectives, alternatives, and solver-neutral result forms | Feasible plans and a retained alternative frontier |
| `simulation` | Deterministic scenario execution, stochastic samples, discrete-event model interfaces, and sensitivity results | Percentile bands, scenario failure rate, variable influence |
| `governance` | Purpose constraints, prohibited use declarations, review requirements, result explanations, and audit records | Rights-impact and review-ready result envelope |
| `report` | Structured, serializable, accessible results and plain-language explanation components | Machine-readable and human-readable outcome report |

### Explicitly excluded functions

`popmath` should not implement:

- Resident-level tracking, profiling, identity resolution, or location-history analysis.
- Social scores, behavioral scores, risk scores, deservingness scores, or civic worthiness scores.
- Automated decisions about housing, employment, healthcare, benefits, policing, immigration, credit, education, voting, or public participation.
- Facial recognition, biometric matching, neural-data processing, augmentation telemetry processing, or device fingerprinting.
- Coercive routing, surveillance enforcement, or hidden behavior modification.
- Direct execution against vehicles, traffic systems, power systems, water systems, dispatch systems, or public databases.
- Secret ranking mechanisms, opaque weights, or silent changes to constraints.

A consumer may use `popmath` to calculate an aggregate scenario, but cannot use the crate itself as a justification for reducing a person’s rights, service access, or dignity.

## Core Design Principles

### Deterministic by default

For identical validated inputs, configuration, and crate version, deterministic models must return identical outputs.

Any nondeterministic operation, including random sampling, must require an explicit seed and must return that seed in the result envelope.

### Units are part of correctness

A number without a unit is not an accepted mathematical input for physical, financial, time, distance, energy, mass, flow, emissions, or population calculations.

Examples of intended typed values include:

- `Mass<Kilogram>`
- `Volume<CubicMeter>`
- `FlowRate<CubicMeterPerSecond>`
- `Energy<KilowattHour>`
- `Power<Kilowatt>`
- `Duration<Minute>`
- `Distance<Meter>`
- `Money<UsdCents>`
- `Emissions<KilogramCo2e>`
- `Probability`
- `PopulationCount`
- `Ratio`

Dimensionally incompatible calculations must fail before execution.

### Privacy-preserving inputs

The crate accepts:

- Aggregate population counts.
- Approved geographic summaries.
- Synthetic scenario agents.
- Public infrastructure measurements.
- Environmental sensor summaries.
- Consent-authorized data represented through an external, verified data contract.

The crate must reject inputs marked as containing individual-level sensitive personal data unless a consuming application explicitly performs a separate, reviewed transformation into a permitted aggregate form before invoking `popmath`.

Sensitive categories include:

- Neural signals.
- Biometric measurements.
- Health records.
- Assistive-device telemetry.
- Augmentation telemetry.
- Persistent personal location histories.
- Identity-linked mobility traces.
- Unconsented behavioral records.

### Explainability is a required output

A result is incomplete unless it carries:

- Calculation identity and semantic version.
- Input provenance and time scope.
- Units.
- Assumptions.
- Constraints.
- Model and solver configuration.
- Numerical results.
- Uncertainty or confidence information where applicable.
- Feasibility and validation status.
- Accessibility impact.
- Ecological impact.
- Rights-impact notes.
- Human-review requirement.
- Reproducibility digest.

### Alternatives, not a single imposed answer

Optimization outputs should retain:

- At least one feasible baseline.
- The best result for each declared objective.
- A Pareto frontier or bounded set of near-optimal alternatives when feasible.
- Constraint violations and infeasibility causes.
- Tradeoff explanations.

For a municipal delivery plan, for example, the lowest-fuel alternative may be reported alongside alternatives that reduce accessible-path disruptions, improve emergency access, lower neighborhood emissions, or increase schedule resilience.

### Fail closed for invalid math

The crate must return a structured error when it encounters:

- Invalid or missing units.
- Negative physical quantities where not meaningful.
- Non-finite values.
- Probability outside the unit interval.
- Invalid time ranges.
- Unknown provenance.
- Unsupported aggregation levels.
- Inconsistent constraints.
- Unstable queueing conditions when a stable result is requested.
- Missing uncertainty declarations for stochastic outputs.
- Forbidden sensitive-data markers.

It must not silently clamp, invent, infer, or normalize unknown input values.

## Primary Public API Shape

The public API should be deliberately small and centered on four layers.

### Typed inputs

Input types represent validated physical, spatial, temporal, economic, ecological, and service quantities.

They should be immutable after construction and validated through constructors or builders.

Conceptual type families:

- `Quantity<Unit>`
- `Interval<T>`
- `TimeWindow`
- `ScenarioId`
- `ScenarioSet`
- `AggregateGeography`
- `PopulationAggregate`
- `SourceProvenance`
- `DataQuality`
- `Assumption`
- `Constraint`
- `Objective`
- `AccessibilityRequirement`
- `EcologicalBoundary`
- `ReviewRequirement`

### Mathematical models

A model defines the mathematical problem without forcing a particular solver or runtime.

Conceptual traits:

- `DeterministicModel`
- `ScenarioModel`
- `OptimizationModel`
- `SimulationModel`
- `SensitivityModel`
- `ConstraintModel`
- `ResultExplainer`

Every model declares:

- Accepted input type.
- Output type.
- Units.
- Preconditions.
- Constraint semantics.
- Assumptions.
- Determinism status.
- Required provenance quality.
- Sensitive-data compatibility.
- Accessibility and rights-review implications.

### Solver-neutral execution

`popmath` should contain calculations and problem definitions, but not force heavyweight solver dependencies into all users.

The base crate should support:

- Closed-form calculations.
- Bounded search.
- Greedy feasibility screens.
- Deterministic graph algorithms.
- Simple linear and nonlinear model descriptions.
- Scenario evaluation.
- Monte Carlo interfaces with explicit seeds.

Optional features may add adapters for external engines, while preserving a common result format:

- `solver-ortools`
- `solver-highs`
- `solver-goodlp`
- `solver-cbc`
- `geo`
- `serde`
- `wasm`
- `parallel`
- `simulation`

A solution returned by any adapter must include solver identity, version, termination status, numerical tolerance, objective values, and feasibility status.

### Result envelopes

Every meaningful result should be embedded in a common `ResultEnvelope<T>`.

Conceptually, it contains:

- `calculation_name`
- `calculation_version`
- `computed_at`
- `scenario`
- `inputs_digest`
- `provenance`
- `result`
- `units`
- `assumptions`
- `constraints`
- `validation`
- `uncertainty`
- `sensitivity`
- `accessibility_impact`
- `rights_impact`
- `ecological_impact`
- `human_review`
- `reproducibility_digest`

This envelope is the boundary between mathematical execution and civic interpretation.

## Domain Models

### Mobility and route mathematics

The mobility family should support network calculations without requiring individual travel histories.

Its inputs should describe:

- Public road, walkway, trail, transit, freight, or service network edges.
- Distance, travel time, capacity, grade, surface condition, closure state, and permitted modes.
- Accessibility attributes declared as infrastructure facts, such as curb-ramp availability, step-free continuity, crossing availability, lighting, shade, and safe-width constraints.
- Aggregate demand between approved zones.
- Vehicle capacity, material mass, volume, service windows, crew time, staging capacity, and emissions factors.

Its outputs should support:

- Shortest feasible route alternatives.
- Accessible-route alternatives.
- Aggregate origin-to-destination coverage.
- Material-delivery capacity screens.
- Fuel and emissions estimates.
- Fleet-load feasibility.
- Transit transfer reliability inputs.
- Construction-impact scenario comparison.
- Network robustness under closures or disruption scenarios.

It should not create individual travel profiles or determine whether an individual may access a route or service.

Open transit and routing formats such as GTFS, GTFS-Realtime, GeoJSON, and OpenStreetMap-derived networks are appropriate boundary formats for an application layer. OpenTripPlanner demonstrates the practical utility of open, multimodal routing based on GTFS and OpenStreetMap inputs. [57][58][66]

### Water and hydrology mathematics

The water family should represent water as explicitly typed balances.

Core state equation:

\[
S_{t+1}
=
S_t + I_t - D_t - L_t - E_t + R_t
\]

Where:

- \(S_t\) is stored volume.
- \(I_t\) is inflow.
- \(D_t\) is demand.
- \(L_t\) is physical or measured loss.
- \(E_t\) is evaporation or other defined loss.
- \(R_t\) is recovered, reclaimed, or transferred supply.

Core functions should include:

- Storage trajectory.
- Supply-demand deficit.
- Overflow or spill.
- Leakage and loss accounting.
- Pumping energy.
- Hydraulic power.
- Water-quality mass balance.
- Contaminant-removal accounting.
- Conservation scenario comparisons.
- Resilience under drought or supply interruption scenarios.

The crate should preserve separate categories for potable supply, reclaimed supply, ecological flow, emergency reserve, and contractual allocation. It must not erase these distinctions into a single water number.

The included project research establishes a compatible physical accounting pattern: wind power and hydraulic power share watt units, while contaminant mass removal follows the concentration-difference times flow over time relation. Those facts make energy conversion and water-quality calculations auditable through dimensional consistency. [51]

### Energy and public-utility mathematics

The energy family should model:

- Generation.
- Aggregate demand.
- Critical-load demand.
- Storage state.
- Charge and discharge efficiency.
- Curtailment.
- Unserved load.
- Resilience duration.
- Demand-response scenarios.
- Renewable-energy and backup-power comparisons.

Core storage relation:

\[
B_{t+1}
=
\min
\left(
B_{\max},
B_t + \eta_c C_t - \frac{G_t}{\eta_d}
\right)
\]

Where:

- \(B_t\) is stored energy.
- \(B_{\max}\) is usable capacity.
- \(C_t\) is charging energy.
- \(G_t\) is delivered energy.
- \(\eta_c\) and \(\eta_d\) are charge and discharge efficiencies.

Essential services must be modeled separately from optional demand. A deficit calculation is a resilience warning and planning input; it is never authorization to deprioritize people who rely on assistive, medical, or accessibility-critical infrastructure.

### Construction, materials, and logistics mathematics

The construction family should support scenario planning for:

- Material mass and volume.
- Safe vehicle capacity.
- Delivery windows.
- Yard and lot staging capacity.
- Crew capacity.
- Route limits.
- Fuel use.
- Carbon emissions.
- Site cost.
- Delays.
- Work-zone effects.
- Maintenance dependencies.

A baseline delivery-cost expression is:

\[
C_{\text{delivery}}
=
C_{\text{labor}}
+
C_{\text{vehicle}}
+
C_{\text{fuel}}
+
C_{\text{delay}}
+
C_{\text{site}}
+
C_{\text{externality}}
\]

The cost model must expose every included and excluded term. It should permit ecological and accessibility externalities to be represented transparently, rather than treating them as invisible side effects.

### Queueing, staffing, dispatch, and maintenance mathematics

The queueing family should provide capacity and stability analysis for:

- Transit boarding.
- Service desks.
- Maintenance dispatch.
- Permit processing.
- Public-information channels.
- Cooling centers.
- Water or energy service response.
- Construction inspection scheduling.
- Non-emergency public service workflows.

A first-order utilization relation is:

\[
\rho =
\frac{\lambda}{c\mu}
\]

Where:

- \(\lambda\) is arrival rate.
- \(c\) is the number of service channels.
- \(\mu\) is the service rate per channel.

If \(\rho \geq 1\), the modeled system is unstable. The result should explain the condition, quantify the capacity gap, and present alternatives. It must not recommend denying access or making service inaccessible as a capacity-management response.

### Population, housing, labor, and public-finance mathematics

The population family should use aggregate, scenario-based methods such as:

- Cohort-component projection.
- Trend and seasonal forecasting.
- Housing-unit and household-demand scenarios.
- Infrastructure-demand ratios.
- Workforce capacity scenarios.
- Employment and unemployment trend analysis.
- Public-service demand projections.
- Capital-plan sensitivity.
- Lifecycle-cost analysis.

A generic lifecycle-cost relation is:

\[
LCC =
C_0 +
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

Results must disclose the discount rate, study horizon, escalation assumptions, maintenance assumptions, and excluded costs.

### Ecological and restoration mathematics

The ecology family should support accountable calculation for:

- Energy and water accounting.
- Pollutant mass balance.
- Material reuse and diversion.
- Carbon dioxide equivalent estimates.
- Heat mitigation.
- Water-quality improvement.
- Habitat connectivity indicators.
- Restoration workload.
- Environmental uncertainty.
- Lifecycle burdens and benefits.

A generic contaminant mass-removal relation is:

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

- \(M_x\) is removed mass.
- \(C_{\text{in},x}\) and \(C_{\text{out},x}\) are influent and effluent concentration.
- \(Q(t)\) is volumetric flow.
- \(T\) is the defined measurement period.

The crate must preserve the pollutant identity, units, sensor method, calibration status, flow measurement method, and uncertainty. It must not convert ecological claims into unsupported certainty.

### Access, fairness, and continuity mathematics

The access family should quantify service reach without turning personal characteristics into a score.

A basic aggregate access measure is:

\[
SAI_g =
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

Where:

- \(g\) is an approved aggregate geography or voluntary community cohort.
- \(w_i\) is an aggregate weight.
- \(T_i\) is modeled travel time.
- \(A_i\) represents complete-path accessibility.
- \(C_i\) represents user cost.
- \(T_{\max}\) and \(C_{\max}\) are publicly reviewed thresholds.

The result should report access coverage, uncertainty, threshold definitions, and constraints. It must never infer disability, augmentation status, health status, or a person’s ability from mobility data.

`popmath` should also support:

- Accessible-path continuity.
- Service fallback coverage.
- Offline access coverage.
- Essential-service continuity.
- Parity-gap detection across lawfully governed aggregate groups.
- Delay and burden distribution comparison.
- Complaint or grievance workload capacity.

A parity gap is a review signal. It is not a category of person, a basis for exclusion, or an automated adjudication result.

## Governance Layer

The governance layer makes mathematical output usable in accountable public-interest systems.

It should include declarative structures for:

- `Purpose`: the stated reason for a calculation.
- `PermittedUse`: allowed result-use category.
- `ProhibitedUse`: explicitly disallowed downstream use.
- `DataClass`: public, aggregated, synthetic, consent-authorized, sensitive, or prohibited.
- `RetentionClass`: retention and deletion policy reference.
- `ReviewRequirement`: none, technical, accessibility, ecological, community, or human-authority review.
- `RightsImpact`: dignity, equal treatment, privacy, accessibility, continuity, due-process, and civic-participation considerations.
- `EcoImpact`: energy, water, emissions, materials, habitat, uncertainty, and externality boundary.
- `DecisionBoundary`: distinguishes analysis from a decision.
- `AppealOrCorrectionPath`: application-provided reference to a correction or review process.

The governance layer does not replace legal review or public governance. It ensures that a model result carries the information needed for that review.

The design is compatible with the NIST AI Risk Management Framework’s recurring Govern, Map, Measure, and Manage functions: define accountability; establish context and affected populations; evaluate outcomes and uncertainty; and manage mitigations and residual risk. [53][55]

## Feature Design

The default feature set should remain lightweight and deterministic.

| Feature | Purpose |
|---|---|
| `std` | Standard Rust support and ergonomic errors |
| `serde` | Serialization for validated, versioned interchange |
| `json-schema` | JSON Schema generation for external API contracts |
| `geo` | Optional geospatial geometry and spatial math |
| `simulation` | Seeded Monte Carlo and scenario simulation helpers |
| `parallel` | Explicit, deterministic parallel evaluation where supported |
| `wasm` | WebAssembly-safe build profile for local public interfaces |
| `solver-ortools` | Optional adapter for complex routing and optimization |
| `solver-highs` | Optional linear and mixed-integer optimization adapter |
| `solver-goodlp` | Optional Rust-friendly mathematical programming adapter |
| `audit` | Reproducibility digests and structured audit records |
| `proptest` | Property-based test support for downstream model verification |

Solver features should be optional because the mathematical domain model must remain usable in embedded, offline, browser, command-line, server, and simulation environments.

## Error Model

The crate should use explicit, structured errors rather than booleans or stringly typed failure.

Important error categories include:

- `UnitMismatch`
- `InvalidQuantity`
- `NonFiniteValue`
- `OutOfRange`
- `InvalidTimeWindow`
- `MissingProvenance`
- `SensitiveDataRejected`
- `UnsupportedAggregation`
- `InvalidScenario`
- `InfeasibleConstraints`
- `UnstableQueue`
- `MissingRandomSeed`
- `NumericalInstability`
- `SolverUnavailable`
- `SolverFailure`
- `ReviewRequired`
- `ProhibitedUse`

An infeasible optimization problem must return its known infeasibility causes, constraint names, and feasible relaxation candidates where a solver can provide them.

## Verification Strategy

`popmath` should be engineered as a high-assurance numerical crate.

Required validation practices:

- Unit tests for every closed-form method.
- Property-based tests for conservation laws, bounds, monotonicity, and dimensional safety.
- Differential tests against independently calculated reference cases where practical.
- Golden test fixtures for public, non-sensitive scenario inputs.
- Determinism tests across supported targets.
- Overflow, underflow, `NaN`, infinity, and negative-value tests.
- Solver result validation against declared constraints.
- Accessibility and rights-impact envelope presence tests.
- Serialization round-trip tests.
- Reproducibility-digest tests.
- Fuzz testing for parsers and external data adapters.
- Benchmarking for high-volume scenario evaluation without weakening validation.

Important invariants include:

- A storage balance never returns a volume below zero unless a model explicitly represents deficit separately.
- A probability remains within the unit interval.
- A ratio with a nonzero denominator is finite.
- A result never omits its unit and provenance metadata.
- A stochastic result always reports its seed and sample count.
- A route or service plan marked accessible must satisfy all declared accessibility constraints.
- A model using sensitive or insufficiently aggregated data is rejected before calculation.
- A result cannot be labeled decision-ready when its required human review has not been satisfied.

## Intended Integration

`popmath` is intended to be used by other Augmented-Hub components rather than deployed as an independent city-management system.

Possible consumers include:

- An accessible mobility scenario service.
- A construction delivery and staging planner.
- A water and ecological restoration dashboard.
- A resilient microgrid and cooling-service planner.
- A public maintenance capacity dashboard.
- An open transit and active-travel explorer.
- A lifecycle-cost and capital-plan evaluator.
- A community-facing scenario comparison interface.
- An AI-assisted, policy-gated mathematical query layer.

A consumer application should be responsible for:

- Authentication and authorization.
- Consent capture and revocation.
- Data ingestion.
- Geospatial data licensing.
- Long-term audit storage.
- User interface accessibility.
- Community governance workflow.
- Human approvals.
- Operational system integration.
- Jurisdiction-specific legal analysis.

## Recommended Initial Release Boundary

The initial release should prioritize a coherent, reliable core over breadth.

The first stable release should include:

- Typed units and bounded scalar values.
- Time windows and scenario definitions.
- Provenance and aggregation declarations.
- Result envelopes with reproducibility digests.
- Water storage balance.
- Energy storage balance.
- Material-delivery capacity screen.
- Fuel and emissions estimate.
- Queue utilization and stability screen.
- Lifecycle-cost calculation.
- Aggregate service-access index.
- Ecological mass-balance calculation.
- Uncertainty interval structures.
- Rights, accessibility, ecological, and human-review metadata.
- Serialization support.
- Comprehensive tests and examples using non-sensitive synthetic or public aggregate data.

Later releases can add:

- Time-expanded transit networks.
- Capacitated vehicle routing.
- Mixed-integer construction scheduling.
- Robust optimization.
- Discrete-event simulation.
- Advanced hydrology.
- Heat-island spatial modeling.
- Multi-objective Pareto optimization.
- Formal optimization-model verification adapters.
- WebAssembly public scenario execution.

## Quality and Impact Metrics

- `knowledge_factor`: 0.91  
  Basis: the crate is grounded in dimensional analysis, physical balances, operations research, queueing theory, lifecycle-costing, scenario analysis, and reproducible software practice.

- `eco_impact_value`: 0.90  
  Basis: it directly supports water conservation, energy resilience, emissions accounting, material logistics, waste reduction, restoration measurement, and infrastructure planning.

- `harm_risk`: 0.18  
  Basis: risk remains low when the stated aggregation, purpose limitation, review, accessibility, and prohibited-use constraints are enforced; it rises substantially if consumers bypass those boundaries.

- `accessibility_impact`: 0.96

  ## Worked planning examples

- [Public charging kiosk reserve sizing](docs/public-charging-kiosk-reserve-sizing.md): a fully synthetic, aggregate-statistics example that derives an 8.15 kWh nominal reserve estimate for a 2.0 kW kiosk load, an 8-hour service window, and a 90% one-sided outage-duration confidence target.
  Basis: accessible routes, service continuity, parity analysis, offline alternatives, and explicit accessibility constraints are first-class mathematical concerns.

- `rights_alignment`: 0.97  
  Basis: the crate rejects person-level scoring, treats sensitive telemetry as prohibited by default, preserves human review, exposes uncertainty, and frames models as decision support rather than authority.
