from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from math import isfinite
from typing import Optional


class TreeHealthState(str, Enum):
    STABLE = "stable"
    WATCH = "watch"
    ALERT = "alert"
    PRIORITY_REVIEW = "priority_review"
    SENSOR_REVIEW = "sensor_review"


@dataclass(frozen=True)
class TreeMeasurement:
    tree_reference: str
    timestamp_unix_s: int
    canopy_temperature_c: float
    air_temperature_c: float
    vapor_pressure_deficit_kpa: float
    root_zone_moisture_fraction: float
    sap_flow_relative: float
    expected_sap_flow_relative: float
    stem_shrinkage_um: float
    baseline_stem_shrinkage_um: float
    potential_stem_shrinkage_um: float
    actual_et_mm_day: float
    potential_et_mm_day: float
    canopy_temperature_baseline_delta_c: float
    sensor_confidence: float


@dataclass(frozen=True)
class TreeHealthPolicy:
    vpd_minimum_kpa: float = 0.20
    root_zone_wilting_fraction: float = 0.08
    root_zone_target_fraction: float = 0.25
    canopy_temperature_stress_delta_c: float = 4.0
    stem_shrinkage_stress_um: float = 180.0
    et_target_ratio: float = 0.75
    minimum_sensor_confidence: float = 0.70
    watch_threshold: float = 0.25
    alert_threshold: float = 0.45
    priority_review_threshold: float = 0.65


@dataclass(frozen=True)
class TreeStressAssessment:
    tree_reference: str
    stress_index: float
    canopy_heat_signal: float
    root_zone_water_signal: float
    sap_flow_signal: float
    stem_water_signal: float
    evapotranspiration_signal: float
    health_state: TreeHealthState
    explanation: str


def _bounded(value: float, minimum: float, maximum: float) -> float:
    return max(minimum, min(value, maximum))


def _require_finite(name: str, value: float) -> None:
    if not isfinite(value):
        raise ValueError(f"{name} must be finite")


def _require_fraction(name: str, value: float) -> None:
    _require_finite(name, value)
    if value < 0.0 or value > 1.0:
        raise ValueError(f"{name} must be within [0, 1]")


def validate_measurement(measurement: TreeMeasurement) -> None:
    if not measurement.tree_reference.strip():
        raise ValueError("tree_reference must be non-empty")

    if measurement.timestamp_unix_s <= 0:
        raise ValueError("timestamp_unix_s must be positive")

    for name, value in {
        "canopy_temperature_c": measurement.canopy_temperature_c,
        "air_temperature_c": measurement.air_temperature_c,
        "vapor_pressure_deficit_kpa": measurement.vapor_pressure_deficit_kpa,
        "stem_shrinkage_um": measurement.stem_shrinkage_um,
        "baseline_stem_shrinkage_um": measurement.baseline_stem_shrinkage_um,
        "potential_stem_shrinkage_um": measurement.potential_stem_shrinkage_um,
        "actual_et_mm_day": measurement.actual_et_mm_day,
        "potential_et_mm_day": measurement.potential_et_mm_day,
        "canopy_temperature_baseline_delta_c": (
            measurement.canopy_temperature_baseline_delta_c
        ),
    }.items():
        _require_finite(name, value)

    for name, value in {
        "root_zone_moisture_fraction": measurement.root_zone_moisture_fraction,
        "sap_flow_relative": measurement.sap_flow_relative,
        "expected_sap_flow_relative": measurement.expected_sap_flow_relative,
        "sensor_confidence": measurement.sensor_confidence,
    }.items():
        _require_fraction(name, value)

    if measurement.vapor_pressure_deficit_kpa < 0.0:
        raise ValueError("vapor_pressure_deficit_kpa must not be negative")

    if measurement.actual_et_mm_day < 0.0:
        raise ValueError("actual_et_mm_day must not be negative")

    if measurement.potential_et_mm_day <= 0.0:
        raise ValueError("potential_et_mm_day must be positive")

    if measurement.potential_stem_shrinkage_um <= (
        measurement.baseline_stem_shrinkage_um
    ):
        raise ValueError(
            "potential_stem_shrinkage_um must exceed baseline_stem_shrinkage_um"
        )


def validate_policy(policy: TreeHealthPolicy) -> None:
    if policy.vpd_minimum_kpa <= 0.0:
        raise ValueError("vpd_minimum_kpa must be positive")

    _require_fraction(
        "root_zone_wilting_fraction",
        policy.root_zone_wilting_fraction,
    )
    _require_fraction(
        "root_zone_target_fraction",
        policy.root_zone_target_fraction,
    )
    _require_fraction("et_target_ratio", policy.et_target_ratio)
    _require_fraction(
        "minimum_sensor_confidence",
        policy.minimum_sensor_confidence,
    )

    if policy.root_zone_target_fraction <= policy.root_zone_wilting_fraction:
        raise ValueError(
            "root_zone_target_fraction must exceed root_zone_wilting_fraction"
        )

    if policy.canopy_temperature_stress_delta_c <= 0.0:
        raise ValueError("canopy_temperature_stress_delta_c must be positive")

    if policy.stem_shrinkage_stress_um <= 0.0:
        raise ValueError("stem_shrinkage_stress_um must be positive")

    thresholds = (
        policy.watch_threshold,
        policy.alert_threshold,
        policy.priority_review_threshold,
    )
    if any(threshold < 0.0 or threshold > 1.0 for threshold in thresholds):
        raise ValueError("health-state thresholds must be within [0, 1]")

    if not thresholds[0] <= thresholds[1] <= thresholds[2]:
        raise ValueError("health-state thresholds must be non-decreasing")


