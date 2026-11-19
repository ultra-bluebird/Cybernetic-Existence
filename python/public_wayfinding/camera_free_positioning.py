from __future__ import annotations

from dataclasses import dataclass
from math import hypot, isfinite


class WayfindingValidationError(ValueError):
    pass


@dataclass(frozen=True)
class Position:
    x_m: float
    y_m: float
    floor: int

    def __post_init__(self) -> None:
        if not isfinite(self.x_m) or not isfinite(self.y_m):
            raise WayfindingValidationError("Position coordinates must be finite.")


@dataclass(frozen=True)
class InertialStep:
    distance_m: float
    heading_radians: float

    def __post_init__(self) -> None:
        if not isfinite(self.distance_m) or self.distance_m < 0.0:
            raise WayfindingValidationError("distance_m must be finite and non-negative.")
        if not isfinite(self.heading_radians):
            raise WayfindingValidationError("heading_radians must be finite.")


@dataclass(frozen=True)
class PositionEstimate:
    position: Position
    horizontal_uncertainty_m: float
    confidence_state: str
    camera_access_used: bool
    image_data_retained: bool
    beacon_identifier_retained: bool
    location_history_retained: bool


def apply_inertial_step(
    start: Position,
    step: InertialStep,
    horizontal_uncertainty_m: float,
) -> PositionEstimate:
    if not isfinite(horizontal_uncertainty_m) or horizontal_uncertainty_m < 0.0:
        raise WayfindingValidationError(
            "horizontal_uncertainty_m must be finite and non-negative."
        )

    from math import cos, sin

    position = Position(
        x_m=start.x_m + step.distance_m * cos(step.heading_radians),
        y_m=start.y_m + step.distance_m * sin(step.heading_radians),
        floor=start.floor,
    )

    updated_uncertainty = horizontal_uncertainty_m + max(0.25, step.distance_m * 0.08)
    confidence_state = (
        "HIGH_CONFIDENCE"
        if updated_uncertainty < 1.0
        else "LANDMARK_OR_STAFF_CONFIRMATION_RECOMMENDED"
    )

    return PositionEstimate(
        position=position,
        horizontal_uncertainty_m=updated_uncertainty,
        confidence_state=confidence_state,
        camera_access_used=False,
        image_data_retained=False,
        beacon_identifier_retained=False,
        location_history_retained=False,
    )


def apply_ephemeral_beacon_correction(
    predicted: PositionEstimate,
    local_beacon_position: Position,
    measured_distance_m: float,
    correction_weight: float = 0.5,
) -> PositionEstimate:
    if not isfinite(measured_distance_m) or measured_distance_m < 0.0:
        raise WayfindingValidationError(
            "measured_distance_m must be finite and non-negative."
        )
    if not isfinite(correction_weight) or not 0.0 < correction_weight <= 1.0:
        raise WayfindingValidationError(
            "correction_weight must be in the interval (0, 1]."
        )
    if predicted.position.floor != local_beacon_position.floor:
        return PositionEstimate(
            position=predicted.position,
            horizontal_uncertainty_m=predicted.horizontal_uncertainty_m,
            confidence_state="FLOOR_CONFIRMATION_REQUIRED",
            camera_access_used=False,
            image_data_retained=False,
            beacon_identifier_retained=False,
            location_history_retained=False,
        )

    dx = predicted.position.x_m - local_beacon_position.x_m
    dy = predicted.position.y_m - local_beacon_position.y_m
    predicted_distance = hypot(dx, dy)

    if predicted_distance == 0.0:
        corrected = predicted.position
    else:
        scale = max(
            0.0,
            1.0
            - correction_weight
            * (predicted_distance - measured_distance_m)
            / predicted_distance,
        )
        corrected = Position(
            x_m=local_beacon_position.x_m + dx * scale,
            y_m=local_beacon_position.y_m + dy * scale,
            floor=predicted.position.floor,
        )

    return PositionEstimate(
        position=corrected,
        horizontal_uncertainty_m=max(
            0.25,
            predicted.horizontal_uncertainty_m * (1.0 - correction_weight * 0.5),
        ),
        confidence_state=(
            "HIGH_CONFIDENCE"
            if predicted.horizontal_uncertainty_m * (1.0 - correction_weight * 0.5) < 1.0
            else "LANDMARK_OR_STAFF_CONFIRMATION_RECOMMENDED"
        ),
        camera_access_used=False,
        image_data_retained=False,
        beacon_identifier_retained=False,
        location_history_retained=False,
    )


def rms_position_error_m(
    estimates: list[Position],
    references: list[Position],
) -> float:
    if not estimates or len(estimates) != len(references):
        raise WayfindingValidationError(
            "Estimates and references must be non-empty and have equal length."
        )

    squared_errors = []
    for estimate, reference in zip(estimates, references, strict=True):
        if estimate.floor != reference.floor:
            raise WayfindingValidationError(
                "RMS error requires matching reference and estimate floor values."
            )
        squared_errors.append(
            (estimate.x_m - reference.x_m) ** 2
            + (estimate.y_m - reference.y_m) ** 2
        )

    return (sum(squared_errors) / len(squared_errors)) ** 0.5
