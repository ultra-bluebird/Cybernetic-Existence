# DAT-03 to DAT-05 Methodology

## Purpose

This standard defines three related safeguards.

- DAT-03 protects sensitive information during collaborative model training by keeping raw data local, shielding individual updates, bounding privacy loss, and requiring privacy-attack testing.
- DAT-04 creates deterministic synthetic data for tests, simulations, and fairness fixtures without embedding recognizable real people, direct identifiers, or protected identity profiles.
- DAT-05 sets an evidence threshold for causal attribution of ecological outcomes when randomization is unavailable.

The core architectural rule is:

\[
\text{local observation}
\not\Rightarrow
\text{centralized personal-data collection}
\]

The core causal rule is:

\[
\text{observed ecological change}
\not\Rightarrow
\text{caused ecological benefit}
\]

## DAT-03: Federated Learning Boundary

### Explicit data boundary

| System boundary | Permitted processing | Prohibited processing |
|---|---|---|
| Local node | Raw data storage under local control, local feature extraction, local clipping, local noise addition, local gradient or model-update computation | Uploading raw records, stable device identity, biometric, neural, augmentation, health, or precise personal-location data |
| Secure aggregation layer | Threshold-protected cryptographic masking or secret-sharing of a bounded local update | Reconstructing, retaining, or exposing an individual update |
| Central aggregator | Receiving one cohort aggregate, applying pre-approved aggregation, publishing model metadata and aggregate privacy accounting | Receiving raw data, individual model updates, source linkage, device tracking, or identity attribution |
| Model release layer | Privacy, inversion, membership, robustness, fairness, and material-effect testing; accessible explanations; human review | Automatic essential-service denial, opaque adverse decision, or release of a model failing privacy evaluation |
| Audit layer | Aggregate, purpose-limited privacy accounting and release evidence | Durable identity, modality, device, augmentation, or personal-behavior profiles |

Federated learning reduces centralized raw-data handling, but it is not automatically privacy-preserving. NIST notes that sensitive training data can sometimes be recovered from model updates and that trained models may also reveal information about training data. [157][160]

### Local-node controls

For local dataset \(D_i\), a node computes a bounded update:

\[
u_i
=
\operatorname{clip}
\left(
\nabla \mathcal{L}(D_i),
S
\right)
\]

Where \(S\) is the public clipping norm.

The node then adds local differential-privacy noise:

\[
\tilde{u}_i
=
u_i
+
\mathcal{N}(0,\sigma^2 S^2 I)
\]

The secure aggregation protocol exposes only:

\[
\bar{u}
=
\frac{1}{|C|}
\sum_{i \in C}
\tilde{u}_i
\]

Where \(C\) is the successful cohort for the training round.

The central service must not observe \(u_i\), \(\tilde{u}_i\), raw data, or a durable mapping between \(i\) and a person, device, location, assistive technology, cybernetic status, health state, or augmentation configuration.

Secure aggregation can protect individual model updates by revealing an aggregate to the central aggregator instead of the individual updates. [162]

### Minimum cohort policy

There is no universal safe cohort size. The required cohort depends on model dimension, clipping norm, noise multiplier, participation frequency, dropout behavior, threat model, collusion assumptions, and whether the aggregation protocol can isolate a contribution.

This standard defines two operational thresholds:

| Cohort threshold | Use |
|---|---|
| At least 20 successful contributors | Minimum research threshold for a secure-aggregation round; below this, do not aggregate |
| At least 50 successful contributors | Preferred minimum for public-interest or urban-intelligence deployment |
| At least 100 successful contributors | Recommended target for recurring, sensitive, high-dimensional, or potentially linkable updates |

The threshold applies to **successful contributors after dropout**, not merely invited nodes:

\[
|C_{\text{successful}}|
\geq
k_{\text{cohort}}
\]

The coordinator must not reveal a partial aggregate when the threshold is not met. It must discard the round’s aggregation material according to the protocol, retain raw data locally, and record only an aggregate reason for non-completion.

Repeated cohorts must have overlap controls. If nearly the same people contribute in every round, differencing across aggregates can erode privacy even where individual updates are hidden.

\[
\operatorname{overlap}(C_t,C_{t+1})
\leq
\theta_{\text{overlap}}
\]

The schema uses \(\theta_{\text{overlap}} \leq 0.50\) as a conservative default. Programs can set a stricter threshold after privacy review.

### Privacy attacks and defenses

