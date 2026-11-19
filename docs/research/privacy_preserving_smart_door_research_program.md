# Privacy-Preserving Smart Door Research Program

## Purpose

This program develops a human-centered automatic-door intelligence layer that improves uninterrupted, safe passage while minimizing sensing, avoiding identity requirements, preserving independent access, and reducing avoidable conditioned-air exchange.

The system is decision support for door control. It does not identify people, infer protected characteristics, make eligibility decisions, or condition access to essential services on telemetry, connectivity, external identity, or personal devices.

## System Thesis

A smart doorway can improve safety, accessibility, and energy performance when it operates through:

- Local, non-visual sensing.
- Conservative trajectory and intent estimation.
- A bounded timing envelope.
- Accessible equivalent manual activation.
- Sensor-health monitoring and safe degraded operation.
- Privacy-preserving audit records.
- Accessible notices, review, correction, and appeal pathways.
- Site-governed configuration rather than user-specific profiling.

## Research Themes

### Sensor efficacy and privacy

Evaluate mmWave radar, Time-of-Flight sensing, and PIR as a privacy-preserving sensor stack for doorway approach, passage, exit, and pass-by classification.

The primary research outcome is a sensor-selection profile that measures:

\[
\mathrm{FPR} = \frac{FP}{FP + TN}
\]

\[
\mathrm{FNR} = \frac{FN}{FN + TP}
\]

\[
\mathrm{BalancedAccuracy} =
\frac{1}{2}
\left(
\frac{TP}{TP+FN} +
\frac{TN}{TN+FP}
\right)
\]

\[
\mathrm{PrivacyExposure} =
w_r R_{\text{raw}} +
w_t R_{\text{retained}} +
w_l R_{\text{linkability}} +
w_x R_{\text{external-transfer}}
\]

where each privacy-risk term is normalized to \([0,1]\). The target is to minimize privacy exposure while keeping missed-opening risk below a site-approved limit.

A key study compares performance under darkness, glare, rain, fog, smoke, clutter, parallel traffic, luggage, wheelchairs, walkers, strollers, shopping carts, and paired travelers.

### Intent estimation without identity inference

Represent a local trajectory over a short rolling window:

\[
\mathcal{T}_{t} =
\left\{
(x_i,y_i,z_i,v_{x,i},v_{y,i},q_i)
\right\}_{i=t-k}^{t}
\]

where \(q_i\) is a sensor-confidence value. No persistent person identifier is assigned.

Estimate a door-passage likelihood:

\[
p_{\mathrm{pass}} =
P
\left(
Y=\mathrm{passage}
\mid
\mathcal{T}_{t},
c_{\mathrm{door}},
c_{\mathrm{sensor}}
\right)
\]

A conservative opening policy is:

\[
\mathrm{open} =
\begin{cases}
1, & p_{\mathrm{pass}} \ge \theta_{\mathrm{open}} \\
1, & \mathrm{accessible\_activation}=1 \\
1, & \mathrm{degraded\_mode}=1 \land \mathrm{safe\_fallback\_available}=1 \\
0, & \text{otherwise}
\end{cases}
\]

The model should classify doorway-relevant motion states rather than persons:

- Approaching doorway
- Entering threshold zone
- Traversing doorway
- Exiting doorway
- Passing adjacent to doorway
- Stationary near doorway
- Ambiguous motion requiring conservative treatment

A valuable technical comparison is between a deterministic kinematic classifier, a compact temporal convolutional model, and a quantized recurrent model. The first provides explainability and low-power execution; the latter two test whether richer temporal context improves safe-passage performance enough to justify their complexity.

### Adaptive timing envelope

For a site configuration \(s\), define:

\[
T_{\mathrm{hold}}(s,t) =
\mathrm{clip}
\left(
Q_q(\mathcal{D}_{s,t}) +
m_{\mathrm{safety}}(s,t) +
m_{\mathrm{uncertainty}}(s,t),
T_{\min}(s),
T_{\max}(s)
\right)
\]

where:

- \(Q_q(\mathcal{D}_{s,t})\) is a robust passage-time quantile from an aggregated local dataset.
- \(m_{\mathrm{safety}}\) is a site-reviewed safety margin.
- \(m_{\mathrm{uncertainty}}\) grows when sensor confidence, model calibration, or environment quality declines.
- \(T_{\min}\) and \(T_{\max}\) are site-governed hard bounds.

A robust quantile estimator can be based on clipped, windowed observations:

