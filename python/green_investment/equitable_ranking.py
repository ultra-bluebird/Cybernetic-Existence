from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable
import math


@dataclass(frozen=True)
class GreenProject:
    project_code: str
    zone_code: str
    project_type: str
    cost: float
    heat_benefit: float
    air_quality_benefit: float
    social_need: float
    accessible_service_gap: float
    water_feasibility: float
    displacement_risk: float
    confidence: float
    accessible_design_verified: bool
    water_demand: float


@dataclass(frozen=True)
class AllocationWeights:
    heat: float
    air_quality: float
    social_need: float
    accessible_service_gap: float
    water_feasibility: float
    displacement_risk: float


@dataclass(frozen=True)
class RankedProject:
    project_code: str
    selected: bool
    score: float
    priority_per_cost: float
    reason: str


def rank_projects(
    projects: Iterable[GreenProject],
    weights: AllocationWeights,
    total_budget: float,
    maximum_water_demand: float,
    displacement_risk_limit: float,
    minimum_accessible_projects: int,
) -> list[RankedProject]:
    project_list = list(projects)

    if total_budget <= 0.0 or not math.isfinite(total_budget):
        raise ValueError("total_budget must be finite and greater than zero.")
    if maximum_water_demand < 0.0 or not math.isfinite(maximum_water_demand):
        raise ValueError("maximum_water_demand must be finite and non-negative.")
    if not 0.0 <= displacement_risk_limit <= 1.0:
        raise ValueError("displacement_risk_limit must be within [0, 1].")
    if minimum_accessible_projects < 0:
        raise ValueError("minimum_accessible_projects must be non-negative.")

    _validate_weights(weights)

    eligible = [
        project
        for project in project_list
        if _eligible(project, displacement_risk_limit)
    ]

    accessible = [
        project
        for project in eligible
        if project.accessible_design_verified
    ]

    accessible.sort(
        key=lambda project: _priority(project, weights),
        reverse=True,
    )

    selected_codes: set[str] = set()
    remaining_budget = total_budget
    remaining_water = maximum_water_demand

    for project in accessible[:minimum_accessible_projects]:
        if project.cost <= remaining_budget and project.water_demand <= remaining_water:
            selected_codes.add(project.project_code)
            remaining_budget -= project.cost
            remaining_water -= project.water_demand

    remaining_candidates = [
        project for project in eligible
        if project.project_code not in selected_codes
    ]

    remaining_candidates.sort(
        key=lambda project: _priority(project, weights),
        reverse=True,
    )

    for project in remaining_candidates:
        if project.cost <= remaining_budget and project.water_demand <= remaining_water:
            selected_codes.add(project.project_code)
            remaining_budget -= project.cost
            remaining_water -= project.water_demand

    results: list[RankedProject] = []

    for project in project_list:
        score = _score(project, weights)
        priority = _priority(project, weights)

        if project.project_code in selected_codes:
            reason = (
                "Selected within budget and water capacity after applying "
                "accessibility and displacement safeguards."
            )
        elif project.displacement_risk > displacement_risk_limit:
            reason = (
                "Not selected because documented displacement or exclusion risk "
                "exceeds the configured safeguard threshold."
            )
        elif not project.accessible_design_verified:
            reason = (
                "Not selected in the protected accessible-project allocation because "
                "accessible design verification is incomplete."
            )
        else:
            reason = (
                "Eligible but not selected under the current constrained budget, "
                "water, and priority ranking."
            )

        results.append(
            RankedProject(
                project_code=project.project_code,
                selected=project.project_code in selected_codes,
                score=score,
                priority_per_cost=priority,
                reason=reason,
            )
        )

    return sorted(
        results,
        key=lambda result: (not result.selected, -result.priority_per_cost),
    )


def _eligible(project: GreenProject, displacement_risk_limit: float) -> bool:
    _validate_project(project)
    return project.displacement_risk <= displacement_risk_limit


def _score(project: GreenProject, weights: AllocationWeights) -> float:
    return (
        weights.heat * project.heat_benefit
        + weights.air_quality * project.air_quality_benefit
        + weights.social_need * project.social_need
        + weights.accessible_service_gap * project.accessible_service_gap
        + weights.water_feasibility * project.water_feasibility
        - weights.displacement_risk * project.displacement_risk
    )


def _priority(project: GreenProject, weights: AllocationWeights) -> float:
    return _score(project, weights) * project.confidence / max(project.cost, 1e-9)


def _validate_project(project: GreenProject) -> None:
    if not project.project_code.strip() or not project.zone_code.strip():
        raise ValueError("project_code and zone_code are required.")
    if project.project_type not in {"park", "green_roof", "tree_planting"}:
        raise ValueError("project_type must be park, green_roof, or tree_planting.")
    if not math.isfinite(project.cost) or project.cost <= 0.0:
        raise ValueError("cost must be finite and greater than zero.")
    if not math.isfinite(project.water_demand) or project.water_demand < 0.0:
        raise ValueError("water_demand must be finite and non-negative.")

    for name, value in {
        "heat_benefit": project.heat_benefit,
        "air_quality_benefit": project.air_quality_benefit,
        "social_need": project.social_need,
        "accessible_service_gap": project.accessible_service_gap,
        "water_feasibility": project.water_feasibility,
        "displacement_risk": project.displacement_risk,
        "confidence": project.confidence,
    }.items():
        if not math.isfinite(value) or not 0.0 <= value <= 1.0:
            raise ValueError(f"{name} must be finite and within [0, 1].")


def _validate_weights(weights: AllocationWeights) -> None:
    values = (
        weights.heat,
        weights.air_quality,
        weights.social_need,
        weights.accessible_service_gap,
        weights.water_feasibility,
        weights.displacement_risk,
    )

    if any(not math.isfinite(value) or value < 0.0 for value in values):
        raise ValueError("All weights must be finite and non-negative.")

    if not math.isclose(sum(values), 1.0, rel_tol=1e-9, abs_tol=1e-9):
        raise ValueError("Allocation weights must sum to 1.0.")
