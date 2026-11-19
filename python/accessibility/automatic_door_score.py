from __future__ import annotations

from dataclasses import dataclass
import math


@dataclass(frozen=True)
class AutomaticDoorAudit:
    clear_width_inches: float
    hold_open_seconds: float
    required_hold_open_seconds: float
    target_hold_open_seconds: float
    valid_detection_tests: int
    successful_valid_detections: int
    obstruction_tests: int
    safe_obstruction_responses: int
    required_sensor_health_checks: int
    verified_sensor_health_checks: int
    opening_cycles: int
    access_affecting_faults: int
    faults_with_accessible_fallback: int
    tactile_feedback_available: bool
    audio_feedback_available: bool
    visual_feedback_available: bool
    accessible_power_failure_behavior_verified: bool
    accessible_egress_verified: bool
    accessible_fallback_available: bool
    obstruction_protection_verified: bool
    identity_neutral_access_verified: bool


@dataclass(frozen=True)
class DoorScoreResult:
    eligible_for_composite_score: bool
    score: float | None
    width_score: float | None
    timing_score: float | None
    sensor_score: float | None
    reliability_score: float | None
    feedback_score: float | None
    egress_score: float | None
    reasons: tuple[str, ...]


def calculate_accessibility_score(
    audit: AutomaticDoorAudit,
) -> DoorScoreResult:
    _validate_audit(audit)

    gate_failures = _non_offsettable_gate_failures(audit)
    if gate_failures:
        return DoorScoreResult(
            eligible_for_composite_score=False,
            score=None,
            width_score=None,
            timing_score=None,
            sensor_score=None,
            reliability_score=None,
            feedback_score=None,
            egress_score=None,
            reasons=tuple(gate_failures),
        )

    width_score = 25.0 * _clip(
        (audit.clear_width_inches - 28.0) / 4.0,
        0.0,
        1.0,
    )

    timing_denominator = (
        audit.target_hold_open_seconds
        - audit.required_hold_open_seconds
    )
    timing_score = 15.0 * _clip(
        (
            audit.hold_open_seconds
            - audit.required_hold_open_seconds
        ) / timing_denominator,
        0.0,
        1.0,
    )

    detection_reliability = (
        audit.successful_valid_detections
        / audit.valid_detection_tests
    )
    obstruction_reliability = (
        audit.safe_obstruction_responses
        / audit.obstruction_tests
    )
    monitoring_reliability = (
        audit.verified_sensor_health_checks
        / audit.required_sensor_health_checks
    )

    sensor_score = 25.0 * (
        0.60 * detection_reliability
        + 0.25 * obstruction_reliability
        + 0.15 * monitoring_reliability
    )

    failure_rate = audit.access_affecting_faults / audit.opening_cycles

    fallback_recovery_rate = (
        audit.faults_with_accessible_fallback
        / audit.access_affecting_faults
        if audit.access_affecting_faults > 0
        else 1.0
    )

    reliability_score = 15.0 * (
        0.70 * (1.0 - failure_rate)
        + 0.30 * fallback_recovery_rate
    )

    feedback_score = 10.0 * (
        0.40 * float(audit.tactile_feedback_available)
        + 0.30 * float(audit.audio_feedback_available)
        + 0.30 * float(audit.visual_feedback_available)
    )

    egress_score = 10.0 * (
        0.50 * float(audit.accessible_power_failure_behavior_verified)
        + 0.50 * float(audit.accessible_egress_verified)
    )

    score = (
        width_score
        + timing_score
        + sensor_score
        + reliability_score
        + feedback_score
        + egress_score
    )

    return DoorScoreResult(
        eligible_for_composite_score=True,
        score=round(_clip(score, 0.0, 100.0), 2),
        width_score=round(width_score, 2),
        timing_score=round(timing_score, 2),
        sensor_score=round(sensor_score, 2),
        reliability_score=round(reliability_score, 2),
        feedback_score=round(feedback_score, 2),
        egress_score=round(egress_score, 2),
        reasons=(
            "Composite score is an auditable engineering indicator and does not "
            "replace applicable accessibility, building, fire, egress, or safety review.",
        ),
    )


