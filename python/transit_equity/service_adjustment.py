from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Iterable
import math


class TransitDecision(str, Enum):
    ALLOW_HUMAN_REVIEW = "allow_human_review"
    REQUIRE_EQUITY_REVIEW = "require_equity_review"
    REJECT = "reject"


@dataclass(frozen=True)
class RouteSegment:
    route_code: str
    baseline_frequency_per_hour: float
    proposed_frequency_per_hour: float
    demand_estimate: float
    demand_uncertainty: float
    accessibility_critical: bool
    low_income_service_area: bool
    essential_destination_route: bool
    estimated_wait_increase_minutes: float
    estimated_travel_time_increase_minutes: float
    accessible_transfer_loss: float


@dataclass(frozen=True)
class TransitPolicy:
    maximum_adverse_effect_ratio: float
    maximum_demand_uncertainty: float
    allow_temporary_emergency_reduction: bool
    minimum_frequency_per_hour: float


@dataclass(frozen=True)
class TransitReviewResult:
    decision: TransitDecision
    adverse_effect_ratio: float | None
    protected_route_failures: tuple[str, ...]
    reasons: tuple[str, ...]


def evaluate_service_adjustment(
    segments: Iterable[RouteSegment],
    policy: TransitPolicy,
) -> TransitReviewResult:
    segment_list = list(segments)

    if not segment_list:
        raise ValueError("At least one route segment is required.")

    _validate_policy(policy)
    for segment in segment_list:
        _validate_segment(segment)

    protected_failures: list[str] = []
    adverse_effects: list[float] = []
    reference_adverse_effects: list[float] = []

    for segment in segment_list:
        protected = (
            segment.accessibility_critical
            or segment.low_income_service_area
            or segment.essential_destination_route
        )

        if segment.demand_uncertainty > policy.maximum_demand_uncertainty:
            return TransitReviewResult(
                decision=TransitDecision.REQUIRE_EQUITY_REVIEW,
                adverse_effect_ratio=None,
                protected_route_failures=(),
                reasons=(
                    "Demand uncertainty exceeds the configured operational threshold.",
                ),
            )

        if segment.proposed_frequency_per_hour < policy.minimum_frequency_per_hour:
            protected_failures.append(
                f"{segment.route_code}: proposed frequency is below the absolute service floor."
            )

        if (
            protected
            and not policy.allow_temporary_emergency_reduction
            and segment.proposed_frequency_per_hour
            < segment.baseline_frequency_per_hour
        ):
            protected_failures.append(
                f"{segment.route_code}: protected route frequency may not be reduced automatically."
            )

        adverse_effect = (
            segment.estimated_wait_increase_minutes
            + segment.estimated_travel_time_increase_minutes
            + 10.0 * segment.accessible_transfer_loss
        )

        if protected:
            adverse_effects.append(adverse_effect)
        else:
            reference_adverse_effects.append(adverse_effect)

    if protected_failures:
        return TransitReviewResult(
            decision=TransitDecision.REJECT,
            adverse_effect_ratio=None,
            protected_route_failures=tuple(protected_failures),
            reasons=(
                "One or more non-offsettable service-floor or protected-route constraints failed.",
            ),
        )

    protected_average = _mean(adverse_effects)
    reference_average = _mean(reference_adverse_effects)

    if protected_average == 0.0 and reference_average == 0.0:
        adverse_effect_ratio = 1.0
    elif reference_average == 0.0:
        adverse_effect_ratio = float("inf")
    else:
        adverse_effect_ratio = protected_average / reference_average

    if adverse_effect_ratio > policy.maximum_adverse_effect_ratio:
        return TransitReviewResult(
            decision=TransitDecision.REQUIRE_EQUITY_REVIEW,
            adverse_effect_ratio=adverse_effect_ratio,
            protected_route_failures=(),
            reasons=(
                "The aggregate adverse-effect ratio exceeds the configured equity-review threshold.",
            ),
        )

    return TransitReviewResult(
        decision=TransitDecision.ALLOW_HUMAN_REVIEW,
        adverse_effect_ratio=adverse_effect_ratio,
        protected_route_failures=(),
        reasons=(
            "The candidate plan passes automated planning gates and requires human operations review before implementation.",
        ),
    )


def _validate_policy(policy: TransitPolicy) -> None:
    if (
        not math.isfinite(policy.maximum_adverse_effect_ratio)
        or policy.maximum_adverse_effect_ratio < 1.0
    ):
        raise ValueError(
            "maximum_adverse_effect_ratio must be finite and at least 1.0."
        )

    if (
        not math.isfinite(policy.maximum_demand_uncertainty)
        or not 0.0 <= policy.maximum_demand_uncertainty <= 1.0
    ):
        raise ValueError(
            "maximum_demand_uncertainty must be finite and within [0, 1]."
        )

    if (
        not math.isfinite(policy.minimum_frequency_per_hour)
        or policy.minimum_frequency_per_hour <= 0.0
    ):
        raise ValueError(
            "minimum_frequency_per_hour must be finite and greater than zero."
        )


def _validate_segment(segment: RouteSegment) -> None:
    if not segment.route_code.strip():
        raise ValueError("route_code is required.")

    nonnegative_values = {
        "baseline_frequency_per_hour": segment.baseline_frequency_per_hour,
        "proposed_frequency_per_hour": segment.proposed_frequency_per_hour,
        "demand_estimate": segment.demand_estimate,
        "estimated_wait_increase_minutes": segment.estimated_wait_increase_minutes,
        "estimated_travel_time_increase_minutes": (
            segment.estimated_travel_time_increase_minutes
        ),
        "accessible_transfer_loss": segment.accessible_transfer_loss,
    }

    for name, value in nonnegative_values.items():
        if not math.isfinite(value) or value < 0.0:
            raise ValueError(f"{name} must be finite and non-negative.")

    if (
        not math.isfinite(segment.demand_uncertainty)
        or not 0.0 <= segment.demand_uncertainty <= 1.0
    ):
        raise ValueError("demand_uncertainty must be finite and within [0, 1].")


def _mean(values: list[float]) -> float:
    if not values:
        return 0.0
    return sum(values) / len(values)
