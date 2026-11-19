from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from enum import Enum
from typing import Iterable
import math


class MeasurementStatus(str, Enum):
    ACCEPTED = "accepted"
    SENSOR_DISAGREEMENT = "sensor_disagreement"
    LOW_POWER = "low_power"
    INVALID = "invalid"


@dataclass(frozen=True)
class SensorMeasurement:
    asset_public_code: str
    sensor_channel: str
    observed_at: datetime
    value: float
    uncertainty: float
    quality: float
    energy_fraction: float
    message_integrity_valid: bool


@dataclass(frozen=True)
class AggregatedMeasurement:
    asset_public_code: str
    sensor_channel: str
    fused_value: float | None
    fused_uncertainty: float | None
    status: MeasurementStatus
    reason: str


def aggregate_measurements(
    measurements: Iterable[SensorMeasurement],
    maximum_disagreement: float,
    minimum_energy_fraction: float,
) -> AggregatedMeasurement:
    measurement_list = list(measurements)

    if not measurement_list:
        raise ValueError("At least one measurement is required.")
    if not math.isfinite(maximum_disagreement) or maximum_disagreement <= 0.0:
        raise ValueError("maximum_disagreement must be finite and greater than zero.")
    if (
        not math.isfinite(minimum_energy_fraction)
        or not 0.0 <= minimum_energy_fraction <= 1.0
    ):
        raise ValueError("minimum_energy_fraction must be within [0, 1].")

    asset_code = measurement_list[0].asset_public_code
    channel = measurement_list[0].sensor_channel
    accepted: list[tuple[SensorMeasurement, float]] = []

    for measurement in measurement_list:
        _validate_measurement(measurement)

        if measurement.asset_public_code != asset_code:
            raise ValueError("All measurements must belong to the same public asset.")
        if measurement.sensor_channel != channel:
            raise ValueError("All measurements must use the same sensor channel.")

        if not measurement.message_integrity_valid:
            continue

        if measurement.energy_fraction < minimum_energy_fraction:
            continue

        weight = measurement.quality / max(measurement.uncertainty**2, 1e-12)
        accepted.append((measurement, weight))

    if not accepted:
        return AggregatedMeasurement(
            asset_public_code=asset_code,
            sensor_channel=channel,
            fused_value=None,
            fused_uncertainty=None,
            status=MeasurementStatus.LOW_POWER,
            reason=(
                "No integrity-valid measurement with sufficient available energy "
                "was available for aggregation."
            ),
        )

    total_weight = sum(weight for _, weight in accepted)
    fused_value = sum(
        measurement.value * weight
        for measurement, weight in accepted
    ) / total_weight

    fused_uncertainty = math.sqrt(1.0 / total_weight)

    disagreement = max(
        abs(measurement.value - fused_value)
        for measurement, _ in accepted
    )

    if disagreement > maximum_disagreement:
        return AggregatedMeasurement(
            asset_public_code=asset_code,
            sensor_channel=channel,
            fused_value=fused_value,
            fused_uncertainty=fused_uncertainty,
            status=MeasurementStatus.SENSOR_DISAGREEMENT,
            reason=(
                "Redundant sensor disagreement exceeds the configured tolerance; "
                "route the result to maintenance review rather than making a "
                "structural or environmental condition claim."
            ),
        )

    return AggregatedMeasurement(
        asset_public_code=asset_code,
        sensor_channel=channel,
        fused_value=fused_value,
        fused_uncertainty=fused_uncertainty,
        status=MeasurementStatus.ACCEPTED,
        reason=(
            "Redundant, integrity-valid, energy-qualified measurements were fused "
            "for advisory infrastructure monitoring."
        ),
    )


def _validate_measurement(measurement: SensorMeasurement) -> None:
    if not measurement.asset_public_code.strip():
        raise ValueError("asset_public_code is required.")
    if not measurement.sensor_channel.strip():
        raise ValueError("sensor_channel is required.")
    if measurement.observed_at.tzinfo is None:
        raise ValueError("observed_at must be timezone-aware.")
    measurement.observed_at.astimezone(timezone.utc)

    for name, value in {
        "value": measurement.value,
        "uncertainty": measurement.uncertainty,
        "quality": measurement.quality,
        "energy_fraction": measurement.energy_fraction,
    }.items():
        if not math.isfinite(value):
            raise ValueError(f"{name} must be finite.")

    if measurement.uncertainty < 0.0:
        raise ValueError("uncertainty must be non-negative.")

    if not 0.0 <= measurement.quality <= 1.0:
        raise ValueError("quality must be within [0, 1].")

    if not 0.0 <= measurement.energy_fraction <= 1.0:
        raise ValueError("energy_fraction must be within [0, 1].")
