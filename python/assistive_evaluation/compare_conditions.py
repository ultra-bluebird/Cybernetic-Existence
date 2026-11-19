from __future__ import annotations

from dataclasses import dataclass
from math import isfinite


@dataclass(frozen=True)
class ConditionMetrics:
    valid_trials: int
    successful_trials: int
    completion_time_millis: float
    object_drops: int
    excess_force_events: int
    correction_count: int
    workload_score: float
    embodiment_score: float
    agency_preserved: bool


@dataclass(frozen=True)
class ConditionComparison:
    success_rate_delta: float
    completion_time_delta_millis: float
    drop_rate_delta: float
    excess_force_rate_delta: float
    correction_rate_delta: float
    workload_delta: float
    embodiment_delta: float
    closed_loop_benefit_supported: bool
    reasons: tuple[str, ...]


class EvaluationValidationError(ValueError):
    pass


def compare_open_and_closed_loop(
    open_loop: ConditionMetrics,
    closed_loop: ConditionMetrics,
    maximum_workload_increase: float,
) -> ConditionComparison:
    _validate_metrics(open_loop)
    _validate_metrics(closed_loop)

    if (
        not isfinite(maximum_workload_increase)
        or maximum_workload_increase < 0
        or maximum_workload_increase > 1
    ):
        raise EvaluationValidationError(
            "maximum_workload_increase must be finite and in [0, 1]"
        )

    success_rate_delta = _rate(
        closed_loop.successful_trials,
        closed_loop.valid_trials,
    ) - _rate(open_loop.successful_trials, open_loop.valid_trials)

    completion_time_delta_millis = (
        closed_loop.completion_time_millis - open_loop.completion_time_millis
    )

    drop_rate_delta = _rate(
        closed_loop.object_drops,
        closed_loop.valid_trials,
    ) - _rate(open_loop.object_drops, open_loop.valid_trials)

    excess_force_rate_delta = _rate(
        closed_loop.excess_force_events,
        closed_loop.valid_trials,
    ) - _rate(open_loop.excess_force_events, open_loop.valid_trials)

    correction_rate_delta = _rate(
        closed_loop.correction_count,
        closed_loop.valid_trials,
    ) - _rate(open_loop.correction_count, open_loop.valid_trials)

    workload_delta = closed_loop.workload_score - open_loop.workload_score
    embodiment_delta = closed_loop.embodiment_score - open_loop.embodiment_score

    reasons: list[str] = []

    if not closed_loop.agency_preserved:
        reasons.append("closed-loop condition did not preserve reported agency")

    if success_rate_delta < 0:
        reasons.append("closed-loop condition reduced task success rate")

    if drop_rate_delta > 0:
        reasons.append("closed-loop condition increased object-drop rate")

    if excess_force_rate_delta > 0:
        reasons.append("closed-loop condition increased excess-force event rate")

    if correction_rate_delta > 0:
        reasons.append("closed-loop condition increased correction burden")

    if workload_delta > maximum_workload_increase:
        reasons.append("closed-loop workload increase exceeded the declared limit")

    return ConditionComparison(
        success_rate_delta=success_rate_delta,
        completion_time_delta_millis=completion_time_delta_millis,
        drop_rate_delta=drop_rate_delta,
        excess_force_rate_delta=excess_force_rate_delta,
        correction_rate_delta=correction_rate_delta,
        workload_delta=workload_delta,
        embodiment_delta=embodiment_delta,
        closed_loop_benefit_supported=not reasons,
        reasons=tuple(reasons),
    )


def _rate(numerator: int, denominator: int) -> float:
    if denominator == 0:
        return 0.0

    return numerator / denominator


def _validate_metrics(metrics: ConditionMetrics) -> None:
    for value in (
        metrics.valid_trials,
        metrics.successful_trials,
        metrics.object_drops,
        metrics.excess_force_events,
        metrics.correction_count,
    ):
        if not isinstance(value, int) or isinstance(value, bool) or value < 0:
            raise EvaluationValidationError("count values must be non-negative integers")

    if metrics.successful_trials > metrics.valid_trials:
        raise EvaluationValidationError(
            "successful_trials must not exceed valid_trials"
        )

    for value in (
        metrics.completion_time_millis,
        metrics.workload_score,
        metrics.embodiment_score,
    ):
        if not isfinite(value) or value < 0:
            raise EvaluationValidationError("metric values must be finite and non-negative")

    if metrics.workload_score > 1 or metrics.embodiment_score > 1:
        raise EvaluationValidationError(
            "workload_score and embodiment_score must be in [0, 1]"
        )
