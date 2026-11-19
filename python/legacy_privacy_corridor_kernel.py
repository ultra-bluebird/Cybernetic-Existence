from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from math import floor
from typing import Iterable, Mapping


@dataclass(frozen=True)
class LegacySafetyEnvelope:
    maximum_force_newtons: float
    maximum_speed_meters_per_second: float
    fail_safe_mode: str
    independent_manual_override: bool
    obstruction_protection: bool
    emergency_stop_available: bool


@dataclass(frozen=True)
class SmartSafetyEnvelope:
    maximum_force_newtons: float
    maximum_speed_meters_per_second: float
    fail_safe_mode: str
    independent_manual_override: bool
    obstruction_protection: bool
    emergency_stop_available: bool


@dataclass(frozen=True)
class SafetyMappingResult:
    certified_equivalent: bool
    unmet_requirements: tuple[str, ...]


@dataclass(frozen=True)
class AggregatePassage:
    corridor_cell: str
    time_bucket_start_utc: datetime
    passage_count: int


@dataclass(frozen=True)
class VoluntaryEnvironmentalContribution:
    consent_active: bool
    location_x_meters: float
    location_y_meters: float
    observed_at_utc: datetime
    temperature_celsius: float | None
    humidity_percent: float | None
    air_quality_index: float | None
    noise_db_a: float | None


@dataclass(frozen=True)
class CoarseEnvironmentalAggregate:
    spatial_cell: str
    time_bucket_start_utc: datetime
    sample_count: int
    mean_temperature_celsius: float | None
    mean_humidity_percent: float | None
    mean_air_quality_index: float | None
    mean_noise_db_a: float | None


MINIMUM_TRAFFIC_BUCKET_SECONDS = 15 * 60
MINIMUM_TRAFFIC_CELL_METERS = 50
MINIMUM_CONTRIBUTION_BUCKET_SECONDS = 15 * 60
MINIMUM_CONTRIBUTION_CELL_METERS = 100


def map_legacy_safety_features(
    legacy: LegacySafetyEnvelope,
    smart: SmartSafetyEnvelope,
) -> SafetyMappingResult:
    unmet: list[str] = []

    if smart.maximum_force_newtons > legacy.maximum_force_newtons:
        unmet.append("smart force limit exceeds legacy force limit")

    if smart.maximum_speed_meters_per_second > legacy.maximum_speed_meters_per_second:
        unmet.append("smart speed limit exceeds legacy speed limit")

    if smart.fail_safe_mode != legacy.fail_safe_mode:
        unmet.append("smart fail-safe mode differs from legacy fail-safe mode")

    if legacy.independent_manual_override and not smart.independent_manual_override:
        unmet.append("independent manual override is not preserved")

    if legacy.obstruction_protection and not smart.obstruction_protection:
        unmet.append("obstruction protection is not preserved")

    if legacy.emergency_stop_available and not smart.emergency_stop_available:
        unmet.append("emergency stop is not preserved")

    return SafetyMappingResult(
        certified_equivalent=not unmet,
        unmet_requirements=tuple(unmet),
    )


def time_bucket_start(
    timestamp: datetime,
    bucket_seconds: int,
) -> datetime:
    if timestamp.tzinfo is None:
        raise ValueError("Timestamp must include timezone information.")

    if bucket_seconds <= 0:
        raise ValueError("Bucket duration must be positive.")

    timestamp_utc = timestamp.astimezone(timezone.utc)
    epoch_seconds = timestamp_utc.timestamp()
    bucket_epoch = floor(epoch_seconds / bucket_seconds) * bucket_seconds
    return datetime.fromtimestamp(bucket_epoch, tz=timezone.utc)


def spatial_cell(
    x_meters: float,
    y_meters: float,
    cell_size_meters: int,
) -> str:
    if cell_size_meters <= 0:
        raise ValueError("Cell size must be positive.")

    cell_x = floor(x_meters / cell_size_meters)
    cell_y = floor(y_meters / cell_size_meters)
    return f"{cell_x}:{cell_y}:{cell_size_meters}m"


