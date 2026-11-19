from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable
import math


@dataclass(frozen=True)
class AuditRecord:
    decision_value: int
    counterfactual_decision_value: int
    group_label: str
    is_reference_group: bool
    human_overridden: bool
    appeal_completed: bool
    appeal_corrected: bool


@dataclass(frozen=True)
class GroupAuditResult:
    group_label: str
    record_count: int
    decision_rate: float
    disparate_impact_ratio: float | None
    counterfactual_difference: float
    human_override_rate: float
    appeal_correction_rate: float
    requires_human_review: bool
    reasons: tuple[str, ...]


@dataclass(frozen=True)
class AuditThresholds:
    minimum_group_size: int
    minimum_disparate_impact_ratio: float
    maximum_counterfactual_difference: float
    maximum_override_rate: float
    maximum_appeal_correction_rate: float


def audit_month(
    records: Iterable[AuditRecord],
    thresholds: AuditThresholds,
) -> list[GroupAuditResult]:
    record_list = list(records)
    _validate_thresholds(thresholds)
    _validate_records(record_list)

    reference_records = [
        record for record in record_list
        if record.is_reference_group
    ]

    reference_decision_rate = _mean(
        [record.decision_value for record in reference_records]
    )

    grouped: dict[str, list[AuditRecord]] = {}
    for record in record_list:
        grouped.setdefault(record.group_label, []).append(record)

    results: list[GroupAuditResult] = []

    for group_label, group_records in sorted(grouped.items()):
        if len(group_records) < thresholds.minimum_group_size:
            results.append(
                GroupAuditResult(
                    group_label=group_label,
                    record_count=len(group_records),
                    decision_rate=0.0,
                    disparate_impact_ratio=None,
                    counterfactual_difference=0.0,
                    human_override_rate=0.0,
                    appeal_correction_rate=0.0,
                    requires_human_review=True,
                    reasons=(
                        "Aggregate audit output is suppressed because the minimum "
                        "group-size threshold is not met.",
                    ),
                )
            )
            continue

        decision_rate = _mean(
            [record.decision_value for record in group_records]
        )

        if reference_decision_rate == 0.0:
            disparate_impact_ratio = None
        else:
            disparate_impact_ratio = decision_rate / reference_decision_rate

        counterfactual_difference = _mean(
            [
                abs(
                    record.decision_value
                    - record.counterfactual_decision_value
                )
                for record in group_records
            ]
        )

        human_override_rate = _mean(
            [int(record.human_overridden) for record in group_records]
        )

        completed_appeals = [
            record for record in group_records
            if record.appeal_completed
        ]

        appeal_correction_rate = (
            _mean(
                [
                    int(record.appeal_corrected)
                    for record in completed_appeals
                ]
            )
            if completed_appeals
            else 0.0
        )

        reasons: list[str] = []

        if (
            disparate_impact_ratio is not None
            and disparate_impact_ratio
            < thresholds.minimum_disparate_impact_ratio
        ):
            reasons.append(
                "Disparate-impact ratio is below the configured review threshold."
            )

        if (
            counterfactual_difference
            > thresholds.maximum_counterfactual_difference
        ):
            reasons.append(
                "Counterfactual decision difference exceeds the review threshold."
            )

        if human_override_rate > thresholds.maximum_override_rate:
            reasons.append(
                "Human override rate exceeds the review threshold."
            )

        if (
            appeal_correction_rate
            > thresholds.maximum_appeal_correction_rate
        ):
            reasons.append(
                "Appeal correction rate exceeds the review threshold."
            )

        results.append(
            GroupAuditResult(
                group_label=group_label,
                record_count=len(group_records),
                decision_rate=decision_rate,
                disparate_impact_ratio=disparate_impact_ratio,
                counterfactual_difference=counterfactual_difference,
                human_override_rate=human_override_rate,
                appeal_correction_rate=appeal_correction_rate,
                requires_human_review=bool(reasons),
                reasons=tuple(reasons) or (
                    "No configured aggregate review threshold was exceeded.",
                ),
            )
        )

    return results


def _validate_thresholds(thresholds: AuditThresholds) -> None:
    if thresholds.minimum_group_size < 1:
        raise ValueError("minimum_group_size must be at least one.")

    for name, value in {
        "minimum_disparate_impact_ratio": (
            thresholds.minimum_disparate_impact_ratio
        ),
        "maximum_counterfactual_difference": (
            thresholds.maximum_counterfactual_difference
        ),
        "maximum_override_rate": thresholds.maximum_override_rate,
        "maximum_appeal_correction_rate": (
            thresholds.maximum_appeal_correction_rate
        ),
    }.items():
        if not math.isfinite(value) or not 0.0 <= value <= 1.0:
            raise ValueError(f"{name} must be finite and within [0, 1].")


def _validate_records(records: list[AuditRecord]) -> None:
    if not records:
        raise ValueError("At least one audit record is required.")

    if not any(record.is_reference_group for record in records):
        raise ValueError("At least one reference-group record is required.")

    for record in records:
        if record.decision_value not in (0, 1):
            raise ValueError("decision_value must be either zero or one.")
        if record.counterfactual_decision_value not in (0, 1):
            raise ValueError(
                "counterfactual_decision_value must be either zero or one."
            )
        if not record.group_label.strip():
            raise ValueError("group_label is required.")


def _mean(values: list[int]) -> float:
    if not values:
        return 0.0
    return sum(values) / len(values)
