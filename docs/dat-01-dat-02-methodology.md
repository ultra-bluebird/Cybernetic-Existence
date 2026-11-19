# DAT-01 and DAT-02 Methodology

## Purpose

DAT-01 establishes a privacy-budget allocation framework for recurring aggregate urban-data releases. DAT-02 establishes a small-cell protection method for geographic, temporal, and attribute aggregations.

The system treats privacy as a cumulative and compositional property:

\[
\epsilon_{\text{total}}
=
\sum_{i=1}^{n}\epsilon_i
\leq
\epsilon_{\max}
\]

This is the baseline sequential-composition rule. When releases use genuinely disjoint individual-level dataset partitions, parallel composition may use:

\[
\epsilon_{\text{total}}
=
\max_i(\epsilon_i)
\]

The framework is designed for aggregate environmental, water, heat, transit, infrastructure, and public-service statistics. It is not a license to identify residents, infer cybernetic status, derive biometrics, collect neural data, profile device use, or make service access dependent on privacy-invasive data collection.

NIST finalized guidance for evaluating differential-privacy guarantees in 2025, emphasizing that practitioners need a clear basis for understanding, evaluating, and comparing differential-privacy guarantees in real-world deployments. [141][142][147]

## DAT-01: Privacy Budgets

### Privacy accounting units

A privacy budget must be tracked by all of the following dimensions:

| Dimension | Purpose |
|---|---|
| Dataset partition | Prevents incorrectly treating overlapping populations as disjoint |
| Population universe | Defines which people may contribute to a release |
| Geographic scope | Captures geographic overlap and nested-area release risks |
| Temporal scope | Captures repeated-release and differencing risks |
| Query family | Groups similar count, mean, histogram, or model-output releases |
| Release frequency | Converts an apparently small per-release epsilon into cumulative privacy loss |
| Mechanism | Documents Laplace, Gaussian, geometric, hierarchical, or synthetic-aggregate release method |
| Sensitivity bound | Defines the maximum effect one person can have on the statistic |
| Accounting window | Defines whether budget resets daily, monthly, annually, or only with a new protected dataset |
| Adaptive status | Identifies requests selected after seeing prior outputs |

A privacy-budget ledger should not be keyed to a public identity, a user’s assistive technology, a disability category, a cybernetic attribute, a biometric, neural data, or a persistent device fingerprint. It is keyed to the release program, bounded dataset, accounting window, and approved query family.

### Budget policy

The framework uses three budgets:

\[
\epsilon_{\max}
=
\epsilon_{\text{routine}}
+
\epsilon_{\text{emergency reserve}}
\]

\[
\epsilon_{\text{routine}}
=
\epsilon_{\max}
-
\epsilon_{\text{emergency reserve}}
\]

Routine publications cannot consume the emergency reserve. A human-reviewed, documented emergency procedure governs any reserve use.

A privacy budget must include a \(\delta\) policy for approximate differential privacy:

\[
\delta_{\text{total}}
\leq
\delta_{\max}
\]

The schema limits \(\delta_{\max}\) to \(10^{-6}\) as a conservative program guard. A deployment must further set \(\delta\) in relation to the protected population and risk model rather than treating a single number as universally sufficient.

### Appropriate epsilon maximum

There is no scientifically universal \(\epsilon_{\max}\) for urban-intelligence workloads. The appropriate program value depends on sensitivity, dataset size, release frequency, publication scope, utility requirements, whether outputs can be linked with other releases, and the consequences of disclosure.

The recommended default policy is deliberately conservative:

| Release class | Planning epsilon range per protected dataset and accounting window | Governance requirement |
|---|---:|---|
| High-level public citywide indicators | 0.1 to 1.0 | Fixed query catalog, public methodology, and annual review |
| District or neighborhood aggregates | 0.25 to 2.0 | Small-cell controls, overlap accounting, and release-frequency cap |
| Frequent operational public indicators | 0.05 to 0.5 per planned release family | Cached outputs, coarsened geography or time, and strict composition accounting |
| Sensitive or sparse environmental and public-service indicators | 0.1 to 1.0 | Independent privacy review, motivated-intruder testing, and limited release cadence |
| Interactive or adaptive queries | Reserve-based allocation only | Query catalog, cached reuse, coarsening, or accountable human approval |

For a new public urban-data program, this standard recommends beginning with:

\[
\epsilon_{\max}=4.0
\]

per protected dataset and declared annual accounting window, with:

\[
\epsilon_{\text{emergency reserve}}=0.5
\]

This is a configurable **planning default**, not a universal guarantee of adequacy. A lower budget is preferable when the dataset is sparse, sensitive, repeatedly released, geographically fine-grained, or linkable with external sources. A higher budget requires a specific, independently reviewed justification.

The Census Bureau used differential privacy in its 2020 Census disclosure-avoidance system to protect respondents in published data products, illustrating the practical necessity of disclosure controls for large public tabular releases. [140][143][145]

### Frequency-aware allocation

For a release family \(j\) with per-release budget \(\epsilon_j\) and planned frequency \(f_j\):

