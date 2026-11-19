from __future__ import annotations

from dataclasses import dataclass
from math import hypot
from typing import Literal


MotionDecision = Literal[
    "proceed",
    "yield",
    "stop_for_human_access",
    "stop_for_emergency_access",
    "stop_for_accessibility_path",
    "retreat_to_yield_pocket",
    "escalate_human_coordination",
]


@dataclass(frozen=True)
class CorridorState:
    corridor_segment: str
    reservation_present: bool
    reservation_expired: bool
    human_in_protected_zone: bool
    emergency_access_active: bool
    accessibility_path_blocked: bool
    safe_yield_pocket_available: bool


@dataclass(frozen=True)
class BotState:
    rotating_pseudonym: str
    priority: int
    wait_cycles: int
    preferred_speed_mps: float
    proposed_speed_mps: float
    goal_distance_m: float
    stopping_distance_m: float
    battery_margin: float


@dataclass(frozen=True)
class CoordinationDecision:
    decision: MotionDecision
    permitted_speed_mps: float
    reason: str


def decide_corridor_motion(
    corridor: CorridorState,
    bot: BotState,
    minimum_motion_speed_mps: float = 0.03,
    deadlock_cycle_threshold: int = 5,
) -> CoordinationDecision:
    if corridor.human_in_protected_zone:
        return CoordinationDecision(
            decision="stop_for_human_access",
            permitted_speed_mps=0.0,
            reason="Human access has absolute corridor priority.",
        )

    if corridor.emergency_access_active:
        return CoordinationDecision(
            decision="stop_for_emergency_access",
            permitted_speed_mps=0.0,
            reason="Emergency-equipment or emergency-response access is active.",
        )

    if corridor.accessibility_path_blocked:
        return CoordinationDecision(
            decision="stop_for_accessibility_path",
            permitted_speed_mps=0.0,
            reason="Accessible-path continuity must be restored before bot motion.",
        )

    if not corridor.reservation_present or corridor.reservation_expired:
        return CoordinationDecision(
            decision="yield",
            permitted_speed_mps=0.0,
            reason="Narrow-corridor motion requires a current reservation.",
        )

    proposed_speed = max(0.0, min(bot.proposed_speed_mps, bot.preferred_speed_mps))
    if (
        proposed_speed < minimum_motion_speed_mps
        and bot.goal_distance_m > bot.stopping_distance_m
        and bot.wait_cycles >= deadlock_cycle_threshold
    ):
        if corridor.safe_yield_pocket_available:
            return CoordinationDecision(
                decision="retreat_to_yield_pocket",
                permitted_speed_mps=0.0,
                reason="Persistent low-speed conflict requires a safe retreat negotiation.",
            )
        return CoordinationDecision(
            decision="escalate_human_coordination",
            permitted_speed_mps=0.0,
            reason="Persistent conflict has no safe automated retreat option.",
        )

    return CoordinationDecision(
        decision="proceed",
        permitted_speed_mps=proposed_speed,
        reason="Current reservation and safety protections permit bounded motion.",
    )


def relative_distance(
    first_position: tuple[float, float],
    second_position: tuple[float, float],
) -> float:
    return hypot(
        second_position[0] - first_position[0],
        second_position[1] - first_position[1],
    )
