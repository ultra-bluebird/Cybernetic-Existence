# Equitable Maintenance Bot Scheduling via Constrained Multi-Objective Reinforcement Learning

## Purpose

This specification describes a simulation-first reinforcement-learning scheduler for municipal maintenance bots.

The scheduler recommends assignments for inspection, preventive maintenance, repair delivery, and non-emergency service tasks across a city. It seeks to improve infrastructure uptime, prevent unequal maintenance backlogs, reduce energy and travel costs, and protect accessibility-critical infrastructure.

It is not an authorization for unconstrained physical autonomy. Physical bot operation requires a separately approved safety case, a declared operating corridor, real-time local safety controls, accessible pedestrian-first behavior, emergency stop capability, human oversight, and a policy-approved dispatch envelope.

## Non-Negotiable Invariants

The scheduler must not:

- Reduce baseline maintenance in any district because it has lower commercial value, lower complaint volume, lower connectivity, or lower political visibility.
- Treat disability, augmentation status, health information, identity, or personal mobility data as a scheduling feature.
- Defer an accessibility-critical repair solely to improve aggregate uptime or energy efficiency.
- Route a bot through inaccessible, unsafe, or prohibited pedestrian corridors.
- Use public cameras, audio, biometric data, faces, personal device identifiers, or person-level location history as training data.
- Make a final decision to disable, close, or withdraw access to elevators, automatic doors, accessible transit features, cooling systems, water access, or other essential infrastructure.
- Act outside a valid corridor, active maintenance authorization, energy budget, or human-approved emergency policy.

The project’s corridor-first approach provides an appropriate implementation pattern: a maintenance plan must carry declared operational context, risk constraints, and an auditable evaluation before it becomes eligible for deployment. [83]

## State

At decision time \(t\), define state:

\[
s_t =
[
a_t,
b_t,
\ell_t,
e_t,
q_t,
u_t,
f_t,
c_t
]
\]

Where:

- \(a_t\): asset health and predicted failure-risk summaries.
- \(b_t\): current maintenance backlog by district and asset class.
- \(\ell_t\): bot positions, battery state, tool availability, and workload capacity.
- \(e_t\): travel-time, route-accessibility, weather, and energy-cost summaries.
- \(q_t\): service-quality and uptime indicators by district and asset class.
- \(u_t\): accessibility-critical asset condition and service-floor status.
- \(f_t\): district-level fairness debt and historic repair-delay indicators.
- \(c_t\): active corridor, safety, staffing, policy, and operating constraints.

All state features are asset- and district-level aggregates. The state excludes individual identity, health, disability, augmentation, biometric, and personal location information.

## Action

An action \(a_t\) selects:

- A maintenance bot.
- An approved task.
- A destination asset or corridor.
- A route from the pre-approved accessible route graph.
- A time window.
- An energy allocation.
- A bounded service mode, such as inspect, deliver part, perform approved repair, or request human escalation.

\[
a_t =
[
\operatorname{bot},
\operatorname{task},
\operatorname{asset},
\operatorname{route},
\operatorname{time\ window},
\operatorname{energy\ budget},
\operatorname{service\ mode}
]
\]

The action space is masked before policy selection. Invalid routes, unavailable bots, inaccessible corridors, tasks outside authorization, low-battery actions, and unsafe weather conditions are removed from the agent’s choices.

## Multi-Objective Reward

The immediate reward is:

\[
r_t =
0.30U_t
+
0.25F_t
+
0.20A_t
+
0.15P_t
-
0.05E_t
-
0.05T_t
-
\Pi_t
\]

Where:

- \(U_t\): system uptime improvement.
- \(F_t\): fair service-distribution improvement.
- \(A_t\): accessibility-critical infrastructure protection.
- \(P_t\): preventive-maintenance value.
- \(E_t\): normalized energy cost.
- \(T_t\): normalized travel-time cost.
- \(\Pi_t\): hard-constraint penalty.

### Uptime Component

\[
U_t
=
\sum_{i \in \mathcal{I}}
w_i^{\mathrm{asset}}
\cdot
\Delta \operatorname{Availability}_{i,t}
\]

Asset weights can reflect verified service criticality, but may not encode property value, resident identity, or revenue maximization.

### Fairness Component

For district \(d\), let \(L_{d,t}\) be the normalized maintenance burden:

\[
L_{d,t}
=
0.50\operatorname{RepairDelay}_{d,t}
+
0.30\operatorname{Backlog}_{d,t}
+
0.20\operatorname{FailureExposure}_{d,t}
\]

Define the worst-service fairness score:

\[
F_t
=
1 -
\max_{d \in \mathcal{D}} L_{d,t}
\]

This minimax term directly rewards reductions in the highest district maintenance burden rather than only improving citywide averages.

A second disparity term can be added:

\[
F_t^{\mathrm{ratio}}
=
\frac{
\min_{d \in \mathcal{D}}\operatorname{ServiceLevel}_{d,t}
}{
\operatorname{mean}_{d \in \mathcal{D}}\operatorname{ServiceLevel}_{d,t}+\epsilon
}
\]

