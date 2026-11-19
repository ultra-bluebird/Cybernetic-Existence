from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from enum import Enum
from typing import Iterable
import math


class Outcome(str, Enum):
    RECOGNIZED = "recognized"
    NOT_RECOGNIZED = "not_recognized"
    CORRECTED = "corrected"
    WITHDRAWN = "withdrawn"
    UNDER_REVIEW = "under_review"


@dataclass(frozen=True)
class AuditRecord:
    policy_version: str
    audit_group: str
    is_reference_group: bool
    outcome: Outcome
    application_received_at: datetime
    decision_issued_at: datetime | None
    evidence_index_present: bool
    notice_provided: bool
    accessible_route_available: bool
    accommodation_requested: bool
    accommodation_fulfilled: bool
    appeal_route_available: bool
    appeal_completed: bool
    appeal_corrected: bool
    conflict_screening_passed: bool
    independent_review_available: bool
    reasoned_decision_provided: bool
    append_only_continuity_preserved: bool
    consent_or_withdrawal_recorded: bool


@dataclass(frozen=True)
class AuditThresholds:
    minimum_group_size: int
    maximum_adverse_outcome_ratio: float
    maximum_median_decision_days: float
    minimum_accommodation_fulfillment_rate: float


@dataclass(frozen=True)
class GroupAuditResult:
    audit_group: str
    record_count: int
    suppressed: bool
    process_validity_rate: float | None
    final_adverse_validity_rate: float | None
    recognition_rate: float | None
    adverse_outcome_rate: float | None
    appeal_correction_rate: float | None
    median_decision_days: float | None
    accommodation_fulfillment_rate: float | None
    adverse_outcome_ratio: float | None
    requires_human_review: bool
    findings: tuple[str, ...]


def audit_records(
    records: Iterable[AuditRecord],
    thresholds: AuditThresholds,
) -> list[GroupAuditResult]:
    record_list = list(records)

    _validate_thresholds(thresholds)
    _validate_records(record_list)

    reference_records = [
        record
        for record in record_list
        if record.is_reference_group
    ]

    reference_adverse_outcome_rate = _adverse_outcome_rate(reference_records)

    grouped_records: dict[str, list[AuditRecord]] = {}
    for record in record_list:
        grouped_records.setdefault(record.audit_group, []).append(record)

    results: list[GroupAuditResult] = []

    for group_name, group in sorted(grouped_records.items()):
        if len(group) < thresholds.minimum_group_size:
            results.append(
                GroupAuditResult(
                    audit_group=group_name,
                    record_count=len(group),
                    suppressed=True,
                    process_validity_rate=None,
                    final_adverse_validity_rate=None,
                    recognition_rate=None,
                    adverse_outcome_rate=None,
                    appeal_correction_rate=None,
                    median_decision_days=None,
                    accommodation_fulfillment_rate=None,
                    adverse_outcome_ratio=None,
                    requires_human_review=True,
                    findings=(
                        "Group-level result suppressed because the minimum "
                        "privacy-preserving aggregation threshold is not met.",
                    ),
                )
            )
            continue

        process_validity_rate = _mean(
            [float(_process_valid(record)) for record in group]
        )

        adverse_records = [
            record
            for record in group
            if record.outcome is Outcome.NOT_RECOGNIZED
        ]

        final_adverse_validity_rate = (
            _mean(
                [
                    float(_final_adverse_valid(record))
                    for record in adverse_records
                ]
            )
            if adverse_records
            else 1.0
        )

        recognition_rate = _mean(
            [float(record.outcome is Outcome.RECOGNIZED) for record in group]
        )

        adverse_outcome_rate = _adverse_outcome_rate(group)

        appeal_records = [
            record
            for record in group
            if record.appeal_completed
        ]

        appeal_correction_rate = (
            _mean(
                [float(record.appeal_corrected) for record in appeal_records]
            )
            if appeal_records
            else 0.0
        )

        decision_days = [
            _decision_days(record)
            for record in group
            if record.decision_issued_at is not None
        ]

        median_decision_days = (
            _median(decision_days)
            if decision_days
            else None
        )

        accommodation_records = [
            record
            for record in group
            if record.accommodation_requested
        ]

        accommodation_fulfillment_rate = (
            _mean(
                [
                    float(record.accommodation_fulfilled)
                    for record in accommodation_records
                ]
            )
            if accommodation_records
            else 1.0
        )

        adverse_outcome_ratio = _ratio(
            adverse_outcome_rate,
            reference_adverse_outcome_rate,
        )

        findings = _findings(
            process_validity_rate=process_validity_rate,
            final_adverse_validity_rate=final_adverse_validity_rate,
            median_decision_days=median_decision_days,
            accommodation_fulfillment_rate=accommodation_fulfillment_rate,
            adverse_outcome_ratio=adverse_outcome_ratio,
            thresholds=thresholds,
        )

        results.append(
            GroupAuditResult(
                audit_group=group_name,
                record_count=len(group),
                suppressed=False,
                process_validity_rate=process_validity_rate,
                final_adverse_validity_rate=final_adverse_validity_rate,
                recognition_rate=recognition_rate,
                adverse_outcome_rate=adverse_outcome_rate,
                appeal_correction_rate=appeal_correction_rate,
                median_decision_days=median_decision_days,
                accommodation_fulfillment_rate=accommodation_fulfillment_rate,
                adverse_outcome_ratio=adverse_outcome_ratio,
                requires_human_review=bool(findings),
                findings=tuple(findings) or (
                    "No configured aggregate audit threshold was exceeded.",
                ),
            )
        )

    return results


