from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from math import sqrt
from typing import Mapping, Sequence


class AutomationMode(str, Enum):
    FULL_AUTOMATIC = "full_automatic"
    CAUTIOUS_AUTOMATIC = "cautious_automatic"
    ASSISTED_MANUAL = "assisted_manual"
    FULL_MANUAL = "full_manual"


@dataclass(frozen=True)
class SensorObservation:
    source: str
    values: Mapping[str, float]
    confidence: float
    stability: float


@dataclass(frozen=True)
class ManualOverrideStatus:
    physical_control_present: bool
    independent_power_available: bool
    multilingual_signage_present: bool
    activation_force_newtons: float
    operable_with_one_hand: bool
    requires_tight_grasping: bool
    requires_pinch_or_wrist_twist: bool


@dataclass(frozen=True)
class CalibrationStatus:
    residual_error: float
    baseline_error: float
    environmental_stability: float
    reference_available: bool
    sensor_health: float


@dataclass(frozen=True)
class CalibrationDecision:
    learning_rate: float
    drift_risk: float
    mode: AutomationMode
    calibration_update_allowed: bool


IDENTITY_DISCRIMINATING_FEATURES = frozenset(
    {
        "identity",
        "name",
        "persistent_device_id",
        "biometric_template",
        "neural_signature",
        "precise_person_location",
        "face_embedding",
        "voice_embedding",
        "gait_embedding",
        "protected_attribute",
    }
)

MAX_ACCESSIBLE_OPERABLE_FORCE_NEWTONS = 22.2


def _require_unit_interval(value: float, label: str) -> None:
    if not 0.0 <= value <= 1.0:
        raise ValueError(f"{label} must be within [0, 1].")


def _validate_feature_name(feature_name: str) -> None:
    if feature_name in IDENTITY_DISCRIMINATING_FEATURES:
        raise ValueError(
            f"Identity-discriminating feature is prohibited: {feature_name}"
        )


def fused_environmental_state(
    observations: Sequence[SensorObservation],
    weights: Sequence[float],
) -> dict[str, float]:
    if not observations:
        raise ValueError("At least one sensor observation is required.")

    if len(observations) != len(weights):
        raise ValueError("Observations and weights must have equal length.")

    if any(weight < 0.0 for weight in weights):
        raise ValueError("Fusion weights must be non-negative.")

    total_weight = sum(weights)

    if total_weight <= 0.0:
        raise ValueError("At least one fusion weight must be positive.")

    weighted_totals: dict[str, float] = {}

    for observation, weight in zip(observations, weights):
        _require_unit_interval(observation.confidence, "Sensor confidence")
        _require_unit_interval(observation.stability, "Sensor stability")

        for feature_name, value in observation.values.items():
            _validate_feature_name(feature_name)
            weighted_totals[feature_name] = (
                weighted_totals.get(feature_name, 0.0) + weight * value
            )

    return {
        feature_name: total / total_weight
        for feature_name, total in weighted_totals.items()
    }


def identity_leakage_bound(
    proxy_dependence: Sequence[float],
    identity_association: Sequence[float],
) -> float:
    if len(proxy_dependence) != len(identity_association):
        raise ValueError("Leakage inputs must have equal length.")

    if not proxy_dependence:
        return 0.0

    terms = []

    for dependence, association in zip(proxy_dependence, identity_association):
        _require_unit_interval(dependence, "Proxy dependence")
        _require_unit_interval(association, "Identity association")
        terms.append((dependence * association) ** 2)

    return sqrt(sum(terms))


def identity_blind_fusion_verified(
    fused_features: Mapping[str, float],
    proxy_dependence: Sequence[float],
    identity_association: Sequence[float],
    epsilon: float,
) -> bool:
    _require_unit_interval(epsilon, "Identity leakage epsilon")

    for feature_name in fused_features:
        _validate_feature_name(feature_name)

    return identity_leakage_bound(
        proxy_dependence,
        identity_association,
    ) <= epsilon


def manual_override_available(status: ManualOverrideStatus) -> bool:
    return (
        status.physical_control_present
        and status.independent_power_available
        and status.multilingual_signage_present
        and status.activation_force_newtons
        <= MAX_ACCESSIBLE_OPERABLE_FORCE_NEWTONS
        and status.operable_with_one_hand
        and not status.requires_tight_grasping
        and not status.requires_pinch_or_wrist_twist
    )


def select_automation_mode(
    manual_override_is_available: bool,
    drift_risk: float,
    sensor_health: float,
) -> AutomationMode:
    _require_unit_interval(drift_risk, "Drift risk")
    _require_unit_interval(sensor_health, "Sensor health")

    if not manual_override_is_available:
        return AutomationMode.FULL_MANUAL

    if drift_risk >= 0.70 or sensor_health < 0.40:
        return AutomationMode.ASSISTED_MANUAL

    if drift_risk >= 0.35 or sensor_health < 0.70:
        return AutomationMode.CAUTIOUS_AUTOMATIC

    return AutomationMode.FULL_AUTOMATIC


def evaluate_calibration(
    status: CalibrationStatus,
    base_learning_rate: float,
) -> CalibrationDecision:
    _require_unit_interval(status.residual_error, "Residual error")
    _require_unit_interval(status.baseline_error, "Baseline error")
    _require_unit_interval(
        status.environmental_stability,
        "Environmental stability",
    )
    _require_unit_interval(status.sensor_health, "Sensor health")

    if not 0.0 <= base_learning_rate <= 1.0:
        raise ValueError("Base learning rate must be within [0, 1].")

    drift_delta = max(0.0, status.residual_error - status.baseline_error)
    drift_risk = min(
        1.0,
        0.60 * drift_delta
        + 0.20 * (1.0 - status.environmental_stability)
        + 0.20 * (1.0 - status.sensor_health),
    )

    confidence = status.sensor_health if status.reference_available else 0.0
    learning_rate = (
        base_learning_rate
        * confidence
        * status.environmental_stability
        * (1.0 - drift_risk)
    )

    provisional_mode = select_automation_mode(
        manual_override_is_available=True,
        drift_risk=drift_risk,
        sensor_health=status.sensor_health,
    )

    update_allowed = (
        status.reference_available
        and status.sensor_health >= 0.70
        and status.environmental_stability >= 0.60
        and drift_risk < 0.35
    )

    if not update_allowed:
        learning_rate = 0.0

    return CalibrationDecision(
        learning_rate=learning_rate,
        drift_risk=drift_risk,
        mode=provisional_mode,
        calibration_update_allowed=update_allowed,
    )
