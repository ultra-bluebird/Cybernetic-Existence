from __future__ import annotations

from dataclasses import dataclass
from math import isfinite


class TransitSafetyValidationError(ValueError):
    pass


@dataclass(frozen=True)
class ShuttleState:
    speed_m_s: float
    sensor_delay_s: float
    planning_delay_s: float
    braking_delay_s: float
    safe_deceleration_m_s2: float
    uncertainty_margin_m: float
    sensor_health_valid: bool
    operating_domain_valid: bool

    def __post_init__(self) -> None:
        values = (
            self.speed_m_s,
            self.sensor_delay_s,
            self.planning_delay_s,
            self.braking_delay_s,
            self.safe_deceleration_m_s2,
            self.uncertainty_margin_m,
        )
        if any(not isfinite(value) for value in values):
            raise TransitSafetyValidationError("All shuttle-state values must be finite.")
        if self.speed_m_s < 0.0:
            raise TransitSafetyValidationError("speed_m_s must be non-negative.")
        if any(value < 0.0 for value in values[1:4]):
            raise TransitSafetyValidationError("Delay values must be non-negative.")
        if self.safe_deceleration_m_s2 <= 0.0:
            raise TransitSafetyValidationError("safe_deceleration_m_s2 must be positive.")
        if self.uncertainty_margin_m < 0.0:
            raise TransitSafetyValidationError("uncertainty_margin_m must be non-negative.")

    @property
    def total_delay_s(self) -> float:
        return self.sensor_delay_s + self.planning_delay_s + self.braking_delay_s

    @property
    def stopping_distance_m(self) -> float:
        reaction_distance = self.speed_m_s * self.total_delay_s
        braking_distance = (self.speed_m_s**2) / (2.0 * self.safe_deceleration_m_s2)
        return reaction_distance + braking_distance + self.uncertainty_margin_m

    @property
    def minimum_ttc_s(self) -> float:
        braking_time = self.speed_m_s / self.safe_deceleration_m_s2
        return max(3.0, self.total_delay_s + braking_time)


@dataclass(frozen=True)
class PedestrianInteraction:
    distance_m: float
    relative_closing_speed_m_s: float
    occupancy_uncertain: bool
    path_intersection_predicted: bool

    def __post_init__(self) -> None:
        values = (self.distance_m, self.relative_closing_speed_m_s)
        if any(not isfinite(value) for value in values):
            raise TransitSafetyValidationError("Interaction values must be finite.")
        if self.distance_m < 0.0:
            raise TransitSafetyValidationError("distance_m must be non-negative.")
        if self.relative_closing_speed_m_s < 0.0:
            raise TransitSafetyValidationError(
                "relative_closing_speed_m_s must be non-negative."
            )

    def time_to_collision_s(self) -> float:
        if self.relative_closing_speed_m_s == 0.0:
            return float("inf")
        return self.distance_m / self.relative_closing_speed_m_s


@dataclass(frozen=True)
class SafetyDecision:
    state: str
    time_to_collision_s: float
    required_ttc_s: float
    stopping_distance_m: float
    safe_for_continuation: bool
    reason: str


def evaluate_interaction(
    shuttle: ShuttleState,
    interaction: PedestrianInteraction,
) -> SafetyDecision:
    ttc = interaction.time_to_collision_s()
    required_ttc = shuttle.minimum_ttc_s
    stopping_distance = shuttle.stopping_distance_m

    if not shuttle.sensor_health_valid:
        return SafetyDecision(
            state="MINIMAL_RISK_STOP",
            time_to_collision_s=ttc,
            required_ttc_s=required_ttc,
            stopping_distance_m=stopping_distance,
            safe_for_continuation=False,
            reason="Sensor-health validation failed.",
        )

    if not shuttle.operating_domain_valid:
        return SafetyDecision(
            state="MINIMAL_RISK_STOP",
            time_to_collision_s=ttc,
            required_ttc_s=required_ttc,
            stopping_distance_m=stopping_distance,
            safe_for_continuation=False,
            reason="The operating design domain is not currently valid.",
        )

    required_distance = stopping_distance
    if interaction.occupancy_uncertain:
        required_distance += shuttle.uncertainty_margin_m

    unsafe_ttc = ttc <= required_ttc
    unsafe_distance = interaction.distance_m <= required_distance

    if interaction.path_intersection_predicted and (unsafe_ttc or unsafe_distance):
        return SafetyDecision(
            state="CONTROLLED_DECELERATION_OR_STOP",
            time_to_collision_s=ttc,
            required_ttc_s=required_ttc,
            stopping_distance_m=stopping_distance,
            safe_for_continuation=False,
            reason=(
                "A person-associated or uncertain dynamic occupancy overlaps the "
                "conservative stopping and time-to-collision envelope."
            ),
        )

    if interaction.occupancy_uncertain:
        return SafetyDecision(
            state="REDUCED_SPEED_WITH_CONSERVATIVE_CLEARANCE",
            time_to_collision_s=ttc,
            required_ttc_s=required_ttc,
            stopping_distance_m=stopping_distance,
            safe_for_continuation=False,
            reason=(
                "Occupancy uncertainty requires reduced speed and conservative clearance "
                "until the shuttle can establish a safe path."
            ),
        )

    return SafetyDecision(
        state="CONTINUE_WITH_MONITORING",
        time_to_collision_s=ttc,
        required_ttc_s=required_ttc,
        stopping_distance_m=stopping_distance,
        safe_for_continuation=True,
        reason="The conservative stopping and time-to-collision constraints are currently satisfied.",
    )
