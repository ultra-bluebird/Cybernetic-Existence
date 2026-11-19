# Privacy-Preserving Federated Learning for Public-Infrastructure Maintenance

## Purpose

This architecture trains failure-risk models for public infrastructure—such as elevators, automatic doors, HVAC systems, pumps, and accessibility equipment—without centrally collecting raw device telemetry.

Each participating node retains raw observations locally. The coordinator receives only protected, clipped, masked model updates and aggregate quality metrics after secure aggregation.

The system is decision support. It may recommend inspection or maintenance prioritization, but it must not autonomously disable essential access infrastructure, reduce accessibility service, or defer safety-critical maintenance without qualified human review.

## Data Boundary

Local data may include:

- Equipment health counters.
- Vibration, temperature, pressure, current, duty-cycle, or fault-code summaries.
- Maintenance events and repair outcomes.
- Environmental operating ranges.
- Local device model and firmware compatibility.
- Aggregate energy and runtime measures.

The system must not collect or train on:

- Video, images, raw audio, speech, faces, gait, identity, location trails, occupant counts tied to individuals, biometrics, neural data, health data, cybernetic-host status, or accessibility-service usage tied to an identifiable person.
- Door opening behavior, elevator destination patterns, or HVAC presence data that can be used to infer a person’s routine.
- Any maintenance data that is unnecessary for the stated failure-prediction purpose.

Federated learning supports data minimization because local data are processed at the source while the coordinator receives focused updates and intended aggregate metrics rather than the source data itself. [106] Secure aggregation further restricts the coordinator to learning an aggregate, such as a sum or average, rather than each participant’s individual model update. [100]

## Architecture

```text
Local sensor nodes
    |
    +--> Local feature extraction
    |
    +--> Local training and update clipping
    |
    +--> Distributed differential privacy noise
    |
    +--> Threshold secure aggregation masks
    |
    +--> Authenticated protected update
    |
Regional aggregation relays
    |
    +--> Secure sum verification
    |
    +--> Dropout recovery only above threshold
    |
Coordinator
    |
    +--> Aggregate protected model update
    |
    +--> Differential privacy accounting
    |
    +--> Validation against holdout safety data
    |
    +--> Signed model release
    |
Maintenance planners
    |
    +--> Human review
    |
    +--> Accessible maintenance schedule
    |
    +--> Local deployment with rollback capability
```

## Local Model

For node \(k\), let:

- \(D_k\) be its local maintenance dataset.
- \(w_t\) be the current globally signed model parameters.
- \(n_k\) be the number of valid local training windows.
- \(\Delta_k\) be the locally trained model update.
- \(C\) be the clipping norm.
- \(\sigma\) be the distributed differential-privacy noise multiplier.

First clip the update:

\[
\overline{\Delta}_k
=
\Delta_k
\cdot
\min
\left(
1,
\frac{C}{\lVert\Delta_k\rVert_2 + \epsilon}
\right)
\]

Then add local or distributed noise:

\[
\widetilde{\Delta}_k
=
\overline{\Delta}_k
+
\mathcal{N}(0,\sigma^2C^2I)
\]

The node sends only a masked protected update:

\[
m_k
=
\widetilde{\Delta}_k
+
\sum_{l > k} r_{k,l}
-
\sum_{l < k} r_{l,k}
\]

Where \(r_{k,l}\) are pairwise masks derived from authenticated ephemeral keys. When participating nodes are aggregated, the pairwise masks cancel:

\[
\sum_{k=1}^{K}m_k
=
\sum_{k=1}^{K}\widetilde{\Delta}_k
\]

The coordinator learns the aggregate protected update but not the individual update values.

## Secure Aggregation Threshold

A training round proceeds only when:

\[
K_{\mathrm{participating}}
\ge
K_{\mathrm{minimum}}
\]

Recommended minimums are set by local privacy risk and network size. A small cohort must not be aggregated because a nearly isolated update can reveal operational characteristics of one building or device.

If too few nodes participate:

- Abort the round.
- Do not publish an aggregate.
- Do not reveal which specific nodes were unavailable.
- Record an aggregate, privacy-preserving reason category.
- Retry in a later window or expand the cohort.

