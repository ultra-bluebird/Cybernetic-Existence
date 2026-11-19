# Population.Math Foundation

## Purpose

Population.Math is a municipal-scale mathematical services foundation for transparent, reproducible, privacy-preserving decision support.

It combines:

- Physical accounting
- Network optimization
- Queueing and capacity analysis
- Demand forecasting
- Spatial statistics
- Scenario simulation
- Ecological mass balance
- Accessibility-aware service analysis
- Public-budget and lifecycle-cost models
- Uncertainty quantification
- Rights-impact and equity review gates

Population.Math produces bounded, explainable outputs. It does not make binding eligibility, enforcement, medical, employment, housing, credit, policing, immigration, or civic-participation decisions about individuals.

## Non-Negotiable Constraints

- No resident-level social scores.
- No inference of identity, disability, augmentation status, health condition, behavior, or worthiness from telemetry.
- No essential service may require continuous connectivity, proprietary hardware, biometric identity, optional location sharing, or unrelated consent.
- Sensitive data must be minimized, aggregated, purpose-limited, encrypted in storage and transit, retained only as long as necessary, and deletable where feasible.
- Every material recommendation must identify inputs, units, assumptions, uncertainty bounds, known limitations, affected groups, accessibility effects, and a review path.
- Human and community review remain required for consequential public actions.
- Models must compare alternatives rather than present one optimization result as an unquestionable civic decision.

## Core Mathematical Domains

| Domain | Main question | Primary methods | Output examples |
|---|---|---|---|
| Mobility | How can people and materials travel safely, accessibly, and efficiently? | Graph theory, shortest paths, min-cost flow, vehicle routing, network assignment, robust optimization | Route alternatives, travel time ranges, accessible-path coverage, fleet utilization |
| Transit | How should fixed and flexible transit capacity be allocated? | Time-expanded graphs, headway optimization, GTFS routing, queueing, demand models | Transfer reliability, crowding probability, service-frequency scenarios |
| Freight and construction | How can material deliveries be coordinated under load, yard, crew, and site constraints? | Capacitated vehicle routing, bin packing, scheduling, mixed-integer optimization | Delivery plans, staging capacity, fuel estimates, schedule risk |
| Water | Can supply meet demand under climate, storage, losses, and conservation scenarios? | Water balance, time-series forecasting, stochastic hydrology, network flow | Storage trajectory, shortage risk, conservation value, leakage priority |
| Energy | Can generation, storage, and demand meet service needs with resilience? | Load forecasting, unit commitment approximations, dispatch optimization, reliability metrics | Peak-demand ranges, critical-load coverage, storage duration |
| Infrastructure maintenance | What work should be scheduled given crews, safety windows, assets, and response targets? | Scheduling, queueing, reliability engineering, condition-based maintenance | Backlog forecasts, crew-load bands, response-time risk |
| Growth and land use | What infrastructure demand follows from growth scenarios? | Cohort-component projections, land-use scenarios, input-output models | Population bands, housing demand, school-water-transit implications |
| Public services | Are service workloads sustainable and accessible? | Queueing theory, workload allocation, service-level analysis | Wait-time distributions, staffing ranges, accessible service coverage |
| Ecological systems | What environmental benefit or burden follows from an intervention? | Mass balance, energy balance, spatial interpolation, lifecycle accounting | Water-quality change, heat mitigation, habitat connectivity, emissions ranges |
| Labor and economy | What are the local implications of employment, wages, skills, and project spending? | Time-series analysis, input-output analysis, constrained allocation | Workforce requirements, unemployment trends, local procurement scenarios |
| Finance | What is the full cost and benefit of a project over time? | Net present value, lifecycle costing, Monte Carlo simulation, sensitivity analysis | Capital plan scenarios, operating-cost bands, contingency requirements |
| Emergency response | How can capacity be prepared without discriminating against residents? | Coverage optimization, discrete-event simulation, robust facility location | Response coverage, cooling-center capacity, accessible evacuation alternatives |

## Canonical Units

All data structures must carry units and timestamps.

| Quantity | Canonical unit |
|---|---|
| Distance | meter |
| Area | square meter |
| Volume | cubic meter |
| Flow | cubic meter per second |
| Mass | kilogram |
| Energy | kilowatt-hour or joule |
| Power | kilowatt or watt |
| Time | second internally; ISO 8601 externally |
| Currency | integer minor units with currency code |
| Carbon emissions | kilogram carbon-dioxide-equivalent |
| Population count | persons, aggregated to an approved geography |
| Probability | unit interval from 0 to 1 |
| Confidence interval | lower and upper bounds in the source quantity unit |

## Foundation Indices

### Service Access Index

The Service Access Index measures whether a population can reach a service through usable modes rather than only whether the service exists.

