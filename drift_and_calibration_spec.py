# mk-bluebird/Cybercore/research/drift_and_calibration_spec.py
from __future__ import annotations

from dataclasses import asdict, dataclass
from enum import StrEnum
from math import log
from typing import Sequence


class DriftMethod(StrEnum):
    KULLBACK_LEIBLER = "kullback-leibler"
    WASSERSTEIN_ONE = "wasserstein-one"
    POPULATION_STABILITY_INDEX = "population-stability-index"
    CLASSIFIER_BASED = "classifier-based"


class DriftDisposition(StrEnum):
    STABLE = "stable"
    ATTENTION = "attention"
    INVESTIGATE = "investigate"


class ComparisonDisposition(StrEnum):
    ADVANCES_EVIDENCE = "advances-evidence"
    MIXED_EVIDENCE = "mixed-evidence"
    DOES_NOT_ADVANCE_EVIDENCE = "does-not-advance-evidence"


@dataclass(frozen=True)
class DriftThresholds:
    psi_attention: float = 0.10
    psi_investigate: float = 0.20
    classifier_auc_attention: float = 0.60
    classifier_auc_investigate: float = 0.70


@dataclass(frozen=True)
class AssistiveWeights:
    accuracy: float
    reliability: float
    latency: float
    false_activation: float
    usability: float

    def validate(self) -> None:
        values = (
            self.accuracy,
            self.reliability,
            self.latency,
            self.false_activation,
            self.usability,
        )
        if any(value < 0.0 or value > 1.0 for value in values):
            raise ValueError("assistive weights must be normalized values in [0, 1]")
        if abs(sum(values) - 1.0) > 1e-12:
            raise ValueError("assistive weights must sum exactly to 1")


@dataclass(frozen=True)
class AssistiveMetrics:
    accuracy: float
    reliability: float
    normalized_latency: float
    false_activation_rate: float
    usability: float

    def validate(self) -> None:
        values = (
            self.accuracy,
            self.reliability,
            self.normalized_latency,
            self.false_activation_rate,
            self.usability,
        )
        if any(value < 0.0 or value > 1.0 for value in values):
            raise ValueError("assistive metrics must be normalized values in [0, 1]")

    def score(self, weights: AssistiveWeights) -> float:
        self.validate()
        weights.validate()
        return (
            weights.accuracy * self.accuracy
            + weights.reliability * self.reliability
            + weights.latency * (1.0 - self.normalized_latency)
            + weights.false_activation * (1.0 - self.false_activation_rate)
            + weights.usability * self.usability
        )


@dataclass(frozen=True)
class CalibrationBurdenWeights:
    calibration_time: float
    recalibration_fraction: float
    confirmation_burden: float

    def validate(self) -> None:
        values = (
            self.calibration_time,
            self.recalibration_fraction,
            self.confirmation_burden,
        )
        if any(value < 0.0 or value > 1.0 for value in values):
            raise ValueError("calibration-burden weights must be normalized values in [0, 1]")
        if abs(sum(values) - 1.0) > 1e-12:
            raise ValueError("calibration-burden weights must sum exactly to 1")


@dataclass(frozen=True)
class CalibrationBurdenInput:
    normalized_calibration_time: float
    recalibration_sessions: int
    total_sessions: int
    normalized_confirmation_burden: float

    def score(self, weights: CalibrationBurdenWeights) -> float:
        weights.validate()
        if not 0.0 <= self.normalized_calibration_time <= 1.0:
            raise ValueError("normalized calibration time must be in [0, 1]")
        if not 0.0 <= self.normalized_confirmation_burden <= 1.0:
            raise ValueError("normalized confirmation burden must be in [0, 1]")
        if self.total_sessions <= 0:
            raise ValueError("total sessions must be positive")
        if self.recalibration_sessions < 0 or self.recalibration_sessions > self.total_sessions:
            raise ValueError("recalibration sessions must be within total sessions")

        recalibration_fraction = self.recalibration_sessions / self.total_sessions
        return (
            weights.calibration_time * self.normalized_calibration_time
            + weights.recalibration_fraction * recalibration_fraction
            + weights.confirmation_burden * self.normalized_confirmation_burden
        )


@dataclass(frozen=True)
class AdaptiveComparisonResult:
    fixed_score: float
    adaptive_score: float
    score_delta: float
    false_activation_delta: float
    usability_delta: float
    disposition: ComparisonDisposition


def _validate_probabilities(reference: Sequence[float], current: Sequence[float]) -> None:
    if len(reference) == 0 or len(reference) != len(current):
        raise ValueError("reference and current distributions must be non-empty and same length")
    if any(value < 0.0 for value in reference) or any(value < 0.0 for value in current):
        raise ValueError("distribution values must be non-negative")
    if abs(sum(reference) - 1.0) > 1e-9 or abs(sum(current) - 1.0) > 1e-9:
        raise ValueError("distribution values must each sum to 1")


def kullback_leibler(reference: Sequence[float], current: Sequence[float]) -> float:
    _validate_probabilities(reference, current)
    epsilon = 1e-12
    return sum(
        max(current_value, epsilon) * log(max(current_value, epsilon) / max(reference_value, epsilon))
        for reference_value, current_value in zip(reference, current, strict=True)
    )


def population_stability_index(reference: Sequence[float], current: Sequence[float]) -> float:
    _validate_probabilities(reference, current)
    epsilon = 1e-12
    return sum(
        (max(current_value, epsilon) - max(reference_value, epsilon))
        * log(max(current_value, epsilon) / max(reference_value, epsilon))
        for reference_value, current_value in zip(reference, current, strict=True)
    )