| Threat | Description | Required control |
|---|---|---|
| Gradient or update inversion | Attempt to reconstruct local examples from an update | Secure aggregation, local clipping, local DP noise, minimum batches, round threshold, red-team attack evaluation |
| Membership inference | Attempt to learn whether a record participated in training | Differential privacy, output restrictions, membership-inference evaluation, limited release cadence |
| Model inversion | Attempt to infer sensitive training attributes from a trained model | Differential privacy, minimization, model inversion testing, output filtering, human release review |
| Property inference | Attempt to infer group-level sensitive characteristics from updates or model behavior | No protected-status targets, cohort thresholds, DP accounting, fairness and privacy review |
| Poisoning or backdoor | Malicious local contribution shifts the aggregate model | Robust aggregation review, contribution clipping, anomaly-resistant training, independent evaluation |
| Linkage and longitudinal profiling | Cohort membership or stable identifiers reveal who participated repeatedly | Ephemeral participation credentials, no retained source mapping, cohort-overlap limits, minimum aggregation frequency |

Model-inversion attacks matter because a trained model can itself leak information about its training data; secure aggregation protects input privacy for updates, while differential privacy is needed to strengthen output privacy of the final model. [160][162]

### Privacy accountant

Privacy loss is cumulative across rounds.

Under basic composition:

\[
\epsilon_{\text{total}}
=
\sum_{t=1}^{T}\epsilon_t
\]

\[
\delta_{\text{total}}
=
\sum_{t=1}^{T}\delta_t
\]

A production implementation should prefer Rényi Differential Privacy or a privacy-loss-distribution accountant when its assumptions and configuration are independently reviewed:

\[
\epsilon_{\text{estimated}}
\approx
\epsilon_{\text{round}}
\sqrt{T}
\]

The square-root expression is a simplified planning approximation used by the provided TypeScript evaluator. It is not a substitute for a validated accountant in production.

If the cumulative budget is exhausted:

\[
\epsilon_{\text{used}}
\geq
\epsilon_{\max}
\Rightarrow
\text{stop new training participation}
\]

The system may continue to offer the last approved model, but may not silently continue collecting updates, weaken noise, lower cohort thresholds, or remove a person’s access to essential services.

## DAT-04: Synthetic Testing

### Definition

Synthetic test data is created from explicit scenario rules, simulation assumptions, and bounded probabilistic processes. It is not a copy, lightly perturbed replica, or identifier-stripped version of real personal data.

\[
D_{\text{synthetic}}
=
G(\text{seed}, \text{scenario catalog}, \text{parameter bounds})
\]

The generator must be deterministic given the same seed, scenario catalog, and implementation version:

\[
G(s,\Theta,v)
=
G(s,\Theta,v)
\]

This makes test failures reproducible and makes review possible without retaining real personal data.

### Permitted generation methods

| Method | Best use | Key protection |
|---|---|---|
| Rule-based scenario generation | Policy fixtures, accessibility tests, outage workflows, correction and appeal paths | No dependence on real records; excellent edge-case control |
| Agent-based simulation | Infrastructure demand, evacuation, water resilience, ecological interaction, queueing, and network scenarios | Uses synthetic agents and declared behavior rules rather than people |
| Probabilistic graphical model | Interdependent environmental and infrastructure variables | Explicit assumptions and bounded distributions |
| Differentially private generator | High-level distributional emulation when governed source data is available | Requires privacy accounting, privacy attacks, and disclosure review |
| Hybrid rule plus probabilistic generator | Complex public-service and ecological tests | Deterministic edge cases plus varied non-identifying conditions |

NIST’s PETs Testbed evaluates privacy-enhancing technologies using utility, fidelity, empirical privacy metrics, and red-teaming approaches; those same four evaluation dimensions are suitable for synthetic-data governance. [155][158]

### Required scenario catalog

A rights-preserving synthetic catalog includes conditions that reveal exclusionary or fragile behavior without assigning protected identities to records.

| Scenario family | Example test variables |
|---|---|
| Essential-service continuity | Network outage, power loss, vendor failure, staffed fallback capacity, paper-intake delay |
| Accessibility equivalence | Keyboard navigation, switch scanning, text-only route, screen-reader semantic coverage, relay route, tactile cue fallback |
| Privacy and consent | Refused optional telemetry, no account, no personal device, local-only processing, deletion request |
| Ecological operations | Heat event, drought, monsoon, sensor calibration drift, habitat protection window, water-quality anomaly |
| Fairness and non-discrimination | Equivalent outcomes under differing interface paths, timing constraints, communication methods, repair status, connectivity availability |
| Adverse and rare conditions | Queue overload, partial infrastructure failure, missing data, contradictory evidence, extreme uncertainty, concurrent emergencies |
| Correction and appeal | Anonymous or pseudonymous reference, no digital account, mail delay, relay communication, portal outage, escalation requirement |

