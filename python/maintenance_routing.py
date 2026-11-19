from dataclasses import dataclass
from decimal import Decimal
from typing import Iterable


@dataclass(frozen=True)
class RouteCandidate:
    route_ref: str
    disruption_cost: Decimal
    energy_cost: Decimal
    operational_risk: Decimal
    ecological_benefit: Decimal
    access_restoration_benefit: Decimal
    enters_prohibited_zone: bool
    violates_time_window: bool
    blocks_accessible_route_without_verified_detour: bool
    emergency_access_preserved: bool
    provenance_complete: bool


@dataclass(frozen=True)
class RouteWeights:
    disruption: Decimal
    energy: Decimal
    operational_risk: Decimal
    ecological_benefit: Decimal
    access_restoration_benefit: Decimal


@dataclass(frozen=True)
class RouteAssessment:
    route_ref: str
    objective_value: Decimal | None
    eligible: bool
    exclusions: tuple[str, ...]


def evaluate_route(
    candidate: RouteCandidate,
    weights: RouteWeights,
) -> RouteAssessment:
    exclusions: list[str] = []

    if candidate.enters_prohibited_zone:
        exclusions.append("PROHIBITED_ZONE")

    if candidate.violates_time_window:
        exclusions.append("RESTRICTED_TIME_WINDOW")

    if candidate.blocks_accessible_route_without_verified_detour:
        exclusions.append("ACCESSIBLE_DETOUR_NOT_VERIFIED")

    if not candidate.emergency_access_preserved:
        exclusions.append("EMERGENCY_ACCESS_NOT_PRESERVED")

    if not candidate.provenance_complete:
        exclusions.append("MISSING_CONSTRAINT_PROVENANCE")

    if exclusions:
        return RouteAssessment(
            route_ref=candidate.route_ref,
            objective_value=None,
            eligible=False,
            exclusions=tuple(exclusions),
        )

    objective_value = (
        weights.disruption * candidate.disruption_cost
        + weights.energy * candidate.energy_cost
        + weights.operational_risk * candidate.operational_risk
        - weights.ecological_benefit * candidate.ecological_benefit
        - weights.access_restoration_benefit
        * candidate.access_restoration_benefit
    )

    return RouteAssessment(
        route_ref=candidate.route_ref,
        objective_value=objective_value,
        eligible=True,
        exclusions=(),
    )


def select_route(
    candidates: Iterable[RouteCandidate],
    weights: RouteWeights,
) -> RouteAssessment | None:
    eligible_assessments = [
        evaluate_route(candidate, weights)
        for candidate in candidates
    ]

    eligible_assessments = [
        assessment
        for assessment in eligible_assessments
        if assessment.eligible and assessment.objective_value is not None
    ]

    if not eligible_assessments:
        return None

    return min(
        eligible_assessments,
        key=lambda assessment: assessment.objective_value,
    )
