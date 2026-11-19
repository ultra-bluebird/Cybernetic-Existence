# Population.Math Research-Agent Directives

## Objective

Use these directives when researching, selecting, validating, and documenting foundations for `crates/popmath`.

The goal is to produce a mathematically rigorous, interoperable, privacy-preserving, accessible, reproducible Rust crate for aggregate civic, ecological, infrastructure, and public-service scenario analysis.

The research agent must preserve:

- Mathematical correctness.
- Explicit units.
- Data provenance.
- Purpose limitation.
- Aggregate and privacy-preserving computation.
- Accessibility and service continuity.
- Ecological accountability.
- Human and community review.
- Solver transparency.
- Reproducibility.
- Compatibility with established public standards.

The research agent must not weaken the crate’s internal correctness model merely to accommodate ambiguous, underspecified, or unconventional external data formats.

## Directive One: Units, Standards, and Type Safety

### Decision

Prioritize **maximal internal type safety**. Support existing civic, ecological, transportation, water, energy, construction, and emissions standards through explicit adapter layers at data-ingestion and data-export boundaries.

Do not weaken the `popmath` core quantity system to mirror every external source’s raw numeric representation.

### Required architecture

The units architecture must have three distinct layers:

| Layer | Responsibility | Rules |
|---|---|---|
| External representation | Read data formats used by outside systems, reports, sensor exports, spreadsheets, APIs, and standards | May accept unconventional labels, columns, unit strings, locale formatting, or source-specific structures only through a validated parser |
| Canonical `popmath` representation | Store and calculate with strongly typed canonical quantities | Every physical, temporal, financial, environmental, and population quantity has an explicit unit and validated range |
| External reporting representation | Export results into required reporting formats | Conversion must be explicit, reversible when possible, documented, and attached to the result provenance |

### Core rule

External interoperability is an adapter responsibility.

Internal mathematical correctness is a core-crate responsibility.

The crate must never permit ambiguous or unconventional external unit forms to flow directly into internal calculation types as untyped numbers.

### Required input-normalization process

For every external standard or source format, the research agent must define:

1. The source field name or unit expression.
2. The source standard, publisher, documentation version, and applicable period.
3. The parsed physical meaning.
4. The canonical `popmath` quantity type.
5. The conversion formula.
6. The conversion-factor provenance.
7. The valid numeric range.
8. Missing-value behavior.
9. Precision and rounding behavior.
10. Export round-trip behavior.
11. Test fixtures demonstrating valid, invalid, and ambiguous records.

### Examples of acceptable boundary adaptation

| External form | Canonical internal form | Required conversion note |
|---|---|---|
| `gallons/day` | `FlowRate<CubicMeterPerSecond>` | Declare gallon convention and conversion factor |
| `acre-feet` | `Volume<CubicMeter>` | Preserve source reporting unit for display if requested |
| `kWh/month` | `Energy<KilowattHour>` over declared `TimeWindow` | Do not infer month length without an explicit period |
| `lbs CO2e` | `Emissions<KilogramCo2e>` | Preserve accounting-factor source and lifecycle boundary |
| `metric tons CO2e` | `Emissions<KilogramCo2e>` | Record whether “tonne” means metric tonne |
| `vehicle miles traveled` | `Distance<Meter>` plus mode and time basis | Preserve aggregation and calculation method |
| `MGD` | `FlowRate<CubicMeterPerSecond>` | Expand abbreviation only through an approved parser |
| `USD` decimal value | `Money<CurrencyCode>` in integer minor units | Define rounding and currency-scale rule |
| `persons per household` | Typed `Ratio` | Preserve geographic and temporal aggregation boundary |
| `percent` | `UnitInterval` or explicitly typed `Ratio` | Divide by 100 only through declared parser semantics |

### Unconventional-unit policy

When an external standard uses a non-SI, abbreviated, mixed, or source-specific unit representation:

- Accept it only through a named adapter.
- Record the original unit string exactly as received.
- Normalize to a canonical internal quantity.
- Store the converter version and factor source in provenance.
- Reject ambiguous abbreviations unless the adapter has an unambiguous source-specific contract.
- Reject unitless values unless the adapter’s schema permanently defines the unit and version.
- Never guess whether `ton` means short ton, long ton, or metric tonne.
- Never guess whether `gal` means U.S. gallon or imperial gallon.
- Never assume a reporting period for rate-normalized values.
- Never convert currency without a declared rate, source, timestamp, and currency basis.
- Never treat `CO2`, `carbon`, and `CO2e` as interchangeable quantities.

### Canonical-unit policy

The canonical internal system should favor:

- SI units for physical calculation.
- Explicit unit-bearing wrappers for readability.
- Integer minor units for money.
- Explicitly typed emissions quantities with declared accounting boundaries.
- Explicit time windows for rates, accumulations, and averages.
- Explicit ratio and probability types.
- Unit-bearing intervals for uncertainty.

`uom` is an appropriate high-priority candidate for the internal physical-unit layer because it provides type-safe, zero-cost dimensional analysis and includes prebuilt SI-oriented quantity systems. The research agent should validate its actual fit through a bounded prototype rather than assume suitability from its general description. [68][70]

### Research tasks

The research agent must:

- Evaluate `uom` against the core quantity requirements.
- Compare it with a small custom wrapper approach only where domain requirements cannot be met cleanly.
- Produce an interoperability matrix for initial target standards, including water, energy, construction, transportation, emissions, and public-finance formats.
- Design a `UnitAdapter` contract for source-specific parsing and normalized conversion.
- Define `UnitParseError` categories for ambiguous, unsupported, invalid, missing, and incompatible source units.
- Define golden test fixtures for each initial adapter.
- Test exact conversions, bounded conversion error, and round-trip output.
- Confirm serialization maintains explicit unit labels.
- Confirm WebAssembly compatibility for selected unit dependencies.
- Confirm that solver adapters can safely receive normalized scalar coefficients while result values remain unit-typed.

### Acceptance criteria

The units research is complete only when:

- The core can reject incompatible dimensions before a domain calculation executes.
- Every initial external standard has an explicit adapter specification.
- Every adapter identifies source version and canonical output unit.
- Unitless or ambiguous inputs fail with a structured error.
- Conversions preserve provenance.
- Physical calculations remain type-safe internally.
- Results can be exported in a requested supported standard without altering their canonical result meaning.
- Tests demonstrate that changing only a unit representation does not change the physical result.
- Tests demonstrate that ambiguous source unit labels are rejected rather than guessed.

## Directive Two: Provenance and Aggregation Declarations

### Decision

Do not fully reject all inputs lacking explicit aggregation declarations at the ingestion boundary.

Instead, classify them as:

```text
AggregationStatus::Unknown
```

and place them in a **quarantined research-only state**.

Unknown-aggregation inputs may be used only for non-decision-ready exploratory validation, schema inspection, adapter development, or data-quality assessment. They must not be used to generate public reports, policy comparisons, optimization recommendations, service-access outcomes, parity analysis, operational planning outputs, or decision-support results.

No default aggregation level may be assumed.

### Why this is the required balance

A strict immediate rejection would discard potentially valuable public, historical, legacy, or scientifically relevant data before the research workflow can inspect and classify it.

A permissive default would contaminate scenario outputs because the crate could not determine:

- Whether the data is person-level, household-level, facility-level, segment-level, neighborhood-level, or citywide.
- Whether it carries disclosure risk.
- Whether it can be combined with other aggregates.
- Whether it is representative of the intended geography.
- Whether it is compatible with access, service, fairness, or demand calculations.
- Whether the stated purpose permits the proposed use.

The required design therefore separates **ingestion for inspection** from **authorization for analysis**.

### Required aggregation states

The provenance layer should distinguish:

| Aggregation status | Meaning | Permitted use |
|---|---|---|
| `VerifiedAggregate` | Aggregation method, scope, minimum group conditions where applicable, and data classification are documented | Eligible for scenario analysis subject to purpose and review rules |
| `VerifiedInfrastructureScope` | Data describes infrastructure, assets, networks, facilities, or environmental measurements rather than people | Eligible for relevant domain models subject to provenance and purpose rules |
| `Synthetic` | Generated scenario data with documented method and no claim of observed population behavior | Eligible for research, testing, and scenario analysis when clearly labeled |
| `PublicAggregate` | Publicly published aggregate with sufficient scope and source documentation | Eligible for analysis subject to data-quality and purpose requirements |
| `Unknown` | Aggregation or scope is not sufficiently documented | Quarantined research-only use; no decision-ready result |
| `Insufficient` | Known to lack needed aggregation, scope, or privacy documentation | Rejected for model execution until remediated |
| `Prohibited` | Known to be outside allowed data-use conditions | Rejected |

### Quarantine behavior

When provenance contains `AggregationStatus::Unknown`, the crate must:

- Preserve the original provenance record.
- Mark the input as non-decision-ready.
- Require a data-stewardship review.
- Require a documented aggregation assessment before scenario execution.
- Prevent use in public-facing, operational, access, parity, allocation, or optimization results.
- Permit metadata inspection, schema validation, unit normalization research, and data-quality profiling.
- Require any derived aggregate to carry a `TransformationRecord`.
- Require the derived aggregate to declare its aggregation method, geographic scope, time scope, disclosure-risk review, and transformation digest.
- Emit `ValidationStatus::InsufficientData` or `ValidationStatus::ReviewRequired` rather than `Validated`.

### No automatic aggregation

The crate must not automatically aggregate unknown records into a supposedly safe form.

Aggregation is not merely summation. It can alter representativeness, hide subgroup differences, create misleading denominators, and potentially expose small groups. It requires a declared method, scope, purpose, and review process.

The core crate may validate an aggregation declaration, but it should not infer a privacy guarantee from an arithmetic operation.

### Minimum provenance declaration for decision-ready use

A dataset used in a decision-ready calculation must declare:

- Source name.
- Source kind.
- Collection or publication time coverage.
- Geographic scope.
- Data classification.
- Aggregation status.
- Aggregation method or infrastructure scope explanation.
- Transformation history.
- Data-quality statement.
- Intended or permitted purpose.
- Retention reference where applicable.
- Known limitations.
- Integrity digest where available.

The W3C PROV family provides a useful interoperable conceptual basis for recording entities, activities, agents, derivations, and annotations in provenance systems. `popmath` may use a compatible internal mapping or export adapter, while retaining domain-specific metadata for aggregation, quality, purpose, and review. [79][84][86]

### Required provenance model additions

The research agent should add the following structures or equivalent semantics:

- `AggregationStatus`
- `AggregationMethod`
- `AggregationScope`
- `DisclosureRiskDeclaration`
- `DataStewardshipReview`
- `QuarantineReason`
- `TransformationRecord`
- `DerivedAggregateDeclaration`
- `AnalysisAuthorization`
- `DecisionReadiness`

### Required validation rules

The provenance system must enforce:

- `Unknown` aggregation cannot produce `DecisionReadiness::Ready`.
- `Unknown` aggregation cannot enter `access`, `population`, `mobility-demand`, `parity`, or public-service allocation models.
- `Unknown` aggregation cannot be used to optimize resource allocation across communities.
- `Unknown` aggregation may enter only approved inspection and normalization workflows.
- A derived aggregate cannot become `VerifiedAggregate` without declared method, scope, quality statement, and review completion.
- Facility, network, environmental, and project-site data can use `VerifiedInfrastructureScope` when no person-level interpretation is claimed.
- Synthetic data is always labeled synthetic in downstream result envelopes.
- Data-quality warnings propagate from input provenance to every downstream result.
- A result is non-decision-ready if any required input remains quarantined.