\[
\widetilde{\tau}_i =
\mathrm{clip}(\tau_i,\tau_{\mathrm{low}},\tau_{\mathrm{high}})
\]

\[
Q_q(\mathcal{D}) =
\inf
\left\{
x:
\frac{1}{n}
\sum_{i=1}^{n}
\mathbf{1}
[
\widetilde{\tau}_i \le x
]
\ge q
\right\}
\]

The research question is not simply “which quantile is best?” It is:

> Which site-governed policy provides the highest safe-passage probability subject to bounded energy use, no identity inference, and accessible fallback?

A distributionally robust alternative protects against distribution shift:

\[
T_{\mathrm{hold}} =
\min
\left\{
T_{\max},
\sup_{P \in \mathcal{U}(\widehat{P})}
Q_q(P) +
m_{\mathrm{safety}}
\right\}
\]

where \(\mathcal{U}(\widehat{P})\) is a bounded uncertainty set around the observed local distribution.

### Accessibility and safe-passage science

Define successful passage as a passage attempt where the user can enter or exit without collision, premature closing, avoidable interruption, identity interaction, or inaccessible workaround.

\[
P_{\mathrm{successful\_passage}} =
\frac{
N_{\mathrm{safe\_completed\_passages}}
}{
N_{\mathrm{passage\_attempts}}
}
\]

Define request-to-safe-passage delay:

\[
D_{\mathrm{safe}} =
t_{\mathrm{safe\_doorway\_state}}
-
t_{\mathrm{request\_or\_intent}}
\]

The evaluation target centers on the tail of the delay distribution:

\[
D_{95,\mathrm{safe}} =
Q_{0.95}
\left(
D_{\mathrm{safe}}
\right)
\]

A fair, site-level accessibility criterion is:

\[
D_{95,\mathrm{safe}}^{\mathrm{system}}
\le
D_{95,\mathrm{safe}}^{\mathrm{baseline}}
+
\delta_{\mathrm{access}}
\]

The criterion applies to the entire deployment population and to study cohorts representing varied passage conditions. It must not require the system to infer disability, health status, age, or identity.

### Degraded-mode resilience

The system has explicit operating states:

\[
\mathcal{S} =
\{
\mathrm{normal},
\mathrm{cautious},
\mathrm{degraded},
\mathrm{manual},
\mathrm{maintenance}
\}
\]

A sensor-health function can combine observability, signal quality, self-test status, and disagreement between sensing channels:

\[
H_{\mathrm{sensor}} =
w_o O +
w_q Q +
w_s S +
w_d (1-D)
\]

where \(O,Q,S,D \in [0,1]\), and larger \(D\) denotes larger sensor disagreement.

The state policy is:

\[
\mathrm{mode} =
\begin{cases}
\mathrm{normal}, & H_{\mathrm{sensor}} \ge h_N \\
\mathrm{cautious}, & h_D \le H_{\mathrm{sensor}} < h_N \\
\mathrm{degraded}, & h_M \le H_{\mathrm{sensor}} < h_D \\
\mathrm{manual}, & H_{\mathrm{sensor}} < h_M
\end{cases}
\]

In degraded and manual states, the door continues to provide accessible independent use through a reliable, discoverable, non-network-dependent activation or equivalent safe fallback.

The availability invariant is:

\[
A_{\mathrm{manual/equivalent\_fallback}} =
\frac{
\mathrm{time\ fallback\ is\ functionally\ available}
}{
\mathrm{time\ door\ service\ is\ expected}
}
= 1
\]

### Privacy architecture and retention proofs

The default data lifecycle is:

\[
\mathrm{sensor\ signal}
\rightarrow
\mathrm{volatile\ local\ feature}
\rightarrow
\mathrm{ephemeral\ decision}
\rightarrow
\mathrm{minimized\ aggregate}
\rightarrow
\mathrm{automatic\ deletion}
\]

The system does not retain raw video. It avoids storage of raw radar frames wherever real-time features suffice. It does not create persistent trajectory identities, face templates, gait templates, device identifiers, or cross-session linkage keys.

A privacy-preserving aggregate record may contain:

\[
a =
(
t_{\mathrm{bucket}},
s_{\mathrm{site}},
\mathrm{mode},
\mathrm{reason\_code},
\mathrm{outcome},
\mathrm{confidence\_band},
\mathrm{duration\_band},
\mathrm{integrity\_tag}
)
\]

