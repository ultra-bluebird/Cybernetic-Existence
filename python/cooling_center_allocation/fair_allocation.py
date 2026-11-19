from __future__ import annotations

from dataclasses import dataclass
from math import ceil
from typing import Iterable


@dataclass(frozen=True)
class PlanningArea:
    name: str
    population_estimate: int
    heat_exposure: float
    environmental_heat_burden: float
    age_related_heat_risk: float
    disability_access_need: float
    home_cooling_constraint: float
    transportation_burden: float
    service_disruption_burden: float
    cooling_resource_access: float
    water_resource_access: float
    accessible_transport_access: float
    backup_power_access: float
    uncertainty: float
    minimum_service_floor: int

    def __post_init__(self) -> None:
        if not self.name.strip():
            raise ValueError("name must not be empty.")

        if self.population_estimate < 0:
            raise ValueError("population_estimate must be non-negative.")

        if self.minimum_service_floor < 0:
            raise ValueError("minimum_service_floor must be non-negative.")

        unit_interval_fields = (
            self.heat_exposure,
            self.environmental_heat_burden,
            self.age_related_heat_risk,
            self.disability_access_need,
            self.home_cooling_constraint,
            self.transportation_burden,
            self.service_disruption_burden,
            self.cooling_resource_access,
            self.water_resource_access,
            self.accessible_transport_access,
            self.backup_power_access,
            self.uncertainty,
        )

        if any(value < 0.0 or value > 1.0 for value in unit_interval_fields):
            raise ValueError("All normalized planning factors must be within 0.0..=1.0.")


@dataclass(frozen=True)
class AllocationWeights:
    heat_exposure: float = 0.24
    environmental_heat_burden: float = 0.16
    age_related_heat_risk: float = 0.12
    disability_access_need: float = 0.12
    home_cooling_constraint: float = 0.14
    transportation_burden: float = 0.12
    service_disruption_burden: float = 0.10

    cooling_resource_access: float = 0.35
    water_resource_access: float = 0.20
    accessible_transport_access: float = 0.25
    backup_power_access: float = 0.20

    uncertainty_precaution: float = 0.15
    heat_escalation: float = 0.80

    def __post_init__(self) -> None:
        vulnerability_weight_sum = (
            self.heat_exposure
            + self.environmental_heat_burden
            + self.age_related_heat_risk
            + self.disability_access_need
            + self.home_cooling_constraint
            + self.transportation_burden
            + self.service_disruption_burden
        )

        resource_weight_sum = (
            self.cooling_resource_access
            + self.water_resource_access
            + self.accessible_transport_access
            + self.backup_power_access
        )

        if abs(vulnerability_weight_sum - 1.0) > 1e-9:
            raise ValueError("Vulnerability weights must sum to 1.0.")

        if abs(resource_weight_sum - 1.0) > 1e-9:
            raise ValueError("Protective-resource weights must sum to 1.0.")

        if self.uncertainty_precaution < 0.0:
            raise ValueError("uncertainty_precaution must be non-negative.")

        if self.heat_escalation < 0.0:
            raise ValueError("heat_escalation must be non-negative.")


@dataclass(frozen=True)
class AreaAllocation:
    area_name: str
    vulnerability_score: float
    protective_resource_score: float
    robust_unmet_need_score: float
    forecast_demand_seats: int
    allocated_seats: int
    unmet_seats: int
    minimum_service_floor: int


@dataclass(frozen=True)
class AllocationPlan:
    allocations: tuple[AreaAllocation, ...]
    total_available_seats: int
    allocated_seats: int
    reserve_seats: int

    @property
    def maximum_normalized_shortage(self) -> float:
        shortages = [
            allocation.unmet_seats / max(allocation.forecast_demand_seats, 1)
            for allocation in self.allocations
        ]
        return max(shortages, default=0.0)