def wasserstein_one(
    reference_histogram: Sequence[float],
    current_histogram: Sequence[float],
    bin_edges: Sequence[float],
) -> float:
    _validate_probabilities(reference_histogram, current_histogram)
    if len(bin_edges) != len(reference_histogram) + 1:
        raise ValueError("bin edge count must equal histogram count plus one")
    if any(right <= left for left, right in zip(bin_edges, bin_edges[1:], strict=True)):
        raise ValueError("bin edges must be strictly increasing")

    reference_cdf = 0.0
    current_cdf = 0.0
    distance = 0.0
    for index, (reference_value, current_value) in enumerate(
        zip(reference_histogram, current_histogram, strict=True)
    ):
        reference_cdf += reference_value
        current_cdf += current_value
        distance += abs(reference_cdf - current_cdf) * (bin_edges[index + 1] - bin_edges[index])
    return distance


def classifier_auc_from_scores(
    reference_scores: Sequence[float],
    current_scores: Sequence[float],
) -> float:
    if not reference_scores or not current_scores:
        raise ValueError("both score collections must be non-empty")

    wins = 0.0
    for current_score in current_scores:
        for reference_score in reference_scores:
            if current_score > reference_score:
                wins += 1.0
            elif current_score == reference_score:
                wins += 0.5

    auc = wins / (len(reference_scores) * len(current_scores))
    return max(auc, 1.0 - auc)


def classify_psi(value: float, thresholds: DriftThresholds = DriftThresholds()) -> DriftDisposition:
    if value < 0.0:
        raise ValueError("PSI must be non-negative")
    if value >= thresholds.psi_investigate:
        return DriftDisposition.INVESTIGATE
    if value >= thresholds.psi_attention:
        return DriftDisposition.ATTENTION
    return DriftDisposition.STABLE


def classify_classifier_auc(
    value: float,
    thresholds: DriftThresholds = DriftThresholds(),
) -> DriftDisposition:
    if not 0.5 <= value <= 1.0:
        raise ValueError("classifier AUC must be in [0.5, 1]")
    if value >= thresholds.classifier_auc_investigate:
        return DriftDisposition.INVESTIGATE
    if value >= thresholds.classifier_auc_attention:
        return DriftDisposition.ATTENTION
    return DriftDisposition.STABLE


def evaluate_adaptive_policy(
    fixed: AssistiveMetrics,
    adaptive: AssistiveMetrics,
    weights: AssistiveWeights,
    false_activation_tolerance: float,
    usability_tolerance: float,
) -> AdaptiveComparisonResult:
    if false_activation_tolerance < 0.0 or usability_tolerance < 0.0:
        raise ValueError("tolerances must be non-negative")

    fixed_score = fixed.score(weights)
    adaptive_score = adaptive.score(weights)
    score_delta = adaptive_score - fixed_score
    false_activation_delta = adaptive.false_activation_rate - fixed.false_activation_rate
    usability_delta = adaptive.usability - fixed.usability

    if (
        score_delta >= 0.0
        and false_activation_delta <= false_activation_tolerance
        and usability_delta >= -usability_tolerance
    ):
        disposition = ComparisonDisposition.ADVANCES_EVIDENCE
    elif score_delta >= 0.0 or false_activation_delta <= false_activation_tolerance:
        disposition = ComparisonDisposition.MIXED_EVIDENCE
    else:
        disposition = ComparisonDisposition.DOES_NOT_ADVANCE_EVIDENCE

    return AdaptiveComparisonResult(
        fixed_score=fixed_score,
        adaptive_score=adaptive_score,
        score_delta=score_delta,
        false_activation_delta=false_activation_delta,
        usability_delta=usability_delta,
        disposition=disposition,
    )


def specification_example() -> dict[str, object]:
    weights = AssistiveWeights(
        accuracy=0.25,
        reliability=0.30,
        latency=0.15,
        false_activation=0.20,
        usability=0.10,
    )
    fixed = AssistiveMetrics(
        accuracy=0.80,
        reliability=0.75,
        normalized_latency=0.25,
        false_activation_rate=0.05,
        usability=0.70,
    )
    adaptive = AssistiveMetrics(
        accuracy=0.83,
        reliability=0.82,
        normalized_latency=0.22,
        false_activation_rate=0.05,
        usability=0.72,
    )
    burden = CalibrationBurdenInput(
        normalized_calibration_time=0.20,
        recalibration_sessions=2,
        total_sessions=10,
        normalized_confirmation_burden=0.30,
    )
    burden_weights = CalibrationBurdenWeights(
        calibration_time=0.40,
        recalibration_fraction=0.35,
        confirmation_burden=0.25,
    )
    comparison = evaluate_adaptive_policy(
        fixed=fixed,
        adaptive=adaptive,
        weights=weights,
        false_activation_tolerance=0.01,
        usability_tolerance=0.05,
    )
    return {
        "assistive_weights": asdict(weights),
        "comparison": asdict(comparison),
        "calibration_burden": burden.score(burden_weights),
        "drift_reference": {
            "kl": kullback_leibler([0.50, 0.50], [0.40, 0.60]),
            "psi": population_stability_index([0.50, 0.50], [0.40, 0.60]),
            "wasserstein_one": wasserstein_one([0.50, 0.50], [0.40, 0.60], [0.0, 1.0, 2.0]),
        },
    }
