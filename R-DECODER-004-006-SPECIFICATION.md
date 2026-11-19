Document Ref: RES-DECODER-004-006-2026-REV1
Classification: Institutionally Managed / De-identified Research Specification
Scope: Drift characterization, adaptive-comparison evaluation, and calibration-burden accounting

## 04 — Drift Taxonomy and Distance Selection

### Objective

Define a de-identified summary-level method for detecting and interpreting session-to-session distribution shift in managed interface or biosignal research records.

### System boundary

The research object consumes authorized de-identified feature distributions, model-output summaries, and performance aggregates. It does not require raw neural, clinical, physiological, identity, or augmentation-status data.

### Canonical formula

D_shift(t, 0) = D(F_t, F_0)

where F_0 is an authorized baseline feature summary and F_t is an authorized later-session feature summary.

### Method-selection matrix

| Method | Primary use | Strength | Limitation | Required input |
|---|---|---|---|---|
| Kullback-Leibler divergence | Distributional feature shift against a designated baseline | Sensitive to directional change and useful with sufficiently populated normalized histograms | Asymmetric and requires explicit smoothing for empty bins | Matched probability vectors |
| Wasserstein-1 distance | Continuous feature shift where bin geometry has physical or ordinal meaning | Reflects movement of probability mass across value distance | Requires stable ordered bin edges and scale normalization | Histograms plus bin edges |
| Population Stability Index | Feature-level monitoring and operational reporting | Interpretable binned monitoring index | Depends on binning strategy and does not capture feature covariance | Matched baseline-defined bins |
| Classifier-based drift | Multivariate joint-distribution shift | Can detect interactions among many features | Requires held-out evaluation, class balance, and model documentation | Feature summaries or authorized feature vectors |

### Selection rule

Use a multi-method panel rather than a single universal score:

1. PSI for feature-by-feature operational monitoring.
2. Wasserstein-1 for continuous features with stable measurement units and meaningful value distance.
3. KL divergence for directional distribution comparisons where smoothing and baseline selection are explicit.
4. Classifier-based detection for multivariate shift after the univariate panel identifies an unresolved pattern.

No drift statistic independently demonstrates a biological, clinical, or causal change. The object records only evidence of distributional change requiring technical interpretation.

### PSI formula

PSI = sum_i (p_t,i - p_0,i) ln(p_t,i / p_0,i)

where p_0,i and p_t,i are baseline and current proportions for baseline-defined bin i.

Planning dispositions:

| PSI result | Disposition |
|---|---|
| PSI < 0.10 | Stable |
| 0.10 <= PSI < 0.20 | Attention |
| PSI >= 0.20 | Investigate |

These thresholds are operational conventions for research monitoring, not clinical thresholds.

### Performance correlation

For each authorized session-level aggregate:

rho_drift = corr(D_shift(t, 0), Delta Q_assistive(t))

where:

Delta Q_assistive(t) = Q_assistive(t) - Q_assistive(0)

Interpret rho_drift only as an association between recorded distribution shift and recorded performance change. It does not establish causality.

### Completion artifacts

- Drift-method selection record
- Feature summary schema
- Baseline-definition policy
- Drift-score report template
- Correlation-analysis plan
- Interpretation and uncertainty matrix
- Provenance-manifest entries

## 05 — Fixed vs Calibration-Assisted Comparison Gate

### Objective

Evaluate whether an authorized calibration-assisted policy improves or preserves assistive performance relative to an authorized fixed baseline while remaining within predeclared false-activation and usability tolerances.

### Comparison conditions

Configuration A is a fixed decoder under its authorized baseline configuration.

Configuration B is a calibration-assisted or drift-aware decoder under a documented adaptation policy.

The task class, evaluation period, metric normalization, data-handling class, and report structure are locked before comparison results are reviewed.

### Assistive score

Q_assistive = w_a A + w_r R + w_l(1 - L) + w_f(1 - F) + w_u U

with:

w_a + w_r + w_l + w_f + w_u = 1

and:

w_a, w_r, w_l, w_f, w_u >= 0

where:

- A: normalized task accuracy
- R: normalized session reliability
- L: normalized latency
- F: normalized false-activation rate
- U: normalized usability or user-centered outcome aggregate

### Advancement gate

The evidence status advances when:

Q_assistive(B) - Q_assistive(A) >= 0

and:

F(B) - F(A) <= delta_F

and:

U(B) - U(A) >= -delta_U

where delta_F and delta_U are predeclared, non-negative tolerances.

### Interpretation matrix

| Composite score | False activation | Usability | Result |
|---|---|---|---|
| Improves or preserves | Within tolerance | Within tolerance | Advances evidence |
| Improves or preserves | Exceeds tolerance | Any | Mixed evidence |
| Any | Within tolerance | Below tolerance | Mixed evidence |
| Decreases | Exceeds tolerance | Below tolerance | Does not advance evidence |

### Completion artifacts

- Locked-weight declaration
- Metric normalization policy
- Fixed and adaptive configuration references
- Adaptive-policy record
- Tolerance declaration
- Comparison report
- Metric-level interpretation matrix
- Provenance-manifest entry

## 06 — Calibration Burden Accounting

### Objective

Quantify the operational effort associated with reaching and retaining stable assistive use, expressed entirely through authorized aggregate measures.

### Canonical formula

B_cal = alpha T_cal + beta (N_recal / N_total) + gamma C_confirm

with:

alpha + beta + gamma = 1

and:

alpha, beta, gamma >= 0

where:

- T_cal: normalized time-to-stable-use or calibration-time burden
- N_recal / N_total: fraction of evaluation sessions requiring recalibration
- C_confirm: normalized user-confirmation burden

### Normalization policy

Every burden component is normalized into [0, 1] by a locked research policy:

T_cal = min(observed_calibration_time / declared_reference_time, 1)

C_confirm = min(observed_confirmation_events / declared_reference_event_count, 1)

The declared reference time and reference event count must be recorded in the study manifest before evaluating results.

### Recommended initial weights

alpha = 0.40
beta = 0.35
gamma = 0.25

These values prioritize time-to-stable-use while retaining explicit attention to recurring recalibration and confirmation effort. They are planning values and may be changed only through a dated, provenance-linked rationale before analysis.

### Burden interpretation

| B_cal | Interpretation |
|---|---|
| 0.00 to 0.20 | Low documented calibration burden |
| Greater than 0.20 to 0.50 | Moderate documented calibration burden |
| Greater than 0.50 to 1.00 | High documented calibration burden requiring workflow analysis |

The bands are reporting categories only. They do not identify a clinical condition, determine system eligibility, or direct treatment.

### Wiring

[Authorized Calibration Event Summary]
-> [Duration and Confirmation Aggregation]
-> [Normalized Components]
-> [Calibration Burden Index]
-> [Human Factors Report]
-> [R-HUMANFACTORS-001 and R-PROVENANCE-001 Ledger Entries]

### Completion artifacts

- Calibration-event schema
- Normalization-policy declaration
- Burden-index calculator
- Longitudinal burden report template
- Human-factors linkage model
- Comparison-ready burden interpretation guide
