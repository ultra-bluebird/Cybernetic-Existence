from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

import cvxpy as cp


AllocationMode = Literal["nash_social_welfare", "minimax_fairness"]


@dataclass(frozen=True)
class PlanningGroup:
    group_id: str
    need_units: float
    baseline_floor_units: float
    maximum_absorption_units: float
    accessible_delivery_capacity: float
    evidence_quality: float
    equity_weight: float
    delivery_cost_per_unit: float


@dataclass(frozen=True)
class AllocationResult:
    status: str
    allocations: dict[str, float]
    service_levels: dict[str, float]
    objective_value: float | None
    maximum_weighted_shortfall: float | None
    explanation: str


def bounded_unit(value: float) -> float:
    return max(0.0, min(1.0, float(value)))


def solve_fair_allocation(
    groups: list[PlanningGroup],
    total_resource_units: float,
    total_delivery_budget: float,
    mode: AllocationMode = "nash_social_welfare",
    epsilon: float = 1e-5,
) -> AllocationResult:
    if not groups:
        raise ValueError("at least one planning group is required")
    if total_resource_units < 0.0 or total_delivery_budget < 0.0:
        raise ValueError("resource and delivery budgets must be non-negative")
    if epsilon <= 0.0:
        raise ValueError("epsilon must be positive")

    group_count = len(groups)
    need = [max(0.0, group.need_units) for group in groups]
    floor = [max(0.0, group.baseline_floor_units) for group in groups]
    maximum = [
        max(
            0.0,
            min(
                group.need_units,
                group.maximum_absorption_units,
                group.accessible_delivery_capacity,
            ),
        )
        for group in groups
    ]
    quality = [bounded_unit(group.evidence_quality) for group in groups]
    weights = [max(0.0, group.equity_weight) for group in groups]
    costs = [max(0.0, group.delivery_cost_per_unit) for group in groups]

    if any(floor[index] > maximum[index] for index in range(group_count)):
        return AllocationResult(
            status="human_emergency_review_required",
            allocations={},
            service_levels={},
            objective_value=None,
            maximum_weighted_shortfall=None,
            explanation="A published baseline floor exceeds accessible delivery or absorptive capacity.",
        )

    if sum(floor) > total_resource_units:
        return AllocationResult(
            status="human_emergency_review_required",
            allocations={},
            service_levels={},
            objective_value=None,
            maximum_weighted_shortfall=None,
            explanation="Available resource cannot meet all published baseline service floors.",
        )

    if sum(costs[index] * floor[index] for index in range(group_count)) > total_delivery_budget:
        return AllocationResult(
            status="human_emergency_review_required",
            allocations={},
            service_levels={},
            objective_value=None,
            maximum_weighted_shortfall=None,
            explanation="Available delivery budget cannot meet all published baseline service floors.",
        )

    allocation = cp.Variable(group_count, nonneg=True)
    service_level = cp.hstack([
        quality[index] * allocation[index] / max(need[index], epsilon)
        for index in range(group_count)
    ])

    constraints = [
        allocation >= floor,
        allocation <= maximum,
        cp.sum(allocation) <= total_resource_units,
        cp.sum(cp.multiply(costs, allocation)) <= total_delivery_budget,
    ]

    weighted_shortfall = cp.hstack([
        weights[index] * (1.0 - service_level[index])
        for index in range(group_count)
    ])
    maximum_shortfall = cp.Variable(nonneg=True)
    constraints.append(weighted_shortfall <= maximum_shortfall)

    minimax_problem = cp.Problem(cp.Minimize(maximum_shortfall), constraints)
    minimax_problem.solve(solver=cp.CLARABEL)

    if minimax_problem.status not in {"optimal", "optimal_inaccurate"}:
        return AllocationResult(
            status="human_emergency_review_required",
            allocations={},
            service_levels={},
            objective_value=None,
            maximum_weighted_shortfall=None,
            explanation="The fairness-constrained allocation could not be solved reliably.",
        )

    minimax_value = float(maximum_shortfall.value)
    minimax_constraint = maximum_shortfall <= minimax_value + 1e-6
    refined_constraints = [*constraints, minimax_constraint]

    if mode == "minimax_fairness":
        allocation_value = allocation.value
        objective_value = minimax_value
    else:
        nash_utility = cp.sum(cp.multiply(
            weights,
            cp.log(service_level + epsilon),
        ))
        nash_problem = cp.Problem(cp.Maximize(nash_utility), refined_constraints)
        nash_problem.solve(solver=cp.CLARABEL)

        if nash_problem.status not in {"optimal", "optimal_inaccurate"}:
            return AllocationResult(
                status="human_emergency_review_required",
                allocations={},
                service_levels={},
                objective_value=None,
                maximum_weighted_shortfall=minimax_value,
                explanation="The Nash refinement could not be solved reliably after fairness protection.",
            )

        allocation_value = allocation.value
        objective_value = float(nash_problem.value)

    allocations = {
        group.group_id: round(float(allocation_value[index]), 6)
        for index, group in enumerate(groups)
    }
    service_levels = {
        group.group_id: round(
            bounded_unit(
                quality[index] * float(allocation_value[index]) / max(need[index], epsilon)
            ),
            6,
        )
        for index, group in enumerate(groups)
    }

    return AllocationResult(
        status="candidate_for_human_review",
        allocations=allocations,
        service_levels=service_levels,
        objective_value=objective_value,
        maximum_weighted_shortfall=minimax_value,
        explanation=(
            "Baseline floors passed. Allocation minimizes the maximum weighted "
            "shortfall and applies the selected fairness objective."
        ),
    )
