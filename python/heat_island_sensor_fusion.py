from dataclasses import dataclass
from math import isfinite
from typing import Iterable


EPSILON = 1e-12


@dataclass(frozen=True)
class ThermalObservation:
    source_ref: str
    timestamp_ms: int
    temperature_celsius: float
    uncertainty_celsius: float
    quality_factor: float
    drift_estimate_celsius: float
    is_air_temperature: bool
    is_surface_temperature: bool
    is_stale: bool
    is_out_of_range: bool
    provenance_complete: bool


@dataclass(frozen=True)
class ThermalFusionResult:
    timestamp_ms: int
    fused_temperature_celsius: float | None
    uncertainty_proxy_celsius: float | None
    contributing_sources: int
    excluded_sources: tuple[str, ...]
    review_required: bool


def observation_is_usable(observation: ThermalObservation) -> bool:
    values = (
        observation.temperature_celsius,
        observation.uncertainty_celsius,
        observation.quality_factor,
        observation.drift_estimate_celsius,
    )

    return (
        all(isfinite(value) for value in values)
        and observation.uncertainty_celsius > 0
        and observation.drift_estimate_celsius >= 0
        and 0.0 <= observation.quality_factor <= 1.0
        and observation.provenance_complete
        and not observation.is_stale
        and not observation.is_out_of_range
    )


def observation_weight(observation: ThermalObservation) -> float:
    variance = (
        observation.uncertainty_celsius ** 2
        + observation.drift_estimate_celsius ** 2
    )
    return observation.quality_factor / max(variance, EPSILON)


def fuse_temperature(
    observations: Iterable[ThermalObservation],
    *,
    require_air_temperature: bool,
) -> ThermalFusionResult:
    observations_tuple = tuple(observations)

    if not observations_tuple:
        return ThermalFusionResult(
            timestamp_ms=0,
            fused_temperature_celsius=None,
            uncertainty_proxy_celsius=None,
            contributing_sources=0,
            excluded_sources=(),
            review_required=True,
        )

    timestamp_ms = observations_tuple[0].timestamp_ms
    weighted_sum = 0.0
    total_weight = 0.0
    contributors = 0
    excluded: list[str] = []

    for observation in observations_tuple:
        correct_measurement_type = (
            observation.is_air_temperature
            if require_air_temperature
            else observation.is_surface_temperature
        )

        if (
            observation.timestamp_ms != timestamp_ms
            or not correct_measurement_type
            or not observation_is_usable(observation)
        ):
            excluded.append(observation.source_ref)
            continue

        weight = observation_weight(observation)
        weighted_sum += weight * observation.temperature_celsius
        total_weight += weight
        contributors += 1

    if contributors == 0 or total_weight <= EPSILON:
        return ThermalFusionResult(
            timestamp_ms=timestamp_ms,
            fused_temperature_celsius=None,
            uncertainty_proxy_celsius=None,
            contributing_sources=0,
            excluded_sources=tuple(excluded),
            review_required=True,
        )

    return ThermalFusionResult(
        timestamp_ms=timestamp_ms,
        fused_temperature_celsius=weighted_sum / total_weight,
        uncertainty_proxy_celsius=(1.0 / total_weight) ** 0.5,
        contributing_sources=contributors,
        excluded_sources=tuple(excluded),
        review_required=bool(excluded),
    )


def urban_heat_island_intensity(
    urban_air_temperature_celsius: float,
    reference_air_temperature_celsius: float,
) -> float:
    return urban_air_temperature_celsius - reference_air_temperature_celsius
