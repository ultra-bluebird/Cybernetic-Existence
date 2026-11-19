from dataclasses import dataclass
from math import isfinite
from typing import Iterable


EPSILON = 1e-12


@dataclass(frozen=True)
class CorridorReading:
    sensor_ref: str
    timestamp_ms: int
    reading: float
    expected_reading: float
    uncertainty: float
    drift_tolerance: float
    quality_factor: float
    is_stale: bool
    is_out_of_range: bool
    has_reference_mismatch: bool


@dataclass(frozen=True)
class AlignedCorridorEstimate:
    timestamp_ms: int
    estimated_reading: float | None
    contributing_sensors: int
    excluded_sensors: tuple[str, ...]
    uncertainty_proxy: float | None
    review_required: bool


def normalized_drift(reading: CorridorReading) -> float:
    tolerance = max(reading.drift_tolerance, EPSILON)
    return abs(reading.reading - reading.expected_reading) / tolerance


def usable_reading(reading: CorridorReading) -> bool:
    finite_values = (
        reading.reading,
        reading.expected_reading,
        reading.uncertainty,
        reading.drift_tolerance,
        reading.quality_factor,
    )

    return (
        all(isfinite(value) for value in finite_values)
        and reading.uncertainty > 0
        and reading.drift_tolerance > 0
        and 0.0 <= reading.quality_factor <= 1.0
        and not reading.is_stale
        and not reading.is_out_of_range
        and not reading.has_reference_mismatch
        and normalized_drift(reading) <= 1.0
    )


def alignment_weight(reading: CorridorReading) -> float:
    drift_component = normalized_drift(reading) * reading.drift_tolerance
    denominator = max(
        (reading.uncertainty * reading.uncertainty)
        + (drift_component * drift_component),
        EPSILON,
    )
    return reading.quality_factor / denominator


def align_corridor_readings(
    readings: Iterable[CorridorReading],
) -> AlignedCorridorEstimate:
    readings_tuple = tuple(readings)

    if not readings_tuple:
        return AlignedCorridorEstimate(
            timestamp_ms=0,
            estimated_reading=None,
            contributing_sensors=0,
            excluded_sensors=(),
            uncertainty_proxy=None,
            review_required=True,
        )

    timestamp_ms = readings_tuple[0].timestamp_ms
    excluded: list[str] = []
    weighted_sum = 0.0
    total_weight = 0.0
    contributors = 0

    for reading in readings_tuple:
        if reading.timestamp_ms != timestamp_ms or not usable_reading(reading):
            excluded.append(reading.sensor_ref)
            continue

        weight = alignment_weight(reading)
        weighted_sum += weight * reading.reading
        total_weight += weight
        contributors += 1

    if contributors == 0 or total_weight <= EPSILON:
        return AlignedCorridorEstimate(
            timestamp_ms=timestamp_ms,
            estimated_reading=None,
            contributing_sensors=0,
            excluded_sensors=tuple(excluded),
            uncertainty_proxy=None,
            review_required=True,
        )

    return AlignedCorridorEstimate(
        timestamp_ms=timestamp_ms,
        estimated_reading=weighted_sum / total_weight,
        contributing_sensors=contributors,
        excluded_sensors=tuple(excluded),
        uncertainty_proxy=(1.0 / total_weight) ** 0.5,
        review_required=bool(excluded),
    )