The system may use:

\[
F_t^{\mathrm{combined}}
=
0.70F_t
+
0.30F_t^{\mathrm{ratio}}
\]

### Accessibility-Critical Protection

Let \(\mathcal{A}\) be accessibility-critical assets, including elevators, automatic doors, ramps, accessible crossings, accessible transit equipment, public cooling equipment, accessible restroom equipment, public information systems, and emergency communication devices.

\[
A_t
=
1 -
\max_{i \in \mathcal{A}}
\operatorname{CriticalServiceRisk}_{i,t}
\]

This term gives high value to reducing the worst unresolved accessibility-critical risk.

### Preventive-Maintenance Value

\[
P_t
=
\sum_{i \in \mathcal{I}}
\operatorname{FailureProbability}_{i,t}
\cdot
\operatorname{ConsequenceSeverity}_{i}
\cdot
\operatorname{PreventedFailure}_{i,t}
\]

### Constraint Penalty

\[
\Pi_t
=
\Pi_t^{\mathrm{corridor}}
+
\Pi_t^{\mathrm{safety}}
+
\Pi_t^{\mathrm{accessibility}}
+
\Pi_t^{\mathrm{energy}}
+
\Pi_t^{\mathrm{human\ approval}}
\]

For a hard violation, the episode terminates with a large negative reward and no physical action is authorized.

## Hard Constraints

The scheduler must enforce:

\[
\operatorname{TravelTime}_{b,i}
\le
\operatorname{TravelLimit}_{b}
\]

\[
\operatorname{EnergyUsed}_{b,t}
\le
\operatorname{EnergyBudget}_{b,t}
\]

\[
\operatorname{RouteAccessible}_{b,i}
=
1
\]

\[
\operatorname{CorridorApproved}_{b,i,t}
=
1
\]

\[
\operatorname{ServiceFloor}_{d,t}
\ge
\operatorname{MinimumServiceFloor}_{d}
\]

\[
\operatorname{AccessibilityCriticalBacklog}_{t}
\le
\operatorname{MaximumAllowedCriticalBacklog}
\]

The final two constraints prevent an optimizer from increasing overall uptime while allowing a district or accessibility-critical service class to fall below an approved service level.

## Lexicographic Dispatch Order

Before optimizing secondary objectives, the system applies a rights-preserving dispatch sequence:

- Resolve immediate safety and accessibility-critical service failures.
- Protect district service floors and maximum repair-delay limits.
- Select preventive tasks that reduce imminent essential-service failure risk.
- Optimize fair service distribution.
- Optimize general uptime.
- Minimize travel time and energy use within the remaining feasible space.

This order ensures that cost or efficiency does not override basic public access.

## Training and Evaluation

Train only in Gazebo or an equivalent non-actuating simulator using synthetic or de-identified asset conditions.

The simulation should model:

- Road, sidewalk, building, and facility corridors.
- Accessible-route restrictions.
- Battery depletion and charging.
- Weather effects.
- Bot travel time and task duration.
- Asset failure distributions.
- Human technician availability.
- Parts inventory and supply delay.
- District-level backlog and repair-delay histories.
- Accessibility-critical asset classes.
- Network and sensor failures.
- Emergency overrides and no-go zones.

Evaluate against baselines:

- Earliest-deadline-first.
- Highest-failure-risk-first.
- Round-robin by district.
- Mixed-integer fair scheduling optimizer.
- Human planner historical policy, where lawful and appropriately de-identified.

Required evaluation metrics:

- Overall asset uptime.
- Accessibility-critical uptime.
- Maximum district repair delay.
- Maintenance-burden disparity.
- Service-floor violations.
- Energy per completed task.
- Travel time per completed task.
- False deferral rate for critical repairs.
- Human override rate.
- Corridor and safety violation attempts.
- Model performance by district and asset class.

## Human Oversight

The agent outputs a recommended dispatch plan with:

- Ranked assignments.
- Predicted uptime gain.
- Predicted fairness change.
- Accessibility-critical impact.
- Energy and travel estimate.
- Constraint checks.
- Confidence and uncertainty.
- Counterfactual explanation: why this task was selected instead of the nearest alternative.

A human dispatcher approves, modifies, or rejects any plan outside the pre-approved low-risk envelope. The override and reason become part of the training-audit record, but must not be treated as a ground-truth label without review.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.93 | Uses constrained state/action design, multi-objective reward, minimax fairness, simulation, baseline comparison, and auditability |
| eco_impact_value | 0.78 | Supports preventive repair, reduced premature replacement, lower travel and energy use, and longer public-infrastructure life |
| harm_risk | 0.18 | Bounded by action masks, service floors, human oversight, safety gates, privacy limits, and simulation-first validation |
| accessibility_impact | 0.99 | Makes accessibility-critical infrastructure protection and district service floors primary constraints |
| rights_alignment | 0.98 | Prevents identity profiling, blocks exclusionary service tradeoffs, retains human accountability, and requires accessible review |
