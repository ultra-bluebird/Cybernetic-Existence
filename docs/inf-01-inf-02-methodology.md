# INF-01 and INF-02 Methodology

## Purpose

INF-01 detects probable sensor drift using multiple independent signals. INF-02 selects calibration intervals that balance calibration effort against the expected harm and cost of measurement error.

The framework applies to environmental and infrastructure measurements, including:

- Air quality particulate and gas sensors
- Temperature, humidity, and meteorological sensors
- Water temperature, conductivity, dissolved oxygen, pH, turbidity, level, and flow sensors
- Soil moisture and soil-temperature sensors
- Ecological restoration, stormwater, water-quality, and urban heat-monitoring systems

The key epistemic rule is:

\[
\text{drift signal}
\ne
\text{confirmed calibration error}
\]

Without a traceable reference, collocation, controlled comparison, or other independent verification, a system can identify evidence consistent with drift but cannot reliably prove that the sensor changed rather than the environment.

The policy response is therefore conservative:

\[
\text{uncertain measurement integrity}
\Rightarrow
\text{increased uncertainty}
\Rightarrow
\text{verification or reduced decision authority}
\]

USGS continuous water-quality guidance recognizes calibration drift and fouling as conditions that require correction procedures and record review. [169][172][174]

## INF-01: Drift Detection

### Composite drift score

For a sensor \(s\) over an observation window \(W\):

\[
D_s
=
\operatorname{clamp}
\left(
A_s \cdot G_s \cdot
\left[
w_\mu M_s
+
w_p P_s
+
w_b B_s
+
w_a A_s^{\ast}
+
w_{\sigma} S_s
\right],
0,1
\right)
\]

To avoid symbol overlap, the terms are:

| Symbol | Meaning |
|---|---|
| \(D_s\) | Final bounded drift score |
| \(A_s\) | Sensor age factor |
| \(G_s\) | Environmental-shift guard |
| \(M_s\) | Baseline mean-shift score |
| \(P_s\) | Peer-disagreement score |
| \(B_s\) | Physical-plausibility score |
| \(A_s^{\ast}\) | Temporal autocorrelation or sticking score |
| \(S_s\) | Seasonal-deviation score |
| \(w_\mu,w_p,w_b,w_a,w_{\sigma}\) | Publicly documented weights that sum to one |

The mean-shift component is:

\[
M_s
=
\operatorname{clamp}
\left(
\frac{
\left|
\bar{x}_{W}
-
\mu_{\text{baseline}}
\right|
}{
\max(
\sigma_{\text{baseline}},
\sigma_W,
\varepsilon
)
}
\cdot
\frac{1}{z_{\max}},
0,1
\right)
\]

Where:

| Term | Meaning |
|---|---|
| \(\bar{x}_{W}\) | Mean value in current window |
| \(\mu_{\text{baseline}}\) | Baseline mean for comparable environmental conditions |
| \(\sigma_{\text{baseline}}\) | Baseline standard deviation |
| \(\sigma_W\) | Current-window standard deviation |
| \(\varepsilon\) | Small positive stability constant |
| \(z_{\max}\) | Declared normalization threshold, such as five standard deviations |

The peer-disagreement component is:

\[
P_s
=
\operatorname{clamp}
\left(
\frac{
\left|
\bar{x}_W
-
\overline{x}_{\text{peers}}
\right|
}{
\sigma_{\text{baseline}}
}
\cdot
\frac{1}{z_{\max}},
0,1
\right)
\]

The physical-plausibility component is:

\[
B_s
=
\frac{
\text{samples outside physical or engineering bounds}
}{
\text{samples in } W
}
\]

The temporal autocorrelation component detects stuck or unrealistically persistent values:

\[
A_s^{\ast}
=
\left|
\operatorname{corr}
(
x_t,
x_{t-1}
)
\right|
\]

High autocorrelation is not automatically drift. It becomes stronger evidence when combined with disagreement from peers, an implausible plateau, known sensor aging, fouling, or divergence from expected seasonal behavior.

EPA’s air-sensor quality-assurance guidance recommends frequent review for outliers and drift, as well as automatic checks for valid units, timestamps, expected range, rate of change, stuck values, data completeness, and duplicate-sensor agreement. [171]

### Environmental-shift guard

A real weather, hydrologic, emissions, or ecological event can cause a true shift in all nearby measurements. To avoid labelling that shared event as individual sensor drift, apply a guard:

\[
G_s
=
\begin{cases}
g_{\text{shared}}, &
\left|
\bar{x}_W-\mu_{\text{seasonal}}
\right|
>
z_{\text{event}}\sigma_{\text{seasonal}}
\land
\left|
\bar{x}_W-\overline{x}_{\text{peers}}
\right|
\leq
z_{\text{peer}}\sigma_{\text{seasonal}}
\\
1, & \text{otherwise}
\end{cases}
\]

Where \(0 < g_{\text{shared}} < 1\).

In plain language: if the focal sensor and comparable peers show the same unusual seasonal shift, the system lowers the sensor-specific drift score and records a candidate environmental event instead.

The guard does not erase uncertainty. It changes the conclusion from “suspected individual drift” to “shared deviation requiring environmental and measurement review.”

