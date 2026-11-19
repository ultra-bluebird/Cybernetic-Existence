from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timezone
from math import isfinite
from typing import Any


@dataclass(frozen=True)
class StreetlightTelemetry:
    schema_version: str
    node_pseudonym: str
    observed_at: str
    temperature_c: float
    relative_humidity_percent: float
    illuminance_lux: float
    luminaire_state: str
    grid_power_present: bool
    battery_confidence: float
    sensor_confidence: float


ALLOWED_LUMINAIRE_STATES = {
    "operational",
    "degraded",
    "fault",
}


def clamp_unit(value: float) -> float:
    if not isfinite(value):
        raise ValueError("value must be finite")
    return max(0.0, min(1.0, value))


def parse_telemetry(payload: bytes) -> StreetlightTelemetry:
    document: dict[str, Any] = json.loads(payload.decode("utf-8"))
    required = {
        "schema_version",
        "node_pseudonym",
        "observed_at",
        "temperature_c",
        "relative_humidity_percent",
        "illuminance_lux",
        "luminaire_state",
        "grid_power_present",
        "battery_confidence",
        "sensor_confidence",
    }
    missing = required.difference(document)
    if missing:
        raise ValueError(f"missing telemetry fields: {sorted(missing)}")

    observed_at = str(document["observed_at"])
    datetime.fromisoformat(observed_at.replace("Z", "+00:00"))

    luminaire_state = str(document["luminaire_state"])
    if luminaire_state not in ALLOWED_LUMINAIRE_STATES:
        raise ValueError("unsupported luminaire state")

    temperature_c = float(document["temperature_c"])
    humidity = float(document["relative_humidity_percent"])
    illuminance = float(document["illuminance_lux"])

    if not all(isfinite(value) for value in (temperature_c, humidity, illuminance)):
        raise ValueError("environmental values must be finite")
    if not 0.0 <= humidity <= 100.0:
        raise ValueError("relative_humidity_percent must be in [0, 100]")
    if illuminance < 0.0:
        raise ValueError("illuminance_lux must be non-negative")

    return StreetlightTelemetry(
        schema_version=str(document["schema_version"]),
        node_pseudonym=str(document["node_pseudonym"]),
        observed_at=observed_at,
        temperature_c=temperature_c,
        relative_humidity_percent=humidity,
        illuminance_lux=illuminance,
        luminaire_state=luminaire_state,
        grid_power_present=bool(document["grid_power_present"]),
        battery_confidence=clamp_unit(float(document["battery_confidence"])),
        sensor_confidence=clamp_unit(float(document["sensor_confidence"])),
    )


def mqtt_message(telemetry: StreetlightTelemetry) -> dict[str, object]:
    return {
        "schema_version": telemetry.schema_version,
        "node_pseudonym": telemetry.node_pseudonym,
        "observed_at": telemetry.observed_at,
        "temperature_c": telemetry.temperature_c,
        "relative_humidity_percent": telemetry.relative_humidity_percent,
        "illuminance_lux": telemetry.illuminance_lux,
        "luminaire_state": telemetry.luminaire_state,
        "grid_power_present": telemetry.grid_power_present,
        "battery_confidence": telemetry.battery_confidence,
        "sensor_confidence": telemetry.sensor_confidence,
        "received_at": datetime.now(timezone.utc).isoformat(),
    }
