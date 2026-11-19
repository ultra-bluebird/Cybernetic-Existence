from __future__ import annotations

from dataclasses import dataclass
from math import isfinite


class CrosswalkTimingValidationError(ValueError):
    pass


@dataclass(frozen=True)
class CrosswalkConfiguration:
    crossing_width_m: float
    slowest_expected_speed_m_s: float
    fixed_buffer_s: float
    minimum_walk_s: float
    maximum_total_crossing_s: float
    extension_increment_s: float

    def __post_init__(self) -> None:
        values = (
            self.crossing_width_m,
            self.slowest_expected_speed_m_s,
            self.fixed_buffer_s,
            self.minimum_walk_s,
            self.maximum_total_crossing_s,
            self.extension_increment_s,
        )

        if any(not isfinite(value) for value in values):
            raise CrosswalkTimingValidationError(
                "All timing configuration values must be finite."
            )
        if self.crossing_width_m <= 0.0:
            raise CrosswalkTimingValidationError("crossing_width_m must be positive.")
        if self.slowest_expected_speed_m_s <= 0.0:
            raise CrosswalkTimingValidationError(
                "slowest_expected_speed_m_s must be positive."
            )
        if self.fixed_buffer_s < 0.0:
            raise CrosswalkTimingValidationError("fixed_buffer_s must be non-negative.")
        if self.minimum_walk_s <= 0.0:
            raise CrosswalkTimingValidationError("minimum_walk_s must be positive.")
        if self.maximum_total_crossing_s <= 0.0:
            raise CrosswalkTimingValidationError(
                "maximum_total_crossing_s must be positive."
            )
        if self.extension_increment_s <= 0.0:
            raise CrosswalkTimingValidationError(
                "extension_increment_s must be positive."
            )

        if self.minimum_total_crossing_s > self.maximum_total_crossing_s:
            raise CrosswalkTimingValidationError(
                "maximum_total_crossing_s must not be below the universal minimum."
            )

    @property
    def minimum_total_crossing_s(self) -> float:
        return max(
            self.minimum_walk_s,
            (self.crossing_width_m / self.slowest_expected_speed_m_s)
            + self.fixed_buffer_s,
        )


@dataclass(frozen=True)
class CrosswalkSensorState:
    crossing_zone_state: str
    sensor_health_valid: bool

    def __post_init__(self) -> None:
        allowed_states = {
            "CROSSING_CLEAR",
            "CROSSING_OCCUPIED",
            "CROSSING_UNCERTAIN",
            "SENSOR_FAULT",
        }
        if self.crossing_zone_state not in allowed_states:
            raise CrosswalkTimingValidationError(
                "crossing_zone_state is not supported."
            )


@dataclass(frozen=True)
class CrosswalkTimingDecision:
    state: str
    applied_total_crossing_s: float
    universal_minimum_preserved: bool
    adaptive_extension_applied: bool
    trajectory_retained: bool
    identity_or_health_inference_performed: bool
    reason: str


def determine_crossing_time(
    configuration: CrosswalkConfiguration,
    sensor_state: CrosswalkSensorState,
    current_total_crossing_s: float | None = None,
) -> CrosswalkTimingDecision:
    if current_total_crossing_s is not None:
        if not isfinite(current_total_crossing_s) or current_total_crossing_s <= 0.0:
            raise CrosswalkTimingValidationError(
                "current_total_crossing_s must be finite and positive when provided."
            )

    baseline = configuration.minimum_total_crossing_s
    current = baseline if current_total_crossing_s is None else max(
        current_total_crossing_s,
        baseline,
    )

    sensor_unavailable = (
        not sensor_state.sensor_health_valid
        or sensor_state.crossing_zone_state == "SENSOR_FAULT"
    )

    if sensor_unavailable:
        return CrosswalkTimingDecision(
            state="SENSOR_FAULT_FIXED_TIME_FALLBACK",
            applied_total_crossing_s=baseline,
            universal_minimum_preserved=True,
            adaptive_extension_applied=False,
            trajectory_retained=False,
            identity_or_health_inference_performed=False,
            reason=(
                "Adaptive sensing is unavailable. The controller uses the approved "
                "universal minimum fixed-time pedestrian plan."
            ),
        )

    if sensor_state.crossing_zone_state in {
        "CROSSING_OCCUPIED",
        "CROSSING_UNCERTAIN",
    }:
        extended = min(
            current + configuration.extension_increment_s,
            configuration.maximum_total_crossing_s,
        )
        return CrosswalkTimingDecision(
            state=(
                "CROSSING_OCCUPIED_EXTENSION"
                if sensor_state.crossing_zone_state == "CROSSING_OCCUPIED"
                else "CROSSING_UNCERTAIN_EXTENSION"
            ),
            applied_total_crossing_s=extended,
            universal_minimum_preserved=True,
            adaptive_extension_applied=extended > current,
            trajectory_retained=False,
            identity_or_health_inference_performed=False,
            reason=(
                "Anonymous crossing-zone occupancy or uncertainty extends timing and "
                "does not identify, classify, or track a person."
            ),
        )

    return CrosswalkTimingDecision(
        state="FIXED_TIME_ACCESSIBLE_OPERATION",
        applied_total_crossing_s=baseline,
        universal_minimum_preserved=True,
        adaptive_extension_applied=False,
        trajectory_retained=False,
        identity_or_health_inference_performed=False,
        reason=(
            "The universal minimum crossing time is provided without identity, health, "
            "mobility, or trajectory processing."
        ),
    )
