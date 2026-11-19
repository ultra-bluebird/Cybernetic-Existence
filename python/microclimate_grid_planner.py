from __future__ import annotations

from dataclasses import dataclass
from math import ceil, isfinite
from typing import Iterable


@dataclass(frozen=True)
class InterventionScale:
    minimum_width_m: float
    minimum_height_m: float
    required_measurements_per_feature: int


@dataclass(frozen=True)
class ResolutionPlan:
    cell_width_m: float
    cell_height_m: float
    cells_x: int
    cells_y: int
    total_cells: int
    recommendation: str


def plan_resolution(
    area_width_m: float,
    area_height_m: float,
    intervention: InterventionScale,
    maximum_cell_m: float = 20.0,
    minimum_cell_m: float = 5.0,
) -> ResolutionPlan:
    values: Iterable[float] = (
        area_width_m,
        area_height_m,
        intervention.minimum_width_m,
        intervention.minimum_height_m,
        maximum_cell_m,
        minimum_cell_m,
    )

    if any(not isfinite(value) or value <= 0.0 for value in values):
        raise ValueError("All lengths must be finite positive values.")

    if intervention.required_measurements_per_feature < 1:
        raise ValueError("required_measurements_per_feature must be positive.")

    feature_limit_m = min(
        intervention.minimum_width_m,
        intervention.minimum_height_m,
    ) / intervention.required_measurements_per_feature

    proposed_cell_m = min(maximum_cell_m, feature_limit_m)
    cell_m = max(minimum_cell_m, proposed_cell_m)

    if cell_m > feature_limit_m:
        recommendation = (
            "Requested resolution cannot sample the smallest intervention feature "
            "at the required density. Use a finer survey method or revise the "
            "intervention-scale requirement."
        )
    else:
        recommendation = (
            "Use this grid for intervention screening, then validate priority "
            "areas with fixed references and repeated time-of-day sampling."
        )

    cells_x = ceil(area_width_m / cell_m)
    cells_y = ceil(area_height_m / cell_m)

    return ResolutionPlan(
        cell_width_m=cell_m,
        cell_height_m=cell_m,
        cells_x=cells_x,
        cells_y=cells_y,
        total_cells=cells_x * cells_y,
        recommendation=recommendation,
    )


def area_weighted_heat_island(
    temperatures_celsius: list[float],
    valid_areas_m2: list[float],
    rural_reference_celsius: float,
) -> float:
    if len(temperatures_celsius) != len(valid_areas_m2) or not temperatures_celsius:
        raise ValueError("Temperature and area arrays must be non-empty and equal in length.")

    if not isfinite(rural_reference_celsius):
        raise ValueError("rural_reference_celsius must be finite.")

    weighted_sum = 0.0
    total_area = 0.0

    for temperature, area in zip(temperatures_celsius, valid_areas_m2, strict=True):
        if not isfinite(temperature) or not isfinite(area) or area <= 0.0:
            raise ValueError("Temperatures must be finite and areas must be finite positive values.")

        weighted_sum += temperature * area
        total_area += area

    return weighted_sum / total_area - rural_reference_celsius
