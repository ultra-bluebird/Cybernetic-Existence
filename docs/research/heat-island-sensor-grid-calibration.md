# Heat-Island Mitigation Sensor Grid Calibration

## Purpose

This research object defines a privacy-preserving, sub-block-resolution sensor-grid and calibration protocol for urban heat-island mapping.

The system estimates air temperature, relative humidity, and derived heat indicators across a target area using:

- fixed temperature and relative-humidity nodes
- a small set of reference-grade anchor nodes
- optional mobile transects
- local quality control
- drift-aware calibration
- uncertainty-aware spatial interpolation
- privacy-minimized aggregation

The system supports public environmental intelligence, heat-risk mapping, tree-canopy and shade evaluation, cooling-infrastructure planning, and accessible public communication.

It does not identify, track, profile, rank, or infer information about individuals.

It does not use personal sensor data, identity, device ownership, connectivity, wealth, participation, augmentation status, or telemetry consent as a condition of access to cooling centers, emergency information, water, transit, accommodation, or any essential public service.

## Research Questions

1. How can sensor placement minimize node count while maintaining defensible spatial coverage and temporal responsiveness?
2. Which calibration and drift-correction models preserve accuracy without requiring frequent manual intervention?
3. How can uncertainty be measured and communicated instead of hidden?
4. How can fixed-node data and optional mobile transects complement each other without degrading provenance?
5. How can heat-risk information improve cooling access and public planning while preserving privacy and essential-service independence?

## System Scope

The primary measurement layer is near-surface canopy-layer air monitoring.

Each fixed node may measure:

- air temperature in degrees Celsius
- relative humidity in percent
- sensor status
- battery status or external-power status
- local enclosure temperature where available
- quality-control flags
- calibration-model version
- calibration uncertainty
- timestamp

Each node must avoid collecting:

- audio
- video
- device identifiers
- network identifiers
- personal location histories
- biometric data
- identity data
- augmentation data
- individual mobility data
- household occupancy data
- person-level cooling-center usage data

A node location may be represented as a public planning cell, coarse coordinate, or managed asset location according to the deployment profile. Exact locations should be withheld from public releases when disclosure would create safety, vandalism, privacy, or operational risks.

## Spatial Resolution

Sub-block resolution is an analytical target, not a claim that every sub-block has a dedicated sensor.

Let the target planning area be partitioned into spatial cells:

\[
\mathcal{G} = \{g_1, g_2, \ldots, g_m\}
\]

Each cell has:

- area \(A_i\)
- land-surface and built-form covariates
- canopy or shade covariates
- impervious-surface covariates
- distance-to-water or cooling-infrastructure covariates where relevant
- an estimated thermal field
- an uncertainty estimate

The sensor network is:

\[
\mathcal{N} = \{n_1, n_2, \ldots, n_k\}
\]

where \(k\) is selected to meet defined coverage, uncertainty, resilience, and maintenance constraints.

## Coverage Metrics

### Binary coverage

For a sensor sensing radius \(r_j\), define the area covered by at least one sensor as:

\[
A_{\mathrm{covered}} =
\operatorname{Area}
\left(
\bigcup_{j=1}^{k}
B(n_j, r_j)
\right)
\]

The binary coverage ratio is:

\[
C_{\mathrm{binary}} =
\frac{A_{\mathrm{covered}}}{A_{\mathrm{target}}}
\]

where:

\[
0 \le C_{\mathrm{binary}} \le 1
\]

Binary coverage is useful for first-pass deployment planning but does not represent actual interpolation accuracy.

### Distance-weighted coverage

For spatial cell \(g_i\), let \(d_i\) be the distance to the closest valid sensor.

Define a distance-decay function:

\[
w(d_i) = \exp\left(-\frac{d_i}{\lambda}\right)
\]

where \(\lambda\) is a locally selected spatial decorrelation scale.

The distance-weighted coverage score is:

\[
C_{\mathrm{weighted}} =
\frac{
\sum_{i=1}^{m} A_i w(d_i)
}{
\sum_{i=1}^{m} A_i
}
\]

This metric gives more credit to coverage where sensors are closer to planning cells.

### Uncertainty-weighted coverage

Let \(\sigma_i^2\) be the predicted variance for cell \(g_i\).

For a maximum accepted uncertainty \(\sigma_{\max}^2\), define:

\[
C_{\mathrm{uncertainty}} =
\frac{
\sum_{i=1}^{m}
A_i
\mathbb{I}
\left[
\sigma_i^2 \le \sigma_{\max}^2
\right]
}{
\sum_{i=1}^{m} A_i
}
\]

This is the preferred operational metric because it measures whether the network can estimate local conditions with a stated degree of confidence.

### Resilient coverage

Let \(C^{(-j)}_{\mathrm{uncertainty}}\) be the uncertainty-weighted coverage after removing node \(n_j\).

Define single-node failure resilience as:

\[
R_{\mathrm{single}} =
\min_{j \in \{1,\ldots,k\}}
C^{(-j)}_{\mathrm{uncertainty}}
\]

A deployment should set a minimum acceptable resilience target so that one failed node does not erase meaningful coverage of a high-priority heat area.

## Placement Objective

The network-placement objective is multi-criteria.

\[
\max_{\mathcal{N}}
\left[
w_c C_{\mathrm{uncertainty}}
+
w_r R_{\mathrm{single}}
+
w_h H_{\mathrm{priority}}
-
w_m M_{\mathrm{cost}}
-
w_e E_{\mathrm{energy}}
\right]
\]

Where:

- \(C_{\mathrm{uncertainty}}\) is uncertainty-weighted spatial coverage
- \(R_{\mathrm{single}}\) is resilience against one node failure
- \(H_{\mathrm{priority}}\) is coverage of high-heat and high-public-benefit planning cells
- \(M_{\mathrm{cost}}\) is installation and maintenance burden
- \(E_{\mathrm{energy}}\) is energy use and replacement-material burden
- \(w_c\), \(w_r\), \(w_h\), \(w_m\), and \(w_e\) are transparent policy weights

The placement objective must not use protected characteristics, personal identities, individual health records, income records, consumer behavior, or personal mobility data as deployment eligibility inputs.

Environmental-justice and public-health planning may use carefully governed, aggregate, non-identifying area-level indicators when a local profile explicitly documents the source, uncertainty, purpose, access controls, and review process.

## Candidate Placement Layers

A useful candidate set combines physical representativeness and public-benefit relevance.

Candidate nodes should cover:

- high impervious-surface areas
- low-canopy areas
- dense built-form areas
- shaded and unshaded street corridors
- transit-access corridors
- public cooling-resource vicinity
- parks and tree-canopy reference zones
- water-influenced microclimates where applicable
- urban-rural or urban-park reference edges
- known heat-retaining materials and surfaces
- elevation and drainage variation where relevant
- locations safe for maintenance and accessible installation

The grid should include both hot-zone and cool-reference locations.

A network containing only expected hot zones cannot reliably estimate the local thermal gradient or validate mitigation effects.

## Reference Anchors

Reference anchors are higher-confidence nodes used to assess drift and detect network-wide bias.

A deployment should use at least:

- one cool or vegetated reference context
- one representative urban residential or mixed-use context
- one dense built or heat-retaining context
- one rotating calibration anchor available for field co-location checks

Reference anchors should be physically sited with attention to:

- shade and radiation shielding
- airflow
- height consistency
- avoidance of direct artificial heat sources
- avoidance of exhaust outlets
- avoidance of reflective surfaces that distort air-temperature readings
- accessible and safe maintenance access
- power resilience where needed

## Calibration Model

### Linear correction

For a raw sensor temperature \(T_{\mathrm{raw}}\):

\[
T_{\mathrm{corrected}} =
\alpha T_{\mathrm{raw}} + \beta
\]

Where:

