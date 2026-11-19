from __future__ import annotations

from dataclasses import dataclass
from math import isfinite, sqrt
from typing import Iterable, Mapping, Sequence


class MetricsValidationError(ValueError):
    pass


@dataclass(frozen=True)
class BinaryOutcomes:
    true_positive: int
    false_positive: int
    true_negative: int
    false_negative: int

    def __post_init__(self) -> None:
        values = (
            self.true_positive,
            self.false_positive,
            self.true_negative,
            self.false_negative,
        )
        if any(not isinstance(value, int) or value < 0 for value in values):
            raise MetricsValidationError("All confusion-matrix values must be non-negative integers.")

    @property
    def positives(self) -> int:
        return self.true_positive + self.false_negative

    @property
    def negatives(self) -> int:
        return self.false_positive + self.true_negative

    def true_positive_rate(self) -> float:
        if self.positives == 0:
            raise MetricsValidationError("True-positive rate is undefined with zero positive examples.")
        return self.true_positive / self.positives

    def false_positive_rate(self) -> float:
        if self.negatives == 0:
            raise MetricsValidationError("False-positive rate is undefined with zero negative examples.")
        return self.false_positive / self.negatives


@dataclass(frozen=True)
class FairnessReport:
    equalized_odds_gap: float
    true_positive_rate_range: tuple[float, float]
    false_positive_rate_range: tuple[float, float]
    passes_target: bool


@dataclass(frozen=True)
class CalibrationReport:
    rms_reprojection_error_px: float
    max_reprojection_error_px: float
    correspondence_count: int
    passes_target: bool


def _validate_point(point: Sequence[float], label: str) -> tuple[float, float]:
    if len(point) != 2:
        raise MetricsValidationError(f"{label} must contain exactly two coordinates.")
    x, y = point
    if not isinstance(x, (int, float)) or not isinstance(y, (int, float)):
        raise MetricsValidationError(f"{label} coordinates must be numeric.")
    if not isfinite(x) or not isfinite(y):
        raise MetricsValidationError(f"{label} coordinates must be finite.")
    return float(x), float(y)


def reprojection_report(
    observed_points: Iterable[Sequence[float]],
    projected_points: Iterable[Sequence[float]],
    target_rms_px: float = 1.0,
) -> CalibrationReport:
    if not isinstance(target_rms_px, (int, float)) or not isfinite(target_rms_px) or target_rms_px <= 0:
        raise MetricsValidationError("target_rms_px must be a finite positive number.")

    observed = list(observed_points)
    projected = list(projected_points)

    if not observed or len(observed) != len(projected):
        raise MetricsValidationError("Observed and projected points must be non-empty and have equal length.")

    squared_errors: list[float] = []
    for index, (measured, estimated) in enumerate(zip(observed, projected, strict=True)):
        measured_x, measured_y = _validate_point(measured, f"observed_points[{index}]")
        estimated_x, estimated_y = _validate_point(estimated, f"projected_points[{index}]")
        dx = measured_x - estimated_x
        dy = measured_y - estimated_y
        squared_errors.append(dx * dx + dy * dy)

    rms = sqrt(sum(squared_errors) / len(squared_errors))
    maximum = sqrt(max(squared_errors))

    return CalibrationReport(
        rms_reprojection_error_px=rms,
        max_reprojection_error_px=maximum,
        correspondence_count=len(squared_errors),
        passes_target=rms < float(target_rms_px),
    )


def equalized_odds_report(
    outcomes_by_scenario: Mapping[str, BinaryOutcomes],
    target_gap: float = 0.05,
) -> FairnessReport:
    if not isinstance(target_gap, (int, float)) or not isfinite(target_gap) or not 0 <= target_gap <= 1:
        raise MetricsValidationError("target_gap must be a finite number from zero through one.")
    if len(outcomes_by_scenario) < 2:
        raise MetricsValidationError("At least two scenario strata are required for an equalized-odds comparison.")

    scenario_names = list(outcomes_by_scenario.keys())
    if any(not isinstance(name, str) or not name.strip() for name in scenario_names):
        raise MetricsValidationError("Scenario labels must be non-empty strings.")

    true_positive_rates = {
        name: outcomes.true_positive_rate()
        for name, outcomes in outcomes_by_scenario.items()
    }
    false_positive_rates = {
        name: outcomes.false_positive_rate()
        for name, outcomes in outcomes_by_scenario.items()
    }

    tpr_gap = max(true_positive_rates.values()) - min(true_positive_rates.values())
    fpr_gap = max(false_positive_rates.values()) - min(false_positive_rates.values())
    equalized_odds_gap = max(tpr_gap, fpr_gap)

    return FairnessReport(
        equalized_odds_gap=equalized_odds_gap,
        true_positive_rate_range=(min(true_positive_rates.values()), max(true_positive_rates.values())),
        false_positive_rate_range=(min(false_positive_rates.values()), max(false_positive_rates.values())),
        passes_target=equalized_odds_gap < float(target_gap),
    )