## Global Aggregation

For valid participating nodes:

\[
w_{t+1}
=
w_t
+
\eta
\left(
\frac{
\sum_{k=1}^{K}n_k\widetilde{\Delta}_k
}{
\sum_{k=1}^{K}n_k
}
\right)
\]

Where \(\eta\) is the global server learning rate.

Before release, the coordinator must:

- Check aggregate update magnitude.
- Check model performance by device class and environmental operating band.
- Check false-negative rate for safety-relevant failures.
- Check that accessibility-critical equipment is not systematically assigned worse prediction performance.
- Conduct a privacy-budget check.
- Require an authorized human release decision.

## Differential Privacy Ledger

Each node and training cohort receives a privacy budget:

\[
\varepsilon_{\mathrm{used}}
=
\sum_{t \in T}
\varepsilon_t
\]

\[
\varepsilon_{\mathrm{used}}
\le
\varepsilon_{\mathrm{maximum}}
\]

The system maintains an append-only privacy ledger containing:

- Cohort pseudonym.
- Model version.
- Training-round time window.
- Clipping norm.
- Noise multiplier.
- Sampling rate.
- Privacy-accounting method.
- Cumulative privacy budget band.
- Secure-aggregation threshold.
- Aggregate validation status.
- Human release decision.

The ledger must not reveal an individual building, device, or node’s participation.

Combining distributed differential privacy with secure aggregation provides complementary protections: privacy noise limits what can be inferred statistically, while secure aggregation restricts access to individual updates. [104][105]

## Coordinator Governance

The coordinator must:

- Verify signed model manifests and node software attestations.
- Reject unapproved model architectures and feature schemas.
- Enforce minimum-cohort thresholds.
- Enforce privacy-budget limits.
- Reject updates outside allowed numeric bounds.
- Maintain model-version provenance and reproducible validation records.
- Issue signed model-release packages.
- Support immediate rollback to the prior approved model.
- Separate maintenance-planning access from raw device administration access.
- Provide accessible human review for maintenance recommendations that affect public access.

## Non-Monetary Reward Mechanism

Participating nodes may receive a non-transferable maintenance-contribution credit.

The credit recognizes verified contribution to collective reliability. It is not a currency, property interest, tradable asset, proof of service eligibility, or mechanism for reducing baseline maintenance obligations.

For node \(k\):

\[
R_k
=
\operatorname{eligible}_k
\cdot
\left[
0.45Q_k
+
0.35V_k
+
0.20E_k
\right]
\]

Where:

- \(Q_k\) is local update-quality score, based on validation consistency and protocol compliance.
- \(V_k\) is maintenance value score, based on contribution to improvement in aggregate predictive performance for the node’s equipment class.
- \(E_k\) is energy-aware participation score, rewarding training during approved low-carbon or surplus-energy windows where this does not delay safety maintenance.
- \(\operatorname{eligible}_k\) equals one only if secure-aggregation, privacy, consent, software-integrity, and fairness rules pass.

The system must not use reward credits to ration emergency maintenance, cooling access, accessibility support, or public-service eligibility.

## Rights and Safety Gates

The following conditions must be true before a model release:

\[
\operatorname{ReleaseAllowed}
=
\operatorname{SecureAggregationPassed}
\land
\operatorname{PrivacyBudgetAvailable}
\land
\operatorname{ValidationPassed}
\land
\operatorname{AccessibilityParityPassed}
\land
\operatorname{HumanApprovalRecorded}
\]

A failed condition creates a research-only outcome, not an operational maintenance recommendation.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.94 | Uses established federated-learning, secure-aggregation, clipping, differential-privacy, and validation mechanisms |
| eco_impact_value | 0.82 | Enables preventative maintenance, longer equipment life, reduced emergency replacement, and energy-aware compute scheduling |
| harm_risk | 0.17 | Reduced through local processing, minimum cohorts, secure aggregation, privacy accounting, model validation, and human release gates |
| accessibility_impact | 0.96 | Protects maintenance quality for elevators, doors, HVAC, and other accessibility-critical systems through parity checks |
| rights_alignment | 0.98 | Blocks personal telemetry collection, identity inference, adverse automated action, and opaque model deployment |
