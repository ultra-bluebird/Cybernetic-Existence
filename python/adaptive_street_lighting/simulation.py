from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable


@dataclass(frozen=True)
class LightingInterval:
    duration_seconds: float
    actual_power_w: float
    reference_power_w: float
    minimum_illuminance_lux: float
    measured_illuminance_lux: float
    average_illuminance_lux: float
    sensor_fault: bool
    raw_presence_data_retained: bool

    def __post_init__(self) -> None:
        for name, value in (
            ("duration_seconds", self.duration_seconds),
            ("actual_power_w", self.actual_power_w),
            ("reference_power_w", self.reference_power_w),
            ("minimum_illuminance_lux", self.minimum_illuminance_lux),
            ("measured_illuminance_lux", self.measured_illuminance_lux),
            ("average_illuminance_lux", self.average_illuminance_lux),
        ):
            if value < 0.0:
                raise ValueError(f"{name} must be non-negative.")

        if self.average_illuminance_lux == 0.0:
            raise ValueError("average_illuminance_lux must be greater than zero.")


@dataclass(frozen=True)
class LightingReport:
    reference_energy_wh: float
    actual_energy_wh: float
    energy_saved_wh: float
    minimum_light_compliance: float
    raw_presence_retention_rate: float
    fail_safe_compliance: float


def energy_saved_wh(intervals: Iterable[LightingInterval]) -> float:
    return sum(
        (interval.reference_power_w - interval.actual_power_w)
        * interval.duration_seconds
        / 3600.0
        for interval in intervals
    )


def reference_energy_wh(intervals: Iterable[LightingInterval]) -> float:
    return sum(
        interval.reference_power_w * interval.duration_seconds / 3600.0
        for interval in intervals
    )


def actual_energy_wh(intervals: Iterable[LightingInterval]) -> float:
    return sum(
        interval.actual_power_w * interval.duration_seconds / 3600.0
        for interval in intervals
    )


def minimum_light_compliance(intervals: Iterable[LightingInterval]) -> float:
    values = list(intervals)

    if not values:
        raise ValueError("At least one lighting interval is required.")

    compliant = sum(
        interval.measured_illuminance_lux >= interval.minimum_illuminance_lux
        for interval in values
    )

    return compliant / len(values)


def raw_presence_retention_rate(intervals: Iterable[LightingInterval]) -> float:
    values = list(intervals)

    if not values:
        raise ValueError("At least one lighting interval is required.")

    retained = sum(interval.raw_presence_data_retained for interval in values)
    return retained / len(values)


def fail_safe_compliance(intervals: Iterable[LightingInterval]) -> float:
    fault_intervals = [interval for interval in intervals if interval.sensor_fault]

    if not fault_intervals:
        return 1.0

    compliant_fault_intervals = sum(
        interval.measured_illuminance_lux >= interval.minimum_illuminance_lux
        for interval in fault_intervals
    )

    return compliant_fault_intervals / len(fault_intervals)


def build_report(intervals: Iterable[LightingInterval]) -> LightingReport:
    values = list(intervals)

    if not values:
        raise ValueError("At least one lighting interval is required.")

    return LightingReport(
        reference_energy_wh=reference_energy_wh(values),
        actual_energy_wh=actual_energy_wh(values),
        energy_saved_wh=energy_saved_wh(values),
        minimum_light_compliance=minimum_light_compliance(values),
        raw_presence_retention_rate=raw_presence_retention_rate(values),
        fail_safe_compliance=fail_safe_compliance(values),
    )
