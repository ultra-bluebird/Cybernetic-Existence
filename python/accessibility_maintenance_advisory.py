from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from math import exp, isfinite


class MaintenanceDecision(str, Enum):
    ROUTINE_REVIEW = "routine_review"
    PRIORITIZED_HUMAN_REVIEW = "prioritized_human_review"
    MANUAL_INSPECTION_REQUIRED = "manual_inspection_required"
    ACCESS_IMPACT_REVIEW_REQUIRED = "access_impact_review_required"


@dataclass(frozen=True)
class WeibullBaseline:
    shape: float
    scale_days: float

    def validate(self) -> None:
        if not isfinite(self.shape) or self.shape <= 0:
            raise ValueError("shape must be a finite value greater than zero")
        if not isfinite(self.scale_days) or self.scale_days <= 0:
            raise ValueError("scale_days must be a finite value greater than zero")

    def hazard_at(self, age_days: float) -> float:
        self.validate()

        if not isfinite(age_days) or age_days < 0:
            raise ValueError("age_days must be finite and non-negative")

        if age_days == 0 and self.shape < 1:
            raise ValueError("hazard is unbounded at zero for shape values below one")

        normalized_age = age_days / self.scale_days
        return (self.shape / self.scale_days) * normalized_age ** (self.shape - 1)


@dataclass(frozen=True)
class MaintenanceCovariates:
    cycles_per_day: float
    load_variance: float
    sensor_drift: float
    environmental_stress: float
    evidence_complete: bool
    accessible_alternative_verified: bool
    estimated_disruption_minutes: int
    low_disruption_window_available: bool

    def validate(self) -> None:
        values = (
            self.cycles_per_day,
            self.load_variance,
            self.sensor_drift,
            self.environmental_stress,
        )

        if not all(isfinite(value) for value in values):
            raise ValueError("maintenance covariates must be finite")

        if self.cycles_per_day < 0:
            raise ValueError("cycles_per_day must not be negative")

        if self.load_variance < 0:
            raise ValueError("load_variance must not be negative")

        if self.sensor_drift < 0:
            raise ValueError("sensor_drift must not be negative")

        if self.environmental_stress < 0:
            raise ValueError("environmental_stress must not be negative")

        if self.estimated_disruption_minutes < 0:
            raise ValueError("estimated_disruption_minutes must not be negative")


@dataclass(frozen=True)
class HazardCoefficients:
    cycles_per_day: float
    load_variance: float
    sensor_drift: float
    environmental_stress: float

    def validate(self) -> None:
        values = (
            self.cycles_per_day,
            self.load_variance,
            self.sensor_drift,
            self.environmental_stress,
        )

        if not all(isfinite(value) for value in values):
            raise ValueError("hazard coefficients must be finite")


@dataclass(frozen=True)
class MaintenanceAssessment:
    modeled_hazard_per_day: float | None
    decision: MaintenanceDecision
    reasons: tuple[str, ...]
    human_authorization_required: bool
    physical_action_authorized: bool


def assess_maintenance(
    baseline: WeibullBaseline,
    coefficients: HazardCoefficients,
    covariates: MaintenanceCovariates,
    age_days: float,
    prioritized_review_threshold: float,
) -> MaintenanceAssessment:
    baseline.validate()
    coefficients.validate()
    covariates.validate()

    if not isfinite(prioritized_review_threshold) or prioritized_review_threshold <= 0:
        raise ValueError("prioritized_review_threshold must be finite and greater than zero")

    if not covariates.evidence_complete:
        return MaintenanceAssessment(
            modeled_hazard_per_day=None,
            decision=MaintenanceDecision.MANUAL_INSPECTION_REQUIRED,
            reasons=(
                "maintenance_evidence_is_incomplete",
                "do_not_impute_missing_safety_or_access_critical_evidence",
            ),
            human_authorization_required=True,
            physical_action_authorized=False,
        )

    linear_predictor = (
        coefficients.cycles_per_day * covariates.cycles_per_day
        + coefficients.load_variance * covariates.load_variance
        + coefficients.sensor_drift * covariates.sensor_drift
        + coefficients.environmental_stress * covariates.environmental_stress
    )

    modeled_hazard = baseline.hazard_at(age_days) * exp(linear_predictor)

    if not covariates.accessible_alternative_verified:
        return MaintenanceAssessment(
            modeled_hazard_per_day=modeled_hazard,
            decision=MaintenanceDecision.ACCESS_IMPACT_REVIEW_REQUIRED,
            reasons=(
                "accessible_alternative_not_verified",
                "maintenance_timing_requires_accessibility_review",
            ),
            human_authorization_required=True,
            physical_action_authorized=False,
        )

    if modeled_hazard >= prioritized_review_threshold:
        reasons = [
            "modeled_hazard_exceeds_prioritized_review_threshold",
            "review_result_is_advisory_not_a_maintenance_command",
        ]

        if covariates.low_disruption_window_available:
            reasons.append("low_disruption_window_can_be_considered_by_human_scheduler")

        return MaintenanceAssessment(
            modeled_hazard_per_day=modeled_hazard,
            decision=MaintenanceDecision.PRIORITIZED_HUMAN_REVIEW,
            reasons=tuple(reasons),
            human_authorization_required=True,
            physical_action_authorized=False,
        )

    return MaintenanceAssessment(
        modeled_hazard_per_day=modeled_hazard,
        decision=MaintenanceDecision.ROUTINE_REVIEW,
        reasons=(
            "modeled_hazard_below_prioritized_review_threshold",
            "continue_normal_inspection_and_accessibility_monitoring",
        ),
        human_authorization_required=True,
        physical_action_authorized=False,
    )


if __name__ == "__main__":
    result = assess_maintenance(
        baseline=WeibullBaseline(shape=1.4, scale_days=1_800.0),
        coefficients=HazardCoefficients(
            cycles_per_day=0.0003,
            load_variance=0.08,
            sensor_drift=0.45,
            environmental_stress=0.12,
        ),
        covariates=MaintenanceCovariates(
            cycles_per_day=1_100.0,
            load_variance=0.7,
            sensor_drift=0.2,
            environmental_stress=0.4,
            evidence_complete=True,
            accessible_alternative_verified=True,
            estimated_disruption_minutes=45,
            low_disruption_window_available=True,
        ),
        age_days=1_200.0,
        prioritized_review_threshold=0.01,
    )

    print(
        {
            "modeled_hazard_per_day": result.modeled_hazard_per_day,
            "decision": result.decision.value,
            "human_authorization_required": result.human_authorization_required,
            "physical_action_authorized": result.physical_action_authorized,
            "reasons": result.reasons,
        }
    )
