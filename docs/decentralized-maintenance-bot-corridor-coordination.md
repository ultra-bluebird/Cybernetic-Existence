# Decentralized Maintenance-Bot Coordination in Narrow Corridors

## Purpose

This design coordinates multiple maintenance bots moving through narrow corridors, such as sidewalks, station passages, service tunnels, hospital-adjacent routes, accessible pedestrian paths, building corridors, and utility spaces.

The design uses local velocity-obstacle avoidance, distributed priority negotiation, corridor reservations, and deadlock recovery.

The system is constrained by a primary rule:

> Human passage, emergency-equipment access, and accessible-route continuity take priority over maintenance-bot throughput.

Bots are tools for maintenance support. They are not permitted to obstruct people, restrict accessible route use, block emergency equipment, enter prohibited areas, or make access-control decisions.

## Priority Classes

| Priority | Class | Examples |
|---:|---|---|
| 0 | Human and emergency access | Pedestrians, mobility-device users, emergency response, evacuation, emergency equipment access |
| 1 | Accessibility-critical infrastructure repair | Automatic door repair, elevator support, accessible crossing repair, ramp obstruction response |
| 2 | Safety-critical infrastructure repair | Water leak response, electrical hazard inspection, structural alert |
| 3 | Planned public maintenance | Scheduled inspection, cleaning, minor repair |
| 4 | Deferred optimization | Inventory movement, routine mapping, nonurgent logistics |

A bot may never negotiate a priority higher than class 1. Human and emergency access are not “agents” in the negotiation system; they are exclusion conditions that trigger bot yielding behavior.

## Corridor State

Each robot maintains local corridor state:

\[
s_i =
[
p_i,
v_i,
g_i,
r_i,
\pi_i,
b_i,
c_i,
h_i
]
\]

Where:

- \(p_i\): robot position and footprint.
- \(v_i\): current velocity.
- \(g_i\): local goal or task target.
- \(r_i\): robot radius and safety envelope.
- \(\pi_i\): task priority.
- \(b_i\): battery and stopping capability.
- \(c_i\): current corridor segment and reservation state.
- \(h_i\): local hazard, human-presence, emergency-access, and accessibility-path state.

The system must not retain human identities, faces, gait signatures, device identifiers, or personal trajectories. Human detection is short-lived safety sensing only.

## Velocity Obstacles

For robots \(i\) and \(j\), define relative position and velocity:

\[
p_{ij}=p_j-p_i
\]

\[
v_{ij}=v_i-v_j
\]

The velocity-obstacle region for time horizon \(\tau\) is:

\[
VO_{i|j}^{\tau}
=
\{
v_i
\mid
\exists t \in [0,\tau]:
\|p_{ij}+t(v_i-v_j)\|
<
r_i+r_j+r_{\mathrm{safe}}
\}
\]

The robot selects a velocity outside all forbidden regions:

\[
v_i^{*}
=
\arg\min_{v \notin \bigcup_j VO_{i|j}^{\tau}}
\left[
\|v-v_i^{\mathrm{preferred}}\|^2
+
\lambda \operatorname{DeviationCost}(v)
\right]
\]

Optimal Reciprocal Collision Avoidance assigns each robot a reciprocal share of pairwise collision avoidance and reduces local velocity selection to a low-dimensional linear program. [265]

## Human and Accessibility Exclusion Zones

Before bot-to-bot negotiation, each robot applies:

\[
\operatorname{BotMotionAllowed}
=
\neg\operatorname{HumanInProtectedZone}
\land
\neg\operatorname{EmergencyAccessActive}
\land
\neg\operatorname{AccessibilityPathBlocked}
\]

If false:

```text
stop safely
yield corridor
release or shorten reservation
announce local status to peers
request human support if blockage persists
```

A bot must maintain an accessible passage width and stop outside protected zones. Exact width and clearance requirements must use applicable local building, accessibility, transit, and safety standards.

## Distributed Corridor Reservation

Each narrow segment has a logical reservation token:

```text
corridor_segment
reservation_epoch
requesting_bot
task_priority
entry_time_window
exit_time_window
battery_margin
yield_capability
previous_reservation_hash
signature
```

A bot requests a reservation only for an approved route and a bounded future time window.

Reservation precedence is:

\[
\operatorname{Precedence}(i,j)
=
\begin{cases}
i, & \pi_i < \pi_j \\
i, & \pi_i=\pi_j \land \operatorname{WaitTime}_i>\operatorname{WaitTime}_j \\
i, & \pi_i=\pi_j \land \operatorname{WaitTime}_i=\operatorname{WaitTime}_j
\land
\operatorname{TieBreak}_i<\operatorname{TieBreak}_j
\end{cases}
\]

Lower numeric priority indicates higher urgency.

The tie-break uses a rotating, epoch-bound pseudonymous value, not a permanent identity ranking.

## Deadlock Detection

A potential deadlock occurs when:

\[
\|v_i^{*}\| < v_{\mathrm{minimum}}
\]

for at least \(K\) planning cycles and the robot remains outside its goal tolerance.

If two or more bots remain mutually blocked:

- Freeze new corridor-entry requests for the involved segment.
- Preserve emergency and human-access exclusions.
- Compare reservation precedence.
- Require the lower-precedence bot to retreat to its last designated yield pocket if safe.
- If no safe yield pocket exists, both bots stop and request human coordination.
- Increase a bounded wait-time credit for the yielded bot to prevent starvation.
- Log the event as an aggregate corridor-coordination incident.

ORCA can still deadlock when large robots with opposing goals meet in constrained spaces, so a reservation and retreat rule is required rather than relying on velocity obstacles alone. [261][269]

## Decentralized Negotiation Messages

Bots exchange only:

```text
rotating_bot_pseudonym
corridor_segment
task_priority
reservation_window
footprint_class
stopping_distance
battery_margin
yield_pocket_availability
protocol_version
signature
```

Bots do not exchange personal data, camera streams, building occupant data, individual route histories, or unrestricted mission data.

Messages are authenticated, rate-limited, expiration-bounded, and rejected when stale or inconsistent with corridor policy.

## ROS 2 and Nav2 Integration

Use ROS 2 for robot-local coordination and Nav2 for global route planning and recovery behavior.

Recommended integration points:

- Nav2 costmap layer for protected accessibility zones, emergency equipment exclusion zones, and narrow-corridor metadata.
- Nav2 behavior-tree nodes for `RequestCorridorReservation`, `YieldForHumanAccess`, `RetreatToYieldPocket`, and `EscalateToHumanCoordinator`.
- Collision Monitor for local speed restriction and stop zones.
- A local ORCA or velocity-obstacle node that publishes safe velocity constraints to the controller.
- C++ low-level controller that enforces acceleration, braking, footprint, emergency stop, and safety-envelope limits independently of task planning.

Nav2 behavior trees provide a configurable way to organize navigation actions, planning, recovery, and control flow. [259][267] Nav2’s Collision Monitor supports velocity-polygons and stop zones that can be configured around a robot’s motion envelope. [263]

## C++ Control Invariant

\[
v_{\mathrm{command}}
=
\begin{cases}
0, & \text{if human, emergency, or access-path protection is active} \\
0, & \text{if reservation is absent or expired in a narrow segment} \\
\operatorname{Clamp}(v_i^{*}), & \text{otherwise}
\end{cases}
\]

The low-level controller must independently validate every velocity command and must not accept a speed command that violates:

- Maximum speed.
- Maximum acceleration.
- Braking-distance requirement.
- Current collision-monitor constraint.
- Emergency stop.
- Human-protection zone.
- Accessibility-path exclusion.
- Active reservation rule.

## Metrics

| Metric | Value | Basis |
|---|---:|---|
| knowledge_factor | 0.94 | Uses velocity obstacles, reciprocal avoidance, reservations, deadlock detection, retreat policy, Nav2 integration, and independent controller constraints |
| eco_impact_value | 0.68 | Supports targeted maintenance with reduced redundant travel and avoids unnecessary corridor blockage or emergency intervention |
| harm_risk | 0.16 | Reduced through human priority, emergency equipment exclusion, accessibility-path protection, stop defaults, and human escalation |
| accessibility_impact | 0.99 | Makes accessible-path continuity, yield behavior, and accessibility-critical repairs higher priority than bot throughput |
| rights_alignment | 0.99 | Prevents person tracking, blocks automated corridor control over people, protects public passage, and requires auditable safety behavior |