\[
SAI_g =
\frac{
\sum_{i \in g} w_i \cdot \mathbb{1}
\left[
T_i \leq T_{\max}
\land A_i = 1
\land C_i \leq C_{\max}
\right]
}{
\sum_{i \in g} w_i
}
\]

Where:

- \(g\) is an aggregate geography or voluntarily defined community cohort.
- \(w_i\) is a non-sensitive population weight.
- \(T_i\) is travel time.
- \(A_i\) indicates that the complete path is accessible.
- \(C_i\) is user cost.
- \(T_{\max}\) and \(C_{\max}\) are publicly reviewed thresholds.

Use this index only with sufficiently aggregated inputs. It should not expose a person’s route, medical device needs, location history, or assistive-technology status.

### Accessibility Parity Gap

\[
APG =
\left|
SAI_{\text{reference}} - SAI_{\text{protected-access}}
\right|
\]

The model flags a parity gap for review; it does not infer why a person uses an assistive technology and does not deny service based on the result.

### Network Reliability Index

\[
NRI =
\frac{
\sum_{s \in S}
p_s \cdot Q_s
}{
\sum_{s \in S} p_s
}
\]

Where:

- \(S\) is a set of predefined disruption scenarios.
- \(p_s\) is the scenario weight.
- \(Q_s\) is the fraction of demand served under scenario \(s\).

This supports resilience planning for heat events, outages, flooding, construction closures, and service interruptions.

### Water Balance

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

- \(S_t\) is stored water.
- \(I_t\) is inflow.
- \(D_t\) is demand.
- \(L_t\) is losses.
- \(E_t\) is evaporation or other measured loss.
- \(R_t\) is recovered, reclaimed, or transferred supply.

The model must keep potable, reclaimed, ecological, emergency, and contractual allocations distinct.

### Energy Balance

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

- \(B_t\) is battery energy.
- \(B_{\max}\) is usable storage capacity.
- \(C_t\) is charge energy.
- \(G_t\) is discharge energy.
- \(\eta_c\) and \(\eta_d\) are charging and discharge efficiencies.

Critical services must be modeled separately from discretionary demand so resilience analysis does not hide a loss of essential access.

### Construction Delivery Cost

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

A delivery route can be optimized under constraints:

\[
\sum_{j} x_{ij} = 1
\]

\[
\sum_i q_i x_{ij} \leq Q_j
\]

\[
\sum_i v_i x_{ij} \leq V_j
\]

\[
t_i^{\text{arrival}}
\in
[a_i, b_i]
\]

Where capacity includes mass, volume, safe axle load, staging space, crew availability, and delivery windows.

### Carbon Estimate

\[
E_{\text{CO2e}}
=
\sum_k
d_k \cdot r_k
+
\sum_m
M_m \cdot e_m
+
E_{\text{idle}}
\]

Where:

- \(d_k\) is vehicle distance.
- \(r_k\) is an approved emissions factor.
- \(M_m\) is material quantity.
- \(e_m\) is a material lifecycle factor.
- \(E_{\text{idle}}\) represents measured or modeled idle emissions.

Results must state the emissions-factor source, year, boundary, and uncertainty.

### Public-Service Queue

For an approximate service queue:

\[
\rho = \frac{\lambda}{c\mu}
\]

Where:

- \(\lambda\) is arrival rate.
- \(c\) is the number of service channels.
- \(\mu\) is service rate per channel.
- \(\rho\) is utilization.

If \(\rho \geq 1\), the system is unstable under the stated assumptions. The output must be presented as a capacity warning, not as a justification to reduce access.

### Lifecycle Cost

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

All public-facing results must show discount rate, study horizon, cost categories included, and sensitivity ranges.

### Community Benefit Feasibility Score

\[
CBF
=
w_a A
+
w_r R
+
w_e E
+
w_s S
-
w_h H
\]

Where:

- \(A\) is accessibility improvement.
- \(R\) is resilience improvement.
- \(E\) is ecological benefit.
- \(S\) is service-quality improvement.
- \(H\) is assessed harm risk.
- weights are publicly documented and subject to governance review.

This score must never be used as a hidden score for communities or persons. It is a transparent comparison tool for project alternatives.

## Simulation Classes

### Deterministic calculations

Use when inputs are measured or stipulated:

- Water-volume accounting
- Material quantities
- Road-distance estimates
- Budget arithmetic
- Energy conversion
- Carbon-factor multiplication
- Crew-hour scheduling

### Optimization

Use when choosing among constrained alternatives:

- Accessible route planning
- Transit frequency allocation
- Delivery scheduling
- Pump and storage dispatch
- Maintenance crew allocation
- Facility siting
- Resource allocation

All optimization must retain multiple near-optimal alternatives when decisions affect communities. A single minimum-cost solution can hide accessibility, equity, ecological, or resilience tradeoffs.