def aggregate_traffic_passages(
    raw_passage_events: Iterable[tuple[float, float, datetime]],
    bucket_seconds: int = MINIMUM_TRAFFIC_BUCKET_SECONDS,
    cell_size_meters: int = MINIMUM_TRAFFIC_CELL_METERS,
) -> tuple[AggregatePassage, ...]:
    if bucket_seconds < MINIMUM_TRAFFIC_BUCKET_SECONDS:
        raise ValueError("Traffic aggregation windows must be at least 15 minutes.")

    if cell_size_meters < MINIMUM_TRAFFIC_CELL_METERS:
        raise ValueError("Traffic spatial cells must be at least 50 meters.")

    counts: dict[tuple[str, datetime], int] = {}

    for x_meters, y_meters, observed_at in raw_passage_events:
        key = (
            spatial_cell(x_meters, y_meters, cell_size_meters),
            time_bucket_start(observed_at, bucket_seconds),
        )
        counts[key] = counts.get(key, 0) + 1

    return tuple(
        AggregatePassage(
            corridor_cell=cell,
            time_bucket_start_utc=bucket,
            passage_count=count,
        )
        for (cell, bucket), count in sorted(counts.items())
    )


def aggregate_voluntary_environmental_contributions(
    contributions: Iterable[VoluntaryEnvironmentalContribution],
    bucket_seconds: int = MINIMUM_CONTRIBUTION_BUCKET_SECONDS,
    cell_size_meters: int = MINIMUM_CONTRIBUTION_CELL_METERS,
) -> tuple[CoarseEnvironmentalAggregate, ...]:
    if bucket_seconds < MINIMUM_CONTRIBUTION_BUCKET_SECONDS:
        raise ValueError("Contribution windows must be at least 15 minutes.")

    if cell_size_meters < MINIMUM_CONTRIBUTION_CELL_METERS:
        raise ValueError("Contribution cells must be at least 100 meters.")

    grouped: dict[tuple[str, datetime], list[VoluntaryEnvironmentalContribution]] = {}

    for contribution in contributions:
        if not contribution.consent_active:
            continue

        key = (
            spatial_cell(
                contribution.location_x_meters,
                contribution.location_y_meters,
                cell_size_meters,
            ),
            time_bucket_start(contribution.observed_at_utc, bucket_seconds),
        )
        grouped.setdefault(key, []).append(contribution)

    def average(values: list[float | None]) -> float | None:
        present = [value for value in values if value is not None]
        return sum(present) / len(present) if present else None

    results = []

    for (cell, bucket), entries in sorted(grouped.items()):
        results.append(
            CoarseEnvironmentalAggregate(
                spatial_cell=cell,
                time_bucket_start_utc=bucket,
                sample_count=len(entries),
                mean_temperature_celsius=average(
                    [entry.temperature_celsius for entry in entries]
                ),
                mean_humidity_percent=average(
                    [entry.humidity_percent for entry in entries]
                ),
                mean_air_quality_index=average(
                    [entry.air_quality_index for entry in entries]
                ),
                mean_noise_db_a=average(
                    [entry.noise_db_a for entry in entries]
                ),
            )
        )

    return tuple(results)


def eligible_for_corridor_timing_optimization(
    traffic_bucket_seconds: int,
    traffic_cell_meters: int,
    access_guarantees_verified: bool,
    individual_trajectory_data_present: bool,
    individual_velocity_data_present: bool,
    individual_dwell_data_present: bool,
) -> bool:
    return (
        traffic_bucket_seconds >= MINIMUM_TRAFFIC_BUCKET_SECONDS
        and traffic_cell_meters >= MINIMUM_TRAFFIC_CELL_METERS
        and access_guarantees_verified
        and not individual_trajectory_data_present
        and not individual_velocity_data_present
        and not individual_dwell_data_present
    )