### Privacy and data-quality rationale

The provenance policy should increase disassociability, minimize unnecessary personal linkage, document the origin and history of data, and preserve data-quality limitations. These goals are consistent with the NIST Privacy Framework’s emphasis on data minimization and processing that limits observability, linkability, identification, and unnecessary inference, as well as with provenance practices that record source and transformation history. [78][81][85]

### Acceptance criteria

The aggregation research is complete only when:

- A verified citywide water-demand aggregate can run through a water-balance scenario.
- A verified infrastructure network can run through a route or maintenance model.
- A synthetic scenario can run through a simulation while clearly retaining its synthetic status.
- An unknown-aggregation dataset can be parsed and inspected but cannot produce a decision-ready result.
- An unknown-aggregation dataset cannot enter access or parity calculations.
- A derived aggregate must declare its transformation and review before use.
- Data-quality limitations appear in all derived result envelopes.
- No aggregation level is inferred by default.
- No unsupported claim about privacy or anonymity is generated by the crate.

## Directive Three: Optimization Alternatives and Uniqueness

### Decision

Alternative solutions are not required as a blanket condition for every optimization problem.

Instead, every optimization result must include an **alternative-analysis record**, and the required alternative output depends on the problem’s geometry, solver status, objective structure, and material tradeoffs.

The crate must always make it possible to determine whether:

- The solution is unique.
- Multiple mathematically equivalent optima exist.
- Near-optimal solutions exist within a declared tolerance.
- Multiple objectives create non-dominated tradeoffs.
- Integer, routing, scheduling, and discrete choices create materially distinct feasible alternatives.
- The solver was unable to establish uniqueness or optimality.

### Required result categories

| Problem condition | Required output |
|---|---|
| Proven unique optimum under stated numerical tolerance | One solution plus a uniqueness certificate or explicit solver-supported uniqueness finding |
| Multiple exact optima | Representative solution plus alternative-optima summary and a method for enumerating or sampling materially distinct optima where feasible |
| Single-objective continuous optimization with near-optimal alternatives | Best solution plus a near-optimal sensitivity or stability analysis |
| Multi-objective optimization | Retained Pareto frontier or a documented representative subset of non-dominated alternatives |
| Integer, routing, scheduling, assignment, or facility-location optimization | At least one baseline and a bounded set of materially distinct feasible or near-optimal alternatives where computationally feasible |
| Infeasible problem | Infeasibility explanation, conflicting constraints, and feasible-relaxation alternatives where safe and meaningful |
| Time-limited or gap-limited solver result | Best known feasible solution, optimality gap, termination reason, and alternative-analysis limitation |
| Closed-form or analytically unique calculation | Result plus a mathematical explanation of why alternatives are not applicable |

### Core rule

Every material optimization result must disclose its alternative-analysis status.

It must not imply that a returned solution is the only possible plan unless uniqueness has been established under the declared model, tolerances, and constraints.

### When alternatives are mandatory

The research agent must require retained alternatives for:

- Multi-objective problems.
- Problems with conflicting financial, accessibility, ecological, resilience, or service-quality objectives.
- Integer or discrete allocation problems.
- Vehicle routing.
- Transit service allocation.
- Crew assignment.
- Construction scheduling.
- Facility siting.
- Resource allocation among multiple service areas.
- Problems with hard and soft constraints.
- Problems where a near-optimal solution may materially reduce ecological burden, increase accessibility, preserve service continuity, or improve resilience.
- Problems where a result affects public-facing planning options.

### When alternatives may be summarized instead of enumerated

A full list of alternatives is not required when:

- The model is closed-form and analytically unique.
- The optimization problem is proven unique within declared numerical tolerance.
- A convex continuous problem has a unique optimum and material objective sensitivity is low.
- The available solver cannot enumerate alternatives without disproportionate computational cost.

In these cases, the result must still include:

- Uniqueness or stability method.
- Numerical tolerance.
- Objective sensitivity.
- Constraint sensitivity where relevant.
- A statement of what changes would alter the result.
- A baseline comparison where a baseline exists.
- A limitation note if uniqueness could not be fully established.

### Distinctness policy

Alternative solutions must be materially distinct, not trivial permutations.

For example:

- Two vehicle routes that only swap identical vehicle labels are not meaningful alternatives.
- Two energy-dispatch schedules may be meaningfully distinct if they change critical-load continuity, renewable curtailment, battery cycling, or peak demand.
- Two delivery plans may be meaningfully distinct if they change accessible-path disruption, arrival windows, crew requirements, emissions, or neighborhood burden.
- Two transit alternatives may be meaningfully distinct if they change transfer reliability, total travel time, wait time, step-free continuity, coverage, or operating cost.

The research agent must define a domain-specific `AlternativeDistinctnessMetric` for each major optimization family.

### Required optimization metadata

Every optimization result must contain:

- Objective definitions and priorities.
- Hard constraints.
- Soft constraints.
- Constraint relaxations, if any.
- Solver identity and version.
- Solver configuration.
- Numerical tolerances.
- Random seed, if applicable.
- Solver status.
- Optimality gap.
- Feasibility status.
- Uniqueness status.
- Alternative-analysis status.
- Alternative distinctness criteria.
- Retained alternatives or the reason alternatives are not applicable.
- Post-solve constraint validation.
- Accessibility, rights, ecological, and service-continuity implications for each material alternative.
- Human-review requirement.

### Uniqueness statuses

The result layer should define:

- `ProvenUnique`
- `LikelyUniqueWithinTolerance`
- `MultipleExactOptima`
- `MultipleNearOptima`
- `NotAssessed`
- `NotApplicable`
- `UnknownDueToSolverLimit`

A solver result reported as optimal is not automatically proof that it is unique.

### Required proof-of-concept studies

The research agent must demonstrate:

| Case | Required alternative analysis |
|---|---|
| Shortest accessible path | Determine whether one route is uniquely shortest; if not, retain routes with materially different travel time, grade, crossings, or closure exposure |
| Delivery routing | Retain alternatives with different fuel, delivery lateness, crew load, accessible-path impact, and emissions profiles |
| Water dispatch | Compare alternatives that preserve ecological flow, reduce shortage, retain emergency reserve, or reduce energy cost |
| Energy storage dispatch | Compare alternatives affecting critical-load continuity, cycling, curtailment, and peak demand |
| Public-service staffing | Compare alternatives affecting queue stability, service level, staffing cost, and accessibility-support capacity |
| Lifecycle investment selection | Compare alternatives affecting cost, maintenance burden, emissions, resilience, and access coverage |

### Acceptance criteria

The alternative-solution research is complete only when:

- Every optimization result reports uniqueness or alternative-analysis status.
- Multi-objective models retain a Pareto frontier or documented representative set.
- Integer and routing models retain materially distinct alternatives when feasible.
- Unique or closed-form results include a stability or uniqueness explanation.
- Alternative enumeration cannot violate hard constraints.
- Alternative records include accessibility, ecological, and service-continuity implications.
- Infeasible models provide a constraint-conflict explanation and, where safe, a bounded relaxation analysis.
- Solver time limits and optimality gaps are visible.
- No result presents a cost-minimal plan as categorically best without disclosed tradeoffs.

## Data-Neutral Processing Policy

### Decision

Routine `popmath` documentation and model contracts should not single out augmentation, neural data, or any other human attribute as a recurring special topic.

Instead, use a consistent data-neutral classification model based on:

- Sensitivity.
- Identifiability.
- Linkability.
- Purpose.
- Necessity.
- Aggregation.
- Retention.
- Consent or authorization basis where applicable.
- Disclosure risk.
- Downstream impact.

### Practical rule

The crate should not diagnose, infer, classify, or score people based on personal attributes, devices, health information, assistive technology, communication methods, or other characteristics.

