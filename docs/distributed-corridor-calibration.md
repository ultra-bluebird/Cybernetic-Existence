# Distributed Corridor Calibration Using Consensus Kalman Filtering

## Purpose

This specification calibrates temperature and humidity sensors deployed along a long linear corridor, such as a subway tunnel, pedestrian passage, canal edge, station platform, utility corridor, or climate-resilience route.

The objective is not to force every sensor to report the same number. Temperature and humidity can legitimately vary along a corridor because of airflow, station entrances, equipment heat, occupancy, sunlight exposure, groundwater, ventilation, and local materials.

The objective is to estimate and reduce sensor-specific bias and drift while preserving spatially credible environmental gradients.

## Local State Model

For node \(i\) at time \(k\), define:

\[
x_{i,k}
=
\begin{bmatrix}
T_{i,k}^{\mathrm{true}} \\
H_{i,k}^{\mathrm{true}} \\
b_{i,k}^{T} \\
b_{i,k}^{H}
\end{bmatrix}
\]

Where:

- \(T_{i,k}^{\mathrm{true}}\) is the local true temperature estimate.
- \(H_{i,k}^{\mathrm{true}}\) is the local true relative-humidity estimate.
- \(b_{i,k}^{T}\) is local temperature-sensor bias.
- \(b_{i,k}^{H}\) is local humidity-sensor bias.

The node receives a raw measurement:

\[
z_{i,k}
=
\begin{bmatrix}
T_{i,k}^{\mathrm{raw}} \\
H_{i,k}^{\mathrm{raw}}
\end{bmatrix}
=
\begin{bmatrix}
T_{i,k}^{\mathrm{true}} + b_{i,k}^{T} \\
H_{i,k}^{\mathrm{true}} + b_{i,k}^{H}
\end{bmatrix}
+
v_{i,k}
\]

Where \(v_{i,k}\) is measurement noise with covariance \(R_{i,k}\).

Use a slowly varying random-walk model:

\[
x_{i,k+1}
=
F_i x_{i,k}
+
w_{i,k}
\]

\[
F_i
=
\begin{bmatrix}
1 & 0 & 0 & 0 \\
0 & 1 & 0 & 0 \\
0 & 0 & 1 & 0 \\
0 & 0 & 0 & 1
\end{bmatrix}
\]

Where \(w_{i,k}\) is process noise with covariance \(Q_i\).

The bias components receive low but nonzero process noise, enabling gradual drift adaptation without treating short-term local environmental changes as calibration drift.

## Local Kalman Predict and Update

Each node first predicts:

\[
\hat{x}_{i,k|k-1}
=
F_i\hat{x}_{i,k-1|k-1}
\]

\[
P_{i,k|k-1}
=
F_iP_{i,k-1|k-1}F_i^{T}+Q_i
\]

Use measurement matrix:

\[
H
=
\begin{bmatrix}
1 & 0 & 1 & 0 \\
0 & 1 & 0 & 1
\end{bmatrix}
\]

Compute innovation:

\[
y_{i,k}
=
z_{i,k}
-
H\hat{x}_{i,k|k-1}
\]

\[
S_{i,k}
=
HP_{i,k|k-1}H^T+R_{i,k}
\]

\[
K_{i,k}
=
P_{i,k|k-1}H^TS_{i,k}^{-1}
\]

Then update:

\[
\tilde{x}_{i,k}
=
\hat{x}_{i,k|k-1}
+
K_{i,k}y_{i,k}
\]

\[
\tilde{P}_{i,k}
=
(I-K_{i,k}H)P_{i,k|k-1}
\]

## Spatial-Gradient Preservation

A simple consensus average would incorrectly erase valid local differences. Therefore, nodes exchange only calibration-relevant residual state after accounting for an expected spatial gradient.

Let \(\mu_{ij,k}\) be the expected local difference from node \(j\) to node \(i\), estimated from corridor geometry, historical baselines, airflow model, ventilation state, or a locally approved empirical gradient.

\[
r_{ij,k}
=
\tilde{x}_{j,k}
-
\tilde{x}_{i,k}
-
\mu_{ij,k}
\]

The consensus operation focuses on bias dimensions:

\[
\tilde{b}_{i,k}
=
\begin{bmatrix}
\tilde{b}_{i,k}^{T} \\
\tilde{b}_{i,k}^{H}
\end{bmatrix}
\]

\[
\bar{b}_{i,k}
=
\tilde{b}_{i,k}
+
\alpha_i
\sum_{j \in \mathcal{N}_i}
w_{ij,k}
\left(
\tilde{b}_{j,k}
-
\tilde{b}_{i,k}
\right)
\]

Where:

- \(\mathcal{N}_i\) is the current set of authenticated neighbors.
- \(w_{ij,k}\) is a nonnegative neighbor weight.
- \(\sum_{j \in \mathcal{N}_i}w_{ij,k}\le1\).
- \(\alpha_i\) is a bounded consensus gain.

The true local temperature and humidity estimates are not indiscriminately averaged. Only bias estimates and calibration confidence are shared for consensus.

## Reliability-Weighted Consensus

Set each neighbor weight using reported covariance and link quality:

\[
w_{ij,k}
=
\frac{
\ell_{ij,k}
\cdot
\left[
\operatorname{tr}(P_{j,k}^{b})+\epsilon
\right]^{-1}
}{
\sum_{m \in \mathcal{N}_i}
\ell_{im,k}
\cdot
\left[
\operatorname{tr}(P_{m,k}^{b})+\epsilon
\right]^{-1}
}
\]

Where:

- \(P_{j,k}^{b}\) is the bias-state covariance for node \(j\).
- \(\ell_{ij,k}\) is authenticated link-quality and message-freshness confidence.
- Lower uncertainty and higher link confidence increase a node’s calibration influence.

The final calibrated measurement is:

\[
\hat{z}_{i,k}^{\mathrm{calibrated}}
=
\begin{bmatrix}
T_{i,k}^{\mathrm{raw}}-\bar{b}_{i,k}^{T} \\
H_{i,k}^{\mathrm{raw}}-\bar{b}_{i,k}^{H}
\end{bmatrix}
\]

## Communication Protocol

Each node broadcasts a signed, minimized calibration packet:

```text
protocol_version
corridor_epoch
node_pseudonym
time_bucket
bias_temperature_estimate
bias_humidity_estimate
bias_covariance_summary
measurement_noise_summary
calibration_confidence
gradient_model_version
message_sequence
previous_commitment
signature
```

The packet excludes:

```text
raw_audio
raw_video
personal_identity
device_owner_identity
precise_passenger_presence
biometric_data
neural_data
health_data
unnecessary_location_history
```

Nodes accept a peer packet only if:

- The signature verifies.
- The corridor epoch matches.
- The packet is fresh.
- The sequence number is monotonic.
- The peer is in the approved neighbor graph.
- The covariance is positive semidefinite within numeric tolerance.
- The reported bias lies within an approved calibration corridor.
- The packet does not violate local privacy or data-minimization policy.

## No Central Authority Requirement

The protocol does not require a continuously available central calibration server.

It uses:

- Pairwise authenticated neighbor exchange.
- Local Kalman filtering.
- Local consensus iteration.
- Versioned gradient-model configuration.
- Distributed conflict detection.
- Periodic reference checks when a portable or fixed reference instrument is available.

A central service may publish approved calibration policy, reference-model versions, public aggregate quality summaries, and software updates. It cannot silently rewrite local calibration state.

Distributed Kalman-filter and consensus research supports combining local estimation with peer information exchange, and event-triggered variants can reduce communication and energy use. [203][207][214]

## Event-Triggered Communication

To reduce radio use, node \(i\) transmits only when:

\[
\left\|
\tilde{b}_{i,k}
-
b_{i,k}^{\mathrm{last\ sent}}
\right\|_2
>
\theta_i
\]

or when:

- Calibration uncertainty rises above a threshold.
- A local reference check occurs.
- Neighbor disagreement persists.
- Sensor health changes.
- A corridor safety alert requires fast environmental alignment.

The node must still send a bounded periodic heartbeat so neighbors can distinguish a stable estimate from an offline sensor.

## Drift and Fault Handling

| Condition | Required action |
|---|---|
| Innovation exceeds statistical gate | Mark reading provisional and increase local uncertainty |
| Neighbor disagreement exceeds threshold | Preserve local reading, flag calibration review, do not force convergence |
| Sensor has stale heartbeat | Remove from consensus weights and report degraded coverage |
| Reference comparison fails | Quarantine calibration state, retain raw measurement with quality flag, schedule inspection |
| Partitioned network | Continue local filtering, preserve last valid consensus state, do not fabricate peer agreement |
| Rejoined node | Require signed state resynchronization and conservative covariance inflation |
| Gradient model mismatch | Reject peer state until model version aligns |

## Corridor Quality Metrics

\[
K_{\mathrm{corridor}}
=
\exp
\left(
\frac{
\sum_{i \in \mathcal{N}}
w_i\ln c_{i}
}{
\sum_{i \in \mathcal{N}}w_i
}
\right)
\]

Where \(c_i\) is each node’s calibration confidence.

\[
R_{\mathrm{calibration}}
=
\operatorname{clip}
\left(
\max_i
\left[
\frac{
\operatorname{tr}(P_{i}^{b})
}{
P_{\mathrm{reference}}+\epsilon
}
\right],
0,
1
\right)
\]

These aggregate metrics support public reporting and maintenance planning. They must not be used to withdraw environmental monitoring from lower-resource or hard-to-maintain corridor sections.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.94 | Uses local state estimation, covariance tracking, gradient-aware bias consensus, event triggering, authentication, and fault handling |
| eco_impact_value | 0.76 | Improves reliable microclimate evidence for ventilation, heat resilience, and energy-aware public infrastructure |
| harm_risk | 0.16 | Reduced through local autonomy, privacy-minimized packets, preserved gradients, covariance gates, and fail-conservative sensor states |
| accessibility_impact | 0.92 | Supports trustworthy corridor comfort data and avoids under-monitoring hard-to-maintain public routes |
| rights_alignment | 0.97 | Prevents unnecessary people data, central control over local readings, and service reduction based on monitoring difficulty |