\[
\epsilon_{j,\text{planned}}
=
f_j\epsilon_j
\]

Under basic sequential composition:

\[
\epsilon_{\text{routine used}}
=
\sum_j f_j\epsilon_j
\]

A monthly release with \(\epsilon=0.10\) has annual planned cost:

\[
12 \cdot 0.10 = 1.20
\]

The release-planning rule is:

\[
\sum_j f_j\epsilon_j
\leq
\epsilon_{\text{routine}}
\]

This forces a program to budget frequent releases before publication rather than spending privacy loss invisibly over time.

### Allocation priorities

The order of preference for handling demand beyond budget is:

1. Reuse a cached approved release.
2. Publish an already approved coarser geographic or temporal aggregate.
3. Combine requests into a pre-approved summary rather than issue multiple overlapping releases.
4. Delay release until the next accounting window if the dataset definition supports that reset.
5. Submit a human-reviewed exception request that documents public benefit, privacy risk, intersection risk, and alternatives.
6. Decline the new fine-grained release.

Budget exhaustion must not block a person’s essential service, correction, appeal, access request, or non-digital pathway. It limits new fine-grained aggregate publication only.

The project’s governance material already frames depleted differential-privacy budget as a guard on new fine-grained responses, with coarser aggregate fallback rather than loss of stakeholder access or forced session termination. [138]

### Adaptive queries

Adaptive querying creates a reconstruction risk because each new request can be selected after learning from earlier releases.

The default allowed adaptive-query modes are:

| Mode | Behavior |
|---|---|
| Pre-approved query catalog | Analysts may issue only pre-defined, bounded releases with known budget allocation |
| Cached release reuse | Return an existing approved output at zero new privacy cost |
| Coarsen then recompute | Reduce geographic detail, extend the time window, lower dimensionality, or use a less sensitive statistic before considering a new release |
| Human-reviewed exception | Requires documented public purpose, privacy accounting, overlap analysis, and independent approval |
| No adaptive queries | Reject all new interactive outputs from protected data |

The system must log release metadata—not requester identity—including query family, dataset partition, geography, time window, epsilon, delta, mechanism, sensitivity, decision, and reason.

## DAT-02: Small-Cell Protection

### Base safety condition

The proposed small-cell condition is:

\[
\operatorname{CellSafe}(n,k)
=
\begin{cases}
\text{true}, &
n \geq k
\land
\frac{n-\max_i(c_i)}{n}
\geq \delta
\\
\text{false}, &
\text{otherwise}
\end{cases}
\]

Where:

| Symbol | Meaning |
|---|---|
| \(n\) | Population or contribution count in the cell |
| \(k\) | Minimum count threshold |
| \(c_i\) | Count of an attribute category within the cell |
| \(\delta\) | Minimum diversity share outside the dominant category |

The diversity term is:

\[
D
=
\frac{n-\max_i(c_i)}{n}
=
1-\max_i\left(\frac{c_i}{n}\right)
\]

This protects against releasing a cell where nearly every contributing record has the same sensitive characteristic.

However, k-anonymity and diversity checks alone are not sufficient against linkage, differencing, composition, or external-data attacks. They must be combined with differential privacy, geographic and temporal minimums, overlap governance, suppression or coarsening, and motivated-intruder testing.

NIST describes de-identification as preventing or limiting disclosure risk, while recognizing that re-identification can remain a residual risk as new datasets and analytics are combined. [139][146][153]

### Recommended threshold tiers

| Cell-risk context | Minimum \(k\) | Minimum diversity \(\delta\) | Minimum temporal span | Recommended publication treatment |
|---|---:|---:|---:|---|
| Low-sensitivity citywide aggregate | 5 | 0.20 | 7 days | Differentially private aggregate plus overlap logging |
| Neighborhood infrastructure indicator | 10 | 0.30 | 7 to 30 days | Differential privacy, minimum geographic size, and hierarchical release control |
| Sparse geographic or sensitive service indicator | 15 | 0.40 | 30 days or more | Coarsen geography and time; independent privacy review |
| Highly sparse, safety-sensitive, or potentially stigmatizing indicator | 25 or more | 0.50 or more | 90 days or more | Aggregate at district or citywide level; do not publish raw cells |
| Protected habitat or high-risk location data | Contextual | Contextual | Contextual | Use separate ecological sensitivity policy; public release may be inappropriate regardless of \(k\) |

These are conservative implementation defaults, not a claim that any threshold independently guarantees anonymity. A small geographic cell with \(n=15\) can remain vulnerable if it is released repeatedly, overlaps with nearby cells, reveals rare time patterns, or can be linked with public records.

### Sparse geographic areas

For sparse rural, peri-urban, tribal, remote, or otherwise low-density areas, the system must not lower \(k\) merely to increase map coverage. Instead, it applies the following ordered mitigation sequence:

1. Suppress the cell.
2. Merge it into an adjacent cell with compatible geography and public-service meaning.
3. Coarsen the geography to a district, service zone, watershed subunit, or other suitable aggregate.
4. Extend the temporal window.
5. Reduce attribute dimensionality.
6. Release only a differentially private, coarsened aggregate.
7. Publish an explicit data-availability limitation.