def assess_tree_stress(
    measurement: TreeMeasurement,
    policy: TreeHealthPolicy = TreeHealthPolicy(),
) -> TreeStressAssessment:
    validate_measurement(measurement)
    validate_policy(policy)

    canopy_air_delta_c = (
        measurement.canopy_temperature_c - measurement.air_temperature_c
    )
    canopy_excess_c = (
        canopy_air_delta_c - measurement.canopy_temperature_baseline_delta_c
    )
    canopy_heat_signal = _bounded(
        canopy_excess_c / policy.canopy_temperature_stress_delta_c,
        0.0,
        1.0,
    )

    root_zone_water_signal = 1.0 - _bounded(
        (
            measurement.root_zone_moisture_fraction
            - policy.root_zone_wilting_fraction
        )
        / (
            policy.root_zone_target_fraction
            - policy.root_zone_wilting_fraction
        ),
        0.0,
        1.0,
    )

    expected_flow = max(measurement.expected_sap_flow_relative, 0.01)
    sap_flow_signal = 1.0 - _bounded(
        measurement.sap_flow_relative / expected_flow,
        0.0,
        1.0,
    )

    stem_water_signal = _bounded(
        (
            measurement.stem_shrinkage_um
            - measurement.baseline_stem_shrinkage_um
        )
        / (
            measurement.potential_stem_shrinkage_um
            - measurement.baseline_stem_shrinkage_um
        ),
        0.0,
        1.0,
    )

    et_ratio = _bounded(
        measurement.actual_et_mm_day / measurement.potential_et_mm_day,
        0.0,
        1.0,
    )
    et_denominator = max(1.0 - policy.et_target_ratio, 0.01)
    evapotranspiration_signal = _bounded(
        (1.0 - et_ratio) / et_denominator,
        0.0,
        1.0,
    )

    stress_index = _bounded(
        0.25 * canopy_heat_signal
        + 0.25 * root_zone_water_signal
        + 0.25 * sap_flow_signal
        + 0.15 * stem_water_signal
        + 0.10 * evapotranspiration_signal,
        0.0,
        1.0,
    )

    daytime_vpd_usable = (
        measurement.vapor_pressure_deficit_kpa >= policy.vpd_minimum_kpa
    )
    sensor_usable = (
        measurement.sensor_confidence >= policy.minimum_sensor_confidence
    )

    if not sensor_usable or not daytime_vpd_usable:
        health_state = TreeHealthState.SENSOR_REVIEW
        explanation = (
            "The physiological stress assessment is withheld because sensor "
            "confidence is low or vapor-pressure deficit is too low for a "
            "reliable transpiration interpretation. Review sensor condition "
            "and use a comparable daytime observation window."
        )
    elif stress_index >= policy.priority_review_threshold:
        health_state = TreeHealthState.PRIORITY_REVIEW
        explanation = (
            "Multiple physiological indicators show substantial water or heat "
            "stress. Schedule a field review of irrigation, rooting volume, "
            "soil compaction, mulch condition, and nearby disturbance before "
            "making any intervention decision."
        )
    elif stress_index >= policy.alert_threshold:
        health_state = TreeHealthState.ALERT
        explanation = (
            "Convergent sensor signals suggest developing stress. Increase "
            "monitoring frequency and initiate a field inspection to evaluate "
            "water availability and site conditions."
        )
    elif stress_index >= policy.watch_threshold:
        health_state = TreeHealthState.WATCH
        explanation = (
            "Early deviation from the expected physiological baseline is "
            "present. Continue comparable-event monitoring and inspect the "
            "site during the next scheduled maintenance round."
        )
    else:
        health_state = TreeHealthState.STABLE
        explanation = (
            "The available measurements are consistent with the tree's current "
            "physiological baseline. Continue seasonal monitoring and periodic "
            "field condition assessment."
        )

    return TreeStressAssessment(
        tree_reference=measurement.tree_reference,
        stress_index=stress_index,
        canopy_heat_signal=canopy_heat_signal,
        root_zone_water_signal=root_zone_water_signal,
        sap_flow_signal=sap_flow_signal,
        stem_water_signal=stem_water_signal,
        evapotranspiration_signal=evapotranspiration_signal,
        health_state=health_state,
        explanation=explanation,
    )
