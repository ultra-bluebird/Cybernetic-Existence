from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
import heapq
from math import hypot
from typing import Iterable


class RouteStatus(str, Enum):
    ROUTE_COMPARISON_AVAILABLE = "ROUTE_COMPARISON_AVAILABLE"
    ROUTE_COMPARISON_REVIEW_REQUIRED = "ROUTE_COMPARISON_REVIEW_REQUIRED"
    INSUFFICIENT_ROUTE_CONTEXT = "INSUFFICIENT_ROUTE_CONTEXT"


@dataclass(frozen=True)
class RouteWeights:
    distance_weight: float
    uv_dose_weight: float
    uncertainty_weight: float
    accessibility_weight: float


@dataclass(frozen=True)
class PedestrianNode:
    node_id: str
    x: float
    y: float


@dataclass(frozen=True)
class PedestrianEdge:
    edge_id: str
    from_node_id: str
    to_node_id: str
    normalized_distance: float
    normalized_travel_duration: float
    building_shade_fraction: float
    canopy_shade_fraction: float
    uncertainty: float
    accessibility_barrier: float


@dataclass(frozen=True)
class RouteContext:
    normalized_uv_index: float
    forecast_fresh: bool
    shade_provenance_available: bool
    accessibility_context_complete: bool
    uncertainty_within_review_limit: bool
    advisory_only: bool
    human_review_required: bool


@dataclass(frozen=True)
class RouteResult:
    status: RouteStatus
    path_edge_ids: tuple[str, ...]
    total_cost: float | None
    modeled_uv_dose: float | None
    explanation: str


def _unit_interval(value: float, field: str) -> None:
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        raise ValueError(f"{field} must be numeric.")
    if not 0.0 <= float(value) <= 1.0:
        raise ValueError(f"{field} must be in [0, 1].")


def _validate_weights(weights: RouteWeights) -> None:
    values = (
        weights.distance_weight,
        weights.uv_dose_weight,
        weights.uncertainty_weight,
        weights.accessibility_weight,
    )

    for value, name in zip(
        values,
        (
            "distance_weight",
            "uv_dose_weight",
            "uncertainty_weight",
            "accessibility_weight",
        ),
        strict=True,
    ):
        _unit_interval(value, name)

    if abs(sum(values) - 1.0) > 1.0e-12:
        raise ValueError("Route weights must sum exactly to 1.0.")


def shade_fraction(edge: PedestrianEdge) -> float:
    _unit_interval(edge.building_shade_fraction, "building_shade_fraction")
    _unit_interval(edge.canopy_shade_fraction, "canopy_shade_fraction")

    return 1.0 - (
        (1.0 - edge.building_shade_fraction)
        * (1.0 - edge.canopy_shade_fraction)
    )


def modeled_uv_dose(edge: PedestrianEdge, normalized_uv_index: float) -> float:
    _unit_interval(normalized_uv_index, "normalized_uv_index")
    _unit_interval(edge.normalized_travel_duration, "normalized_travel_duration")

    return normalized_uv_index * edge.normalized_travel_duration * (1.0 - shade_fraction(edge))


def edge_cost(
    edge: PedestrianEdge,
    weights: RouteWeights,
    context: RouteContext,
) -> float:
    for value, name in (
        (edge.normalized_distance, "normalized_distance"),
        (edge.uncertainty, "uncertainty"),
        (edge.accessibility_barrier, "accessibility_barrier"),
    ):
        _unit_interval(value, name)

    return (
        weights.distance_weight * edge.normalized_distance
        + weights.uv_dose_weight * modeled_uv_dose(edge, context.normalized_uv_index)
        + weights.uncertainty_weight * edge.uncertainty
        + weights.accessibility_weight * edge.accessibility_barrier
    )


def route_cost_heuristic(
    current: PedestrianNode,
    goal: PedestrianNode,
    distance_weight: float,
) -> float:
    return distance_weight * hypot(goal.x - current.x, goal.y - current.y)


