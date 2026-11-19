from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Iterable


class TransitPredictionValidationError(ValueError):
    pass


@dataclass(frozen=True)
class RouteSegment:
    distance_m: float
    expected_speed_m_s: float

    def __post_init__(self) -> None:
        if not isfinite(self.distance_m) or self.distance_m < 0.0:
            raise TransitPredictionValidationError(
                "distance_m must be finite and non-negative."
            )
        if not isfinite(self.expected_speed_m_s) or self.expected_speed_m_s <= 0.0:
            raise TransitPredictionValidationError(
                "expected_speed_m_s must be finite and positive."
            )


@dataclass(frozen=True)
class VehicleTelemetry:
    route_id: str
    trip_id: str
    telemetry_age_s: float
    schedule_deviation_s: float
    estimated_dwell_adjustment_s: float
    disruption_adjustment_s: float
    passenger_device_data_used: bool = False
    wifi_or_bluetooth_tracking_used: bool = False

    def __post_init__(self) -> None:
        if not self.route_id.strip() or not self.trip_id.strip():
            raise TransitPredictionValidationError(
                "route_id and trip_id must be non-empty."
            )
        for field_name, value in (
            ("telemetry_age_s", self.telemetry_age_s),
            ("schedule_deviation_s", self.schedule_deviation_s),
            ("estimated_dwell_adjustment_s", self.estimated_dwell_adjustment_s),
            ("disruption_adjustment_s", self.disruption_adjustment_s),
        ):
            if not isfinite(value):
                raise TransitPredictionValidationError(
                    f"{field_name} must be finite."
                )
        if self.telemetry_age_s < 0.0:
            raise TransitPredictionValidationError(
                "telemetry_age_s must be non-negative."
            )


@dataclass(frozen=True)
class EtaPrediction:
    predicted_arrival_seconds: float | None
    prediction_mode: str
    passenger_tracking_used: bool
    reason: str


def predict_arrival_seconds(
    segments: Iterable[RouteSegment],
    telemetry: VehicleTelemetry,
    maximum_live_telemetry_age_s: float = 90.0,
) -> EtaPrediction:
    if (
        not isfinite(maximum_live_telemetry_age_s)
        or maximum_live_telemetry_age_s <= 0.0
    ):
        raise TransitPredictionValidationError(
            "maximum_live_telemetry_age_s must be finite and positive."
        )

    if telemetry.passenger_device_data_used or telemetry.wifi_or_bluetooth_tracking_used:
        raise TransitPredictionValidationError(
            "Passenger device and Wi-Fi/Bluetooth tracking data are prohibited."
        )

    route_segments = list(segments)
    if not route_segments:
        return EtaPrediction(
            predicted_arrival_seconds=None,
            prediction_mode="SERVICE_ALERT_ACTIVE",
            passenger_tracking_used=False,
            reason="No valid route geometry is available for a prediction.",
        )

    travel_seconds = sum(
        segment.distance_m / segment.expected_speed_m_s
        for segment in route_segments
    )

    estimate = max(
        0.0,
        travel_seconds
        + telemetry.schedule_deviation_s
        + telemetry.estimated_dwell_adjustment_s
        + telemetry.disruption_adjustment_s,
    )

    if telemetry.telemetry_age_s > maximum_live_telemetry_age_s:
        return EtaPrediction(
            predicted_arrival_seconds=estimate,
            prediction_mode="SCHEDULE_BASED_ESTIMATE",
            passenger_tracking_used=False,
            reason=(
                "Vehicle telemetry is stale. The displayed estimate uses route and "
                "schedule context with a visible uncertainty notice."
            ),
        )

    return EtaPrediction(
        predicted_arrival_seconds=estimate,
        prediction_mode="LIVE_VEHICLE_PREDICTION",
        passenger_tracking_used=False,
        reason=(
            "The estimate uses vehicle telemetry, route geometry, and fixed "
            "operational adjustments only."
        ),
    )


def prediction_quality(
    actual_arrival_seconds: Iterable[float],
    predicted_arrival_seconds: Iterable[float],
) -> tuple[float, float]:
    actual = list(actual_arrival_seconds)
    predicted = list(predicted_arrival_seconds)

    if not actual or len(actual) != len(predicted):
        raise TransitPredictionValidationError(
            "Actual and predicted arrival values must be non-empty and have equal length."
        )

    absolute_errors: list[float] = []
    for observed, estimated in zip(actual, predicted, strict=True):
        if not isfinite(observed) or not isfinite(estimated):
            raise TransitPredictionValidationError(
                "Arrival values must be finite."
            )
        absolute_errors.append(abs(observed - estimated))

    mean_absolute_error_seconds = sum(absolute_errors) / len(absolute_errors)
    within_one_minute_fraction = (
        sum(error < 60.0 for error in absolute_errors) / len(absolute_errors)
    )
    return mean_absolute_error_seconds, within_one_minute_fraction
