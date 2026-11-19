from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from enum import Enum
from typing import Iterable
import math


class ObservationScope(str, Enum):
    COMMUNITY_CONTROLLED = "community_controlled"
    MUNICIPAL_OPERATIONAL = "municipal_operational"
    JOINTLY_GOVERNED = "jointly_governed"


class AlertClass(str, Enum):
    NO_ALERT = "no_alert"
    SENSOR_MAINTENANCE_REVIEW = "sensor_maintenance_review"
    OPERATOR_VERIFICATION_REQUIRED = "operator_verification_required"


@dataclass(frozen=True)
class WaterObservation:
    node_public_code: str
    observed_at: datetime
    metric: str
    value: float
    uncertainty: float
    freshness_factor: float
    calibration_factor: float
    health_factor: float
    scope: ObservationScope
    signature_valid: bool


@dataclass(frozen=True)
class FusionResult:
    metric: str
    fused_value: float
    fused_uncertainty: float
    quality: float
    maximum_disagreement: float
    alert_class: AlertClass
    reason: str


def fuse_observations(
    observations: Iterable[WaterObservation],
    maximum_disagreement: float,
    minimum_quality: float,
    anomaly_present: bool,
) -> FusionResult:
    observation_list = list(observations)

    if not observation_list:
        raise ValueError("At least one observation is required.")
    if not math.isfinite(maximum_disagreement) or maximum_disagreement <= 0.0:
        raise ValueError("maximum_disagreement must be finite and greater than zero.")
    if not math.isfinite(minimum_quality) or not 0.0 <= minimum_quality <= 1.0:
        raise ValueError("minimum_quality must be within [0, 1].")

    metric = observation_list[0].metric
    accepted: list[tuple[WaterObservation, float]] = []

    for observation in observation_list:
        _validate_observation(observation)

        if observation.metric != metric:
            raise ValueError("All fused observations must use the same metric.")

        if not observation.signature_valid:
            continue

        weight = (
            observation.freshness_factor
            * observation.calibration_factor
            * observation.health_factor
            / max(observation.uncertainty**2, 1e-12)
        )

        if weight > 0.0:
            accepted.append((observation, weight))

    if not accepted:
        return FusionResult(
            metric=metric,
            fused_value=0.0,
            fused_uncertainty=float("inf"),
            quality=0.0,
            maximum_disagreement=float("inf"),
            alert_class=AlertClass.SENSOR_MAINTENANCE_REVIEW,
            reason="No signed, healthy, calibrated observations were available.",
        )

    total_weight = sum(weight for _, weight in accepted)
    fused_value = sum(
        observation.value * weight
        for observation, weight in accepted
    ) / total_weight

    fused_uncertainty = math.sqrt(1.0 / total_weight)

    quality = sum(
        observation.freshness_factor
        * observation.calibration_factor
        * observation.health_factor
        for observation, _ in accepted
    ) / len(accepted)

    disagreement = max(
        abs(observation.value - fused_value)
        for observation, _ in accepted
    )

    if disagreement > maximum_disagreement:
        return FusionResult(
            metric=metric,
            fused_value=fused_value,
            fused_uncertainty=fused_uncertainty,
            quality=quality,
            maximum_disagreement=disagreement,
            alert_class=AlertClass.SENSOR_MAINTENANCE_REVIEW,
            reason=(
                "Sensor disagreement exceeds the configured limit; route the "
                "finding to maintenance and validation rather than contamination labeling."
            ),
        )

    if anomaly_present and quality >= minimum_quality:
        return FusionResult(
            metric=metric,
            fused_value=fused_value,
            fused_uncertainty=fused_uncertainty,
            quality=quality,
            maximum_disagreement=disagreement,
            alert_class=AlertClass.OPERATOR_VERIFICATION_REQUIRED,
            reason=(
                "A confidence-qualified anomaly requires water-operator verification; "
                "this result is not a confirmed contamination determination."
            ),
        )

    return FusionResult(
        metric=metric,
        fused_value=fused_value,
        fused_uncertainty=fused_uncertainty,
        quality=quality,
        maximum_disagreement=disagreement,
        alert_class=AlertClass.NO_ALERT,
        reason="No confidence-qualified anomaly was detected.",
    )


def _validate_observation(observation: WaterObservation) -> None:
    if not observation.node_public_code.strip():
        raise ValueError("node_public_code is required.")
    if not observation.metric.strip():
        raise ValueError("metric is required.")
    if observation.observed_at.tzinfo is None:
        raise ValueError("observed_at must be timezone-aware.")
    observation.observed_at.astimezone(timezone.utc)

    for field_name, value in {
        "value": observation.value,
        "uncertainty": observation.uncertainty,
        "freshness_factor": observation.freshness_factor,
        "calibration_factor": observation.calibration_factor,
        "health_factor": observation.health_factor,
    }.items():
        if not math.isfinite(value):
            raise ValueError(f"{field_name} must be finite.")

    if observation.uncertainty < 0.0:
        raise ValueError("uncertainty must be non-negative.")

    for field_name, value in {
        "freshness_factor": observation.freshness_factor,
        "calibration_factor": observation.calibration_factor,
        "health_factor": observation.health_factor,
    }.items():
        if not 0.0 <= value <= 1.0:
            raise ValueError(f"{field_name} must be within [0, 1].")
