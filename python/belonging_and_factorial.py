from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from math import isfinite
from threading import RLock
from typing import Mapping


def require_text(value: str, field: str, maximum: int = 4096) -> None:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{field} must be non-empty text.")
    if len(value) > maximum:
        raise ValueError(f"{field} exceeds the configured limit.")


def require_count(value: int, field: str) -> None:
    if type(value) is not int or value < 0:
        raise ValueError(f"{field} must be a non-negative integer.")


class AnswerState(str, Enum):
    RATED = "rated"
    NO_OPPORTUNITY = "no_opportunity"
    DECLINED = "prefer_not_to_answer"
    MISSING = "missing"


@dataclass(frozen=True)
class OptionalAnswer:
    state: AnswerState
    rating: int | None = None

    def __post_init__(self) -> None:
        if not isinstance(self.state, AnswerState):
            raise ValueError("Unsupported response state.")
        if self.state == AnswerState.RATED:
            if type(self.rating) is not int or not 0 <= self.rating <= 10:
                raise ValueError("Rating must be an integer from zero to ten.")
        elif self.rating is not None:
            raise ValueError("Non-rated responses cannot contain a rating.")


@dataclass(frozen=True)
class SurveyResponse:
    belonging: OptionalAnswer
    contribution_confidence: OptionalAnswer
    recall_period: str
    instrument_version: str

    def __post_init__(self) -> None:
        if not isinstance(self.belonging, OptionalAnswer):
            raise ValueError("Use a validated belonging response.")
        if not isinstance(self.contribution_confidence, OptionalAnswer):
            raise ValueError("Use a validated confidence response.")
        require_text(self.recall_period, "Recall period")
        require_text(self.instrument_version, "Instrument version", 256)


class LocalSurvey:
    """Volatile local response; no export, telemetry, or persistence."""

    def __init__(self) -> None:
        self._lock = RLock()
        self._response: SurveyResponse | None = None

    def save(self, response: SurveyResponse) -> None:
        if not isinstance(response, SurveyResponse):
            raise ValueError("Use a validated survey response.")
        with self._lock:
            self._response = response

    def review(self) -> SurveyResponse | None:
        with self._lock:
            return self._response

    def delete(self) -> None:
        with self._lock:
            self._response = None


@dataclass(frozen=True)
class ItemAggregate:
    rating_counts: tuple[int, ...]
    no_opportunity: int
    declined: int
    missing: int

    def __post_init__(self) -> None:
        if type(self.rating_counts) is not tuple:
            raise ValueError("Rating counts must be an immutable tuple.")
        if len(self.rating_counts) != 11:
            raise ValueError("Provide counts for every rating from zero to ten.")
        for value in self.cells():
            require_count(value, "Aggregate cell")

    def cells(self) -> tuple[int, ...]:
        return self.rating_counts + (
            self.no_opportunity, self.declined, self.missing,
        )


def approved_item_report(
    aggregate: ItemAggregate,
    *,
    item_wording: str,
    recall_period: str,
    instrument_version: str,
    privacy_review_approved: bool,
    distinct_respondent_threshold_verified: bool,
    minimum_cohort: int,
    minimum_nonzero_cell: int,
) -> dict[str, object]:
    if not isinstance(aggregate, ItemAggregate):
        raise ValueError("Use a validated item aggregate.")
    require_text(item_wording, "Item wording")
    require_text(recall_period, "Recall period")
    require_text(instrument_version, "Instrument version", 256)

    for value in (minimum_cohort, minimum_nonzero_cell):
        if type(value) is not int or value < 1:
            raise ValueError("Release thresholds must be positive integers.")

    cells = aggregate.cells()
    permitted = (
        privacy_review_approved is True
        and distinct_respondent_threshold_verified is True
        and sum(cells) >= minimum_cohort
        and all(
            value == 0 or value >= minimum_nonzero_cell
            for value in cells
        )
    )
    if not permitted:
        return {"status": "aggregate_release_withheld"}

    rated = sum(aggregate.rating_counts)
    distribution = tuple(
        value / rated if rated else None
        for value in aggregate.rating_counts
    )
    return {
        "status": "aggregate_experience_report_not_individual_score",
        "item_wording": item_wording,
        "recall_period": recall_period,
        "instrument_version": instrument_version,
        "rating_counts": aggregate.rating_counts,
        "rated_count": rated,
        "rating_distribution": distribution,
        "no_opportunity": aggregate.no_opportunity,
        "prefer_not_to_answer": aggregate.declined,
        "missing": aggregate.missing,
    }


@dataclass(frozen=True)
class FactorialCell:
    observation_count: int
    independent_team_count: int
    mean: float | None

    def __post_init__(self) -> None:
        require_count(self.observation_count, "Observation count")
        require_count(self.independent_team_count, "Independent team count")
        if self.independent_team_count > self.observation_count:
            raise ValueError("Team count cannot exceed observation count.")
        if self.observation_count == 0:
            if self.mean is not None or self.independent_team_count != 0:
                raise ValueError("Empty cells require no mean and zero teams.")
        else:
            if self.independent_team_count < 1:
                raise ValueError("Non-empty cells require a team count.")
            if (
                isinstance(self.mean, bool)
                or not isinstance(self.mean, (int, float))
                or not isfinite(self.mean)
            ):
                raise ValueError("Non-empty cells require a finite mean.")


def factorial_contrasts(
    cells: Mapping[tuple[bool, bool], FactorialCell],
    *,
    outcome: str,
    unit: str,
) -> dict[str, object]:
    require_text(outcome, "Outcome")
    require_text(unit, "Unit", 256)

    required = {
        (False, False), (True, False),
        (False, True), (True, True),
    }
    if (
        any(
            not isinstance(key, tuple)
            or len(key) != 2
            or any(type(value) is not bool for value in key)
            for key in cells
        )
        or set(cells) != required
    ):
        raise ValueError("Provide exactly four Boolean factorial conditions.")
    if any(not isinstance(cell, FactorialCell) for cell in cells.values()):
        raise ValueError("Use validated factorial cells.")

    summary = {
        f"individual_{int(i)}_environment_{int(e)}": {
            "observations": cells[(i, e)].observation_count,
            "independent_teams": cells[(i, e)].independent_team_count,
            "mean": cells[(i, e)].mean,
        }
        for i, e in (
            (False, False), (True, False),
            (False, True), (True, True),
        )
    }

    if any(cell.mean is None for cell in cells.values()):
        return {
            "status": "not_assessable_missing_cell_outcome",
            "outcome": outcome,
            "unit": unit,
            "cells": summary,
            "causal_attribution_established": False,
        }

    baseline = float(cells[(False, False)].mean)
    individual = float(cells[(True, False)].mean)
    environment = float(cells[(False, True)].mean)
    combined = float(cells[(True, True)].mean)

    return {
        "status": "descriptive_equal_weight_contrasts",
        "outcome": outcome,
        "unit": unit,
        "cells": summary,
        "individual_effect_without_environment":
            individual - baseline,
        "individual_effect_with_environment":
            combined - environment,
        "environment_effect_without_individual":
            environment - baseline,
        "environment_effect_with_individual":
            combined - individual,
        "individual_marginal_contrast":
            ((individual - baseline) + (combined - environment)) / 2,
        "environment_marginal_contrast":
            ((environment - baseline) + (combined - individual)) / 2,
        "interaction":
            combined - individual - environment + baseline,
        "causal_attribution_established": False,
    }
