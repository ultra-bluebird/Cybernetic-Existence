from __future__ import annotations

from dataclasses import dataclass
from math import isfinite


@dataclass(frozen=True)
class AcceptanceInputs:
    discourse_score: float
    legal_recognition_score: float
    service_accessibility_score: float
    discrimination_safety_score: float
    community_engagement_score: float
    data_quality_confidence: float


def clamp_unit(value: float) -> float:
    if not isfinite(value):
        raise ValueError("all CHAI inputs must be finite")
    return max(0.0, min(1.0, value))


def calculate_chai(inputs: AcceptanceInputs) -> float:
    weighted_score = (
        0.22 * clamp_unit(inputs.discourse_score)
        + 0.26 * clamp_unit(inputs.legal_recognition_score)
        + 0.26 * clamp_unit(inputs.service_accessibility_score)
        + 0.16 * clamp_unit(inputs.discrimination_safety_score)
        + 0.10 * clamp_unit(inputs.community_engagement_score)
    )
    return clamp_unit(clamp_unit(inputs.data_quality_confidence) * weighted_score)


def smooth_monthly_score(previous_score: float | None, current_score: float) -> float:
    current = clamp_unit(current_score)
    if previous_score is None:
        return current
    return clamp_unit(0.70 * clamp_unit(previous_score) + 0.30 * current)


def discrimination_safety_score(
    underreporting_adjusted_incident_rate: float,
    reference_incident_rate: float,
    grievance_resolution_quality: float,
) -> float:
    if not isfinite(underreporting_adjusted_incident_rate):
        raise ValueError("incident rate must be finite")
    if not isfinite(reference_incident_rate) or reference_incident_rate <= 0.0:
        raise ValueError("reference incident rate must be finite and greater than zero")

    incident_burden = clamp_unit(
        underreporting_adjusted_incident_rate / reference_incident_rate
    )
    return clamp_unit(
        0.55 * (1.0 - incident_burden)
        + 0.45 * clamp_unit(grievance_resolution_quality)
    )