- \(\alpha\) corrects gain error
- \(\beta\) corrects offset error

For humidity:

\[
RH_{\mathrm{corrected}} =
\gamma RH_{\mathrm{raw}} + \delta
\]

Calibration parameters must be stored with:

- model version
- effective start time
- effective end time
- fit uncertainty
- reference source class
- calibration quality flag

### Recursive least squares drift update

Let:

\[
\theta_t =
\begin{bmatrix}
\alpha_t \\
\beta_t
\end{bmatrix}
\]

and:

\[
\phi_t =
\begin{bmatrix}
T_{\mathrm{raw},t} \\
1
\end{bmatrix}
\]

For reference temperature \(y_t\), the predicted temperature is:

\[
\hat{y}_t = \phi_t^\top \theta_{t-1}
\]

The residual is:

\[
e_t = y_t - \hat{y}_t
\]

With covariance matrix \(P_t\) and forgetting factor \(\lambda\), where:

\[
0 < \lambda \le 1
\]

the gain is:

\[
K_t =
\frac{
P_{t-1}\phi_t
}{
\lambda + \phi_t^\top P_{t-1}\phi_t
}
\]

The parameter update is:

\[
\theta_t =
\theta_{t-1} + K_t e_t
\]

The covariance update is:

\[
P_t =
\frac{1}{\lambda}
\left(
P_{t-1} -
K_t\phi_t^\top P_{t-1}
\right)
\]

A lower \(\lambda\) responds more quickly to drift but can overreact to short-term environmental mismatch. A value closer to \(1\) is more stable but slower to adapt.

The deployment profile must document the selected forgetting-factor range and the conditions under which recalibration is required.

### State-space drift model

For temporal drift, use:

\[
x_{t+1} =
F x_t + w_t
\]

\[
z_t =
H x_t + v_t
\]

Where:

- \(x_t\) is the latent state containing temperature, offset, gain, and optional humidity bias
- \(z_t\) is the sensor observation
- \(F\) is the transition model
- \(H\) is the observation model
- \(w_t\) is process noise
- \(v_t\) is observation noise

A practical temperature state is:

\[
x_t =
\begin{bmatrix}
T_{\mathrm{ambient},t} \\
b_t
\end{bmatrix}
\]

where \(b_t\) is a slowly varying sensor bias.

The sensor observation becomes:

\[
z_t =
\begin{bmatrix}
1 & 1
\end{bmatrix}
x_t + v_t
\]

The Kalman filter estimates both ambient temperature and sensor bias while providing posterior uncertainty.

### Gaussian-process residual correction

For spatial residual field \(\epsilon(s,t)\), use:

\[
T(s,t) =
\mu(s,t) + \epsilon(s,t)
\]

where:

\[
\epsilon(s,t) \sim
\mathcal{GP}(0, k((s,t),(s',t')))
\]

A separable covariance kernel is:

\[
k((s,t),(s',t')) =
\sigma^2
k_{\mathrm{space}}(s,s')
k_{\mathrm{time}}(t,t')
+
\sigma_n^2
\mathbb{I}
\left[
(s,t) = (s',t')
\right]
\]

A common spatial kernel is:

\[
k_{\mathrm{space}}(s,s') =
\exp
\left(
-\frac{\|s-s'\|^2}{2\ell_s^2}
\right)
\]

A common temporal kernel is:

\[
k_{\mathrm{time}}(t,t') =
\exp
\left(
-\frac{|t-t'|}{\ell_t}
\right)
\]

Where:

- \(\sigma^2\) is signal variance
- \(\sigma_n^2\) is measurement-noise variance
- \(\ell_s\) is spatial correlation length
- \(\ell_t\) is temporal correlation length

A Gaussian process is appropriate for periodic offline analysis, interpolation, and uncertainty estimation.

A Kalman filter or recursive least squares approach is more appropriate for resource-bounded on-device or gateway-level near-real-time correction.

## Hybrid Calibration Strategy

The recommended architecture uses three calibration tiers.

### Tier One: Factory and acceptance validation

Before deployment:

- verify temperature and humidity response against a traceable reference
- record calibration coefficients and uncertainty
- reject non-finite readings and readings outside supported sensor ranges
- assign a calibration model version
- store the acceptance record locally and in the approved project record

### Tier Two: Network co-location validation

At planned intervals or after a quality-control trigger:

- temporarily co-locate a field node with a reference anchor
- compare readings through a stable observation period
- update drift estimates only when environmental comparability checks pass
- retain both raw and corrected values with quality flags
- record whether an update is automatic, proposed, or approved

### Tier Three: Continuous statistical monitoring

During routine operation:

- estimate deviation from nearby reference anchors
- estimate residuals against local spatiotemporal predictions
- flag persistent deviations
- prevent automatic correction from exceeding a bounded maximum change
- mark suspicious readings as uncertain rather than silently replacing them

## Quality Control

Each observation must be evaluated using transparent checks.

### Range validation

For expected physical operating ranges:

\[
T_{\min} \le T_{\mathrm{raw}} \le T_{\max}
\]

\[
0 \le RH_{\mathrm{raw}} \le 100
\]

Readings outside configured physical ranges are retained only as flagged raw observations and excluded from ordinary map interpolation.

### Rate-of-change validation

For interval \(\Delta t\):

\[
\left|
\frac{
T_t - T_{t-\Delta t}
}{
\Delta t
}
\right|
\le r_{\max}
\]

The maximum rate must be configured conservatively and contextually. A rate-of-change flag indicates a possible anomaly, exposure change, enclosure issue, or rapid meteorological event. It does not automatically prove a sensor failure.

### Neighbor consistency

For node \(i\), let \(\mathcal{N}(i)\) be nearby comparison nodes.

\[
z_i =
\frac{
T_i - \operatorname{median}
\left(
\{T_j : j \in \mathcal{N}(i)\}
\right)
}{
1.4826 \cdot \operatorname{MAD}
\left(
\{T_j : j \in \mathcal{N}(i)\}
\right) + \varepsilon
}
\]

Where:

- \(\operatorname{MAD}\) is median absolute deviation
- \(\varepsilon\) prevents division by zero

A large absolute \(z_i\) should create an uncertainty or calibration-review flag, not a silent deletion of the observation.

### Sensor health score

Let:

- \(q_r\) be range-check quality
- \(q_c\) be calibration confidence
- \(q_n\) be neighbor-consistency quality
- \(q_p\) be power and communication quality
- \(q_e\) be enclosure and exposure quality

Each term is normalized to \([0,1]\).

\[
Q_{\mathrm{sensor}} =
w_r q_r +
w_c q_c +
w_n q_n +
w_p q_p +
w_e q_e
\]

The weights must be versioned and documented.

The score is an equipment-quality indicator. It must not be reused to infer neighborhood worth, resident behavior, service eligibility, or civic priority.

## Temporal Responsiveness

Let \(\Delta t\) be the sampling interval.

The sampling interval should be selected from the fastest phenomenon the system is expected to resolve.

For a target response period \(\tau_{\mathrm{target}}\):

\[
\Delta t \le \frac{\tau_{\mathrm{target}}}{n}
\]

where \(n\) is the desired number of samples per response period.

A practical design may use:

- frequent local sampling
- lower-frequency secure aggregation
- adaptive high-frequency sampling during heat alerts
- local buffering during connectivity loss
- batched transfer after connectivity resumes

The system must retain environmental readings locally during ordinary network interruptions according to its retention policy.

Connectivity loss must not erase observations, sensor-maintenance records, calibration records, or heat-alert evidence.

## Derived Heat Indicators

### Dew point

For temperature \(T\) in degrees Celsius and relative humidity \(RH\) in percent:

\[
\gamma(T,RH) =
\ln
\left(
\frac{RH}{100}
\right)
+
\frac{aT}{b+T}
\]

\[
T_d =
\frac{
b\gamma(T,RH)
}{
a-\gamma(T,RH)
}
\]

where \(a\) and \(b\) are documented constants selected by the implementation.

### Heat-index policy

The system may compute a heat-index or heat-risk indicator only when:

- the formula version is identified
- its valid meteorological range is documented
- it is presented as an estimate
- the system displays uncertainty where applicable
- it does not replace accessible public-safety messaging

### Local anomaly

For corrected node temperature \(T_i(t)\) and predicted background temperature \(\hat{T}_{\mathrm{background}}(s_i,t)\):

\[
\Delta T_i(t) =
T_i(t) -
\hat{T}_{\mathrm{background}}(s_i,t)
\]

This anomaly distinguishes a locally warmer or cooler location from the modelled background at that time.

## Privacy and Rights Constraints

The sensor grid must enforce the following rules:

\[
\Box(
\texttt{environmental\_observation}
\Rightarrow
\neg
\texttt{person\_identity\_required}
)
\]

\[
\Box(
\texttt{cooling\_service\_request}
\Rightarrow
\neg
\texttt{personal\_sensor\_data\_required}
)
\]

\[
\Box(
\texttt{essential\_cooling\_access}
\Rightarrow
\neg
\texttt{wealth\_dependent}
\land
\neg
\texttt{device\_dependent}
\land
\neg
\texttt{telemetry\_dependent}
\land
\neg
\texttt{connectivity\_dependent}
)
\]

\[
\Box(
\texttt{sensor\_maintenance\_or\_offline\_state}
\Rightarrow
\neg
\texttt{public\_service\_restriction}
)
\]

The system may use aggregated heat estimates to publish public risk maps and help route public resources.

It must not require a person to carry a sensor, share a device location, disclose a health condition, verify identity, maintain connectivity, use an augmentation, or accept unrelated telemetry to receive cooling information or access a cooling service.

## Governance and Review

A sensor-grid deployment requires:

- documented deployment purpose
- public explanation of measured environmental variables
- data-minimization assessment
- retention schedule
- calibration and maintenance protocol
- accessible public map and alert format
- uncertainty communication plan
- review process for reported sensor errors
- correction path for incorrectly published asset or location metadata
- human review for proposed changes to calibration thresholds, model versions, or retention periods
- versioned configuration records
- public-interest review for any expansion of data categories

The grid must not be repurposed into surveillance, individual tracking, social scoring, or eligibility scoring.

## Acceptance Criteria

A grid configuration is ready for a bounded pilot simulation when:

- each sensor has a documented measurement range and expected uncertainty
- each sensor has a calibration record and model version
- each planning cell has a predicted coverage and uncertainty estimate
- the placement plan reports ordinary coverage and single-node-failure resilience
- reference anchors represent contrasting thermal contexts
- drift correction is bounded and auditable
- raw, corrected, and flagged observations remain distinguishable
- quality-control failures create flags rather than silent data replacement
- public heat guidance is accessible and uncertainty-aware
- cooling-center and emergency information remain available without personal sensor data
- all configurations can be evaluated offline using synthetic or public environmental inputs

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| `knowledge_factor` | 0.95 | Placement, coverage, calibration, drift, uncertainty, quality-control, privacy, and rights constraints are specified as testable research components |
| `eco_impact_value` | 0.90 | Better heat mapping supports shade, cooling, tree-canopy, water, and infrastructure interventions while minimizing unnecessary sensor deployment and replacement |
| `harm_risk` | 0.12 | Residual risk arises from placement bias, sensor drift, public-map misinterpretation, and maintenance gaps; explicit uncertainty, quality flags, and non-surveillance constraints reduce these risks |
| `accessibility_impact` | 0.99 | The system requires accessible public information and preserves cooling access independently of devices, telemetry, identity, wealth, or connectivity |
| `rights_alignment` | 0.99 | The design centers data minimization, non-surveillance, essential-service independence, accessible information, transparent uncertainty, correction, review, and accountable governance |