def allocate_cooling_seats(
    areas: Iterable[PlanningArea],
    total_seats: int,
    forecast_heat_severity: float,
    weights: AllocationWeights = AllocationWeights(),
    reserve_fraction: float = 0.10,
) -> AllocationPlan:
    planning_areas = tuple(areas)

    if not planning_areas:
        raise ValueError("At least one planning area is required.")

    if total_seats < 0:
        raise ValueError("total_seats must be non-negative.")

    if not 0.0 <= forecast_heat_severity <= 1.0:
        raise ValueError("forecast_heat_severity must be within 0.0..=1.0.")

    if not 0.0 <= reserve_fraction < 1.0:
        raise ValueError("reserve_fraction must be within 0.0..<1.0.")

    reserve_seats = int(total_seats * reserve_fraction)
    assignable_seats = total_seats - reserve_seats

    minimum_total = sum(area.minimum_service_floor for area in planning_areas)

    if minimum_total > assignable_seats:
        raise ValueError(
            "Total seats cannot meet the defined minimum service floors after reserve."
        )

    working = []

    for area in planning_areas:
        vulnerability = _vulnerability_score(area, weights)
        protective_resources = _protective_resource_score(area, weights)
        unmet_need = max(0.0, vulnerability - protective_resources)
        robust_need = min(
            1.0,
            unmet_need + weights.uncertainty_precaution * area.uncertainty,
        )
        heat_multiplier = 1.0 + weights.heat_escalation * forecast_heat_severity
        forecast_demand = ceil(area.population_estimate * robust_need * heat_multiplier)

        working.append(
            {
                "area": area,
                "vulnerability": vulnerability,
                "protective_resources": protective_resources,
                "robust_need": robust_need,
                "forecast_demand": forecast_demand,
                "allocated": area.minimum_service_floor,
            }
        )

    remaining_seats = assignable_seats - minimum_total

    while remaining_seats > 0:
        selected = max(
            working,
            key=lambda item: _allocation_priority(item),
        )

        if selected["allocated"] >= selected["forecast_demand"]:
            candidates = [
                item
                for item in working
                if item["allocated"] < item["forecast_demand"]
            ]

            if not candidates:
                break

            selected = max(candidates, key=_allocation_priority)

        selected["allocated"] += 1
        remaining_seats -= 1

    allocations = tuple(
        AreaAllocation(
            area_name=item["area"].name,
            vulnerability_score=item["vulnerability"],
            protective_resource_score=item["protective_resources"],
            robust_unmet_need_score=item["robust_need"],
            forecast_demand_seats=item["forecast_demand"],
            allocated_seats=item["allocated"],
            unmet_seats=max(0, item["forecast_demand"] - item["allocated"]),
            minimum_service_floor=item["area"].minimum_service_floor,
        )
        for item in sorted(working, key=lambda item: item["area"].name)
    )

    return AllocationPlan(
        allocations=allocations,
        total_available_seats=total_seats,
        allocated_seats=sum(item.allocated_seats for item in allocations),
        reserve_seats=reserve_seats,
    )


def _vulnerability_score(
    area: PlanningArea,
    weights: AllocationWeights,
) -> float:
    return (
        weights.heat_exposure * area.heat_exposure
        + weights.environmental_heat_burden * area.environmental_heat_burden
        + weights.age_related_heat_risk * area.age_related_heat_risk
        + weights.disability_access_need * area.disability_access_need
        + weights.home_cooling_constraint * area.home_cooling_constraint
        + weights.transportation_burden * area.transportation_burden
        + weights.service_disruption_burden * area.service_disruption_burden
    )


def _protective_resource_score(
    area: PlanningArea,
    weights: AllocationWeights,
) -> float:
    return (
        weights.cooling_resource_access * area.cooling_resource_access
        + weights.water_resource_access * area.water_resource_access
        + weights.accessible_transport_access * area.accessible_transport_access
        + weights.backup_power_access * area.backup_power_access
    )


def _allocation_priority(item: dict[str, object]) -> tuple[float, float, str]:
    forecast_demand = int(item["forecast_demand"])
    allocated = int(item["allocated"])
    robust_need = float(item["robust_need"])
    area = item["area"]

    if not isinstance(area, PlanningArea):
        raise TypeError("Invalid planning-area record.")

    normalized_shortage = max(0, forecast_demand - allocated) / max(forecast_demand, 1)

    return (
        normalized_shortage,
        robust_need,
        area.name,
    )
