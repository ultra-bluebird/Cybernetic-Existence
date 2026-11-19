# Ethical Urban Data Access and Equitable Climate Planning

## Purpose

This specification defines two connected public-interest systems:

1. An ethical urban data-access service for aggregated ecological and planning data.
2. A climate-resilience planning tool that prioritizes public investments through transparent social-need, environmental-risk, ecological-benefit, and feasibility criteria.

The systems are designed for research, planning, and public accountability. They shall not be used for individual surveillance, re-identification, discriminatory eligibility, social scoring, financial ranking, property-value optimization, predictive policing, insurance pricing, credit decisions, or automated denial of public services.

## Shared Rights Commitments

Both systems SHALL:

- Use data minimization, purpose limitation, access controls, retention limits, and auditability.
- Exclude neural, biometric, augmentation, cybernetic-host, disability, health, identity, communications, device, and location-history data from general marketplace access.
- Prohibit re-identification attempts, linkage attacks, reverse engineering of protected records, and onward disclosure.
- Prohibit financial, social, behavioral, identity, property-value, or wealth ranking of individuals.
- Preserve public access to essential-service planning information without registration or payment.
- Provide human review, accessible explanations, correction routes, and an appeal process.
- Publish methodology, uncertainty, aggregation level, provenance, data limitations, and known bias risks.
- Treat AI outputs as decision support rather than binding allocation decisions.
- Include affected communities in governance, parameter selection, release review, and post-deployment evaluation.

## Part One: Ethical Urban Data Access

### Marketplace Model

The data-access service should be called a public-interest data commons or controlled research exchange rather than a marketplace when the primary goal is public benefit. The service may recover legitimate operational costs and return surplus to public services, but it must not convert residents, communities, identities, health conditions, behavior, or environmental exposure into tradeable assets.

The service may provide:

- Differentially private aggregate counts and statistics.
- Coarsened ecological indicators by planning zone.
- Publicly releasable satellite, weather, land-cover, infrastructure, and environmental-monitoring data.
- Research access to governed aggregate datasets.
- Secure-analysis access for approved high-sensitivity data where no raw export is permitted.
- Synthetic datasets validated for planning and method-development use.
- Public methods documentation, data dictionaries, provenance records, uncertainty bounds, and privacy-budget reports.

The service SHALL NOT provide:

- Direct identifiers, persistent identifiers, contact information, biometrics, audio, video, raw mobility traces, browsing history, device identifiers, or account data.
- Individual-level environmental, medical, disability, augmentation, cybernetic-host, or identity information.
- Fine-grained records capable of revealing a person's home, worksite, routine, service use, or participation history.
- Any dataset whose reasonable use case includes discrimination, targeting, eligibility screening, social scoring, financial ranking, or surveillance.
- Data access based on a researcher's wealth, payment capacity, institutional prestige, social status, or activity score.

### Tiered Access Controls

| Access tier | Permitted data | Core control | Export rule |
|---|---|---|---|
| Public | Open environmental indicators, methods, metadata, coarse aggregates | No account required | Public download and accessible web access |
| Registered public-interest research | Differentially private aggregates and documented planning extracts | Purpose declaration, accepted use terms, privacy ledger | Approved aggregate export only |
| Controlled analysis | Sensitive aggregate or restricted microdata where a lawful and ethical basis exists | Project review, bounded workspace, query controls, human approval | No raw export; reviewed aggregate output only |
| Internal stewardship | Source records needed for statutory, operational, or maintenance duties | Role separation, least privilege, audit and retention control | No export without an explicit authorized workflow |

A secure enclave is appropriate only for the controlled-analysis tier. It must provide:

- No general internet access.
- No clipboard, removable-media, print, or direct file-export capability by default.
- Approved software images and reproducible analysis environments.
- Output checking for privacy, aggregation, disclosure, and policy compliance.
- Time-limited project workspaces.
- Immutable project-level audit evidence.
- Separate roles for data steward, privacy reviewer, technical operator, and approving authority.
- An accessible appeal process for denied research requests.

A secure enclave protects sensitive source data from routine export, but it does not make an otherwise harmful research purpose acceptable.

### Differential Privacy

Differential privacy protects a person's contribution by ensuring that a released aggregate changes only within a defined bound if that contribution is added or removed.

