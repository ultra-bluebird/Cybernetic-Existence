from __future__ import annotations

from dataclasses import dataclass
from math import exp, isfinite
from typing import Iterable, Sequence


class AirForecastValidationError(ValueError):
    pass


@dataclass(frozen=True)
class SensorObservation:
    x_m: float
    y_m: float
    measured_value: float
    baseline_prediction: float
    calibrated: bool
    sensor_health_valid: bool
    individual_vehicle_data_used: bool = False
    personal_device_data_used: bool = False
    identity_data_used: bool = False

    def __post_init__(self) -> None:
        for field_name, value in (
            ("x_m", self.x_m),
            ("y_m", self.y_m),
            ("measured_value", self.measured_value),
            ("baseline_prediction", self.baseline_prediction),
        ):
            if not isfinite(value):
                raise AirForecastValidationError(f"{field_name} must be finite.")


@dataclass(frozen=True)
class Forecast:
    predicted_value: float
    kriging_variance: float
    prediction_resolution: str
    public_release_allowed: bool
    reason: str


def squared_distance(left_x: float, left_y: float, right_x: float, right_y: float) -> float:
    return (left_x - right_x) ** 2 + (left_y - right_y) ** 2


def inverse_distance_residual_forecast(
    target_x_m: float,
    target_y_m: float,
    baseline_prediction: float,
    observations: Iterable[SensorObservation],
    range_m: float = 3000.0,
    maximum_public_variance: float = 25.0,
) -> Forecast:
    if not isfinite(target_x_m) or not isfinite(target_y_m):
        raise AirForecastValidationError("Target coordinates must be finite.")
    if not isfinite(baseline_prediction):
        raise AirForecastValidationError("baseline_prediction must be finite.")
    if not isfinite(range_m) or range_m <= 0.0:
        raise AirForecastValidationError("range_m must be finite and positive.")
    if not isfinite(maximum_public_variance) or maximum_public_variance <= 0.0:
        raise AirForecastValidationError(
            "maximum_public_variance must be finite and positive."
        )

    valid = [
        observation
        for observation in observations
        if observation.calibrated
        and observation.sensor_health_valid
        and not observation.individual_vehicle_data_used
        and not observation.personal_device_data_used
        and not observation.identity_data_used
    ]

    if not valid:
        return Forecast(
            predicted_value=baseline_prediction,
            kriging_variance=float("inf"),
            prediction_resolution="regional_only",
            public_release_allowed=False,
            reason=(
                "No calibrated, healthy, privacy-safe local observations are available. "
                "Use a coarser regional estimate with an explicit uncertainty notice."
            ),
        )

    weighted_residual_sum = 0.0
    total_weight = 0.0
    weighted_squared_residual_sum = 0.0

    for observation in valid:
        distance_squared = squared_distance(
            target_x_m,
            target_y_m,
            observation.x_m,
            observation.y_m,
        )
        weight = exp(-distance_squared / (2.0 * range_m * range_m))
        residual = observation.measured_value - observation.baseline_prediction
        weighted_residual_sum += weight * residual
        weighted_squared_residual_sum += weight * residual * residual
        total_weight += weight

    if total_weight <= 0.0:
        raise AirForecastValidationError(
            "Spatial weighting produced no usable observation weight."
        )

    mean_residual = weighted_residual_sum / total_weight
    residual_second_moment = weighted_squared_residual_sum / total_weight
    residual_variance = max(0.0, residual_second_moment - mean_residual * mean_residual)
    coverage_penalty = 1.0 / total_weight
    prediction_variance = residual_variance + coverage_penalty

    prediction = baseline_prediction + mean_residual
    public_release_allowed = prediction_variance <= maximum_public_variance

    return Forecast(
        predicted_value=prediction,
        kriging_variance=prediction_variance,
        prediction_resolution=(
            "neighborhood_level" if public_release_allowed else "regional_only"
        ),
        public_release_allowed=public_release_allowed,
        reason=(
            "Hybrid baseline plus privacy-safe spatial residual estimate."
            if public_release_allowed
            else (
                "Local uncertainty exceeds the publication threshold. "
                "Use a coarser regional estimate."
            )
        ),
    )


def mean_absolute_error(
    observed_values: Sequence[float],
    predicted_values: Sequence[float],
) -> float:
    if not observed_values or len(observed_values) != len(predicted_values):
        raise AirForecastValidationError(
            "Observed and predicted values must be non-empty and have equal length."
        )

    errors = []
    for observed, predicted in zip(observed_values, predicted_values, strict=True):
        if not isfinite(observed) or not isfinite(predicted):
            raise AirForecastValidationError("All values must be finite.")
        errors.append(abs(observed - predicted))

    return sum(errors) / len(errors)
