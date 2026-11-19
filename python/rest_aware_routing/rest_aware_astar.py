from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from heapq import heappop, heappush
from math import hypot
from typing import Iterable


class TaskUrgency(str, Enum):
    ROUTINE = "routine"
    PRIORITY = "priority"
    ESSENTIAL = "essential"
    EMERGENCY = "emergency"


@dataclass(frozen=True)
class Cell:
    x: int
    y: int


@dataclass(frozen=True)
class CostCell:
    traversable: bool
    distance_cost: float
    time_cost: float
    energy_cost: float
    rest_zone_weight: float
    quiet_window_weight: float
    accessibility_protection_cost: float
    hazard_cost: float
    anonymous_density_bucket: int = 0

    def __post_init__(self) -> None:
        nonnegative_values = (
            self.distance_cost,
            self.time_cost,
            self.energy_cost,
            self.rest_zone_weight,
            self.quiet_window_weight,
            self.accessibility_protection_cost,
            self.hazard_cost,
        )

        if any(value < 0.0 for value in nonnegative_values):
            raise ValueError("Cost values must be non-negative.")

        if not 0 <= self.anonymous_density_bucket <= 3:
            raise ValueError("anonymous_density_bucket must be within 0..=3.")


@dataclass(frozen=True)
class PlannerWeights:
    distance: float = 1.0
    time: float = 1.0
    energy: float = 1.0
    rest: float = 4.0
    accessibility: float = 4.0
    hazard: float = 100.0

    def __post_init__(self) -> None:
        values = (
            self.distance,
            self.time,
            self.energy,
            self.rest,
            self.accessibility,
            self.hazard,
        )

        if any(value < 0.0 for value in values):
            raise ValueError("Planner weights must be non-negative.")


@dataclass(frozen=True)
class RouteStep:
    cell: Cell
    incremental_cost: float
    distance_cost: float
    time_cost: float
    energy_cost: float
    rest_cost: float
    accessibility_cost: float
    hazard_cost: float


@dataclass(frozen=True)
class RoutePlan:
    steps: tuple[RouteStep, ...]
    total_cost: float
    total_distance_cost: float
    total_time_cost: float
    total_energy_cost: float
    total_rest_cost: float
    total_accessibility_cost: float
    total_hazard_cost: float
    urgency: TaskUrgency

    @property
    def path(self) -> tuple[Cell, ...]:
        return tuple(step.cell for step in self.steps)


