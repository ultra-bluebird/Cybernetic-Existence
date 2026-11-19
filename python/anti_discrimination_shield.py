from __future__ import annotations

from dataclasses import dataclass
from math import sqrt
from typing import Iterable, Literal


ShieldStatus = Literal[
    "blocked",
    "human_review_required",
    "approved_with_monitoring",
    "research_only",
]


@dataclass(frozen=True)
class AuditCase:
    group: str
    eligible: bool
    favorable_decision: bool
    actual_positive: bool | None = None
    predicted_positive: bool | None = None


@dataclass(frozen=True)
class FeatureReview:
    feature_name: str
    permitted: bool
    contains_sensitive_data: bool
    adverse_use: bool


@dataclass(frozen=True)
class ShieldResult:
    status: ShieldStatus
    statistical_parity_ratio: float | None
    parity_confidence_interval: tuple[float, float] | None
    false_negative_rate_gap: float | None
    false_positive_rate_gap: float | None
    blocked_features: tuple[str, ...]
    reasons: tuple[str, ...]


def selection_rate(cases: Iterable[AuditCase], group: str) -> tuple[int, int]:
    selected = 0
    eligible = 0

    for case in cases:
        if case.group != group or not case.eligible:
            continue
        eligible += 1
        if case.favorable_decision:
            selected += 1

    return selected, eligible


def proportion_confidence_interval(successes: int, total: int, z_score: float = 1.96) -> tuple[float, float] | None:
    if total <= 0:
        return None

    proportion = successes / total
    denominator = 1.0 + z_score * z_score / total
    centre = (proportion + z_score * z_score / (2.0 * total)) / denominator
    margin = (
        z_score
        * sqrt(
            proportion * (1.0 - proportion) / total
            + z_score * z_score / (4.0 * total * total)
        )
        / denominator
    )
    return max(0.0, centre - margin), min(1.0, centre + margin)


def error_rates(cases: Iterable[AuditCase], group: str) -> tuple[float | None, float | None]:
    false_negatives = 0
    actual_positives = 0
    false_positives = 0
    actual_negatives = 0

    for case in cases:
        if case.group != group:
            continue
        if case.actual_positive is None or case.predicted_positive is None:
            continue

        if case.actual_positive:
            actual_positives += 1
            if not case.predicted_positive:
                false_negatives += 1
        else:
            actual_negatives += 1
            if case.predicted_positive:
                false_positives += 1

    false_negative_rate = (
        false_negatives / actual_positives if actual_positives > 0 else None
    )
    false_positive_rate = (
        false_positives / actual_negatives if actual_negatives > 0 else None
    )
    return false_negative_rate, false_positive_rate


def evaluate_shield(
    cases: list[AuditCase],
    protected_group: str,
    reference_group: str,
    features: list[FeatureReview],
    parity_threshold: float = 0.80,
    minimum_group_size: int = 30,
    maximum_error_gap: float = 0.10,
) -> ShieldResult:
    if not 0.0 < parity_threshold <= 1.0:
        raise ValueError("parity_threshold must be in the interval (0, 1]")
    if minimum_group_size < 1:
        raise ValueError("minimum_group_size must be positive")
    if not 0.0 <= maximum_error_gap <= 1.0:
        raise ValueError("maximum_error_gap must be in the interval [0, 1]")

    blocked_features = tuple(
        feature.feature_name
        for feature in features
        if not feature.permitted or feature.contains_sensitive_data or feature.adverse_use
    )
    if blocked_features:
        return ShieldResult(
            status="blocked",
            statistical_parity_ratio=None,
            parity_confidence_interval=None,
            false_negative_rate_gap=None,
            false_positive_rate_gap=None,
            blocked_features=blocked_features,
            reasons=("A prohibited, sensitive, or adverse-use feature is present.",),
        )

    protected_selected, protected_total = selection_rate(cases, protected_group)
    reference_selected, reference_total = selection_rate(cases, reference_group)

    if protected_total < minimum_group_size or reference_total < minimum_group_size:
        return ShieldResult(
            status="research_only",
            statistical_parity_ratio=None,
            parity_confidence_interval=None,
            false_negative_rate_gap=None,
            false_positive_rate_gap=None,
            blocked_features=(),
            reasons=("Insufficient aggregate cohort size for reliable disparity measurement.",),
        )

    protected_rate = protected_selected / protected_total
    reference_rate = reference_selected / reference_total
    parity_ratio = protected_rate / reference_rate if reference_rate > 0.0 else None

    protected_interval = proportion_confidence_interval(
        protected_selected,
        protected_total,
    )
    reference_interval = proportion_confidence_interval(
        reference_selected,
        reference_total,
    )

    ratio_interval: tuple[float, float] | None = None
    if protected_interval is not None and reference_interval is not None and reference_interval[0] > 0.0:
        ratio_interval = (
            protected_interval[0] / reference_interval[1],
            protected_interval[1] / reference_interval[0],
        )

    protected_fnr, protected_fpr = error_rates(cases, protected_group)
    reference_fnr, reference_fpr = error_rates(cases, reference_group)

    fnr_gap = (
        abs(protected_fnr - reference_fnr)
        if protected_fnr is not None and reference_fnr is not None
        else None
    )
    fpr_gap = (
        abs(protected_fpr - reference_fpr)
        if protected_fpr is not None and reference_fpr is not None
        else None
    )

    reasons: list[str] = []
    if parity_ratio is not None and parity_ratio < parity_threshold:
        reasons.append("Statistical parity ratio is below the configured review threshold.")
    if fnr_gap is not None and fnr_gap > maximum_error_gap:
        reasons.append("False-negative-rate disparity exceeds the configured review threshold.")
    if fpr_gap is not None and fpr_gap > maximum_error_gap:
        reasons.append("False-positive-rate disparity exceeds the configured review threshold.")

    if reasons:
        status: ShieldStatus = "human_review_required"
    else:
        status = "approved_with_monitoring"
        reasons.append("No configured statistical disparity threshold was exceeded.")

    return ShieldResult(
        status=status,
        statistical_parity_ratio=parity_ratio,
        parity_confidence_interval=ratio_interval,
        false_negative_rate_gap=fnr_gap,
        false_positive_rate_gap=fpr_gap,
        blocked_features=(),
        reasons=tuple(reasons),
    )
