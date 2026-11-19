from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Iterable


@dataclass(frozen=True)
class CalibrationObservation:
    confidence: float
    correct: bool


@dataclass(frozen=True)
class CalibrationBin:
    lower_bound: float
    upper_bound: float
    count: int
    mean_confidence: float
    accuracy: float
    absolute_gap: float


@dataclass(frozen=True)
class CalibrationReport:
    expected_calibration_error: float
    bins: tuple[CalibrationBin, ...]


class CalibrationError(ValueError):
    pass


def expected_calibration_error(
    observations: Iterable[CalibrationObservation],
    bin_count: int = 10,
) -> CalibrationReport:
    values = tuple(observations)

    if bin_count < 1 or bin_count > 1000:
        raise CalibrationError("bin_count must be in the inclusive range [1, 1000]")

    if not values:
        raise CalibrationError("at least one observation is required")

    for observation in values:
        if not isfinite(observation.confidence) or not 0.0 <= observation.confidence <= 1.0:
            raise CalibrationError("confidence must be finite and in [0, 1]")

    buckets: list[list[CalibrationObservation]] = [[] for _ in range(bin_count)]

    for observation in values:
        index = min(int(observation.confidence * bin_count), bin_count - 1)
        buckets[index].append(observation)

    report_bins: list[CalibrationBin] = []
    ece = 0.0
    total = len(values)

    for index, bucket in enumerate(buckets):
        lower = index / bin_count
        upper = (index + 1) / bin_count

        if not bucket:
            report_bins.append(
                CalibrationBin(
                    lower_bound=lower,
                    upper_bound=upper,
                    count=0,
                    mean_confidence=0.0,
                    accuracy=0.0,
                    absolute_gap=0.0,
                )
            )
            continue

        mean_confidence = sum(item.confidence for item in bucket) / len(bucket)
        accuracy = sum(1 for item in bucket if item.correct) / len(bucket)
        absolute_gap = abs(accuracy - mean_confidence)

        ece += (len(bucket) / total) * absolute_gap

        report_bins.append(
            CalibrationBin(
                lower_bound=lower,
                upper_bound=upper,
                count=len(bucket),
                mean_confidence=mean_confidence,
                accuracy=accuracy,
                absolute_gap=absolute_gap,
            )
        )

    return CalibrationReport(
        expected_calibration_error=ece,
        bins=tuple(report_bins),
    )


def choose_confirmation_mode(
    calibrated_confidence: float,
    false_output_loss: float,
    confirmation_burden: float,
    abstention_burden: float,
    risk_multiplier: float,
    reversible: bool,
) -> str:
    _require_unit_interval(calibrated_confidence, "calibrated_confidence")

    for name, value in (
        ("false_output_loss", false_output_loss),
        ("confirmation_burden", confirmation_burden),
        ("abstention_burden", abstention_burden),
        ("risk_multiplier", risk_multiplier),
    ):
        if not isfinite(value) or value < 0.0:
            raise CalibrationError(f"{name} must be finite and non-negative")

    reversibility_modifier = 0.5 if reversible else 1.0
    issue_loss = (
        (1.0 - calibrated_confidence)
        * false_output_loss
        * risk_multiplier
        * reversibility_modifier
    )

    if issue_loss <= confirmation_burden:
        return "present"

    if confirmation_burden <= abstention_burden:
        return "confirm"

    return "abstain_or_defer"


def _require_unit_interval(value: float, name: str) -> None:
    if not isfinite(value) or not 0.0 <= value <= 1.0:
        raise CalibrationError(f"{name} must be finite and in [0, 1]")
