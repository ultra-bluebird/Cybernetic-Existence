from __future__ import annotations

from dataclasses import dataclass
from math import exp, isfinite
from typing import Iterable, Sequence


@dataclass(frozen=True)
class Point:
    x_m: float
    y_m: float

    def distance_to(self, other: "Point") -> float:
        dx = self.x_m - other.x_m
        dy = self.y_m - other.y_m
        return (dx * dx + dy * dy) ** 0.5


@dataclass(frozen=True)
class PlanningCell:
    location: Point
    area_m2: float
    priority_weight: float = 1.0

    def __post_init__(self) -> None:
        if not isfinite(self.area_m2) or self.area_m2 <= 0.0:
            raise ValueError("area_m2 must be finite and greater than zero")
        if not isfinite(self.priority_weight) or self.priority_weight < 0.0:
            raise ValueError("priority_weight must be finite and nonnegative")


@dataclass(frozen=True)
class SensorCandidate:
    location: Point
    installation_cost: float
    annual_energy_wh: float

    def __post_init__(self) -> None:
        if not isfinite(self.installation_cost) or self.installation_cost < 0.0:
            raise ValueError("installation_cost must be finite and nonnegative")
        if not isfinite(self.annual_energy_wh) or self.annual_energy_wh < 0.0:
            raise ValueError("annual_energy_wh must be finite and nonnegative")


@dataclass(frozen=True)
class PlacementResult:
    selected: tuple[SensorCandidate, ...]
    weighted_coverage: float
    priority_coverage: float
    total_installation_cost: float
    total_annual_energy_wh: float


@dataclass
class RecursiveLeastSquares:
    alpha: float = 1.0
    beta: float = 0.0
    p00: float = 1_000.0
    p01: float = 0.0
    p10: float = 0.0
    p11: float = 1_000.0
    forgetting_factor: float = 0.995

    def __post_init__(self) -> None:
        if not 0.0 < self.forgetting_factor <= 1.0:
            raise ValueError("forgetting_factor must be in the interval (0, 1]")
        for value in (
            self.alpha,
            self.beta,
            self.p00,
            self.p01,
            self.p10,
            self.p11,
        ):
            if not isfinite(value):
                raise ValueError("recursive least squares parameters must be finite")

    def correct(self, raw_temperature_c: float) -> float:
        if not isfinite(raw_temperature_c):
            raise ValueError("raw_temperature_c must be finite")
        return self.alpha * raw_temperature_c + self.beta

    def update(self, raw_temperature_c: float, reference_temperature_c: float) -> float:
        if not isfinite(raw_temperature_c) or not isfinite(reference_temperature_c):
            raise ValueError("calibration observations must be finite")

        phi0 = raw_temperature_c
        phi1 = 1.0

        p_phi0 = self.p00 * phi0 + self.p01 * phi1
        p_phi1 = self.p10 * phi0 + self.p11 * phi1

        denominator = (
            self.forgetting_factor
            + phi0 * p_phi0
            + phi1 * p_phi1
        )

        if denominator <= 0.0 or not isfinite(denominator):
            raise ValueError("invalid recursive least squares denominator")

        gain0 = p_phi0 / denominator
        gain1 = p_phi1 / denominator

        prediction = self.correct(raw_temperature_c)
        residual = reference_temperature_c - prediction

        self.alpha += gain0 * residual
        self.beta += gain1 * residual

        phi_t_p0 = phi0 * self.p00 + phi1 * self.p10
        phi_t_p1 = phi0 * self.p01 + phi1 * self.p11

        self.p00 = (self.p00 - gain0 * phi_t_p0) / self.forgetting_factor
        self.p01 = (self.p01 - gain0 * phi_t_p1) / self.forgetting_factor
        self.p10 = (self.p10 - gain1 * phi_t_p0) / self.forgetting_factor
        self.p11 = (self.p11 - gain1 * phi_t_p1) / self.forgetting_factor

        return residual


def distance_weight(distance_m: float, correlation_length_m: float) -> float:
    if not isfinite(distance_m) or distance_m < 0.0:
        raise ValueError("distance_m must be finite and nonnegative")
    if not isfinite(correlation_length_m) or correlation_length_m <= 0.0:
        raise ValueError("correlation_length_m must be finite and greater than zero")
    return exp(-distance_m / correlation_length_m)


