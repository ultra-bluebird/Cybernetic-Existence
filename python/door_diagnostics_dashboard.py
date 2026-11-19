from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any


@dataclass(frozen=True)
class DoorDiagnostic:
    timestamp: str
    state: str
    fault: str
    speed_ratio: float
    opening_width_ratio: float
    lidar_healthy: bool
    ultrasonic_healthy_count: int
    pressure_mat_healthy: bool
    pressure_mat_occupied: bool
    motor_healthy: bool


def parse_message(payload: bytes) -> DoorDiagnostic:
    document: dict[str, Any] = json.loads(payload.decode("utf-8"))
    required = {
        "state",
        "fault",
        "speed_ratio",
        "opening_width_ratio",
        "lidar_healthy",
        "ultrasonic_healthy_count",
        "pressure_mat_healthy",
        "pressure_mat_occupied",
        "motor_healthy",
    }
    missing = required.difference(document)
    if missing:
        raise ValueError(f"missing status fields: {sorted(missing)}")

    speed_ratio = float(document["speed_ratio"])
    opening_width_ratio = float(document["opening_width_ratio"])
    healthy_count = int(document["ultrasonic_healthy_count"])

    if not 0.0 <= speed_ratio <= 1.0:
        raise ValueError("speed_ratio must be in the interval [0, 1]")
    if not 0.0 <= opening_width_ratio <= 1.0:
        raise ValueError("opening_width_ratio must be in the interval [0, 1]")
    if not 0 <= healthy_count <= 6:
        raise ValueError("ultrasonic_healthy_count must be in the interval [0, 6]")

    return DoorDiagnostic(
        timestamp=datetime.now(timezone.utc).isoformat(),
        state=str(document["state"]),
        fault=str(document["fault"]),
        speed_ratio=speed_ratio,
        opening_width_ratio=opening_width_ratio,
        lidar_healthy=bool(document["lidar_healthy"]),
        ultrasonic_healthy_count=healthy_count,
        pressure_mat_healthy=bool(document["pressure_mat_healthy"]),
        pressure_mat_occupied=bool(document["pressure_mat_occupied"]),
        motor_healthy=bool(document["motor_healthy"]),
    )


def accessible_summary(diagnostic: DoorDiagnostic) -> str:
    health = "healthy" if (
        diagnostic.lidar_healthy
        and diagnostic.ultrasonic_healthy_count >= 4
        and diagnostic.pressure_mat_healthy
        and diagnostic.motor_healthy
    ) else "requires maintenance review"

    return (
        f"Door state: {diagnostic.state}. "
        f"Safety status: {health}. "
        f"Fault status: {diagnostic.fault}. "
        f"Opening width: {diagnostic.opening_width_ratio:.0%}. "
        f"Motion speed: {diagnostic.speed_ratio:.0%}. "
        f"Pressure mat occupied: {'yes' if diagnostic.pressure_mat_occupied else 'no'}."
    )


def publishable_status(diagnostic: DoorDiagnostic) -> dict[str, object]:
    return {
        "timestamp": diagnostic.timestamp,
        "state": diagnostic.state,
        "fault": diagnostic.fault,
        "speed_ratio": diagnostic.speed_ratio,
        "opening_width_ratio": diagnostic.opening_width_ratio,
        "lidar_healthy": diagnostic.lidar_healthy,
        "ultrasonic_healthy_count": diagnostic.ultrasonic_healthy_count,
        "pressure_mat_healthy": diagnostic.pressure_mat_healthy,
        "pressure_mat_occupied": diagnostic.pressure_mat_occupied,
        "motor_healthy": diagnostic.motor_healthy,
        "human_readable_summary": accessible_summary(diagnostic),
    }
