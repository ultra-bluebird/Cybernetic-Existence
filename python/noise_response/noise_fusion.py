from __future__ import annotations

from dataclasses import dataclass
from math import isfinite


class NoiseFusionValidationError(ValueError):
    pass


NIGHTTIME_OPERATIONAL_REVIEW_THRESHOLD_DBA = 55.0


@dataclass(frozen=True)
class NoiseEvidence:
    leq_dba: float
    measurement_validated: bool
    sensor_health_valid: bool
    uncertainty: float
    complaint_evidence_level: int
    accessibility_or_sleep_disruption_context: float

    def __post_init__(self) -> None:
        if not isfinite(self.leq_dba) or self.leq_dba < 0.0:
            raise NoiseFusionValidationError("leq_dba must be finite and non-negative.")
        if not isfinite(self.uncertainty) or not 0.0 <= self.uncertainty <= 1.0:
            raise NoiseFusionValidationError("uncertainty must be in the range from zero through one.")
        if self.complaint_evidence_level not in {0, 1, 2}:
            raise NoiseFusionValidationError(
                "complaint_evidence_level must be a bounded value of zero, one, or two."
            )
        if (
            not isfinite(self.accessibility_or_sleep_disruption_context)
            or not 0.0 <= self.accessibility_or_sleep_disruption_context <= 1.0
        ):
            raise NoiseFusionValidationError(
                "accessibility_or_sleep_disruption_context must be in the range from zero through one."
            )


@dataclass(frozen=True)
class NoiseReviewDecision:
    state: str
    normalized_sensor_evidence: float
    priority: float
    automated_enforcement_performed: bool
    reason: str


def normalized_sensor_evidence(leq_dba: float) -> float:
    return min(
        1.0,
        max(
            0.0,
            (leq_dba - NIGHTTIME_OPERATIONAL_REVIEW_THRESHOLD_DBA)
            / NIGHTTIME_OPERATIONAL_REVIEW_THRESHOLD_DBA,
        ),
    )


def evaluate_noise_review(
    evidence: NoiseEvidence,
    sensor_weight: float = 0.60,
    complaint_weight: float = 0.20,
    context_weight: float = 0.20,
    uncertainty_weight: float = 0.20,
) -> NoiseReviewDecision:
    weights = (
        sensor_weight,
        complaint_weight,
        context_weight,
        uncertainty_weight,
    )
    if any(not isfinite(weight) or weight < 0.0 for weight in weights):
        raise NoiseFusionValidationError("All fusion weights must be finite and non-negative.")

    if complaint_weight > 0.25:
        raise NoiseFusionValidationError(
            "complaint_weight must not exceed 0.25 to prevent frequency-driven priority."
        )

    if sensor_weight < complaint_weight:
        raise NoiseFusionValidationError(
            "sensor_weight must be at least complaint_weight."
        )

    if not evidence.measurement_validated or not evidence.sensor_health_valid:
        return NoiseReviewDecision(
            state="CALIBRATION_AND_CONTEXT_CHECK",
            normalized_sensor_evidence=0.0,
            priority=0.0,
            automated_enforcement_performed=False,
            reason="Sensor evidence is unavailable for operational review until calibration and health checks pass.",
        )

    sensor_value = normalized_sensor_evidence(evidence.leq_dba)
    complaint_value = evidence.complaint_evidence_level / 2.0
    priority = (
        sensor_weight * sensor_value
        + complaint_weight * complaint_value
        + context_weight * evidence.accessibility_or_sleep_disruption_context
        - uncertainty_weight * evidence.uncertainty
    )

    sensor_threshold_exceeded = (
        evidence.leq_dba > NIGHTTIME_OPERATIONAL_REVIEW_THRESHOLD_DBA
    )
    context_supported_complaint = (
        evidence.complaint_evidence_level >= 1
        and evidence.accessibility_or_sleep_disruption_context >= 0.5
    )

    if sensor_threshold_exceeded or context_supported_complaint:
        return NoiseReviewDecision(
            state="REVIEW_REQUIRED",
            normalized_sensor_evidence=sensor_value,
            priority=max(0.0, priority),
            automated_enforcement_performed=False,
            reason=(
                "A calibrated measurement or bounded, reviewable complaint context "
                "supports non-punitive human review."
            ),
        )

    return NoiseReviewDecision(
        state="ACKNOWLEDGED_WITH_MONITORING",
        normalized_sensor_evidence=sensor_value,
        priority=max(0.0, priority),
        automated_enforcement_performed=False,
        reason=(
            "The evidence does not currently meet the operational review condition. "
            "The report remains acknowledged and may be reopened or supplemented."
        ),
    )


def privacy_safe_noise_audit_record() -> dict[str, bool]:
    return {
        "raw_audio_retained": False,
        "voiceprint_created": False,
        "reporter_identity_retained": False,
        "reporter_frequency_score_used": False,
        "automated_enforcement_performed": False,
        "health_or_augmentation_inference_performed": False,
    }
