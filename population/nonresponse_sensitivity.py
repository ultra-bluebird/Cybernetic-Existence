"""Stratified missing-outcome sensitivity calculations.

Python 3.10 or newer; standard library only.

Assumes a defined finite frame and eligible sampled units.
Does not repair unknown selection probabilities or establish representativeness.
No data collection, network access, or external action.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

from dataclasses import dataclass
import math


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

META = {
    "schema_version": "1.0.0",
    "sovereign_attribution": ATTRIBUTION,
    "attribution_use": "document_credit_only",
    "interpretation": "sensitivity_scenario_not_population_validation",
}


@dataclass(frozen=True)
class Cell:
    label: str
    population: int
    eligible_draws: int
    observed: int
    barriers: int


def validate(cells):
    if type(cells) is not tuple or not 1 <= len(cells) <= 64:
        raise ValueError("cell_tuple_required")

    labels = []

    for cell in cells:
        if (
            type(cell) is not Cell
            or type(cell.label) is not str
            or not cell.label.strip()
        ):
            raise ValueError("cell_type_or_label")

        counts = (
            cell.population,
            cell.eligible_draws,
            cell.observed,
            cell.barriers,
        )

        if any(type(value) is not int for value in counts):
            raise ValueError("integer_counts_required")

        if not (
            1 <= cell.eligible_draws <= cell.population <= 1_000_000_000
            and 0 <= cell.barriers <= cell.observed <= cell.eligible_draws
        ):
            raise ValueError("inconsistent_counts")

        labels.append(cell.label)

    if len(set(labels)) != len(labels):
        raise ValueError("duplicate_label")


def scenario(cells, missing_rates):
    validate(cells)

    if type(missing_rates) is not tuple or len(missing_rates) != len(cells):
        raise ValueError("scenario_dimensions")

    if any(
        type(rate) not in (int, float)
        or not math.isfinite(rate)
        or not 0 <= rate <= 1
        for rate in missing_rates
    ):
        raise ValueError("probability_required")

    total = sum(
        cell.population
        * (
            cell.barriers
            + (cell.eligible_draws - cell.observed) * rate
        )
        / cell.eligible_draws
        for cell, rate in zip(cells, missing_rates)
    )

    baseline = (
        None
        if any(cell.observed == 0 for cell in cells)
        else sum(
            cell.population * cell.barriers / cell.observed
            for cell in cells
        )
    )

    return {
        **META,
        "estimated_affected_scenario": total,
        "scenario_prevalence": total / sum(c.population for c in cells),
        "respondent_only_estimate": baseline,
        "change_from_respondent_only": (
            None if baseline is None else total - baseline
        ),
    }


def common_rate_tip(cells, target):
    validate(cells)

    if type(target) not in (int, float) or not math.isfinite(target):
        raise ValueError("finite_target_required")

    lower = scenario(
        cells, (0.0,) * len(cells)
    )["estimated_affected_scenario"]
    upper = scenario(
        cells, (1.0,) * len(cells)
    )["estimated_affected_scenario"]

    slope = upper - lower

    if slope == 0:
        return {
            **META,
            "status": (
                "no_missing_outcome_sensitivity"
                if math.isclose(target, lower)
                else "target_unattainable"
            ),
            "missing_rate": None,
            "range": [lower, upper],
        }

    rate = (target - lower) / slope
    attainable = 0 <= rate <= 1

    return {
        **META,
        "status": "attainable" if attainable else "target_unattainable",
        "missing_rate": rate if attainable else None,
        "range": [lower, upper],
    }


def uniform_delta_tip(cells, target):
    validate(cells)

    if type(target) not in (int, float) or not math.isfinite(target):
        raise ValueError("finite_target_required")
    if any(cell.observed == 0 for cell in cells):
        raise ValueError("respondent_baseline_undefined")

    rates = tuple(cell.barriers / cell.observed for cell in cells)

    def missing_rates(delta):
        return tuple(
            min(1.0, max(0.0, rate + delta))
            for rate in rates
        )

    def at(delta):
        return scenario(
            cells, missing_rates(delta)
        )["estimated_affected_scenario"]

    lower, upper = at(-1.0), at(1.0)

    if target < lower or target > upper:
        return {
            **META,
            "status": "target_unattainable",
            "delta": None,
            "range": [lower, upper],
        }

    if lower == upper:
        return {
            **META,
            "status": "no_missing_outcome_sensitivity",
            "delta": None,
            "range": [lower, upper],
        }

    left, right = -1.0, 1.0

    for _ in range(100):
        middle = (left + right) / 2
        if at(middle) < target:
            left = middle
        else:
            right = middle

    delta = (left + right) / 2

    return {
        **META,
        "status": "attainable",
        "delta": delta,
        "missing_rates": missing_rates(delta),
        "estimated_affected_scenario": at(delta),
    }
