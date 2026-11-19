from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from statistics import mean
from typing import Callable, Iterable


@dataclass(frozen=True)
class TemperatureObservation:
    h3_cell: str
    observed_temperature_c: float
    predicted_temperature_c: float
    independent_sensor_id: str
    observation_day: str
    heat_event_id: str


@dataclass(frozen=True)
class ResolutionEvaluation:
    resolution: int
    sample_count: int
    sensor_count: int
    day_count: int
    heat_event_count: int
    mean_absolute_error_c: float
    mean_bias_c: float
    coverage_fraction: float
    eligible: bool


def _require_finite(name: str, value: float) -> None:
    if not isfinite(value):
        raise ValueError(f"{name} must be finite.")


def mean_absolute_error(observations: Iterable[TemperatureObservation]) -> float:
    values = list(observations)

    if not values:
        raise ValueError("At least one observation is required.")

    absolute_errors = []

    for observation in values:
        _require_finite(
            "observed_temperature_c",
            observation.observed_temperature_c,
        )
        _require_finite(
            "predicted_temperature_c",
            observation.predicted_temperature_c,
        )
        absolute_errors.append(
            abs(
                observation.predicted_temperature_c
                - observation.observed_temperature_c
            )
        )

    return mean(absolute_errors)


def mean_bias(observations: Iterable[TemperatureObservation]) -> float:
    values = list(observations)

    if not values:
        raise ValueError("At least one observation is required.")

    errors = []

    for observation in values:
        _require_finite(
            "observed_temperature_c",
            observation.observed_temperature_c,
        )
        _require_finite(
            "predicted_temperature_c",
            observation.predicted_temperature_c,
        )
        errors.append(
            observation.predicted_temperature_c
            - observation.observed_temperature_c
        )

    return mean(errors)


def evaluate_resolution(
    resolution: int,
    observations: Iterable[TemperatureObservation],
    expected_h3_cells: set[str],
    minimum_observations_per_cell: int,
    mae_target_c: float = 0.5,
    minimum_coverage_fraction: float = 0.8,
) -> ResolutionEvaluation:
    if resolution < 0 or resolution > 15:
        raise ValueError("H3 resolution must be between 0 and 15.")

    if not expected_h3_cells:
        raise ValueError("expected_h3_cells must not be empty.")

    if minimum_observations_per_cell < 1:
        raise ValueError("minimum_observations_per_cell must be at least one.")

    values = list(observations)

    if not values:
        raise ValueError("Observations must not be empty.")

    observations_by_cell: dict[str, int] = {}

    for observation in values:
        observations_by_cell[observation.h3_cell] = (
            observations_by_cell.get(observation.h3_cell, 0) + 1
        )

    covered_cells = {
        cell
        for cell in expected_h3_cells
        if observations_by_cell.get(cell, 0) >= minimum_observations_per_cell
    }

    coverage_fraction = len(covered_cells) / len(expected_h3_cells)
    mae_c = mean_absolute_error(values)
    bias_c = mean_bias(values)

    return ResolutionEvaluation(
        resolution=resolution,
        sample_count=len(values),
        sensor_count=len({value.independent_sensor_id for value in values}),
        day_count=len({value.observation_day for value in values}),
        heat_event_count=len({value.heat_event_id for value in values}),
        mean_absolute_error_c=mae_c,
        mean_bias_c=bias_c,
        coverage_fraction=coverage_fraction,
        eligible=(
            mae_c < mae_target_c
            and coverage_fraction >= minimum_coverage_fraction
        ),
    )


def select_coarsest_eligible_resolution(
    resolutions: Iterable[int],
    observation_provider: Callable[[int], Iterable[TemperatureObservation]],
    expected_cells_provider: Callable[[int], set[str]],
    minimum_observations_per_cell: int,
    mae_target_c: float = 0.5,
    minimum_coverage_fraction: float = 0.8,
) -> tuple[ResolutionEvaluation, tuple[ResolutionEvaluation, ...]]:
    evaluations = []

    for resolution in sorted(set(resolutions)):
        evaluation = evaluate_resolution(
            resolution=resolution,
            observations=observation_provider(resolution),
            expected_h3_cells=expected_cells_provider(resolution),
            minimum_observations_per_cell=minimum_observations_per_cell,
            mae_target_c=mae_target_c,
            minimum_coverage_fraction=minimum_coverage_fraction,
        )
        evaluations.append(evaluation)

    eligible = [evaluation for evaluation in evaluations if evaluation.eligible]

    if not eligible:
        raise ValueError(
            "No tested H3 resolution meets the pre-registered MAE and "
            "coverage criteria. Expand or recalibrate the sensor network "
            "before using a grid for heat-service decisions."
        )

    return eligible[0], tuple(evaluations)