### Stochastic simulation

Use when uncertainty materially changes the outcome:

- Weather-dependent water demand
- Traffic and travel time
- Transit delay propagation
- Grid outages
- Construction delays
- Seasonal employment
- Emergency shelter and cooling-center demand

Monte Carlo outputs should include median, lower percentile, upper percentile, failed-scenario rate, and input sensitivity ranking.

### Discrete-event simulation

Use for systems where events and queues matter:

- Dispatch centers
- Permit processing
- Transit boarding
- Maintenance response
- Clinic appointments
- Construction staging
- Waste and recycling logistics

### Agent-based simulation

Use only for aggregate behavioral scenarios where individual tracking is unnecessary:

- Evacuation route demand
- Market adoption scenarios
- Neighborhood energy conservation programs
- Transit mode shifts
- Water-use response to conservation measures

Agent models must use synthetic agents or statistically aggregated cohorts, never resident-level behavioral surveillance.

## Language and Runtime Strategy

| Layer | Recommended technology | Reason |
|---|---|---|
| Numerical and scientific kernel | Python with NumPy, SciPy, Pandas, Pyomo, OR-Tools, GeoPandas, xarray | Fast research iteration, mature optimization and geospatial ecosystem |
| High-throughput compute kernel | C++20 with Eigen, Boost, Google OR-Tools bindings where appropriate | Deterministic performance, memory control, simulation throughput |
| Civic API and validation layer | Kotlin or Java | Strong typing, stable service deployment, mature validation and observability |
| Browser-facing explorer | TypeScript with Web Workers and WebAssembly | Accessible public interfaces, local computation, offline-capable scenario review |
| Policy and authorization | Rego plus typed policy adapters | Explainable consent, purpose, retention, and approval decisions |
| Compact embedded calculation rules | Lua | Auditable local rules for devices, kiosks, or offline field workflows |
| Formal model checking | TLA+ and property-based tests | Verification of scheduling, consent, and fail-closed invariants |
| Database and analytics | PostgreSQL with PostGIS; DuckDB for reproducible local analysis | Strong spatial queries, public data handling, portable analysis |
| Data interchange | JSON Schema, CSV, GeoJSON, GTFS, GTFS-Realtime, Parquet | Interoperability and auditable exchange |

## AI Capability Boundary

An AI can assist with:

- Mapping natural-language questions to approved mathematical services.
- Explaining formulas and assumptions in plain language.
- Generating scenario configurations.
- Detecting missing units, invalid ranges, incompatible time windows, and data-quality gaps.
- Comparing multiple simulation outputs.
- Producing accessibility-aware summaries.
- Drafting public-facing explanation documents.

An AI must not:

- Invent measurements, source data, constraints, legal authority, or certainty.
- Execute actions against public systems without explicit human approval.
- Produce resident-level predictions or eligibility decisions.
- Conceal uncertainty, assumptions, disagreement, or data limitations.
- Override policy, consent, accessibility, safety, or community-review gates.

## Required Result Envelope

Every Population.Math calculation returns:

- calculation name
- version
- input provenance
- units
- geographic and temporal scope
- assumptions
- model parameters
- result values
- uncertainty interval
- sensitivity summary
- validation status
- accessibility impact
- rights-impact notes
- ecological impact notes
- human-review requirement
- reproducibility hash

## Initial Service Catalog

- `route.accessible_alternatives`
- `route.material_delivery_plan`
- `transit.headway_scenarios`
- `transit.transfer_reliability`
- `traffic.intersection_delay`
- `water.balance_projection`
- `water.loss_priority`
- `energy.load_forecast`
- `energy.storage_resilience`
- `construction.staging_capacity`
- `construction.crew_schedule`
- `maintenance.backlog_projection`
- `maintenance.response_capacity`
- `population.growth_scenarios`
- `housing.infrastructure_demand`
- `public_service.queue_capacity`
- `employment.trend_projection`
- `budget.lifecycle_cost`
- `ecology.mass_balance`
- `ecology.heat_mitigation`
- `ecology.habitat_connectivity`
- `waste.material_diversion`
- `emergency.accessible_coverage`
- `equity.service_access_parity`
- `governance.scenario_tradeoff_report`

## Review and Governance

Population.Math follows four recurring operational functions:

- Govern: define accountability, rights constraints, data stewardship, approval thresholds, and review ownership.
- Map: identify affected communities, intended benefits, possible harms, constraints, input provenance, and uncertainty sources.
- Measure: validate data quality, run tests, calculate outcomes, quantify uncertainty, and monitor disparity or accessibility signals.
- Manage: select mitigations, publish explanations, preserve manual alternatives, document residual risk, and maintain an appeal or correction path.

This structure aligns with NIST’s AI Risk Management Framework core functions of Govern, Map, Measure, and Manage.