The scenario catalog must test conditions, pathways, and outcomes—not speculate about or infer personal identity, disability, cybernetic status, health, or augmentation.

### Validation without real data ground truth

Synthetic test data does not require real personal records as ground truth. It is validated against:

- Formal invariants and policy constraints.
- Engineering limits and physical conservation laws.
- Published non-personal aggregate statistics, where appropriate.
- Scenario coverage requirements.
- Boundary-value tests.
- Metamorphic tests, such as “more missing data cannot increase confidence.”
- Property-based tests, such as “telemetry refusal cannot reduce essential-service access.”
- Differential-privacy and memorization red-team tests where the generator was trained from governed source data.
- Independent review of assumptions and intended use.

Example metamorphic invariant:

\[
\text{missingness}_{2}
>
\text{missingness}_{1}
\Rightarrow
\text{uncertainty}_{2}
\geq
\text{uncertainty}_{1}
\]

Example fairness invariant:

\[
\text{same service request}
\land
\text{different access pathway}
\Rightarrow
\text{same core outcome}
\]

## DAT-05: Causal Attribution

### Evidence tiers

| Tier | Causal claim status | Minimum condition |
|---|---|---|
| Tier A | Verified causal attribution | Pre-registered design, explicit counterfactual, supported method assumptions, spatial and spillover controls, conservative positive lower bound, independent review |
| Tier B | Provisional attribution | Accepted method and positive estimate, but incomplete review, incomplete assumption evidence, or bounded limitations |
| Tier C | Hold for evidence | Credible causal method proposed, but required counterfactual, pre-registration, spatial, spillover, or assumption evidence is missing |
| Tier D | No causal claim | Unsupported method, failed causal assumption, or lower confidence bound at or below zero |

For an outcome \(Y\), intervention \(D\), location \(s\), and time \(t\):

\[
Y_{s,t}
=
\alpha
+
\tau D_{s,t}
+
X_{s,t}\beta
+
\phi_s
+
\eta_t
+
u_{s,t}
\]

Where:

| Symbol | Meaning |
|---|---|
| \(\tau\) | Estimated intervention effect |
| \(X_{s,t}\) | Pre-specified environmental, land-use, meteorological, infrastructure, and policy covariates |
| \(\phi_s\) | Spatial fixed effect or location control |
| \(\eta_t\) | Time fixed effect or seasonal control |
| \(u_{s,t}\) | Residual uncertainty, potentially spatially correlated |

The lower bound remains:

\[
C_{\text{avoided,lower}}
=
\max
\left(
0,
\hat{\tau}
-
z_{\alpha}\sigma_{\hat{\tau}}
\right)
\]

With \(z_{\alpha} \geq 1.645\) for a one-sided 90 percent conservative lower bound.

### Method selection

| Method | Strongest use case | Core assumption | Required verification |
|---|---|---|---|
| Difference-in-differences | Phased interventions with treatment and comparison areas | Parallel pre-trends absent intervention | Event study, pre-trend plots, placebo timing and location checks, spatially robust uncertainty |
| Event study | Intervention impact evolves over time | No anticipatory or differential pre-trends | Leads and lags, pre-period coefficient tests, cluster or spatial inference |
| Synthetic control | One treated site with comparable donor areas | Weighted donor combination recreates pre-period trajectory | Donor-pool review, pre-intervention fit, leave-one-out placebos |
| Augmented synthetic control | One or few treated sites with covariates and time structure | Model adjustment improves comparison without overfitting | Cross-validation, donor sensitivity, pre-period fit, placebo tests |
| Regression discontinuity | Intervention assignment changes at a threshold | Units near threshold are comparable absent treatment | Density test, covariate continuity, bandwidth sensitivity, manipulation assessment |
| Instrumental variables | Exposure varies through a credible external instrument | Relevance and exclusion restriction | First-stage strength, exclusion rationale, balance and falsification tests |
| Matched observational study | Comparison sites can be aligned on observed covariates | No unmeasured confounding after matching | Balance diagnostics, sensitivity analysis, negative controls |
| Interrupted time series | A single system changes at a known date with long records | No concurrent unmodeled shock explains the change | Pre-period trend, seasonality, autocorrelation, co-intervention review |
| Mechanistic model with external validation | Strong physical model plus field calibration | Model represents dominant causal pathways | External validation, uncertainty propagation, structural sensitivity analysis |