def find_low_exposure_route(
    nodes: Iterable[PedestrianNode],
    edges: Iterable[PedestrianEdge],
    start_node_id: str,
    end_node_id: str,
    weights: RouteWeights,
    context: RouteContext,
) -> RouteResult:
    _validate_weights(weights)
    _unit_interval(context.normalized_uv_index, "normalized_uv_index")

    if not (
        context.forecast_fresh
        and context.shade_provenance_available
        and context.accessibility_context_complete
        and context.uncertainty_within_review_limit
        and context.advisory_only
        and context.human_review_required
    ):
        return RouteResult(
            status=RouteStatus.ROUTE_COMPARISON_REVIEW_REQUIRED,
            path_edge_ids=(),
            total_cost=None,
            modeled_uv_dose=None,
            explanation=(
                "Required route, shade, accessibility, uncertainty, forecast, or "
                "advisory-governance context is incomplete. No route comparison is released."
            ),
        )

    node_by_id = {node.node_id: node for node in nodes}
    if start_node_id not in node_by_id or end_node_id not in node_by_id:
        raise ValueError("Start and end nodes must exist in the supplied synthetic graph.")

    outgoing: dict[str, list[PedestrianEdge]] = {}
    for edge in edges:
        if edge.from_node_id not in node_by_id or edge.to_node_id not in node_by_id:
            raise ValueError("Each edge must reference known graph nodes.")
        outgoing.setdefault(edge.from_node_id, []).append(edge)

    distances = {node_id: float("inf") for node_id in node_by_id}
    uv_doses = {node_id: 0.0 for node_id in node_by_id}
    previous: dict[str, PedestrianEdge] = {}

    distances[start_node_id] = 0.0
    queue: list[tuple[float, float, str]] = [
        (
            route_cost_heuristic(
                node_by_id[start_node_id],
                node_by_id[end_node_id],
                weights.distance_weight,
            ),
            0.0,
            start_node_id,
        )
    ]

    while queue:
        _, current_cost, current_node_id = heapq.heappop(queue)

        if current_cost != distances[current_node_id]:
            continue

        if current_node_id == end_node_id:
            break

        for edge in outgoing.get(current_node_id, []):
            candidate_cost = current_cost + edge_cost(edge, weights, context)
            candidate_uv_dose = uv_doses[current_node_id] + modeled_uv_dose(
                edge,
                context.normalized_uv_index,
            )

            if candidate_cost < distances[edge.to_node_id]:
                distances[edge.to_node_id] = candidate_cost
                uv_doses[edge.to_node_id] = candidate_uv_dose
                previous[edge.to_node_id] = edge

                heuristic = route_cost_heuristic(
                    node_by_id[edge.to_node_id],
                    node_by_id[end_node_id],
                    weights.distance_weight,
                )
                heapq.heappush(
                    queue,
                    (
                        candidate_cost + heuristic,
                        candidate_cost,
                        edge.to_node_id,
                    ),
                )

    if distances[end_node_id] == float("inf"):
        return RouteResult(
            status=RouteStatus.INSUFFICIENT_ROUTE_CONTEXT,
            path_edge_ids=(),
            total_cost=None,
            modeled_uv_dose=None,
            explanation=(
                "No route exists in the supplied abstract pedestrian graph. "
                "This is not a travel instruction or safety determination."
            ),
        )

    path: list[str] = []
    cursor = end_node_id

    while cursor != start_node_id:
        edge = previous.get(cursor)
        if edge is None:
            return RouteResult(
                status=RouteStatus.ROUTE_COMPARISON_REVIEW_REQUIRED,
                path_edge_ids=(),
                total_cost=None,
                modeled_uv_dose=None,
                explanation="Route reconstruction was incomplete and requires review.",
            )
        path.append(edge.edge_id)
        cursor = edge.from_node_id

    path.reverse()

    return RouteResult(
        status=RouteStatus.ROUTE_COMPARISON_AVAILABLE,
        path_edge_ids=tuple(path),
        total_cost=distances[end_node_id],
        modeled_uv_dose=uv_doses[end_node_id],
        explanation=(
            "This is an advisory comparison of supplied pedestrian-network segments "
            "using modeled distance, shade, UV, uncertainty, and accessibility costs. "
            "It is not a safety guarantee, medical assessment, or travel command."
        ),
    )
