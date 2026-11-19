from __future__ import annotations

from dataclasses import dataclass
from math import exp, log
from typing import Iterable


@dataclass(frozen=True)
class CalibrationComparison:
    field_value: float
    sensor_value: float

    def absolute_error(self) -> float:
        return abs(self.field_value - self.sensor_value)


@dataclass(frozen=True)
class EvidenceFactors:
    calibration_confidence: float
    validation_confidence: float
    provenance_confidence: float
    privacy_compliance: float
    uncertainty_disclosure: float

    def __post_init__(self) -> None:
        for name, value in (
            ("calibration_confidence", self.calibration_confidence),
            ("validation_confidence", self.validation_confidence),
            ("provenance_confidence", self.provenance_confidence),
            ("privacy_compliance", self.privacy_compliance),
            ("uncertainty_disclosure", self.uncertainty_disclosure),
        ):
            _require_unit_interval(name, value)


@dataclass(frozen=True)
class ImpactFactors:
    knowledge_factor: float
    ecological_value: float
    residual_risk: float

    def __post_init__(self) -> None:
        _require_unit_interval("knowledge_factor", self.knowledge_factor)
        _require_unit_interval("ecological_value", self.ecological_value)
        _require_unit_interval("residual_risk", self.residual_risk)


def mean_absolute_error(comparisons: Iterable[CalibrationComparison]) -> float:
    values = [comparison.absolute_error() for comparison in comparisons]

    if not values:
        raise ValueError("At least one calibration comparison is required.")

    return sum(values) / len(values)


def cohen_kappa(
    observed_agreement: float,
    expected_agreement: float,
) -> float:
    _require_unit_interval("observed_agreement", observed_agreement)
    _require_unit_interval("expected_agreement", expected_agreement)

    denominator = 1.0 - expected_agreement

    if denominator == 0.0:
        raise ValueError("expected_agreement must be less than 1.0.")

    return (observed_agreement - expected_agreement) / denominator


def weighted_geometric_knowledge_factor(
    values_and_weights: Iterable[tuple[float, float]],
    epsilon: float = 1e-12,
) -> float:
    if epsilon <= 0.0:
        raise ValueError("epsilon must be positive.")

    pairs = list(values_and_weights)

    if not pairs:
        raise ValueError("At least one value and weight pair is required.")

    weighted_log_sum = 0.0
    weight_sum = 0.0

    for value, weight in pairs:
        _require_unit_interval("knowledge value", value)

        if weight < 0.0:
            raise ValueError("Weights must be non-negative.")

        if weight == 0.0:
            continue

        weighted_log_sum += weight * log(max(value, epsilon))
        weight_sum += weight

    if weight_sum == 0.0:
        raise ValueError("At least one weight must be positive.")

    return exp(weighted_log_sum / weight_sum)


def evidence_completeness(
    present_required_fields: int,
    required_fields: int,
) -> float:
    if required_fields <= 0:
        raise ValueError("required_fields must be positive.")

    if not 0 <= present_required_fields <= required_fields:
        raise ValueError(
            "present_required_fields must be between zero and required_fields."
        )

    return present_required_fields / required_fields


def ecological_utility_per_joule(
    factors: ImpactFactors,
    energy_joules: float,
) -> float:
    if energy_joules <= 0.0:
        raise ValueError("energy_joules must be positive.")

    return (
        factors.knowledge_factor
        * factors.ecological_value
        * (1.0 - factors.residual_risk)
    ) / energy_joules


def repairability_index(
    repairable_modules: int,
    total_critical_modules: int,
    diagnosis_minutes: float,
    diagnosis_target_minutes: float,
    repair_minutes: float,
    repair_target_minutes: float,
    parts_availability: float,
) -> float:
    if total_critical_modules <= 0:
        raise ValueError("total_critical_modules must be positive.")

    if not 0 <= repairable_modules <= total_critical_modules:
        raise ValueError(
            "repairable_modules must be between zero and total_critical_modules."
        )

    if diagnosis_minutes < 0.0 or repair_minutes < 0.0:
        raise ValueError("Diagnosis and repair times must be non-negative.")

    if diagnosis_target_minutes <= 0.0 or repair_target_minutes <= 0.0:
        raise ValueError("Diagnosis and repair targets must be positive.")

    _require_unit_interval("parts_availability", parts_availability)

    repairable_fraction = repairable_modules / total_critical_modules
    diagnosis_score = 1.0 - min(diagnosis_minutes / diagnosis_target_minutes, 1.0)
    repair_score = 1.0 - min(repair_minutes / repair_target_minutes, 1.0)

    return (
        0.35 * repairable_fraction
        + 0.25 * diagnosis_score
        + 0.25 * repair_score
        + 0.15 * parts_availability
    )


def _require_unit_interval(name: str, value: float) -> None:
    if not 0.0 <= value <= 1.0:
        raise ValueError(f"{name} must be within 0.0..=1.0.")