def _process_valid(record: AuditRecord) -> bool:
    return (
        bool(record.policy_version.strip())
        and record.evidence_index_present
        and record.notice_provided
        and record.accessible_route_available
        and record.appeal_route_available
        and record.append_only_continuity_preserved
        and record.consent_or_withdrawal_recorded
    )


def _final_adverse_valid(record: AuditRecord) -> bool:
    return (
        _process_valid(record)
        and record.conflict_screening_passed
        and record.independent_review_available
        and record.reasoned_decision_provided
    )


def _adverse_outcome_rate(records: list[AuditRecord]) -> float:
    if not records:
        return 0.0

    return _mean(
        [
            float(record.outcome is Outcome.NOT_RECOGNIZED)
            for record in records
        ]
    )


def _decision_days(record: AuditRecord) -> float:
    if record.decision_issued_at is None:
        raise ValueError("decision_issued_at is required.")

    application_time = record.application_received_at.astimezone(timezone.utc)
    decision_time = record.decision_issued_at.astimezone(timezone.utc)

    return (
        decision_time - application_time
    ).total_seconds() / 86_400.0


def _ratio(numerator: float, denominator: float) -> float:
    if denominator == 0.0:
        return 1.0 if numerator == 0.0 else float("inf")
    return numerator / denominator


def _findings(
    process_validity_rate: float,
    final_adverse_validity_rate: float,
    median_decision_days: float | None,
    accommodation_fulfillment_rate: float,
    adverse_outcome_ratio: float,
    thresholds: AuditThresholds,
) -> list[str]:
    findings: list[str] = []

    if process_validity_rate < 1.0:
        findings.append(
            "One or more records are missing a policy version, evidence index, "
            "notice, accessible route, appeal route, continuity record, or "
            "consent/withdrawal record."
        )

    if final_adverse_validity_rate < 1.0:
        findings.append(
            "One or more adverse outcomes lack conflict screening, independent "
            "review availability, or a reasoned decision."
        )

    if (
        median_decision_days is not None
        and median_decision_days > thresholds.maximum_median_decision_days
    ):
        findings.append(
            "Median decision time exceeds the configured review threshold."
        )

    if (
        accommodation_fulfillment_rate
        < thresholds.minimum_accommodation_fulfillment_rate
    ):
        findings.append(
            "Accommodation fulfillment is below the configured threshold."
        )

    if adverse_outcome_ratio > thresholds.maximum_adverse_outcome_ratio:
        findings.append(
            "Aggregate adverse-outcome disparity exceeds the configured review threshold."
        )

    return findings


def _validate_thresholds(thresholds: AuditThresholds) -> None:
    if thresholds.minimum_group_size < 1:
        raise ValueError("minimum_group_size must be at least one.")

    if (
        not math.isfinite(thresholds.maximum_adverse_outcome_ratio)
        or thresholds.maximum_adverse_outcome_ratio < 1.0
    ):
        raise ValueError(
            "maximum_adverse_outcome_ratio must be finite and at least 1.0."
        )

    if (
        not math.isfinite(thresholds.maximum_median_decision_days)
        or thresholds.maximum_median_decision_days <= 0.0
    ):
        raise ValueError(
            "maximum_median_decision_days must be finite and greater than zero."
        )

    if (
        not math.isfinite(thresholds.minimum_accommodation_fulfillment_rate)
        or not 0.0
        <= thresholds.minimum_accommodation_fulfillment_rate
        <= 1.0
    ):
        raise ValueError(
            "minimum_accommodation_fulfillment_rate must be within [0, 1]."
        )


def _validate_records(records: list[AuditRecord]) -> None:
    if not records:
        raise ValueError("At least one audit record is required.")

    if not any(record.is_reference_group for record in records):
        raise ValueError("At least one reference-group record is required.")

    for record in records:
        if not record.audit_group.strip():
            raise ValueError("audit_group is required.")

        if record.application_received_at.tzinfo is None:
            raise ValueError("application_received_at must be timezone-aware.")

        if record.decision_issued_at is not None:
            if record.decision_issued_at.tzinfo is None:
                raise ValueError("decision_issued_at must be timezone-aware.")

            if record.decision_issued_at < record.application_received_at:
                raise ValueError(
                    "decision_issued_at cannot precede application_received_at."
                )


def _mean(values: list[float]) -> float:
    if not values:
        return 0.0
    return sum(values) / len(values)


def _median(values: list[float]) -> float:
    if not values:
        raise ValueError("Cannot calculate median of an empty sequence.")

    ordered = sorted(values)
    midpoint = len(ordered) // 2

    if len(ordered) % 2 == 1:
        return ordered[midpoint]

    return (ordered[midpoint - 1] + ordered[midpoint]) / 2.0