def nearest_sensor_distance(
    cell: PlanningCell,
    sensors: Sequence[SensorCandidate],
) -> float:
    if not sensors:
        return float("inf")
    return min(cell.location.distance_to(sensor.location) for sensor in sensors)


def weighted_coverage(
    cells: Sequence[PlanningCell],
    sensors: Sequence[SensorCandidate],
    correlation_length_m: float,
) -> float:
    if not cells:
        raise ValueError("cells must not be empty")

    total_area = sum(cell.area_m2 for cell in cells)
    weighted_area = 0.0

    for cell in cells:
        distance_m = nearest_sensor_distance(cell, sensors)
        weight = 0.0 if distance_m == float("inf") else distance_weight(
            distance_m,
            correlation_length_m,
        )
        weighted_area += cell.area_m2 * weight

    return weighted_area / total_area


def priority_coverage(
    cells: Sequence[PlanningCell],
    sensors: Sequence[SensorCandidate],
    correlation_length_m: float,
) -> float:
    if not cells:
        raise ValueError("cells must not be empty")

    total_weighted_area = sum(
        cell.area_m2 * cell.priority_weight for cell in cells
    )

    if total_weighted_area == 0.0:
        return 0.0

    covered_weighted_area = 0.0

    for cell in cells:
        distance_m = nearest_sensor_distance(cell, sensors)
        weight = 0.0 if distance_m == float("inf") else distance_weight(
            distance_m,
            correlation_length_m,
        )
        covered_weighted_area += cell.area_m2 * cell.priority_weight * weight

    return covered_weighted_area / total_weighted_area


def select_greedy_sensor_grid(
    cells: Sequence[PlanningCell],
    candidates: Sequence[SensorCandidate],
    sensor_budget: int,
    correlation_length_m: float,
    cost_penalty: float = 0.0,
    energy_penalty: float = 0.0,
) -> PlacementResult:
    if sensor_budget < 0:
        raise ValueError("sensor_budget must be nonnegative")
    if not candidates or sensor_budget == 0:
        return PlacementResult(
            selected=(),
            weighted_coverage=weighted_coverage(cells, (), correlation_length_m),
            priority_coverage=priority_coverage(cells, (), correlation_length_m),
            total_installation_cost=0.0,
            total_annual_energy_wh=0.0,
        )
    if not isfinite(cost_penalty) or cost_penalty < 0.0:
        raise ValueError("cost_penalty must be finite and nonnegative")
    if not isfinite(energy_penalty) or energy_penalty < 0.0:
        raise ValueError("energy_penalty must be finite and nonnegative")

    selected: list[SensorCandidate] = []
    available = list(candidates)

    while available and len(selected) < sensor_budget:
        current_priority = priority_coverage(
            cells,
            selected,
            correlation_length_m,
        )

        best_candidate: SensorCandidate | None = None
        best_score = float("-inf")

        for candidate in available:
            trial = [*selected, candidate]
            coverage_gain = (
                priority_coverage(cells, trial, correlation_length_m)
                - current_priority
            )
            score = (
                coverage_gain
                - cost_penalty * candidate.installation_cost
                - energy_penalty * candidate.annual_energy_wh
            )

            if score > best_score:
                best_score = score
                best_candidate = candidate

        if best_candidate is None:
            break

        selected.append(best_candidate)
        available.remove(best_candidate)

    return PlacementResult(
        selected=tuple(selected),
        weighted_coverage=weighted_coverage(
            cells,
            selected,
            correlation_length_m,
        ),
        priority_coverage=priority_coverage(
            cells,
            selected,
            correlation_length_m,
        ),
        total_installation_cost=sum(
            sensor.installation_cost for sensor in selected
        ),
        total_annual_energy_wh=sum(
            sensor.annual_energy_wh for sensor in selected
        ),
    )


def quality_flag(
    temperature_c: float,
    relative_humidity_percent: float,
    minimum_temperature_c: float,
    maximum_temperature_c: float,
) -> str:
    if not isfinite(temperature_c) or not isfinite(relative_humidity_percent):
        return "invalid_non_finite"
    if not minimum_temperature_c <= temperature_c <= maximum_temperature_c:
        return "temperature_out_of_range"
    if not 0.0 <= relative_humidity_percent <= 100.0:
        return "humidity_out_of_range"
    return "accepted"


def batch_correct(
    raw_temperatures_c: Iterable[float],
    calibrator: RecursiveLeastSquares,
) -> list[float]:
    return [calibrator.correct(raw) for raw in raw_temperatures_c]