def _non_offsettable_gate_failures(
    audit: AutomaticDoorAudit,
) -> list[str]:
    failures: list[str] = []

    if audit.clear_width_inches < 32.0:
        failures.append(
            "Clear opening is below the configured 32-inch accessibility baseline."
        )

    if not audit.obstruction_protection_verified:
        failures.append(
            "Obstruction protection is not verified; composite scoring is blocked."
        )

    if not audit.accessible_power_failure_behavior_verified:
        failures.append(
            "Accessible power-failure behavior is not verified; composite scoring is blocked."
        )

    if not audit.accessible_egress_verified:
        failures.append(
            "Accessible egress is not verified; composite scoring is blocked."
        )

    if not audit.accessible_fallback_available:
        failures.append(
            "No accessible fallback route or assistance path is verified."
        )

    if not audit.identity_neutral_access_verified:
        failures.append(
            "Identity-neutral accessible entry is not verified."
        )

    return failures


def _validate_audit(audit: AutomaticDoorAudit) -> None:
    finite_positive = {
        "clear_width_inches": audit.clear_width_inches,
        "hold_open_seconds": audit.hold_open_seconds,
        "required_hold_open_seconds": audit.required_hold_open_seconds,
        "target_hold_open_seconds": audit.target_hold_open_seconds,
    }

    for field_name, value in finite_positive.items():
        if not math.isfinite(value) or value <= 0.0:
            raise ValueError(f"{field_name} must be finite and greater than zero.")

    if audit.target_hold_open_seconds <= audit.required_hold_open_seconds:
        raise ValueError(
            "target_hold_open_seconds must exceed required_hold_open_seconds."
        )

    nonnegative_counts = {
        "valid_detection_tests": audit.valid_detection_tests,
        "successful_valid_detections": audit.successful_valid_detections,
        "obstruction_tests": audit.obstruction_tests,
        "safe_obstruction_responses": audit.safe_obstruction_responses,
        "required_sensor_health_checks": audit.required_sensor_health_checks,
        "verified_sensor_health_checks": audit.verified_sensor_health_checks,
        "opening_cycles": audit.opening_cycles,
        "access_affecting_faults": audit.access_affecting_faults,
        "faults_with_accessible_fallback": audit.faults_with_accessible_fallback,
    }

    for field_name, value in nonnegative_counts.items():
        if value < 0:
            raise ValueError(f"{field_name} must be non-negative.")

    if audit.valid_detection_tests == 0:
        raise ValueError("valid_detection_tests must be greater than zero.")

    if audit.obstruction_tests == 0:
        raise ValueError("obstruction_tests must be greater than zero.")

    if audit.required_sensor_health_checks == 0:
        raise ValueError(
            "required_sensor_health_checks must be greater than zero."
        )

    if audit.opening_cycles == 0:
        raise ValueError("opening_cycles must be greater than zero.")

    if audit.successful_valid_detections > audit.valid_detection_tests:
        raise ValueError(
            "successful_valid_detections cannot exceed valid_detection_tests."
        )

    if audit.safe_obstruction_responses > audit.obstruction_tests:
        raise ValueError(
            "safe_obstruction_responses cannot exceed obstruction_tests."
        )

    if audit.verified_sensor_health_checks > audit.required_sensor_health_checks:
        raise ValueError(
            "verified_sensor_health_checks cannot exceed required_sensor_health_checks."
        )

    if audit.access_affecting_faults > audit.opening_cycles:
        raise ValueError(
            "access_affecting_faults cannot exceed opening_cycles."
        )

    if audit.faults_with_accessible_fallback > audit.access_affecting_faults:
        raise ValueError(
            "faults_with_accessible_fallback cannot exceed access_affecting_faults."
        )


def _clip(value: float, lower: float, upper: float) -> float:
    return max(lower, min(value, upper))
