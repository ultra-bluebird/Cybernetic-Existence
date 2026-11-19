from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from statistics import fmean
from typing import Iterable


class TaskType(str, Enum):
    ROUTE_PLANNING = "ROUTE_PLANNING"
    MEMORY_RETRIEVAL = "MEMORY_RETRIEVAL"
    DOCUMENT_SUMMARIZATION = "DOCUMENT_SUMMARIZATION"
    FORM_COMPLETION = "FORM_COMPLETION"
    ACCESSIBILITY_NAVIGATION = "ACCESSIBILITY_NAVIGATION"
    REVIEW_QUEUE_ORGANIZATION = "REVIEW_QUEUE_ORGANIZATION"
    SCHEDULE_PLANNING = "SCHEDULE_PLANNING"
    CORRECTION_DRAFTING = "CORRECTION_DRAFTING"


class TaskSupportStatus(str, Enum):
    TASK_SUPPORT_AVAILABLE = "TASK_SUPPORT_AVAILABLE"
    TASK_SUPPORT_REVIEW_REQUIRED = "TASK_SUPPORT_REVIEW_REQUIRED"
    INSUFFICIENT_TASK_CONTEXT = "INSUFFICIENT_TASK_CONTEXT"


@dataclass(frozen=True)
class TaskSupportObservation:
    task_id: str
    task_type: TaskType
    duration_without_support_seconds: float
    duration_with_support_seconds: float
    completed_under_same_criteria: bool
    essential_accessibility_passed: bool
    correction_path_available: bool
    uncertainty: float
    normalized_error_or_rework: float
    host_declared_usefulness: float
    synthetic_or_voluntary_context: bool = True


@dataclass(frozen=True)
class TaskSupportResult:
    task_id: str
    task_type: TaskType
    status: TaskSupportStatus
    time_offload: float | None
    quality_gate: float | None
    advisory_support_value: float | None
    explanation: str


@dataclass(frozen=True)
class TaskTypeAggregate:
    task_type: TaskType
    valid_observation_count: int
    mean_advisory_support_value: float | None
    status: TaskSupportStatus


def _unit_interval(value: float, field: str) -> None:
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        raise ValueError(f"{field} must be a number in [0, 1].")
    if not 0.0 <= float(value) <= 1.0:
        raise ValueError(f"{field} must be a number in [0, 1].")


def _non_negative(value: float, field: str) -> None:
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        raise ValueError(f"{field} must be non-negative.")
    if float(value) < 0.0:
        raise ValueError(f"{field} must be non-negative.")


def evaluate_task_support(observation: TaskSupportObservation) -> TaskSupportResult:
    _non_negative(
        observation.duration_without_support_seconds,
        "duration_without_support_seconds",
    )
    _non_negative(
        observation.duration_with_support_seconds,
        "duration_with_support_seconds",
    )
    _unit_interval(observation.uncertainty, "uncertainty")
    _unit_interval(
        observation.normalized_error_or_rework,
        "normalized_error_or_rework",
    )
    _unit_interval(
        observation.host_declared_usefulness,
        "host_declared_usefulness",
    )

    if not observation.synthetic_or_voluntary_context:
        return TaskSupportResult(
            task_id=observation.task_id,
            task_type=observation.task_type,
            status=TaskSupportStatus.INSUFFICIENT_TASK_CONTEXT,
            time_offload=None,
            quality_gate=None,
            advisory_support_value=None,
            explanation=(
                "The record is not marked as synthetic or voluntarily supplied "
                "task context. No task-support comparison is available."
            ),
        )

    if observation.duration_without_support_seconds <= 0.0:
        return TaskSupportResult(
            task_id=observation.task_id,
            task_type=observation.task_type,
            status=TaskSupportStatus.INSUFFICIENT_TASK_CONTEXT,
            time_offload=None,
            quality_gate=None,
            advisory_support_value=None,
            explanation=(
                "The baseline task duration must be positive before a comparative "
                "time-support value can be calculated."
            ),
        )

    time_offload = (
        observation.duration_without_support_seconds
        - observation.duration_with_support_seconds
    ) / observation.duration_without_support_seconds

    bounded_time_offload = max(-1.0, min(1.0, time_offload))

    quality_gate = (
        float(observation.completed_under_same_criteria)
        * float(observation.essential_accessibility_passed)
        * float(observation.correction_path_available)
        * (1.0 - observation.uncertainty)
        * (1.0 - observation.normalized_error_or_rework)
    )

    if (
        not observation.completed_under_same_criteria
        or not observation.essential_accessibility_passed
        or not observation.correction_path_available
    ):
        return TaskSupportResult(
            task_id=observation.task_id,
            task_type=observation.task_type,
            status=TaskSupportStatus.TASK_SUPPORT_REVIEW_REQUIRED,
            time_offload=bounded_time_offload,
            quality_gate=quality_gate,
            advisory_support_value=None,
            explanation=(
                "An essential completion, accessibility, or correction condition "
                "failed. Time savings cannot compensate for this failure."
            ),
        )

    advisory_support_value = (
        bounded_time_offload
        * quality_gate
        * observation.host_declared_usefulness
    )

    return TaskSupportResult(
        task_id=observation.task_id,
        task_type=observation.task_type,
        status=TaskSupportStatus.TASK_SUPPORT_AVAILABLE,
        time_offload=bounded_time_offload,
        quality_gate=quality_gate,
        advisory_support_value=advisory_support_value,
        explanation=(
            "This value compares one stated task workflow under voluntary or "
            "synthetic conditions. It is not a measure of cognition, health, "
            "capability, identity, or credibility."
        ),
    )


def aggregate_task_types(
    observations: Iterable[TaskSupportObservation],
    minimum_group_size: int,
) -> tuple[TaskTypeAggregate, ...]:
    if minimum_group_size < 1:
        raise ValueError("minimum_group_size must be at least 1.")

    grouped: dict[TaskType, list[float]] = {task_type: [] for task_type in TaskType}

    for observation in observations:
        result = evaluate_task_support(observation)
        if (
            result.status == TaskSupportStatus.TASK_SUPPORT_AVAILABLE
            and result.advisory_support_value is not None
        ):
            grouped[observation.task_type].append(result.advisory_support_value)

    aggregates: list[TaskTypeAggregate] = []
    for task_type in TaskType:
        values = grouped[task_type]
        if len(values) < minimum_group_size:
            aggregates.append(
                TaskTypeAggregate(
                    task_type=task_type,
                    valid_observation_count=len(values),
                    mean_advisory_support_value=None,
                    status=TaskSupportStatus.INSUFFICIENT_TASK_CONTEXT,
                )
            )
            continue

        aggregates.append(
            TaskTypeAggregate(
                task_type=task_type,
                valid_observation_count=len(values),
                mean_advisory_support_value=fmean(values),
                status=TaskSupportStatus.TASK_SUPPORT_AVAILABLE,
            )
        )

    return tuple(aggregates)
