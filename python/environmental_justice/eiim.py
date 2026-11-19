from __future__ import annotations

from dataclasses import dataclass
from typing import Mapping
import math


@dataclass(frozen=True)
class MetricRange:
    low_reference: float
    high_reference: float

    def normalize(self, value: float) -> float:
        if not math.isfinite(value):
            raise ValueError("Metric values must be finite.")
        if not math.isfinite(self.low_reference) or not math.isfinite(self.high_reference):
            raise ValueError("Reference bounds must be finite.")
        if self.high_reference <= self.low_reference:
            raise ValueError("high_reference must exceed low_reference.")

        normalized = (
            (value - self.low_reference)
            / (self.high_reference - self.low_reference)
        )
        return min(1.0, max(0.0, normalized))


@dataclass(frozen=True)
class EcoIdentityAggregate:
    area_code: str
    group_label: str
    burden_values: Mapping[str, float]
    benefit_values: Mapping[str, float]
    confidence: float
    reporting_allowed: bool
    minimum_group_size_met: bool
    voluntary_aggregate_source: bool


@dataclass(frozen=True)
class EiimResult:
    net_disadvantage: float
    reference_disadvantage: float
    disparity: float
    eiim: float
    publication_allowed: bool
    explanation: str


def calculate_eiim(
    group: EcoIdentityAggregate,
    reference: EcoIdentityAggregate,
    burden_weights: Mapping[str, float],
    benefit_weights: Mapping[str, float],
    metric_ranges: Mapping[str, MetricRange],
) -> EiimResult:
    _validate_aggregate(group)
    _validate_aggregate(reference)
    _validate_weights(burden_weights, "burden_weights")
    _validate_weights(benefit_weights, "benefit_weights")

    group_score = _net_disadvantage(
        group,
        burden_weights,
        benefit_weights,
        metric_ranges,
    )
    reference_score = _net_disadvantage(
        reference,
        burden_weights,
        benefit_weights,
        metric_ranges,
    )

    reporting_allowed = (
        group.reporting_allowed
        and reference.reporting_allowed
        and group.minimum_group_size_met
        and reference.minimum_group_size_met
        and group.voluntary_aggregate_source
        and reference.voluntary_aggregate_source
    )

    disparity = group_score - reference_score
    confidence = min(group.confidence, reference.confidence)
    eiim = disparity * confidence if reporting_allowed else 0.0

    if not reporting_allowed:
        explanation = (
            "Publication is suppressed because consent, aggregation, or disclosure "
            "protections are not satisfied. No group-level score is released."
        )
    elif eiim > 0:
        explanation = (
            "The aggregate group has higher modeled net environmental disadvantage "
            "than the comparison reference. Use this as an investigation and "
            "participatory planning signal, not an individual-level decision."
        )
    else:
        explanation = (
            "This comparison does not show a positive aggregate disparity under the "
            "configured measures and weights. Review uncertainty before drawing "
            "planning conclusions."
        )

    return EiimResult(
        net_disadvantage=group_score,
        reference_disadvantage=reference_score,
        disparity=disparity,
        eiim=eiim,
        publication_allowed=reporting_allowed,
        explanation=explanation,
    )


def _net_disadvantage(
    aggregate: EcoIdentityAggregate,
    burden_weights: Mapping[str, float],
    benefit_weights: Mapping[str, float],
    metric_ranges: Mapping[str, MetricRange],
) -> float:
    burdens = 0.0
    benefits = 0.0

    for metric, weight in burden_weights.items():
        if metric not in aggregate.burden_values or metric not in metric_ranges:
            raise ValueError(f"Missing burden metric or range: {metric}")
        burdens += weight * metric_ranges[metric].normalize(
            aggregate.burden_values[metric]
        )

    for metric, weight in benefit_weights.items():
        if metric not in aggregate.benefit_values or metric not in metric_ranges:
            raise ValueError(f"Missing benefit metric or range: {metric}")
        benefits += weight * metric_ranges[metric].normalize(
            aggregate.benefit_values[metric]
        )

    return burdens - benefits


def _validate_aggregate(aggregate: EcoIdentityAggregate) -> None:
    if not aggregate.area_code:
        raise ValueError("area_code is required.")
    if not aggregate.group_label:
        raise ValueError("group_label is required.")
    if not 0.0 <= aggregate.confidence <= 1.0:
        raise ValueError("confidence must be within [0, 1].")


def _validate_weights(weights: Mapping[str, float], field_name: str) -> None:
    if not weights:
        raise ValueError(f"{field_name} must not be empty.")

    total = 0.0
    for metric, weight in weights.items():
        if not metric:
            raise ValueError(f"{field_name} contains an empty metric name.")
        if not math.isfinite(weight) or weight < 0.0:
            raise ValueError(f"{field_name} values must be finite and non-negative.")
        total += weight

    if not math.isclose(total, 1.0, rel_tol=1e-9, abs_tol=1e-9):
        raise ValueError(f"{field_name} must sum to 1.0.")
