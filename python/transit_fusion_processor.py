from __future__ import annotations

from dataclasses import dataclass
from math import isfinite


@dataclass(frozen=True)
class CountObservation:
    camera_delta: float
    camera_variance: float
    infrared_delta: float
    infrared_variance: float


@dataclass(frozen=True)
class EnvironmentObservation:
    cabin_co2_ppm: float
    outdoor_co2_ppm: float
    temperature_c: float
    relative_humidity_percent: float
    hvac_running: bool
    door_open_fraction: float


@dataclass(frozen=True)
class FusionResult:
    occupancy: float
    occupancy_variance: float
    ventilation_indicator: float
    camera_infrared_disagreement: bool
    confidence: str


def clamp(value: float, lower: float, upper: float) -> float:
    if not isfinite(value):
        raise ValueError("input must be finite")
    return max(lower, min(upper, value))


def inverse_variance_fuse(observation: CountObservation) -> tuple[float, float]:
    if observation.camera_variance <= 0.0 or observation.infrared_variance <= 0.0:
        raise ValueError("sensor variances must be positive")

    camera_weight = 1.0 / observation.camera_variance
    infrared_weight = 1.0 / observation.infrared_variance
    total_weight = camera_weight + infrared_weight

    fused_delta = (
        camera_weight * observation.camera_delta
        + infrared_weight * observation.infrared_delta
    ) / total_weight
    fused_variance = 1.0 / total_weight
    return fused_delta, fused_variance


def calculate_ventilation_indicator(
    cabin_co2_ppm: float,
    outdoor_co2_ppm: float,
    reference_co2_ppm: float = 1100.0,
) -> float:
    if reference_co2_ppm <= outdoor_co2_ppm:
        raise ValueError("reference CO2 must exceed outdoor CO2")
    if cabin_co2_ppm < 0.0 or outdoor_co2_ppm < 0.0:
        raise ValueError("CO2 values must be non-negative")

    excess = max(0.0, cabin_co2_ppm - outdoor_co2_ppm)
    return clamp(
        1.0 - excess / (reference_co2_ppm - outdoor_co2_ppm),
        0.0,
        1.0,
    )


def update_fused_state(
    previous_occupancy: float,
    previous_variance: float,
    rated_capacity: float,
    count_observation: CountObservation,
    environment: EnvironmentObservation,
) -> FusionResult:
    if previous_variance < 0.0:
        raise ValueError("previous variance must be non-negative")
    if rated_capacity <= 0.0:
        raise ValueError("rated capacity must be positive")

    delta, delta_variance = inverse_variance_fuse(count_observation)
    occupancy = clamp(previous_occupancy + delta, 0.0, rated_capacity)
    variance = previous_variance + delta_variance

    disagreement_sigma = abs(
        count_observation.camera_delta - count_observation.infrared_delta
    ) / (count_observation.camera_variance + count_observation.infrared_variance) ** 0.5
    disagreement = disagreement_sigma >= 3.0

    ventilation = calculate_ventilation_indicator(
        environment.cabin_co2_ppm,
        environment.outdoor_co2_ppm,
    )

    confidence = "low" if disagreement or variance > 25.0 else "high"
    return FusionResult(
        occupancy=round(occupancy, 2),
        occupancy_variance=round(variance, 4),
        ventilation_indicator=round(ventilation, 4),
        camera_infrared_disagreement=disagreement,
        confidence=confidence,
    )