The decision objective is:

\[
\text{privacy protection}
>
\text{map completeness}
\]

A sparse cell should be visible in the public report only as an appropriately aggregated uncertainty or availability statement, not as a false-precision estimate.

### Temporal aggregation

Repeated releases enable differencing. If a daily count and a weekly count are both released for nearly the same population, subtraction can disclose the remaining day.

The default temporal controls are:

\[
T_{\text{release}}
\geq
T_{\min}
\]

\[
\left|
n_t-n_{t-1}
\right|
\geq
\Delta_{\min}
\]

where \(T_{\min}\) is the minimum temporal span and \(\Delta_{\min}\) is the minimum permitted change before two closely related non-DP releases can be separately published.

Use one or more of:

- Daily internal operations with weekly or monthly public releases.
- Rolling windows only when they are differentially private and accounted for as overlapping releases.
- Non-overlapping release periods for public tables whenever feasible.
- Delayed publication for high-risk cells.
- Hierarchical or top-down differentially private release mechanisms to preserve consistency while limiting composition risk.

### Overlap and intersection attacks

An intersection attack occurs when several published cells overlap and their shared subsets reveal information that no single cell discloses alone.

For public geographic release \(g\):

\[
\operatorname{OverlapRisk}(g)
=
\sum_{h \in \mathcal{H}}
\mathbb{1}
[
g \cap h \ne \varnothing
]
\cdot
\operatorname{Linkability}(g,h)
\]

The framework provides four control models:

| Model | When to use | Rule |
|---|---|---|
| Disjoint partition only | Simple public dashboards and stable maps | Publish only non-overlapping cells within an accounting window |
| Hierarchical rollup only | Nested city, district, and neighborhood products | Generate parent and child outputs through a coordinated top-down method |
| Overlap budget accounting | Complex release programs with approved overlapping regions | Charge privacy loss and evaluate overlap graph before each release |
| Deny overlapping release | Sparse, sensitive, or high-linkage settings | Block new release that overlaps existing public cell geography or time |

For a nested geography, independently releasing every parent, child, and cross-cut subgroup is unsafe unless the outputs are generated by a coordinated disclosure-avoidance mechanism and privacy accounting covers the shared data.

### Small-cell audit tests

Each candidate release must pass:

- Population threshold test.
- Dominant-attribute diversity test.
- Minimum geographic-area test.
- Minimum temporal-span test.
- Query-history overlap test.
- Complementary-subtraction and differencing test.
- Differential-privacy mechanism validation, where required.
- External-linkage or motivated-intruder test.
- Rights and equity review to ensure suppression does not hide an unequal public burden without an aggregate alternative.

The test result is one of:

| Result | Meaning | Required action |
|---|---|---|
| Safe | Required thresholds and attack controls pass | Release under declared DP and governance conditions |
| Unsafe population | Cell count is below \(k\) | Suppress or merge |
| Unsafe diversity | A dominant sensitive category exceeds allowed concentration | Coarsen, suppress, or remove attribute dimension |
| Unsafe geography | Area is too small | Merge or coarsen geography |
| Unsafe time | Window is too narrow | Extend time window |
| Unsafe overlap | Intersection risk is unmanaged | Deny release, apply hierarchical method, or account for overlap |
| Unsafe differencing | Similar releases can be subtracted | Apply DP, change cadence, coarsen, or deny |
| Invalid | Inputs or accounting metadata are incomplete | Hold publication until corrected |

## Rights-preserving governance

All privacy-budget and small-cell decisions must preserve the following:

- No collection of biometric, neural, augmentation, health, or unrelated identity data merely to operate aggregate privacy controls.
- No identity inference from device, browser, language, communication method, access modality, or service use.
- No reduction in essential public-service access because an aggregate data release has exhausted its privacy budget.
- An accessible explanation of why a release is coarsened, delayed, suppressed, or unavailable.
- A correction or appeal route for data-quality errors, classification errors, or claimed public-interest needs.
- Accessible non-digital public reporting and human explanation where public dashboards are unavailable.

## Metrics

| Metric | Score | Basis |
|---|---:|---|
| `knowledge_factor` | 0.95 | Formal composition accounting, adaptive-query guards, cell thresholds, overlap tests, and reproducible validation logic |
| `eco_impact_value` | 0.82 | Enables privacy-preserving use of urban heat, water, restoration, transit, and infrastructure aggregates |
| `harm_risk` | 0.10 | Budget caps, emergency reserve isolation, differential privacy, small-cell suppression, overlap guards, and motivated-intruder testing reduce reconstruction risk |
| `accessibility_impact` | 0.90 | Provides plain-language availability explanations and preserves non-digital and essential-service access when publication controls restrict fine-grained outputs |
| `rights_alignment` | 0.98 | Strong data minimization, no identity inference, correction paths, bounded disclosure, transparent governance, and fail-closed publication controls |
