from __future__ import annotations

from dataclasses import dataclass
from statistics import median
from typing import Iterable


@dataclass(frozen=True)
class AccessibilityDividendInput:
    completion_before: float
    completion_after: float
    barrier_rate_before: float
    barrier_rate_after: float
    median_repair_before_days: float
    median_repair_after_days: float

    def __post_init__(self) -> None:
        for name, value in (
            ("completion_before", self.completion_before),
            ("completion_after", self.completion_after),
            ("barrier_rate_before", self.barrier_rate_before),
            ("barrier_rate_after", self.barrier_rate_after),
        ):
            _unit_interval(name, value)

        if self.median_repair_before_days < 0.0:
            raise ValueError("median_repair_before_days must be non-negative.")

        if self.median_repair_after_days < 0.0:
            raise ValueError("median_repair_after_days must be non-negative.")


@dataclass(frozen=True)
class InteractionResult:
    mode: str
    successful: bool

    def __post_init__(self) -> None:
        if not self.mode.strip():
            raise ValueError("mode must not be empty.")


@dataclass(frozen=True)
class BarrierLifecycle:
    reported_at_hours: float
    acknowledged_at_hours: float
    mitigated_at_hours: float | None
    completed_at_hours: float | None
    verified_at_hours: float | None

    def __post_init__(self) -> None:
        if self.reported_at_hours < 0.0:
            raise ValueError("reported_at_hours must be non-negative.")

        for name, value in (
            ("acknowledged_at_hours", self.acknowledged_at_hours),
            ("mitigated_at_hours", self.mitigated_at_hours),
            ("completed_at_hours", self.completed_at_hours),
            ("verified_at_hours", self.verified_at_hours),
        ):
            if value is not None and value < self.reported_at_hours:
                raise ValueError(f"{name} must not precede reported_at_hours.")


def accessibility_dividend(
    value: AccessibilityDividendInput,
    completion_weight: float = 0.40,
    barrier_weight: float = 0.35,
    repair_weight: float = 0.25,
) -> float:
    _nonnegative("completion_weight", completion_weight)
    _nonnegative("barrier_weight", barrier_weight)
    _nonnegative("repair_weight", repair_weight)

    if abs(completion_weight + barrier_weight + repair_weight - 1.0) > 1e-9:
        raise ValueError("Accessibility dividend weights must sum to 1.0.")

    completion_gain = value.completion_after - value.completion_before
    barrier_reduction = value.barrier_rate_before - value.barrier_rate_after

    if value.median_repair_before_days == 0.0:
        repair_improvement = 0.0
    else:
        repair_improvement = (
            value.median_repair_before_days - value.median_repair_after_days
        ) / value.median_repair_before_days

    return (
        completion_weight * completion_gain
        + barrier_weight * barrier_reduction
        + repair_weight * repair_improvement
    )


def no_disclosure_usability(
    completed_without_disclosure: int,
    total_core_tasks: int,
) -> float:
    if completed_without_disclosure < 0 or total_core_tasks <= 0:
        raise ValueError("Task counts must be non-negative and total must be positive.")

    if completed_without_disclosure > total_core_tasks:
        raise ValueError(
            "completed_without_disclosure cannot exceed total_core_tasks."
        )

    return completed_without_disclosure / total_core_tasks


def interaction_completion(results: Iterable[InteractionResult], mode: str) -> float:
    if not mode.strip():
        raise ValueError("mode must not be empty.")

    relevant = [result for result in results if result.mode == mode]

    if not relevant:
        raise ValueError("At least one result is required for the requested mode.")

    return sum(result.successful for result in relevant) / len(relevant)


def parity_gap(
    results: Iterable[InteractionResult],
    first_mode: str,
    second_mode: str,
) -> float:
    return abs(
        interaction_completion(results, first_mode)
        - interaction_completion(results, second_mode)
    )


def small_cell_publishable(count: int, threshold: int) -> bool:
    if count < 0:
        raise ValueError("count must be non-negative.")

    if threshold <= 0:
        raise ValueError("threshold must be positive.")

    return count >= threshold


def immediate_mitigation_coverage(
    barriers: Iterable[BarrierLifecycle],
) -> float:
    values = list(barriers)

    if not values:
        raise ValueError("At least one barrier lifecycle is required.")

    return sum(item.mitigated_at_hours is not None for item in values) / len(values)


def verified_remediation_coverage(
    barriers: Iterable[BarrierLifecycle],
) -> float:
    values = list(barriers)

    if not values:
        raise ValueError("At least one barrier lifecycle is required.")

    return sum(item.verified_at_hours is not None for item in values) / len(values)


def median_verified_repair_hours(
    barriers: Iterable[BarrierLifecycle],
) -> float:
    repair_times = [
        item.verified_at_hours - item.reported_at_hours
        for item in barriers
        if item.verified_at_hours is not None
    ]

    if not repair_times:
        raise ValueError("At least one verified repair is required.")

    return median(repair_times)


def repair_first_score(
    mitigation_coverage: float,
    verified_coverage: float,
    median_repair_hours: float,
    target_repair_hours: float,
) -> float:
    _unit_interval("mitigation_coverage", mitigation_coverage)
    _unit_interval("verified_coverage", verified_coverage)

    if median_repair_hours < 0.0:
        raise ValueError("median_repair_hours must be non-negative.")

    if target_repair_hours <= 0.0:
        raise ValueError("target_repair_hours must be positive.")

    timeliness = 1.0 - min(median_repair_hours / target_repair_hours, 1.0)

    return (
        0.35 * mitigation_coverage
        + 0.35 * verified_coverage
        + 0.30 * timeliness
    )


def _unit_interval(name: str, value: float) -> None:
    if not 0.0 <= value <= 1.0:
        raise ValueError(f"{name} must be within 0.0..=1.0.")


def _nonnegative(name: str, value: float) -> None:
    if value < 0.0:
        raise ValueError(f"{name} must be non-negative.")
