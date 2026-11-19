from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Iterable


class AuditDecision(str, Enum):
    REPORTABLE = "reportable"
    INSUFFICIENT_EVIDENCE = "insufficient_evidence"
    REVIEW_REQUIRED = "review_required"


@dataclass(frozen=True)
class AggregateConfusionMatrix:
    true_positive: int
    false_positive: int
    true_negative: int
    false_negative: int

    def validate(self) -> None:
        values = (
            self.true_positive,
            self.false_positive,
            self.true_negative,
            self.false_negative,
        )

        if any(value < 0 for value in values):
            raise ValueError("confusion-matrix counts must not be negative")

    @property
    def total(self) -> int:
        return (
            self.true_positive
            + self.false_positive
            + self.true_negative
            + self.false_negative
        )

    @property
    def predicted_positive(self) -> int:
        return self.true_positive + self.false_positive

    @property
    def actual_positive(self) -> int:
        return self.true_positive + self.false_negative

    def selection_rate(self) -> float | None:
        if self.total == 0:
            return None
        return self.predicted_positive / self.total

    def true_positive_rate(self) -> float | None:
        if self.actual_positive == 0:
            return None
        return self.true_positive / self.actual_positive

    def positive_predictive_value(self) -> float | None:
        if self.predicted_positive == 0:
            return None
        return self.true_positive / self.predicted_positive


@dataclass(frozen=True)
class FairnessAuditInput:
    purpose: str
    group_a: AggregateConfusionMatrix
    group_b: AggregateConfusionMatrix
    minimum_group_size: int
    voluntary_audit_cohorts: bool
    accessible_appeal_available: bool
    identity_inference_used: bool
    proxy_feature_used: bool


@dataclass(frozen=True)
class FairnessAuditReport:
    decision: AuditDecision
    demographic_parity_difference: float | None
    equalized_opportunity_difference: float | None
    predictive_parity_difference: float | None
    findings: tuple[str, ...]


def absolute_difference(left: float | None, right: float | None) -> float | None:
    if left is None or right is None:
        return None
    return abs(left - right)


def assess_fairness(audit: FairnessAuditInput) -> FairnessAuditReport:
    audit.group_a.validate()
    audit.group_b.validate()

    findings: list[str] = []

    if not audit.purpose.strip():
        findings.append("purpose_is_required_for_a_fairness_audit")

    if audit.identity_inference_used:
        findings.append("identity_inference_is_prohibited")

    if audit.proxy_feature_used:
        findings.append("proxy_feature_requires_privacy_and_rights_review")

    if not audit.voluntary_audit_cohorts:
        findings.append("audit_cohort_participation_must_be_voluntary")

    if not audit.accessible_appeal_available:
        findings.append("accessible_appeal_and_human_review_are_required")

    if audit.group_a.total < audit.minimum_group_size:
        findings.append("group_a_does_not_meet_minimum_aggregation_threshold")

    if audit.group_b.total < audit.minimum_group_size:
        findings.append("group_b_does_not_meet_minimum_aggregation_threshold")

    demographic_parity_difference = absolute_difference(
        audit.group_a.selection_rate(),
        audit.group_b.selection_rate(),
    )

    equalized_opportunity_difference = absolute_difference(
        audit.group_a.true_positive_rate(),
        audit.group_b.true_positive_rate(),
    )

    predictive_parity_difference = absolute_difference(
        audit.group_a.positive_predictive_value(),
        audit.group_b.positive_predictive_value(),
    )

    if (
        demographic_parity_difference is None
        or equalized_opportunity_difference is None
        or predictive_parity_difference is None
    ):
        findings.append("one_or_more_metrics_are_undefined_due_to_zero_denominators")

    if any(
        finding
        in {
            "identity_inference_is_prohibited",
            "audit_cohort_participation_must_be_voluntary",
            "accessible_appeal_and_human_review_are_required",
            "group_a_does_not_meet_minimum_aggregation_threshold",
            "group_b_does_not_meet_minimum_aggregation_threshold",
        }
        for finding in findings
    ):
        decision = AuditDecision.INSUFFICIENT_EVIDENCE
    elif audit.proxy_feature_used or any(
        value is None
        for value in (
            demographic_parity_difference,
            equalized_opportunity_difference,
            predictive_parity_difference,
        )
    ):
        decision = AuditDecision.REVIEW_REQUIRED
    else:
        decision = AuditDecision.REPORTABLE

    findings.append(
        "metrics_are_diagnostic_only_and_must_not_be_used_for_individual_eligibility_or_ranking"
    )

    return FairnessAuditReport(
        decision=decision,
        demographic_parity_difference=demographic_parity_difference,
        equalized_opportunity_difference=equalized_opportunity_difference,
        predictive_parity_difference=predictive_parity_difference,
        findings=tuple(findings),
    )


def aggregate_qos_failure_rate(
    successful_requests: int,
    failed_requests: int,
) -> float | None:
    if successful_requests < 0 or failed_requests < 0:
        raise ValueError("request counts must not be negative")

    total = successful_requests + failed_requests
    if total == 0:
        return None

    return failed_requests / total


def ensure_no_individual_records(records: Iterable[object]) -> None:
    if any(True for _ in records):
        raise ValueError(
            "this module accepts aggregate counts only; "
            "individual-level records are outside its privacy boundary"
        )