For neighboring datasets \(D\) and \(D'\), a randomized mechanism \(M\) satisfies \(\epsilon\)-differential privacy if:

\[
\Pr[M(D) \in O]
\leq
e^\epsilon
\Pr[M(D') \in O]
\]

for every permitted output set \(O\).

The privacy-loss parameter \(\epsilon\) expresses the privacy-utility tradeoff: lower values generally provide a stronger indistinguishability guarantee while adding more uncertainty to released results. [148][150]

For each approved project or logically separated access context \(u\), the requested operating limit is:

\[
\epsilon_{u,q} \leq 0.1
\]

for each query \(q\).

Composition must be tracked. The cumulative privacy loss is:

\[
\epsilon_{u,\mathrm{total}} =
\sum_{q=1}^{n}
\epsilon_{u,q}
\]

A query is approved only when:

\[
\epsilon_{u,\mathrm{total}} +
\epsilon_{u,q}
\leq
\epsilon_{u,\mathrm{cap}}
\]

The cap must be defined per dataset, release window, population sensitivity, and query family. A flat per-user budget alone is insufficient because it can create a persistent researcher-level profile. The preferred design assigns a privacy budget to the approved project, data domain, release period, and purpose—not to an identity-based reputation record.

When the remaining privacy budget is insufficient, the system SHALL offer:

- A coarser geographic zone.
- A longer time aggregation interval.
- A lower-dimensional result.
- A more strongly noised statistic.
- A synthetic-data alternative.
- A public aggregate already available without registration.

It SHALL NOT silently provide a finer-grained response, infer a person's identity, reduce access to the person's own data, or create a researcher score.

### Query Safety Requirements

Every query request must include:

- Declared public-interest purpose.
- Dataset and variable scope.
- Geographic and time aggregation level.
- Requested statistic.
- Privacy cost estimate.
- Expected benefit and potential harms.
- Need for export versus secure-view-only analysis.
- Retention and deletion plan.
- Statement that re-identification, discriminatory targeting, and onward sharing are prohibited.

The system must reject requests that:

- Seek a small group, rare event, unique location, or sensitive subgroup without a defensible aggregation threshold.
- Attempt differencing, repeated slicing, linkage, reconstruction, or membership inference.
- Use protected or sensitive characteristics to allocate burdens or benefits at the individual level.
- Seek a person-level risk, trust, financial, identity, behavior, or eligibility score.
- Request a dataset whose stated purpose conflicts with public-interest constraints.

### Auditing Without Researcher Surveillance

Audit the **data-access event and policy decision**, not the personal life, identity, or behavior of a researcher.

Use a rotating project pseudonym and retain only the minimum fields needed for reproducibility and accountability:

```json
{
  "event_type": "controlled_aggregate_query",
  "project_pseudonym": "rotating_project_alias",
  "purpose_category": "climate_resilience_planning",
  "dataset_class": "aggregated_environmental_data",
  "geographic_resolution": "planning_zone",
  "time_resolution": "monthly",
  "privacy_epsilon": 0.1,
  "cumulative_project_epsilon": 0.3,
  "output_mode": "reviewed_aggregate_export",
  "reidentification_prohibited": true,
  "financial_or_social_ranking_prohibited": true,
  "review_state": "approved",
  "retention_deadline": "2026-12-31T00:00:00Z"
}
```

The audit log SHALL NOT contain:

- Personal name, home address, personal device identifier, browsing history, private location, biometric data, or unrelated account information.
- Participation frequency scores, trust scores, institutional prestige labels, or reputation rankings.
- Raw queries when the query text itself could expose sensitive research or people; use structured purpose categories and protected review records instead.
- Any field related to a person's cybernetic-host status, augmentation, disability, health, or identity.

### Public-Benefit Revenue Allocation

If a governed data service charges cost-recovery fees or licenses a non-sensitive aggregate product, define:

- \(R_{\mathrm{gross}}\): gross eligible revenue.
- \(C_{\mathrm{direct}}\): verified direct operating costs required to provide the approved data service.
- \(P_{\mathrm{net}}\): net surplus.

\[
P_{\mathrm{net}} =
\max(0, R_{\mathrm{gross}} - C_{\mathrm{direct}})
\]

The public-service allocation is:

\[
A_{\mathrm{public}} =
0.8
\times
P_{\mathrm{net}}
\]

The requested policy target is:

\[
A_{\mathrm{public}} = 80\%
\text{ of net eligible surplus}
\]

This allocation must not be justified by monetizing personal data. It applies only to ethically releasable, lawfully governed, aggregated public-interest data products or transparent cost-recovery arrangements.

The city should publish:

- Gross revenue.
- Direct operating costs.
- Net surplus.
- Public-service allocation.
- Recipient public programs.
- Privacy incidents and remediation.
- Dataset classes and release counts.
- Independent governance-review findings.

## Part Two: Climate Resilience Planning With Equity Metrics

### Planning Purpose

The climate-resilience tool evaluates candidate investments such as:

- Cooling centers and heat-safe community hubs.
- Shade corridors, tree canopy, water access, and heat-refuge infrastructure.
- Green roofs, cool roofs, reflective surfaces, and passive-cooling retrofits.
- Flood barriers, drainage upgrades, wetland restoration, retention basins, and permeable surfaces.
- Public-transit cooling and accessible emergency information.
- Habitat connectivity, native vegetation, biodiversity restoration, and water-conservation measures.

The tool is a transparent decision-support process. It does not determine an individual's worth, legal priority, entitlement, identity, or community legitimacy.

### Defensible Use of Vulnerability Indices

The CDC/ATSDR Social Vulnerability Index is a place-based planning tool built from American Community Survey variables. CDC describes it as supporting emergency preparation, response, and efforts to reduce health inequities; it currently uses 16 ACS variables grouped into four themes. [147]

The SVI is suitable as one input for identifying **where additional outreach, accessible planning, heat relief, evacuation support, and resilience investment may be needed**. It is not a valid proxy for an individual person's vulnerability, capacity, need, identity, or eligibility.

Use it with these safeguards:

- Treat SVI as a screening and outreach indicator, not an automated allocation rule.
- Inspect the component themes and locally relevant indicators rather than relying only on an overall percentile.
- Use the most current documented data version and publish its vintage.
- Pair quantitative data with community-governed local knowledge, lived experience, and accessible public input.
- Avoid using race, disability, language, income, housing condition, or other demographic data to deny benefits, impose surveillance, or assign individual risk labels.
- Evaluate geographic uncertainty, small-area instability, data suppression, boundary changes, and the risk of ecological gentrification or displacement.
- Publish a non-displacement and anti-exclusion assessment for each major investment proposal.
- Maintain universal access to baseline heat, flood, and emergency services rather than conditioning them on an index score.

FEMA resilience programs support planning to reduce community risk through infrastructure modernization and mitigation, while resilient planning resources emphasize considering hazards, equity, and built, natural, and social systems together. [146][154]

### Human-Needs Floor

No ecological or financial benefit may compensate for failure to meet a community-defined human-needs floor.

Let:

- \(N_k\) be the normalized social-need score for candidate \(k\).
- \(E_k\) be the ecological co-benefit score.
- \(F_k\) be a non-wealth-based feasibility or lifecycle-value score.
- \(w_N, w_E, w_F\) be weights.
- \(N_{\min}\) be the minimum human-needs threshold for automatic advancement.

\[
S_k =
w_N N_k +
w_E E_k +
w_F F_k
\]

subject to:

\[
w_N > 0.5
\]

\[
w_N + w_E + w_F = 1
\]

\[
N_k \geq N_{\min}
\]

\[
w_N \geq 0.60
\]

A recommended initial weight configuration is:

\[
w_N = 0.60,\quad
w_E = 0.25,\quad
w_F = 0.15
\]

This ensures social need remains the dominant criterion while still recognizing ecological value and practical delivery constraints.

The feasibility score must not use property wealth, tax yield, rent level, investor return, premium insurance value, payment capacity, or commercial prestige as a positive priority factor.

### Social-Need Components

A social-need measure can combine transparent, place-level indicators:

\[
N_k =
a_1 H_k +
a_2 A_k +
a_3 X_k +
a_4 B_k
\]

where:

- \(H_k\): hazard exposure and intensity.
- \(A_k\): access gap to cooling, evacuation, water, shade, transit, or emergency communication.
- \(X_k\): place-level social vulnerability indicator with uncertainty.
- \(B_k\): community-identified burden or service barrier.

The coefficients satisfy:

\[
a_i \geq 0
\]

\[
\sum_i a_i = 1
\]

Each component must be published with source, geographic scale, date, uncertainty, and known limitations.

### Ecological Co-Benefit Components

Ecological co-benefits should be measured separately before aggregation:

\[
E_k =
b_1 C_k +
b_2 G_k +
b_3 W_k +
b_4 Q_k
\]

where:

- \(C_k\): carbon sequestration or avoided operational emissions, with a documented method.
- \(G_k\): biodiversity and habitat-connectivity benefit.
- \(W_k\): water conservation, infiltration, flood attenuation, or water-quality benefit.
- \(Q_k\): local thermal-comfort, shade, air-quality, or urban-canopy benefit.

The coefficients satisfy:

\[
b_i \geq 0
\]

\[
\sum_i b_i = 1
\]

Ecological benefits require an evidence basis and uncertainty estimate. A projected carbon benefit must not offset a project that displaces residents, restricts public access, increases surveillance, or imposes unequal harm.

### Non-Compensation Constraint

For every candidate \(k\), define:

- \(D_k\): displacement or exclusion risk.
- \(R_k\): rights or accessibility risk.
- \(U_k\): uncertainty severity.
- \(D_{\max}, R_{\max}, U_{\max}\): policy thresholds.

The candidate may advance only when:

\[
D_k \leq D_{\max}
\]

\[
R_k \leq R_{\max}
\]

\[
U_k \leq U_{\max}
\]

A high ecological score cannot compensate for a failed rights, displacement, or access constraint.

### Uncertainty-Aware Score

Let \(u_k \in [0,1]\) represent the documented uncertainty penalty for candidate \(k\).

\[
S_{k,\mathrm{adjusted}} =
S_k
\times
(1-u_k)
\]

The tool shall show both \(S_k\) and \(S_{k,\mathrm{adjusted}}\), along with the source of uncertainty. It must not conceal uncertainty behind a precise-looking rank.

### Community Governance

Community co-design is required at these points:

1. Define the candidate project set.
2. Select and review social-need components.
3. Select ecological co-benefit components and evidence standards.
4. Establish rights, accessibility, displacement, and uncertainty constraints.
5. Approve or revise weight ranges through an accessible public process.
6. Review preliminary results in plain language and accessible formats.
7. Submit corrections, local evidence, or challenge data assumptions.
8. Participate in final deliberation through web, paper, phone, hub, and assisted channels.
9. Review post-implementation performance and any unintended harms.
10. Trigger adaptive changes where outcomes differ materially from stated commitments.

The process must not require smartphone use, private internet, identity disclosure beyond what is legally necessary, professional credentials, or participation frequency.

## Data Retention and Review

### Retention

- Public aggregate datasets: retain under published archival policy.
- Restricted-source data: retain only for the approved public purpose and lawful records schedule.
- Secure-workspace data: delete at project closure unless retention is independently required and documented.
- Privacy-budget ledger: retain only aggregate project-level accounting needed to prevent composition attacks and audit compliance.
- Planning submissions: retain the minimum necessary for public process, correction, and appeal.
- Personal information: segregate, access-restrict, and delete according to explicit retention rules.

### Review

Every data product and planning recommendation requires:

- Data stewardship review.
- Privacy review.
- Rights and accessibility review.
- Ecological evidence review.
- Community-governance review.
- Human approval before external release or investment decision.
- Post-release or post-implementation monitoring.
- Accessible grievance, correction, and appeal pathways.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.91 | Differential-privacy accounting, controlled analysis, CDC place-based vulnerability planning, transparent multicriteria methods, and non-compensation governance |
| eco_impact_value | 0.88 | Directs planning toward cooling, flood reduction, biodiversity, water resilience, and accountable ecological co-benefits |
| harm_risk | 0.36 | Re-identification, data misuse, biased geographic indicators, and displacement risks remain material; tiered access, privacy budgets, hard constraints, and community review reduce exposure |
| accessibility_impact | 0.95 | Requires public access, accessible explanations, paper/phone/hub participation, correction and appeal without device dependence |
| rights_alignment | 0.98 | Enforces data minimization, anti-discrimination, no social or financial scoring, purpose limitation, human review, non-displacement safeguards, and civic participation |
