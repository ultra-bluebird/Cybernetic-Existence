from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class DoorDecision(str, Enum):
    HOLD = "hold"
    OPEN = "open"
    CLOSE = "close"
    REVERSE_TO_OPEN = "reverse_to_open"
    FAULT_SAFE = "fault_safe"


@dataclass(frozen=True)
class SensorObservation:
    manual_activation: bool
    emergency_egress: bool
    approach_detected: bool
    occupancy_detected: bool
    obstruction_detected: bool
    activation_sensor_healthy: bool
    presence_sensor_healthy: bool
    operator_feedback_healthy: bool
    minimum_open_time_elapsed: bool


@dataclass(frozen=True)
class DoorPolicy:
    require_operator_feedback: bool = True
    hold_open_on_safety_fault: bool = True


def safety_healthy(
    observation: SensorObservation,
    policy: DoorPolicy,
) -> bool:
    if not observation.presence_sensor_healthy:
        return False
    if policy.require_operator_feedback and not observation.operator_feedback_healthy:
        return False
    return True


def decide(
    observation: SensorObservation,
    door_is_open: bool,
    policy: DoorPolicy = DoorPolicy(),
) -> DoorDecision:
    if not safety_healthy(observation, policy):
        return DoorDecision.FAULT_SAFE

    if observation.emergency_egress or observation.manual_activation:
        return DoorDecision.OPEN

    if observation.occupancy_detected or observation.obstruction_detected:
        return DoorDecision.REVERSE_TO_OPEN

    if not door_is_open and observation.approach_detected:
        if observation.activation_sensor_healthy:
            return DoorDecision.OPEN
        return DoorDecision.HOLD

    if door_is_open and observation.minimum_open_time_elapsed:
        return DoorDecision.CLOSE

    return DoorDecision.HOLD


def false_rejection_rate(
    valid_attempts: int,
    timely_accesses: int,
) -> float:
    if valid_attempts <= 0:
        raise ValueError("valid_attempts must be greater than zero")
    if timely_accesses < 0 or timely_accesses > valid_attempts:
        raise ValueError("timely_accesses must be within valid_attempts")
    return (valid_attempts - timely_accesses) / valid_attempts


def door_zone_coverage(
    covered_area_m2: float,
    required_area_m2: float,
) -> float:
    if required_area_m2 <= 0.0:
        raise ValueError("required_area_m2 must be greater than zero")
    if covered_area_m2 < 0.0:
        raise ValueError("covered_area_m2 must be nonnegative")
    return min(covered_area_m2 / required_area_m2, 1.0)