EPA’s causal-assessment material identifies confounding, natural variability, and analysis of significant differences as central causal-analysis concerns. [159][161]

### Spatial confounding and interference

Urban ecological interventions are especially exposed to spatial confounding and interference.

- Wealth, zoning, road density, canopy, building materials, industrial activity, water access, maintenance quality, and policy targeting may affect both intervention placement and outcomes.
- Cooling, air quality, runoff, habitat, and water effects can cross neighborhood and administrative boundaries.
- Nearby “control” areas may receive spillover benefits or burdens and therefore may not be true untreated comparisons.

A minimum spatial-control plan includes:

\[
\text{spatial covariate adjustment}
+
\text{matched spatial controls}
+
\text{buffer or exposure mapping}
+
\text{spatially robust uncertainty}
\]

Spatial causal-inference literature identifies spatial confounding and interference as distinct challenges that need explicit design and analysis controls. [156][163]

A practical specification is:

\[
Y_{s,t}
=
\alpha
+
\tau D_{s,t}
+
\psi \cdot \text{ExposureToNearbyTreatment}_{s,t}
+
X_{s,t}\beta
+
\phi_s
+
\eta_t
+
u_{s,t}
\]

This separates direct intervention effect \(\tau\) from a declared spillover effect \(\psi\), subject to sensitivity analysis.

### Assumptions that data can test

| Assumption | Testable evidence |
|---|---|
| Parallel trends | Pre-intervention trend plot, event-study coefficients, placebo intervention dates |
| Matching quality | Standardized mean differences, covariate balance tables, overlap diagnostics |
| Synthetic-control fit | Pre-intervention prediction error, donor weights, leave-one-out and in-space placebo tests |
| Regression-discontinuity integrity | Running-variable density test, covariate continuity, bandwidth and polynomial sensitivity |
| Instrument relevance | First-stage estimate, strength statistic, exposure association |
| Spillover sensitivity | Buffer-distance analysis, exposure mapping, alternate control zones |
| Outcome robustness | Negative-control outcome, alternate valid measurement, blinded quality review |
| Measurement integrity | Calibration traceability, missingness analysis, sensor placement review, spatial autocorrelation assessment |

Some causal assumptions cannot be fully proven from observed data—particularly absence of unmeasured confounding and instrumental-variable exclusion. They must be made explicit, challenged through sensitivity and falsification checks, and disclosed in plain language rather than represented as certain.

## Validation and integration

- Validate all program configurations against the JSON Schema before execution.
- Run federated-learning privacy checks before every training campaign, cohort-policy change, model release, or privacy-accountant change.
- Reject training designs that transmit raw data, reveal individual updates, retain source linkage, require prohibited sensitive data, or permit automated essential-service denial.
- Generate synthetic fixtures deterministically and preserve only generator configuration, seed, scenario catalog, and validation result.
- Run causal protocol checks before publishing avoided-impact, ecological-benefit, carbon, heat-recovery, water-resilience, habitat, or public-health-attribution claims.
- Treat failed causal assumptions and non-positive conservative lower bounds as “no causal claim,” not as a small positive credit.
- Publish accessible plain-language summaries of privacy boundaries, synthetic scenario coverage, causal assumptions, uncertainty, limitations, and human-review pathways.

## Metrics

| Metric | Score | Basis |
|---|---:|---|
| `knowledge_factor` | 0.95 | Formal privacy boundaries, synthetic test invariants, causal assumption registry, uncertainty controls, and deterministic validation |
| `eco_impact_value` | 0.90 | Supports privacy-preserving ecological modeling, safer adaptive infrastructure research, restoration measurement, and validated public-interest analytics |
| `harm_risk` | 0.11 | Raw-data prohibition, secure aggregation, clipping, local noise, cohort controls, attack tests, synthetic-only test data, and conservative attribution gates reduce risk |
| `accessibility_impact` | 0.91 | Participation is optional, essential services retain human review, and synthetic scenarios explicitly test non-digital and assistive-access conditions |
| `rights_alignment` | 0.98 | The artifacts preserve data minimization, consent boundaries, non-discrimination, no identity inference, explainability, correction, appeal, and human oversight |