The record excludes direct identifiers, biometric templates, raw sensor data, precise continuous trajectories, and personal-device identifiers.

Retention is purpose-limited:

\[
\mathrm{retain}(a) =
\begin{cases}
1, & t_{\mathrm{now}} - t_a < R_{\mathrm{aggregate}} \\
0, & \text{otherwise}
\end{cases}
\]

Deletion must be automatic, testable, and recorded as a privacy-preserving completion event.

### Review, explanation, correction, and appeal

The accountable decision chain is:

\[
\mathrm{Detection}
\rightarrow
\mathrm{Reason\ Code}
\rightarrow
\mathrm{Accessible\ Notice}
\rightarrow
\mathrm{Human\ Review}
\rightarrow
\mathrm{Resolution}
\rightarrow
\mathrm{Correction\ or\ Appeal}
\rightarrow
\mathrm{Auditable\ Closure}
\]

A reason code communicates system state without exposing sensitive sensing data. Example codes include:

- `INTENT_CONFIDENT`
- `INTENT_AMBIGUOUS_CONSERVATIVE_OPEN`
- `SENSOR_CONFIDENCE_REDUCED`
- `ACCESSIBLE_ACTIVATION_USED`
- `DEGRADED_MODE_ACTIVE`
- `MAINTENANCE_REQUIRED`
- `REVIEW_REQUEST_RECEIVED`
- `REVIEW_RESOLVED`

Accountability metrics include:

\[
T_{\mathrm{ack}} =
t_{\mathrm{review\ acknowledgement}}
-
t_{\mathrm{review\ request}}
\]

\[
T_{\mathrm{resolve}} =
t_{\mathrm{review\ resolution}}
-
t_{\mathrm{review\ request}}
\]

\[
R_{\mathrm{accessible}} =
\frac{
N_{\mathrm{review\ cases\ with\ accessible\ notice\ and\ support}}
}{
N_{\mathrm{review\ cases}}
}
\]

The target is \(R_{\mathrm{accessible}} = 1\).

### Energy and thermal evaluation

Door-related thermal exchange can be modeled as:

\[
Q_{\mathrm{air}} =
\int_{0}^{T}
\dot{m}_{\mathrm{air}}(t)
c_p
\left|
T_{\mathrm{inside}}(t)
-
T_{\mathrm{outside}}(t)
\right|
dt
\]

A practical study evaluates the paired outcomes:

\[
\Delta \overline{T}_{\mathrm{open}} =
\overline{T}_{\mathrm{open,baseline}}
-
\overline{T}_{\mathrm{open,smart}}
\]

\[
\Delta N_{\mathrm{reopen}} =
N_{\mathrm{reopen,baseline}}
-
N_{\mathrm{reopen,smart}}
\]

\[
\Delta E_{\mathrm{HVAC}} =
E_{\mathrm{HVAC,baseline}}
-
E_{\mathrm{HVAC,smart}}
\]

Energy benefit is valid only when the system preserves or improves accessibility and safety. Reduced energy use must never be obtained through shorter holds that create barriers or force users into manual workarounds.

### Six-site evaluation matrix

| Site profile | Central challenge | Primary measurements | Safe policy emphasis |
|---|---|---|---|
| High-throughput care | Continuous mixed-speed movement | Successful passage, congestion, tail delay | Conservative opening and high observability |
| Transit | Dense, directional flow | Pass-by discrimination, reopening rate, queue effects | Predictive trajectories with wide safety margins |
| Public library | Low noise and mixed dwell behavior | False openings, privacy trust, fallback discoverability | Clear notice and low-disturbance sensing |
| Heat-exposed entry | Large thermal gradient | Door-open duration, thermal exchange, successful passage | Accessibility-first timing with energy measurement |
| Secure public facility | Controlled operations without identity dependency | Fallback access, explanation, review closure | Separate access-control policy from doorway accessibility |
| Power-loss environment | Intermittent power and networking | Fallback availability, recovery time, manual usability | Offline-first independent operation |

## Evaluation Design

### Primary outcomes

- \(P_{\mathrm{successful\_passage}}\)
- \(D_{95,\mathrm{safe}}\)
- \(A_{\mathrm{manual/equivalent\_fallback}}\)
- False-open and missed-open rates
- Privacy-exposure score
- Local-processing conformance
- Mean open duration
- Door reopening frequency
- HVAC energy proxy or measured HVAC energy
- Review acknowledgement and resolution time
- Accessible-review coverage

