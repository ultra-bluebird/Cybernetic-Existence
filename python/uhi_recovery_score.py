from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Sequence


@dataclass(frozen=True)
class DistrictHeatInputs:
    land_surface_temperature_anomaly_c: float
    albedo: float
    ndvi: float
    building_density_ratio: float
    impervious_surface_ratio: float
    feasible_intervention_coverage: float
    data_quality_confidence: float
    realtime_air_temperature_anomaly_c: float | None = None
    realtime_sensor_trust: float = 0.0


@dataclass(frozen=True)
class UhiReferenceDistribution:
    lst_anomaly_p10: float
    lst_anomaly_p90: float
    albedo_p10: float
    albedo_p90: float
    ndvi_p10: float
    ndvi_p90: float
    building_density_p10: float
    building_density_p90: float
    impervious_p10: float
    impervious_p90: float
    air_anomaly_p10: float | None = None
    air_anomaly_p90: float | None = None


def clamp(value: float, lower: float = 0.0, upper: float = 1.0) -> float:
    if not isfinite(value):
        raise ValueError("all numeric inputs must be finite")
    return max(lower, min(upper, value))


def robust_normalize(value: float, p10: float, p90: float) -> float:
    if not all(isfinite(item) for item in (value, p10, p90)):
        raise ValueError("normalization values must be finite")
    if p90 <= p10:
        raise ValueError("p90 must be greater than p10")
    return clamp((value - p10) / (p90 - p10))


def calculate_uhi_recovery_potential(
    inputs: DistrictHeatInputs,
    reference: UhiReferenceDistribution,
) -> float:
    albedo = clamp(inputs.albedo)
    building_density = clamp(inputs.building_density_ratio)
    imperviousness = clamp(inputs.impervious_surface_ratio)
    feasibility = clamp(inputs.feasible_intervention_coverage)
    quality = clamp(inputs.data_quality_confidence)
    sensor_trust = clamp(inputs.realtime_sensor_trust)

    heat_burden = robust_normalize(
        inputs.land_surface_temperature_anomaly_c,
        reference.lst_anomaly_p10,
        reference.lst_anomaly_p90,
    )

    if (
        inputs.realtime_air_temperature_anomaly_c is not None
        and reference.air_anomaly_p10 is not None
        and reference.air_anomaly_p90 is not None
    ):
        realtime_burden = robust_normalize(
            inputs.realtime_air_temperature_anomaly_c,
            reference.air_anomaly_p10,
            reference.air_anomaly_p90,
        )
        heat_burden = (1.0 - sensor_trust) * heat_burden + sensor_trust * realtime_burden

    albedo_deficit = 1.0 - robust_normalize(
        albedo,
        reference.albedo_p10,
        reference.albedo_p90,
    )
    vegetation_deficit = 1.0 - robust_normalize(
        inputs.ndvi,
        reference.ndvi_p10,
        reference.ndvi_p90,
    )
    density = robust_normalize(
        building_density,
        reference.building_density_p10,
        reference.building_density_p90,
    )
    impervious = robust_normalize(
        imperviousness,
        reference.impervious_p10,
        reference.impervious_p90,
    )

    composite = (
        0.32 * heat_burden
        + 0.18 * albedo_deficit
        + 0.22 * vegetation_deficit
        + 0.12 * density
        + 0.16 * impervious
    )
    return clamp(quality * feasibility * composite)


def effective_monitoring_coverage(uptime: float, calibration_quality: float, representativeness: float) -> float:
    return clamp(uptime) * clamp(calibration_quality) * clamp(representativeness)


def coverage_equity_ratio(coverages: Sequence[float]) -> float:
    if not coverages:
        raise ValueError("at least one district coverage value is required")
    normalized = [clamp(value) for value in coverages]
    mean_coverage = sum(normalized) / len(normalized)
    if mean_coverage == 0.0:
        return 0.0
    return min(normalized) / mean_coverage
