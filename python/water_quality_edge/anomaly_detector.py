from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Iterable, Sequence

import numpy as np


class WaterQualityValidationError(ValueError):
    pass


@dataclass(frozen=True)
class WaterReading:
    temperature_c: float
    turbidity_ntu: float
    ph: float
    conductivity_us_cm: float
    battery_v: float
    sensor_maintenance_mode: bool = False

    def feature_vector(self) -> np.ndarray:
        values = (
            self.temperature_c,
            self.turbidity_ntu,
            self.ph,
            self.conductivity_us_cm,
        )
        if any(not isfinite(value) for value in values):
            raise WaterQualityValidationError("Water-quality values must be finite.")
        if not -5.0 <= self.temperature_c <= 80.0:
            raise WaterQualityValidationError("temperature_c is outside the configured physical range.")
        if not 0.0 <= self.turbidity_ntu <= 4000.0:
            raise WaterQualityValidationError("turbidity_ntu is outside the configured physical range.")
        if not 0.0 <= self.ph <= 14.0:
            raise WaterQualityValidationError("ph must be in the inclusive range from 0 through 14.")
        if not 0.0 <= self.conductivity_us_cm <= 200000.0:
            raise WaterQualityValidationError(
                "conductivity_us_cm is outside the configured physical range."
            )
        if not isfinite(self.battery_v) or self.battery_v <= 0.0:
            raise WaterQualityValidationError("battery_v must be finite and positive.")
        return np.asarray(values, dtype=np.float64)


@dataclass(frozen=True)
class BaselineModel:
    mean: np.ndarray
    inverse_regularized_covariance: np.ndarray
    threshold: float
    required_consecutive_exceedances: int
    minimum_battery_v: float

    @classmethod
    def fit(
        cls,
        historical_readings: Iterable[WaterReading],
        threshold: float,
        required_consecutive_exceedances: int = 3,
        minimum_battery_v: float = 3.3,
        covariance_regularization: float = 1e-6,
    ) -> "BaselineModel":
        readings = list(historical_readings)
        if len(readings) < 10:
            raise WaterQualityValidationError(
                "At least ten validated historical readings are required."
            )
        if not isfinite(threshold) or threshold <= 0.0:
            raise WaterQualityValidationError("threshold must be finite and positive.")
        if required_consecutive_exceedances < 1:
            raise WaterQualityValidationError(
                "required_consecutive_exceedances must be at least one."
            )
        if not isfinite(minimum_battery_v) or minimum_battery_v <= 0.0:
            raise WaterQualityValidationError("minimum_battery_v must be finite and positive.")
        if not isfinite(covariance_regularization) or covariance_regularization <= 0.0:
            raise WaterQualityValidationError(
                "covariance_regularization must be finite and positive."
            )

        samples = np.vstack([reading.feature_vector() for reading in readings])
        mean = np.mean(samples, axis=0)
        covariance = np.cov(samples, rowvar=False)
        regularized_covariance = covariance + (
            covariance_regularization * np.eye(covariance.shape[0])
        )

        try:
            inverse_covariance = np.linalg.inv(regularized_covariance)
        except np.linalg.LinAlgError as error:
            raise WaterQualityValidationError(
                "Unable to calculate an invertible regularized covariance matrix."
            ) from error

        return cls(
            mean=mean,
            inverse_regularized_covariance=inverse_covariance,
            threshold=float(threshold),
            required_consecutive_exceedances=required_consecutive_exceedances,
            minimum_battery_v=float(minimum_battery_v),
        )

    def mahalanobis_distance_squared(self, reading: WaterReading) -> float:
        vector = reading.feature_vector()
        delta = vector - self.mean
        score = float(delta.T @ self.inverse_regularized_covariance @ delta)
        if not isfinite(score) or score < 0.0:
            raise WaterQualityValidationError("Anomaly score must be finite and non-negative.")
        return score


@dataclass
class EdgeAnomalyState:
    consecutive_exceedances: int = 0

    def evaluate(self, model: BaselineModel, reading: WaterReading) -> dict[str, object]:
        if reading.sensor_maintenance_mode:
            self.consecutive_exceedances = 0
            return {
                "state": "RECHECK_REQUIRED",
                "reason": "Sensor is in maintenance or calibration mode.",
                "score": None,
                "raw_reading_exported": False,
            }

        if reading.battery_v < model.minimum_battery_v:
            self.consecutive_exceedances = 0
            return {
                "state": "RECHECK_REQUIRED",
                "reason": "Battery voltage is below the configured sensor-health threshold.",
                "score": None,
                "raw_reading_exported": False,
            }

        score = model.mahalanobis_distance_squared(reading)
        if score > model.threshold:
            self.consecutive_exceedances += 1
        else:
            self.consecutive_exceedances = 0

        if self.consecutive_exceedances >= model.required_consecutive_exceedances:
            return {
                "state": "MAINTENANCE_REVIEW_REQUESTED",
                "reason": "Validated multivariate deviation persisted across consecutive samples.",
                "score": score,
                "raw_reading_exported": False,
            }

        return {
            "state": "NORMAL",
            "reason": "No persistent validated multivariate deviation was detected.",
            "score": score,
            "raw_reading_exported": False,
        }