### Experimental structure

Use a mixed-methods deployment study with:

- Baseline period using the existing compliant automatic-door configuration.
- Controlled activation period using the privacy-preserving intelligence layer.
- Crossover or stepped-wedge scheduling where operationally appropriate.
- Environmental-condition strata: lighting, heat, rain, smoke, fog, crowd density, and sensor occlusion.
- Accessibility-centered user research with voluntary participation and non-identifying study procedures.
- Incident, review, and maintenance analysis using minimized aggregate records.

### Statistical models

For passage success:

\[
Y_i \sim
\mathrm{Bernoulli}(p_i)
\]

\[
\mathrm{logit}(p_i) =
\beta_0 +
\beta_1 \mathrm{SmartDoor}_i +
\beta_2 \mathrm{Site}_i +
\beta_3 \mathrm{Environment}_i +
u_{\mathrm{day}(i)}
\]

For skewed delay:

\[
\log(D_i + \epsilon) =
\alpha_0 +
\alpha_1 \mathrm{SmartDoor}_i +
\alpha_2 \mathrm{Site}_i +
\alpha_3 \mathrm{Crowding}_i +
v_{\mathrm{day}(i)} +
\varepsilon_i
\]

For energy and thermal effects:

\[
E_t =
\gamma_0 +
\gamma_1 \mathrm{SmartDoor}_t +
\gamma_2
\left|
T_{\mathrm{inside},t} -
T_{\mathrm{outside},t}
\right|
+
\gamma_3 \mathrm{Traffic}_t +
\gamma_4 \mathrm{HVACState}_t +
\eta_t
\]

These models estimate population-level operational effects without identifying persons.

## High-Value Research Questions

- Can a local radar or ToF feature representation provide sufficient trajectory information for safe doorway control while avoiding persistent identity linkage?
- What uncertainty signal most effectively triggers conservative opening rather than overconfident denial of passage?
- Which site-governed quantile and margin policy maximizes successful passage while reducing avoidable air exchange?
- How should a model distinguish an adjacent pass-by from door-crossing intent when the cost of a missed opening is higher than the cost of an extra opening?
- Can a compact model be formally bounded so that uncertainty, sensor disagreement, or model drift always expands access rather than restricting it?
- What notice designs communicate non-visual sensing, local processing, and fallback use in a way that remains accessible to blind, low-vision, Deaf, hard-of-hearing, neurodivergent, multilingual, and non-technical users?
- What aggregate audit records are sufficient to investigate a service failure without constructing a behavioral dossier?
- How do heat, dust, glare, smoke, and power variability alter sensor confidence and doorway safety in hot-climate deployments?
- How can the door intelligence layer coordinate with HVAC systems using site-level thermal context while preventing occupant tracking?
- What governance process lets facilities approve timing envelopes and retention schedules while preserving a consistent universal-access floor?

## Research Deliverables

- Sensor benchmark protocol and reproducible test corridor.
- Privacy threat model for non-visual sensing.
- Local feature specification with explicit prohibited data classes.
- Intent-classification benchmark with calibration and abstention measures.
- Bounded timing-controller specification.
- Failure-mode and effects analysis for sensing, actuation, power, network, and interface failures.
- Accessible fallback interaction specification.
- Audit-event schema with retention and deletion tests.
- Review and appeal service blueprint.
- Six-site deployment protocol.
- Energy and thermal measurement plan.
- Public-facing accessibility and privacy notice templates.
- Rights-impact assessment and deployment-readiness checklist.

## Research Integrity

This program treats standards, accessibility requirements, privacy frameworks, and local building rules as evidence inputs for jurisdiction-specific engineering and governance review. It does not represent any proposed framework requirement as automatically enforceable law.

## Program Metrics

| Metric | Score | Basis |
|---|---:|---|
| knowledge_factor | 0.92 | Integrates sensing, control, safety, accessibility, privacy, thermal performance, and accountable governance into testable claims |
| eco_impact_value | 0.78 | Reduces avoidable conditioned-air exchange while keeping accessibility as a non-compensable requirement |
| harm_risk | 0.28 | Physical-door and sensing risks remain material; bounded control, fallback, review, and validation reduce them |
| accessibility_impact | 0.96 | Centers uninterrupted independent passage, equivalent fallback, accessible notices, and review pathways |
| rights_alignment | 0.97 | Uses minimization, local processing, non-identification, non-discrimination, autonomy, explanation, correction, and appeal |
