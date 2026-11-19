from __future__ import annotations

from dataclasses import dataclass
from math import sqrt
from statistics import mean
from typing import Iterable


@dataclass(frozen=True)
class BoardingEvent:
    scheduled_arrival_seconds: float
    baseline_dwell_seconds: float
    extra_time_requested: bool
    operational_variation_seconds: float = 0.0

    def __post_init__(self) -> None:
        if self.scheduled_arrival_seconds < 0.0:
            raise ValueError("scheduled_arrival_seconds must be non-negative.")

        if self.baseline_dwell_seconds < 0.0:
            raise ValueError("baseline_dwell_seconds must be non-negative.")


@dataclass(frozen=True)
class BoardingOutcome:
    scheduled_arrival_seconds: float
    actual_arrival_seconds: float
    dwell_seconds: float
    departure_seconds: float
    extra_time_active: bool


@dataclass(frozen=True)
class ServiceReliabilityReport:
    mean_headway_seconds: float
    headway_standard_deviation_seconds: float
    headway_coefficient_of_variation: float
    mean_dwell_seconds: float
    extra_time_activation_rate: float
    maximum_delay_seconds: float


def simulate_boarding(
    events: Iterable[BoardingEvent],
    extra_time_seconds: float = 10.0,
    recovery_rate: float = 0.20,
) -> tuple[BoardingOutcome, ...]:
    event_list = tuple(events)

    if extra_time_seconds < 0.0:
        raise ValueError("extra_time_seconds must be non-negative.")

    if not 0.0 <= recovery_rate <= 1.0:
        raise ValueError("recovery_rate must be within 0.0..=1.0.")

    outcomes: list[BoardingOutcome] = []
    carried_delay_seconds = 0.0

    for event in sorted(event_list, key=lambda item: item.scheduled_arrival_seconds):
        actual_arrival = event.scheduled_arrival_seconds + carried_delay_seconds
        extra_time = extra_time_seconds if event.extra_time_requested else 0.0
        dwell = max(
            0.0,
            event.baseline_dwell_seconds
            + extra_time
            + event.operational_variation_seconds,
        )
        departure = actual_arrival + dwell
        carried_delay_seconds = max(
            0.0,
            carried_delay_seconds * (1.0 - recovery_rate)
            + event.operational_variation_seconds
            + extra_time,
        )

        outcomes.append(
            BoardingOutcome(
                scheduled_arrival_seconds=event.scheduled_arrival_seconds,
                actual_arrival_seconds=actual_arrival,
                dwell_seconds=dwell,
                departure_seconds=departure,
                extra_time_active=event.extra_time_requested,
            )
        )

    return tuple(outcomes)


def service_reliability_report(
    outcomes: Iterable[BoardingOutcome],
    scheduled_headway_seconds: float,
) -> ServiceReliabilityReport:
    values = tuple(outcomes)

    if not values:
        raise ValueError("At least one boarding outcome is required.")

    if scheduled_headway_seconds <= 0.0:
        raise ValueError("scheduled_headway_seconds must be positive.")

    arrival_times = [outcome.actual_arrival_seconds for outcome in values]
    headways = [
        later - earlier
        for earlier, later in zip(arrival_times, arrival_times[1:])
    ]

    mean_headway = mean(headways) if headways else scheduled_headway_seconds
    headway_standard_deviation = _sample_standard_deviation(headways)
    headway_coefficient_of_variation = (
        headway_standard_deviation / mean_headway
        if mean_headway > 0.0
        else 0.0
    )

    delays = [
        outcome.actual_arrival_seconds - outcome.scheduled_arrival_seconds
        for outcome in values
    ]

    return ServiceReliabilityReport(
        mean_headway_seconds=mean_headway,
        headway_standard_deviation_seconds=headway_standard_deviation,
        headway_coefficient_of_variation=headway_coefficient_of_variation,
        mean_dwell_seconds=mean(outcome.dwell_seconds for outcome in values),
        extra_time_activation_rate=(
            sum(outcome.extra_time_active for outcome in values) / len(values)
        ),
        maximum_delay_seconds=max(delays),
    )


def within_headway_reliability_corridor(
    report: ServiceReliabilityReport,
    maximum_coefficient_of_variation: float,
) -> bool:
    if maximum_coefficient_of_variation < 0.0:
        raise ValueError(
            "maximum_coefficient_of_variation must be non-negative."
        )

    return (
        report.headway_coefficient_of_variation
        <= maximum_coefficient_of_variation
    )


def _sample_standard_deviation(values: list[float]) -> float:
    if len(values) < 2:
        return 0.0

    average = mean(values)
    variance = sum((value - average) ** 2 for value in values) / (len(values) - 1)
    return sqrt(variance)
