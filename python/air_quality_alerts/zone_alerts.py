from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Iterable


class AirQualityAlertValidationError(ValueError):
    pass


PM25_24_HOUR_TRIGGER_UG_M3 = 35.0
DELIVERY_TARGET_PERCENT = 95.0


@dataclass(frozen=True)
class ZoneMeasurement:
    zone_id: str
    rolling_24h_pm25_ug_m3: float
    measurement_validated: bool
    measured_at: str

    def __post_init__(self) -> None:
        if not self.zone_id.strip():
            raise AirQualityAlertValidationError("zone_id must be non-empty.")
        if not isfinite(self.rolling_24h_pm25_ug_m3) or self.rolling_24h_pm25_ug_m3 < 0.0:
            raise AirQualityAlertValidationError(
                "rolling_24h_pm25_ug_m3 must be finite and non-negative."
            )
        if not self.measured_at.strip():
            raise AirQualityAlertValidationError("measured_at must be non-empty.")


@dataclass(frozen=True)
class ZoneAlert:
    zone_id: str
    state: str
    message: str
    channels: tuple[str, ...]
    includes_personal_data: bool = False
    includes_health_records: bool = False
    includes_precise_location_tracking: bool = False


def create_zone_alert(
    measurement: ZoneMeasurement,
    channels: Iterable[str],
) -> ZoneAlert:
    unique_channels = tuple(sorted({channel.strip() for channel in channels if channel.strip()}))
    if not unique_channels:
        raise AirQualityAlertValidationError("At least one accessible alert channel is required.")

    if not measurement.measurement_validated:
        return ZoneAlert(
            zone_id=measurement.zone_id,
            state="PRELIMINARY_ELEVATED_READING",
            message=(
                "Preliminary air-quality data are under review. Check official local "
                "public-health information for current conditions."
            ),
            channels=unique_channels,
        )

    if measurement.rolling_24h_pm25_ug_m3 > PM25_24_HOUR_TRIGGER_UG_M3:
        return ZoneAlert(
            zone_id=measurement.zone_id,
            state="VALIDATED_ZONE_ALERT",
            message=(
                "Air quality in this zone may be unhealthy today. Consider reducing "
                "prolonged outdoor exertion if you are sensitive to air pollution. "
                "Check local public-health guidance for current conditions and support options."
            ),
            channels=unique_channels,
        )

    return ZoneAlert(
        zone_id=measurement.zone_id,
        state="NO_ALERT",
        message="No zone-level PM2.5 alert is active under the configured operational rule.",
        channels=unique_channels,
    )


def estimated_coverage_percent(
    estimated_vulnerable_population: int,
    estimated_reached_population: int,
) -> float:
    if estimated_vulnerable_population <= 0:
        raise AirQualityAlertValidationError(
            "estimated_vulnerable_population must be positive."
        )
    if estimated_reached_population < 0:
        raise AirQualityAlertValidationError(
            "estimated_reached_population must be non-negative."
        )

    return min(
        100.0,
        (estimated_reached_population / estimated_vulnerable_population) * 100.0,
    )


def meets_delivery_target(
    estimated_vulnerable_population: int,
    estimated_reached_population: int,
) -> bool:
    return (
        estimated_coverage_percent(
            estimated_vulnerable_population,
            estimated_reached_population,
        )
        >= DELIVERY_TARGET_PERCENT
    )
