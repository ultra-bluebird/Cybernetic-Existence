from __future__ import annotations

from dataclasses import dataclass
from math import isfinite


class CalibrationValidationError(ValueError):
    pass


@dataclass(frozen=True)
class ReferenceObservation:
    sensor_value: float
    reference_value: float
    expected_value: float
    tolerance: float
    instrument_health_valid: bool

    def residual(self) -> float:
        values = (
            self.sensor_value,
            self.reference_value,
            self.expected_value,
            self.tolerance,
        )
        if any(not isfinite(value) for value in values):
            raise CalibrationValidationError("All calibration values must be finite.")
        if self.tolerance <= 0.0:
            raise CalibrationValidationError("tolerance must be positive.")
        return self.sensor_value - self.expected_value


@dataclass(frozen=True)
class DriftDecision:
    state: str
    residual: float | None
    positive_cusum: float
    negative_cusum: float
    requires_calibration_review: bool
    safe_for_automated_reliance: bool
    reason: str


@dataclass
class CusumDriftDetector:
    expected_residual_mean: float
    allowance: float
    decision_threshold: float
    positive_cusum: float = 0.0
    negative_cusum: float = 0.0

    def __post_init__(self) -> None:
        values = (
            self.expected_residual_mean,
            self.allowance,
            self.decision_threshold,
        )
        if any(not isfinite(value) for value in values):
            raise CalibrationValidationError("CUSUM configuration values must be finite.")
        if self.allowance < 0.0:
            raise CalibrationValidationError("allowance must be non-negative.")
        if self.decision_threshold <= 0.0:
            raise CalibrationValidationError("decision_threshold must be positive.")

    def observe(self, observation: ReferenceObservation) -> DriftDecision:
        if not observation.instrument_health_valid:
            self.positive_cusum = 0.0
            self.negative_cusum = 0.0
            return DriftDecision(
                state="OUT_OF_SERVICE_FOR_AUTOMATED_RELIANCE",
                residual=None,
                positive_cusum=self.positive_cusum,
                negative_cusum=self.negative_cusum,
                requires_calibration_review=True,
                safe_for_automated_reliance=False,
                reason="Instrument-health validation failed; reference comparison is not reliable.",
            )

        residual = observation.residual()
        centered = residual - self.expected_residual_mean

        self.positive_cusum = max(
            0.0,
            self.positive_cusum + centered - self.allowance,
        )
        self.negative_cusum = min(
            0.0,
            self.negative_cusum + centered + self.allowance,
        )

        positive_drift = self.positive_cusum > self.decision_threshold
        negative_drift = self.negative_cusum < -self.decision_threshold

        if positive_drift or negative_drift:
            return DriftDecision(
                state="DRIFT_REVIEW_REQUIRED",
                residual=residual,
                positive_cusum=self.positive_cusum,
                negative_cusum=self.negative_cusum,
                requires_calibration_review=True,
                safe_for_automated_reliance=False,
                reason="CUSUM threshold crossed; manual calibration review is required.",
            )

        if self.positive_cusum > 0.0 or self.negative_cusum < 0.0:
            return DriftDecision(
                state="SUSPECT_DRIFT",
                residual=residual,
                positive_cusum=self.positive_cusum,
                negative_cusum=self.negative_cusum,
                requires_calibration_review=False,
                safe_for_automated_reliance=True,
                reason="Residual shift detected but the calibration review threshold is not crossed.",
            )

        return DriftDecision(
            state="NOMINAL",
            residual=residual,
            positive_cusum=self.positive_cusum,
            negative_cusum=self.negative_cusum,
            requires_calibration_review=False,
            safe_for_automated_reliance=True,
            reason="Reference residual remains within the configured calibration corridor.",
        )


def scheduled_calibration_interval_days(
    maximum_allowable_error: float,
    conservative_drift_rate_per_day: float,
    safety_factor: float = 1.5,
) -> float:
    values = (
        maximum_allowable_error,
        conservative_drift_rate_per_day,
        safety_factor,
    )
    if any(not isfinite(value) for value in values):
        raise CalibrationValidationError("Calibration scheduling values must be finite.")
    if maximum_allowable_error <= 0.0:
        raise CalibrationValidationError("maximum_allowable_error must be positive.")
    if conservative_drift_rate_per_day <= 0.0:
        raise CalibrationValidationError(
            "conservative_drift_rate_per_day must be positive."
        )
    if safety_factor < 1.0:
        raise CalibrationValidationError("safety_factor must be at least one.")

    return maximum_allowable_error / (
        safety_factor * conservative_drift_rate_per_day
    )
