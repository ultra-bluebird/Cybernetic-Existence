from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from math import isfinite
from typing import Sequence


class PavementCondition(str, Enum):
    PERFORMING_AS_DESIGNED = "performing_as_designed"
    MONITORING = "monitoring"
    SCHEDULE_MAINTENANCE = "schedule_maintenance"
    INVESTIGATE_HYDROLOGY = "investigate_hydrology"
    SENSOR_REVIEW = "sensor_review"


@dataclass(frozen=True)
class RainfallEvent:
    event_id: str
    rainfall_mm: float
    runoff_volume_l: float
    drainage_area_m2: float
    shallow_moisture_delta: float
    middle_moisture_delta: float
    deep_moisture_delta: float
    drainage_recovery_hours: float
    underdrain_volume_l: float | None
    sensor_confidence: float


@dataclass(frozen=True)
class BaselinePerformance:
    field_infiltration_mm_h: float
    shallow_moisture_delta: float
    middle_moisture_delta: float
    deep_moisture_delta: float
    drainage_recovery_hours: float
    runoff_coefficient: float


@dataclass(frozen=True)
class FieldInspection:
    measured_infiltration_mm_h: float | None
    surface_ponding_observed: bool
    underdrain_flow_observed: bool | None
    sediment_source_observed: bool
    sensor_agreement_score: float


@dataclass(frozen=True)
class VerificationPolicy:
    minimum_rainfall_mm: float = 5.0
    minimum_sensor_confidence: float = 0.70
    monitoring_clogging_index: float = 0.25
    maintenance_clogging_index: float = 0.45
    critical_clogging_index: float = 0.65
    minimum_field_infiltration_ratio: float = 0.60
    weights_field: float = 0.45
    weights_moisture: float = 0.25
    weights_recovery: float = 0.15
    weights_runoff: float = 0.15


@dataclass(frozen=True)
class PerformanceAssessment:
    event_id: str
    inferred_runoff_coefficient: float
    moisture_response_ratio: float
    recovery_ratio: float
    field_infiltration_ratio: float | None
    clogging_index: float
    condition: PavementCondition
    explanation: str


def _bounded(value: float, minimum: float, maximum: float) -> float:
    return max(minimum, min(value, maximum))


def _require_finite(name: str, value: float) -> None:
    if not isfinite(value):
        raise ValueError(f"{name} must be finite")


def _validate_positive(name: str, value: float) -> None:
    _require_finite(name, value)
    if value <= 0.0:
        raise ValueError(f"{name} must be positive")


def validate_event(event: RainfallEvent) -> None:
    if not event.event_id.strip():
        raise ValueError("event_id must be non-empty")

    for name, value in {
        "rainfall_mm": event.rainfall_mm,
        "drainage_area_m2": event.drainage_area_m2,
        "drainage_recovery_hours": event.drainage_recovery_hours,
    }.items():
        _validate_positive(name, value)

    for name, value in {
        "runoff_volume_l": event.runoff_volume_l,
        "shallow_moisture_delta": event.shallow_moisture_delta,
        "middle_moisture_delta": event.middle_moisture_delta,
        "deep_moisture_delta": event.deep_moisture_delta,
        "sensor_confidence": event.sensor_confidence,
    }.items():
        _require_finite(name, value)
        if value < 0.0:
            raise ValueError(f"{name} must not be negative")

    if event.underdrain_volume_l is not None:
        _require_finite("underdrain_volume_l", event.underdrain_volume_l)
        if event.underdrain_volume_l < 0.0:
            raise ValueError("underdrain_volume_l must not be negative")

    if event.sensor_confidence > 1.0:
        raise ValueError("sensor_confidence must be within [0, 1]")


def validate_baseline(baseline: BaselinePerformance) -> None:
    for name, value in {
        "field_infiltration_mm_h": baseline.field_infiltration_mm_h,
        "shallow_moisture_delta": baseline.shallow_moisture_delta,
        "middle_moisture_delta": baseline.middle_moisture_delta,
        "deep_moisture_delta": baseline.deep_moisture_delta,
        "drainage_recovery_hours": baseline.drainage_recovery_hours,
    }.items():
        _validate_positive(name, value)

    _require_finite("runoff_coefficient", baseline.runoff_coefficient)
    if baseline.runoff_coefficient < 0.0 or baseline.runoff_coefficient > 1.0:
        raise ValueError("runoff_coefficient must be within [0, 1]")


def validate_policy(policy: VerificationPolicy) -> None:
    _validate_positive("minimum_rainfall_mm", policy.minimum_rainfall_mm)
    _validate_positive(
        "minimum_field_infiltration_ratio",
        policy.minimum_field_infiltration_ratio,
    )

    if not 0.0 <= policy.minimum_sensor_confidence <= 1.0:
        raise ValueError("minimum_sensor_confidence must be within [0, 1]")

    thresholds = (
        policy.monitoring_clogging_index,
        policy.maintenance_clogging_index,
        policy.critical_clogging_index,
    )
    if any(value < 0.0 or value > 1.0 for value in thresholds):
        raise ValueError("clogging thresholds must be within [0, 1]")

    if not thresholds[0] <= thresholds[1] <= thresholds[2]:
        raise ValueError("clogging thresholds must be non-decreasing")

    weights = (
        policy.weights_field,
        policy.weights_moisture,
        policy.weights_recovery,
        policy.weights_runoff,
    )
    if any(weight < 0.0 for weight in weights):
        raise ValueError("clogging weights must not be negative")

    if abs(sum(weights) - 1.0) > 1e-9:
        raise ValueError("clogging weights must sum to 1")