### Recommended initial windows

Window selection depends on sample frequency, response time, autocorrelation, environmental variability, and the consequences of error. Use a dual-window method:

- A shorter **operational window** detects abrupt changes, sticking, timestamp faults, and rapid drift.
- A longer **baseline-comparison window** estimates stable distributions for comparable seasonal and operational conditions.

| Sensor class | Typical sampling | Initial operational window | Initial baseline-comparison window | Key drift signals |
|---|---|---:|---:|---|
| Air particulate matter | 1 to 60 minutes | 6 to 24 hours | 28 to 90 days, seasonal matching | Collocation disagreement, humidity response shift, stuck values, rate-of-change anomalies |
| Air gas sensor | 1 to 60 minutes | 12 to 48 hours | 28 to 90 days, seasonal matching | Zero drift, cross-sensitivity, temperature and humidity dependence |
| Temperature and humidity | 1 to 15 minutes | 6 to 24 hours | 14 to 60 days, diurnal and seasonal matching | Peer mismatch, plateaus, radiation or enclosure artifacts |
| Water dissolved oxygen | 5 to 60 minutes | 6 to 24 hours | 14 to 60 days, diurnal matching | Fouling, membrane degradation, implausible saturation relation |
| Water pH and conductivity | 5 to 60 minutes | 12 to 48 hours | 14 to 90 days, flow and temperature matching | Electrode drift, fouling, reference degradation, abrupt baseline offset |
| Water turbidity | 1 to 15 minutes | 1 to 12 hours | 14 to 60 days, flow-event matching | Fouling, optical window contamination, persistent offset |
| Water level and flow | 1 to 15 minutes | 6 to 24 hours | 30 to 180 days, hydrologic-regime matching | Stage-discharge inconsistency, zero shifts, pressure drift |
| Soil moisture | 15 to 60 minutes | 1 to 7 days | 30 to 180 days, wet/dry cycle matching | Drying offset, salinity effect, poor soil contact |
| Soil temperature | 15 to 60 minutes | 12 to 48 hours | 30 to 90 days | Peer mismatch, thermal lag, sensor burial-depth shift |

These are initial engineering defaults, not universal calibration intervals. Local deployment must revise them after observing sensor noise, environmental variability, response time, data gaps, fouling, seasonal behavior, and the measurement’s role in operational or public decisions.

### Redundancy requirements

No single sensor can reliably distinguish its own drift from a real local environmental shift without independent information.

Minimum redundancy by decision role:

| Decision role | Minimum evidence topology |
|---|---|
| Informational dashboard | One sensor plus plausibility, timestamp, range, rate-of-change, and seasonal checks |
| Planning or research | One primary sensor plus one comparable peer, periodic collocation, or validated external reference |
| Operational decision support | Two independent sensors or one sensor plus a locally appropriate reference or control measurement |
| Health, ecological, or safety-critical action | Redundant local measurement, traceable verification pathway, quality flags, human review, and conservative failover |

Redundancy must be meaningfully independent. Two measurements that share the same power supply, enclosure failure mode, contaminated intake, maintenance interval, firmware defect, or environmental obstruction are not fully independent.

### Status and action

| Drift status | Meaning | Permitted response |
|---|---|---|
| Stable | Available signals remain within the declared quality corridor | Continue monitoring and scheduled review |
| Watch | Early deviation signal | Increase review frequency and inspect quality evidence |
| Suspected drift | Multi-signal evidence suggests likely sensor error | Verify through traceable reference, collocation, or field inspection |
| High drift | Strong disagreement, physical implausibility, or repeated quality failure | Remove from decision-critical automated use until verification or correction |
| Insufficient evidence | Signals cannot distinguish drift from environment or data quality is incomplete | Preserve quality flags, collect more evidence, and avoid overconfident automated action |

The project’s existing ecosafety direction provides a compatible principle: calibration and uncertainty risk are first-class coordinates, and degraded data quality can reduce confidence or ecological credit but cannot relax a safety gate. [154]

## INF-02: Calibration Optimization

### Objective function

Let \(t\) be the calibration interval in days:

\[
t^*
=
\arg\min_{t \in \mathcal{T}}
\left[
C_{\text{cal}}(t)
+
C_{\text{error}}(t)
\right]
\]

Subject to:

\[
R_{\text{measurement}}(t)
\leq
R_{\max}
\]

The implementation uses:

\[
C_{\text{cal}}(t)
=
\frac{C_{\text{event}}}{t}
\]

\[
b(t)
=
\left(
\hat{r}_{\text{drift}}
+
u_{\text{drift}}
\right)
t
\]

\[
C_{\text{error}}(t)
=
C_{\text{bias}}
\cdot
b(t)
\cdot
m_{\text{criticality}}
\]

\[
R_{\text{measurement}}(t)
=
\operatorname{clamp}
\left(
b(t)
\cdot
m_{\text{criticality}},
0,1
\right)
\]

Where:

| Term | Meaning |
|---|---|
| \(C_{\text{event}}\) | Cost of one calibration event, including staff time, travel, reference materials, access, and operational interruption |
| \(t\) | Candidate calibration interval |
| \(\hat{r}_{\text{drift}}\) | Estimated bias-growth rate per day |
| \(u_{\text{drift}}\) | Drift-rate uncertainty allowance |
| \(b(t)\) | Conservative expected bias at the end of interval \(t\) |
| \(C_{\text{bias}}\) | Cost assigned to one unit of measurement bias per day |
| \(m_{\text{criticality}}\) | Multiplier for health, safety, ecological, operational, or public-decision criticality |
| \(R_{\max}\) | Maximum permitted measurement-risk score |

The scheduler does not choose the cheapest long interval if it violates the measurement-risk corridor.

### Estimating error cost

Error cost should be estimated from the consequence of wrong decisions, not simply instrument replacement price.

\[
C_{\text{error}}
=
C_{\text{decision}}
+
C_{\text{ecological}}
+
C_{\text{service}}
+
C_{\text{regulatory}}
+
C_{\text{rework}}
\]

Examples:

| Sensor type | Example error consequences |
|---|---|
| Air quality particulate sensor | Misstated public advisory, missed pollution episode, incorrect exposure or mitigation planning |
| Water dissolved oxygen sensor | Failure to identify low-oxygen ecological stress, incorrect aeration or flow recommendation |
| Water pH or conductivity sensor | Incorrect source-water or treatment assessment, false alarm, missed contamination signal |
| Turbidity sensor | Misjudged stormwater condition, filtration or monitoring response error |
| Water level or flow sensor | Flood-control, canal, recharge, or supply planning error |
| Soil moisture sensor | Over-irrigation, water waste, plant stress, poor restoration performance |
| Temperature sensor | Incorrect heat-risk, cooling, habitat, energy, or water-quality interpretation |

A high-criticality measurement should receive a larger multiplier even if its sensor is inexpensive.

### Dynamic adaptation

The routine schedule is revised when new evidence changes the risk model.

\[
t_{\text{next}}
=
\min
\left(
t^*,
t_{\text{alert}},
t_{\text{seasonal}}
\right)
\]

Where:

| Term | Meaning |
|---|---|
| \(t^*\) | Least-cost eligible routine interval |
| \(t_{\text{alert}}\) | Accelerated verification interval after a watch or suspected-drift signal |
| \(t_{\text{seasonal}}\) | More frequent interval during known high-stress periods, such as monsoon, extreme heat, flood, high-fouling, or seasonal emission conditions |

A high drift score triggers immediate verification or removal from decision-critical automation. The system must not wait for its routine calendar date.

### Calibration versus drift detection

Drift detection is a screening function. Calibration or controlled comparison is the evidence function.

| Activity | Purpose |
|---|---|
| Drift detector | Finds patterns needing review |
| Field inspection | Identifies fouling, obstruction, damage, power issue, placement change, or maintenance error |
| Collocation | Compares a sensor with a traceable or higher-quality reference under shared conditions |
| Calibration check | Measures and documents offset, slope, response, or other sensor-performance changes |
| Correction procedure | Applies a documented, reviewable correction to historical or operational data |
| Quality flagging | Keeps raw and corrected records distinguishable and communicates uncertainty |

USGS guidance emphasizes field procedures, calibration, data evaluation, correction, computation, review, and publication for continuous water-quality records. [172][174][176]

NIST calibration procedure material illustrates traceable comparison practice, including stabilization, paired observations, replicate measurements, and special handling where excess drift is suspected. [170]

## Privacy and accountability

The drift and calibration artifacts operate on environmental, infrastructure, and sensor-health information. They do not require:

- Individual movement tracking.
- Resident or worker identity registration.
- Biometric, neural, health, or augmentation information.
- Persistent device identifiers.
- Behavioral profiling.
- Service denial when a sensor is uncertain.

A data-quality alert should change the confidence and permitted automated reliance on a measurement. It must not reduce a person’s essential access to water, cooling, transit, public information, corrections, appeals, or human support.

Each public quality statement should identify:

- Sensor class and measured parameter.
- Measurement period and sampling interval.
- Quality status.
- Whether drift is suspected, verified, corrected, or unresolved.
- Practical interpretation.
- Known limitations.
- Human review or correction contact route.
- Accessible, non-digital availability of critical advisories.

## Metrics

| Metric | Score | Basis |
|---|---:|---|
| `knowledge_factor` | 0.94 | Multi-signal detection, environmental-shift guard, redundancy rules, traceable verification, risk-based calibration, and deterministic tests support reproducibility |
| `eco_impact_value` | 0.93 | Reliable sensing improves heat, water, air, habitat, restoration, drought, and pollution decision support while reducing unnecessary field trips and replacement |
| `harm_risk` | 0.12 | The method avoids false certainty, flags uncertainty, requires verification for strong claims, and removes high-risk sensors from critical automated use |
| `accessibility_impact` | 0.85 | Plain-language quality status, human review, and offline public-advisory requirements make data quality understandable across access pathways |
| `rights_alignment` | 0.97 | No identity inference, no surveillance requirement, transparent uncertainty, conservative automation limits, and accessible correction paths preserve autonomy and accountability |
