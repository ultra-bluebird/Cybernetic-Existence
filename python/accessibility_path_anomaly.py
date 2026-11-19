from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Literal


ConditionClass = Literal[
    "ramp_surface_crack",
    "ramp_surface_deformation",
    "ramp_obstruction",
    "ramp_water_or_debris",
    "handrail_damage",
    "tactile_paving_damage",
    "tactile_paving_obstruction",
    "tactile_paving_low_contrast",
    "automatic_door_misalignment",
    "automatic_door_obstruction",
    "automatic_door_sensor_fault_indicator",
    "path_surface_crack",
    "path_surface_heave",
    "path_surface_obstruction",
    "signage_damage",
    "unknown_condition",
]


PriorityBand = Literal[
    "emergency_accessibility_barrier",
    "urgent_repair",
    "standard_repair",
    "monitor",
]


@dataclass(frozen=True)
class ConditionObservation:
    asset_reference: str
    condition_class: ConditionClass
    detector_confidence: float
    anomaly_score: float
    anomaly_reference: float
    safety_severity: float
    accessibility_barrier: float
    route_criticality: float
    public_use_dependency: float
    degradation_duration: float
    persistence_count: int
    privacy_redaction_confirmed: bool
    model_version: str


@dataclass(frozen=True)
class MaintenanceTicketRecommendation:
    asset_reference: str
    condition_class: ConditionClass
    condition_confidence: float
    anomaly_component: float
    combined_condition_score: float
    priority_score: float
    priority_band: PriorityBand
    human_review_required: bool
    privacy_redaction_confirmed: bool


def clamp_unit(value: float) -> float:
    if not isfinite(value):
        raise ValueError("all scoring values must be finite")
    return max(0.0, min(1.0, float(value)))


def classify_priority(priority_score: float) -> PriorityBand:
    if priority_score >= 0.80:
        return "emergency_accessibility_barrier"
    if priority_score >= 0.60:
        return "urgent_repair"
    if priority_score >= 0.35:
        return "standard_repair"
    return "monitor"


def create_maintenance_recommendation(
    observation: ConditionObservation,
    condition_threshold: float = 0.55,
) -> MaintenanceTicketRecommendation | None:
    if not observation.asset_reference.strip():
        raise ValueError("asset_reference is required")
    if not observation.model_version.strip():
        raise ValueError("model_version is required")
    if observation.persistence_count < 1:
        raise ValueError("persistence_count must be positive")
    if observation.anomaly_reference <= 0.0:
        raise ValueError("anomaly_reference must be greater than zero")
    if not 0.0 <= condition_threshold <= 1.0:
        raise ValueError("condition_threshold must be in [0, 1]")

    anomaly_component = clamp_unit(
        observation.anomaly_score / observation.anomaly_reference
    )
    combined_condition_score = clamp_unit(
        0.65 * clamp_unit(observation.detector_confidence)
        + 0.35 * anomaly_component
    )

    if combined_condition_score < condition_threshold:
        return None

    persistence_factor = clamp_unit(observation.persistence_count / 5.0)
    priority_score = clamp_unit(
        0.35 * clamp_unit(observation.safety_severity)
        + 0.25 * clamp_unit(observation.accessibility_barrier)
        + 0.20 * clamp_unit(observation.route_criticality)
        + 0.10 * clamp_unit(observation.public_use_dependency)
        + 0.10 * max(
            clamp_unit(observation.degradation_duration),
            persistence_factor,
        )
    )

    return MaintenanceTicketRecommendation(
        asset_reference=observation.asset_reference,
        condition_class=observation.condition_class,
        condition_confidence=round(clamp_unit(observation.detector_confidence), 6),
        anomaly_component=round(anomaly_component, 6),
        combined_condition_score=round(combined_condition_score, 6),
        priority_score=round(priority_score, 6),
        priority_band=classify_priority(priority_score),
        human_review_required=True,
        privacy_redaction_confirmed=observation.privacy_redaction_confirmed,
    )