def _mean(values: Sequence[float]) -> float:
    if not values:
        raise ValueError("values must not be empty")
    return sum(values) / len(values)


def assess_event(
    event: RainfallEvent,
    baseline: BaselinePerformance,
    inspection: FieldInspection,
    policy: VerificationPolicy = VerificationPolicy(),
) -> PerformanceAssessment:
    validate_event(event)
    validate_baseline(baseline)
    validate_policy(policy)

    if event.rainfall_mm < policy.minimum_rainfall_mm:
        raise ValueError(
            "rainfall event is below the minimum depth for comparable assessment"
        )

    _require_finite("sensor_agreement_score", inspection.sensor_agreement_score)
    if not 0.0 <= inspection.sensor_agreement_score <= 1.0:
        raise ValueError("sensor_agreement_score must be within [0, 1]")

    if inspection.measured_infiltration_mm_h is not None:
        _validate_positive(
            "measured_infiltration_mm_h",
            inspection.measured_infiltration_mm_h,
        )

    incident_rainfall_volume_l = event.rainfall_mm * event.drainage_area_m2
    runoff_coefficient = _bounded(
        event.runoff_volume_l / incident_rainfall_volume_l,
        0.0,
        1.0,
    )

    moisture_response_ratio = _bounded(
        _mean(
            (
                event.shallow_moisture_delta / baseline.shallow_moisture_delta,
                event.middle_moisture_delta / baseline.middle_moisture_delta,
                event.deep_moisture_delta / baseline.deep_moisture_delta,
            )
        ),
        0.0,
        2.0,
    )
    recovery_ratio = _bounded(
        baseline.drainage_recovery_hours / event.drainage_recovery_hours,
        0.0,
        2.0,
    )
    runoff_retention_ratio = _bounded(
        (1.0 - runoff_coefficient) / (1.0 - baseline.runoff_coefficient),
        0.0,
        2.0,
    )

    field_infiltration_ratio = None
    field_component = 1.0
    if inspection.measured_infiltration_mm_h is not None:
        field_infiltration_ratio = _bounded(
            inspection.measured_infiltration_mm_h / baseline.field_infiltration_mm_h,
            0.0,
            2.0,
        )
        field_component = field_infiltration_ratio

    inferred_capacity_ratio = _bounded(
        policy.weights_field * field_component
        + policy.weights_moisture * moisture_response_ratio
        + policy.weights_recovery * recovery_ratio
        + policy.weights_runoff * runoff_retention_ratio,
        0.0,
        1.0,
    )
    clogging_index = 1.0 - inferred_capacity_ratio

    low_confidence = (
        event.sensor_confidence < policy.minimum_sensor_confidence
        or inspection.sensor_agreement_score < policy.minimum_sensor_confidence
    )

    if low_confidence:
        condition = PavementCondition.SENSOR_REVIEW
        explanation = (
            "Hydrologic performance is not classified because sensor confidence or "
            "cross-sensor agreement is below the published verification threshold. "
            "Inspect sensors and confirm performance with a field test."
        )
    elif (
        inspection.measured_infiltration_mm_h is not None
        and field_infiltration_ratio is not None
        and field_infiltration_ratio < policy.minimum_field_infiltration_ratio
    ):
        condition = PavementCondition.SCHEDULE_MAINTENANCE
        explanation = (
            "A direct infiltration test confirms meaningful loss of infiltration "
            "capacity. Schedule approved surface cleaning and re-test after work."
        )
    elif clogging_index >= policy.critical_clogging_index:
        condition = PavementCondition.INVESTIGATE_HYDROLOGY
        explanation = (
            "Multiple event indicators show substantial hydraulic decline. Inspect "
            "for surface clogging, saturated storage, underdrain restriction, "
            "upstream sediment sources, and changed drainage pathways."
        )
    elif clogging_index >= policy.maintenance_clogging_index:
        condition = PavementCondition.SCHEDULE_MAINTENANCE
        explanation = (
            "Comparable-event indicators show reduced hydrologic performance. "
            "Schedule preventive vacuum or regenerative-air cleaning and verify "
            "recovery with a direct infiltration test."
        )
    elif clogging_index >= policy.monitoring_clogging_index:
        condition = PavementCondition.MONITORING
        explanation = (
            "Early performance change is present. Continue event-based monitoring, "
            "inspect nearby sediment sources, and prioritize this zone for the next "
            "field infiltration survey."
        )
    else:
        condition = PavementCondition.PERFORMING_AS_DESIGNED
        explanation = (
            "Current comparable-event indicators are consistent with the monitored "
            "baseline. Continue routine maintenance and periodic direct testing."
        )

    return PerformanceAssessment(
        event_id=event.event_id,
        inferred_runoff_coefficient=runoff_coefficient,
        moisture_response_ratio=moisture_response_ratio,
        recovery_ratio=recovery_ratio,
        field_infiltration_ratio=field_infiltration_ratio,
        clogging_index=clogging_index,
        condition=condition,
        explanation=explanation,
    )