class RestAwareAStar:
    def __init__(
        self,
        grid: dict[Cell, CostCell],
        weights: PlannerWeights,
        width: int,
        height: int,
    ) -> None:
        if width <= 0 or height <= 0:
            raise ValueError("Grid dimensions must be positive.")

        self._grid = dict(grid)
        self._weights = weights
        self._width = width
        self._height = height

    def plan(
        self,
        start: Cell,
        goal: Cell,
        urgency: TaskUrgency,
    ) -> RoutePlan | None:
        self._validate_cell(start)
        self._validate_cell(goal)

        if not self._is_traversable(start) or not self._is_traversable(goal):
            return None

        open_set: list[tuple[float, int, Cell]] = []
        sequence = 0
        heappush(open_set, (0.0, sequence, start))

        came_from: dict[Cell, Cell] = {}
        cost_to: dict[Cell, float] = {start: 0.0}
        step_costs: dict[Cell, RouteStep] = {
            start: RouteStep(
                cell=start,
                incremental_cost=0.0,
                distance_cost=0.0,
                time_cost=0.0,
                energy_cost=0.0,
                rest_cost=0.0,
                accessibility_cost=0.0,
                hazard_cost=0.0,
            )
        }

        while open_set:
            _, _, current = heappop(open_set)

            if current == goal:
                return self._build_plan(
                    start=start,
                    goal=goal,
                    urgency=urgency,
                    came_from=came_from,
                    step_costs=step_costs,
                )

            for neighbor in self._neighbors(current):
                if not self._is_traversable(neighbor):
                    continue

                route_step = self._step_cost(neighbor, urgency)
                tentative_cost = cost_to[current] + route_step.incremental_cost

                if tentative_cost >= cost_to.get(neighbor, float("inf")):
                    continue

                came_from[neighbor] = current
                cost_to[neighbor] = tentative_cost
                step_costs[neighbor] = route_step
                sequence += 1
                estimated_total = tentative_cost + self._heuristic(neighbor, goal)
                heappush(open_set, (estimated_total, sequence, neighbor))

        return None

    def _step_cost(self, cell: Cell, urgency: TaskUrgency) -> RouteStep:
        cost_cell = self._grid[cell]
        urgency_multiplier = self._rest_urgency_multiplier(urgency)
        density = cost_cell.anonymous_density_bucket / 3.0

        distance_cost = self._weights.distance * cost_cell.distance_cost
        time_cost = self._weights.time * cost_cell.time_cost
        energy_cost = self._weights.energy * cost_cell.energy_cost
        rest_cost = (
            self._weights.rest
            * cost_cell.rest_zone_weight
            * cost_cell.quiet_window_weight
            * density
            * urgency_multiplier
        )
        accessibility_cost = (
            self._weights.accessibility * cost_cell.accessibility_protection_cost
        )
        hazard_cost = self._weights.hazard * cost_cell.hazard_cost

        incremental_cost = (
            distance_cost
            + time_cost
            + energy_cost
            + rest_cost
            + accessibility_cost
            + hazard_cost
        )

        return RouteStep(
            cell=cell,
            incremental_cost=incremental_cost,
            distance_cost=distance_cost,
            time_cost=time_cost,
            energy_cost=energy_cost,
            rest_cost=rest_cost,
            accessibility_cost=accessibility_cost,
            hazard_cost=hazard_cost,
        )

    @staticmethod
    def _rest_urgency_multiplier(urgency: TaskUrgency) -> float:
        if urgency is TaskUrgency.ROUTINE:
            return 1.0
        if urgency is TaskUrgency.PRIORITY:
            return 0.65
        if urgency is TaskUrgency.ESSENTIAL:
            return 0.20
        if urgency is TaskUrgency.EMERGENCY:
            return 0.0
        raise ValueError(f"Unsupported urgency: {urgency}")

    def _build_plan(
        self,
        start: Cell,
        goal: Cell,
        urgency: TaskUrgency,
        came_from: dict[Cell, Cell],
        step_costs: dict[Cell, RouteStep],
    ) -> RoutePlan:
        reverse_path = [goal]
        current = goal

        while current != start:
            current = came_from[current]
            reverse_path.append(current)

        path = tuple(reversed(reverse_path))
        steps = tuple(step_costs[cell] for cell in path)

        return RoutePlan(
            steps=steps,
            total_cost=sum(step.incremental_cost for step in steps),
            total_distance_cost=sum(step.distance_cost for step in steps),
            total_time_cost=sum(step.time_cost for step in steps),
            total_energy_cost=sum(step.energy_cost for step in steps),
            total_rest_cost=sum(step.rest_cost for step in steps),
            total_accessibility_cost=sum(
                step.accessibility_cost for step in steps
            ),
            total_hazard_cost=sum(step.hazard_cost for step in steps),
            urgency=urgency,
        )

    def _neighbors(self, cell: Cell) -> Iterable[Cell]:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            candidate = Cell(cell.x + dx, cell.y + dy)
            if 0 <= candidate.x < self._width and 0 <= candidate.y < self._height:
                yield candidate

    def _heuristic(self, current: Cell, goal: Cell) -> float:
        return hypot(goal.x - current.x, goal.y - current.y) * self._weights.distance

    def _is_traversable(self, cell: Cell) -> bool:
        cost_cell = self._grid.get(cell)
        return cost_cell is not None and cost_cell.traversable

    def _validate_cell(self, cell: Cell) -> None:
        if not (0 <= cell.x < self._width and 0 <= cell.y < self._height):
            raise ValueError("Cell is outside the grid.")
