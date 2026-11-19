from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Iterable


class RouteCostValidationError(ValueError):
    pass


@dataclass(frozen=True)
class Segment:
    label: str
    length_m: float
    inaccessibility_score: float
    heat_exposure_score: float
    reliability_penalty: float
    has_stairs: bool
    curb_ramp_present: bool
    elevator_required: bool
    elevator_available: bool
    slope_percent: float

    def __post_init__(self) -> None:
        if not self.label.strip():
            raise RouteCostValidationError("Segment label must be non-empty.")

        for field_name, value in (
            ("length_m", self.length_m),
            ("inaccessibility_score", self.inaccessibility_score),
            ("heat_exposure_score", self.heat_exposure_score),
            ("reliability_penalty", self.reliability_penalty),
            ("slope_percent", self.slope_percent),
        ):
            if not isfinite(value) or value < 0.0:
                raise RouteCostValidationError(
                    f"{field_name} must be finite and non-negative."
                )


@dataclass(frozen=True)
class RoutePreferences:
    accessibility_weight: float
    heat_weight: float
    reliability_weight: float
    avoid_stairs: bool
    require_curb_ramps: bool
    require_operational_elevators: bool
    maximum_slope_percent: float

    def __post_init__(self) -> None:
        for field_name, value in (
            ("accessibility_weight", self.accessibility_weight),
            ("heat_weight", self.heat_weight),
            ("reliability_weight", self.reliability_weight),
            ("maximum_slope_percent", self.maximum_slope_percent),
        ):
            if not isfinite(value) or value < 0.0:
                raise RouteCostValidationError(
                    f"{field_name} must be finite and non-negative."
                )


@dataclass(frozen=True)
class RouteEvaluation:
    eligible: bool
    cost: float | None
    reason: str


def evaluate_route(
    segments: Iterable[Segment],
    preferences: RoutePreferences,
) -> RouteEvaluation:
    route_segments = list(segments)
    if not route_segments:
        raise RouteCostValidationError("A route must contain at least one segment.")

    total_cost = 0.0
    for segment in route_segments:
        if preferences.avoid_stairs and segment.has_stairs:
            return RouteEvaluation(
                eligible=False,
                cost=None,
                reason=f"Route contains stairs on segment: {segment.label}.",
            )

        if preferences.require_curb_ramps and not segment.curb_ramp_present:
            return RouteEvaluation(
                eligible=False,
                cost=None,
                reason=f"Route lacks a required curb ramp on segment: {segment.label}.",
            )

        if (
            preferences.require_operational_elevators
            and segment.elevator_required
            and not segment.elevator_available
        ):
            return RouteEvaluation(
                eligible=False,
                cost=None,
                reason=f"Route requires an unavailable elevator on segment: {segment.label}.",
            )

        if segment.slope_percent > preferences.maximum_slope_percent:
            return RouteEvaluation(
                eligible=False,
                cost=None,
                reason=f"Route exceeds the selected slope limit on segment: {segment.label}.",
            )

        total_cost += (
            segment.length_m
            + preferences.accessibility_weight * segment.inaccessibility_score
            + preferences.heat_weight * segment.heat_exposure_score
            + preferences.reliability_weight * segment.reliability_penalty
        )

    return RouteEvaluation(
        eligible=True,
        cost=total_cost,
        reason="Route satisfies selected accessibility constraints using local segment data.",
    )


def privacy_safe_route_session_record() -> dict[str, bool]:
    return {
        "route_history_retained": False,
        "current_location_history_retained": False,
        "search_history_retained": False,
        "identity_data_retained": False,
        "health_or_augmentation_data_retained": False,
        "device_identifier_retained": False,
        "reputation_score_used": False,
    }