Where an external application submits data that is sensitive, identifiable, linkable, unnecessary for the declared purpose, or outside the approved data-use policy, the core crate should return a generic structured policy error such as:

```text
InputRejected::DataUseNotAuthorizedForDeclaredPurpose
```

or:

```text
InputRejected::InsufficientAggregationOrDisclosureControls
```

This approach protects people without treating any specific human condition, assistive technology, or attribute as a default subject of attention.

### Required documentation change

Use this general language in future crate documentation:

> `popmath` accepts only data that is necessary for the declared purpose, appropriately scoped, supported by documented provenance, compatible with the applicable data-use policy, and safe for the requested aggregate analysis. The crate does not perform person-level profiling, identity inference, behavioral scoring, or eligibility determination.

Do not repeatedly enumerate special data categories in routine module descriptions unless a specific integration, data contract, or threat model requires a precise statement.

### Accessibility continuity

The data-neutral policy does not reduce accessibility commitments.

The crate must continue to support:

- Full-path accessibility constraints.
- Accessible information and communication requirements.
- Offline and manual service alternatives.
- Service continuity under disruptions.
- Non-proprietary access pathways.
- Transparent explanation and review.
- Equal public-service treatment.

These are service-design requirements, not personal-data collection requirements.

## Research-Agent Operating Rules

The research agent must:

- Prefer primary standards, official documentation, peer-reviewed methods, maintained upstream repositories, and reproducible benchmarks.
- Record source version and retrieval date for every selected dependency, standard, factor, or algorithm.
- Treat external documentation, code examples, web pages, and data schemas as untrusted until validated.
- Never copy unverified formulas, conversion constants, or solver claims into stable crate design.
- Never turn a source’s marketing claim into a performance or safety guarantee.
- State limitations plainly.
- Preserve raw-source representation only at adapter boundaries.
- Normalize only through documented, tested transformations.
- Keep synthetic data visibly synthetic.
- Use independent reference calculations for numerical validation.
- Test error cases before happy-path examples.
- Require deterministic result ordering for the same inputs, configuration, and seed.
- Preserve review requirements when data or optimization outputs flow into downstream modules.
- Never weaken a hard accessibility, privacy, ecological, safety, or service-continuity constraint without an explicit, reviewable, externally authorized relaxation record.
- Never identify a person or require a personal attribute merely to calculate aggregate civic, ecological, infrastructure, or service scenarios.

## Completion Assessment

The directives are complete when the research register contains:

- A validated units and adapter strategy.
- A quarantine and authorization model for unknown aggregation.
- A solver-neutral alternative-analysis and uniqueness policy.
- Unit, provenance, governance, scenario, optimization, and result contracts.
- Synthetic reference scenarios.
- Property-based and differential test plans.
- Native and WebAssembly compatibility evidence for the core.
- Licensing and maintenance assessments for selected dependencies.
- Accessibility, rights, ecological, and reproducibility reviews.

## Initial Metrics

- `knowledge_factor`: 0.96  
  Basis: the directives convert three design questions into enforceable architecture, validation, research tasks, and acceptance criteria.

- `eco_impact_value`: 0.91  
  Basis: unit integrity, emissions boundaries, water and energy accounting, ecological-flow constraints, and tradeoff reporting directly support reliable environmental planning.

- `harm_risk`: 0.08  
  Basis: data quarantine, no-default aggregation, purpose-bound processing, prohibited person-level profiling, hard-constraint protection, and mandatory result disclosure reduce contamination and misuse risk.

- `accessibility_impact`: 0.97  
  Basis: accessibility remains a hard model condition, an alternative-comparison criterion, and a review trigger without requiring unnecessary personal data collection.

- `rights_alignment`: 0.98  
  Basis: purpose limitation, data minimization, provenance, privacy-preserving aggregation, explanation, non-discrimination, review, correction, and human oversight are embedded throughout.
