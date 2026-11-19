from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Mapping
import math


@dataclass(frozen=True)
class IrrigationTwin:
    asset_id: str
    twin_version: int
    observed_at: datetime
    soil_moisture_fraction: float
    rainfall_mm: float
    forecast_rainfall_mm: float
    evapotranspiration_mm: float
    delivered_irrigation_mm: float
    valve_healthy: bool
    flood_alert_active: bool
    habitat_protection_active: bool
    maintenance_lock_active: bool


@dataclass(frozen=True)
class ProposedCommand:
    command_id: str
    asset_id: str
    command_type: str
    duration_seconds: int
    expires_at: datetime
    expected_twin_version: int
    reason: str
    requires_simulation: bool
    human_review_required: bool


def propose_irrigation(
    twin: IrrigationTwin,
    now: datetime,
    target_moisture_fraction: float,
    deficit_threshold_mm: float,
    maximum_duration_seconds: int,
    flow_rate_liters_per_second: float,
    zone_area_square_meters: float,
) -> ProposedCommand | None:
    if now.tzinfo is None or twin.observed_at.tzinfo is None:
        raise ValueError("Timestamps must be timezone-aware.")
    if not twin.asset_id or len(twin.asset_id) > 160:
        raise ValueError("asset_id is required and must be at most 160 characters.")
    if twin.twin_version < 0:
        raise ValueError("twin_version must be non-negative.")
    if not 0.0 <= twin.soil_moisture_fraction <= 1.0:
        raise ValueError("soil_moisture_fraction must be within [0, 1].")
    if not 0.0 < target_moisture_fraction <= 1.0:
        raise ValueError("target_moisture_fraction must be within (0, 1].")
    if deficit_threshold_mm < 0.0 or maximum_duration_seconds <= 0:
        raise ValueError("Threshold and duration must be positive.")
    if flow_rate_liters_per_second <= 0.0 or zone_area_square_meters <= 0.0:
        raise ValueError("Hydraulic configuration must be positive.")

    telemetry_age = now.astimezone(timezone.utc) - twin.observed_at.astimezone(timezone.utc)
    if telemetry_age > timedelta(minutes=20):
        return None

    if (
        not twin.valve_healthy
        or twin.flood_alert_active
        or twin.habitat_protection_active
        or twin.maintenance_lock_active
    ):
        return None

    water_deficit_mm = max(
        0.0,
        twin.evapotranspiration_mm
        - twin.rainfall_mm
        - twin.delivered_irrigation_mm,
    )

    soil_moisture_gap = max(
        0.0,
        target_moisture_fraction - twin.soil_moisture_fraction,
    )

    if (
        water_deficit_mm < deficit_threshold_mm
        or soil_moisture_gap <= 0.0
        or twin.forecast_rainfall_mm >= water_deficit_mm
    ):
        return None

    required_liters = soil_moisture_gap * zone_area_square_meters * 1000.0
    requested_duration = math.ceil(required_liters / flow_rate_liters_per_second)
    duration_seconds = min(requested_duration, maximum_duration_seconds)

    if duration_seconds <= 0:
        return None

    return ProposedCommand(
        command_id=f"irrigation:{twin.asset_id}:{twin.twin_version}",
        asset_id=twin.asset_id,
        command_type="irrigation.open_valve",
        duration_seconds=duration_seconds,
        expires_at=now.astimezone(timezone.utc) + timedelta(minutes=10),
        expected_twin_version=twin.twin_version,
        reason=(
            "Verified soil-moisture deficit exceeds configured threshold; "
            "forecast rain is insufficient; safety and habitat interlocks are clear."
        ),
        requires_simulation=True,
        human_review_required=False,
    )
