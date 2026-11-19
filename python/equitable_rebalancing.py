from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Iterable


@dataclass(frozen=True)
class ServiceZone:
    zone_name: str
    available_vehicles: int
    accessibility_ready_vehicles: int
    minimum_available_vehicles: int
    minimum_accessibility_ready_vehicles: int
    expected_requests: int


@dataclass(frozen=True)
class RebalancingMove:
    source_zone: str
    destination_zone: str
    vehicle_count: int
    distance_km: float
    emissions_gco2e_per_km: float


@dataclass(frozen=True)
class RebalancingAssessment:
    approved: bool
    total_deadhead_km: float
    total_deadhead_emissions_gco2e: float
    reasons: tuple[str, ...]


def _require_nonnegative_integer(name: str, value: int) -> None:
    if value < 0:
        raise ValueError(f"{name} must not be negative")


def _require_finite_nonnegative(name: str, value: float) -> None:
    if not isfinite(value) or value < 0.0:
        raise ValueError(f"{name} must be finite and non-negative")


def assess_rebalancing(
    zones: Iterable[ServiceZone],
    moves: Iterable[RebalancingMove],
) -> RebalancingAssessment:
    indexed_zones = {zone.zone_name: zone for zone in zones}
    if not indexed_zones:
        raise ValueError("at least one service zone is required")

    remaining_vehicles = {}
    remaining_accessibility_ready = {}

    for zone in indexed_zones.values():
        if not zone.zone_name.strip():
            raise ValueError("zone_name must be non-empty")

        for name, value in {
            "available_vehicles": zone.available_vehicles,
            "accessibility_ready_vehicles": zone.accessibility_ready_vehicles,
            "minimum_available_vehicles": zone.minimum_available_vehicles,
            "minimum_accessibility_ready_vehicles": (
                zone.minimum_accessibility_ready_vehicles
            ),
            "expected_requests": zone.expected_requests,
        }.items():
            _require_nonnegative_integer(name, value)

        if zone.accessibility_ready_vehicles > zone.available_vehicles:
            raise ValueError(
                "accessibility_ready_vehicles must not exceed available_vehicles"
            )

        remaining_vehicles[zone.zone_name] = zone.available_vehicles
        remaining_accessibility_ready[zone.zone_name] = (
            zone.accessibility_ready_vehicles
        )

    reasons: list[str] = []
    total_deadhead_km = 0.0
    total_deadhead_emissions_gco2e = 0.0

    for move in moves:
        if move.source_zone not in indexed_zones:
            reasons.append(f"Unknown source zone: {move.source_zone}.")
            continue
        if move.destination_zone not in indexed_zones:
            reasons.append(f"Unknown destination zone: {move.destination_zone}.")
            continue
        if move.vehicle_count <= 0:
            reasons.append(
                f"Move from {move.source_zone} must contain at least one vehicle."
            )
            continue

        _require_finite_nonnegative("distance_km", move.distance_km)
        _require_finite_nonnegative(
            "emissions_gco2e_per_km",
            move.emissions_gco2e_per_km,
        )

        remaining_vehicles[move.source_zone] -= move.vehicle_count
        remaining_vehicles[move.destination_zone] += move.vehicle_count
        total_deadhead_km += move.distance_km * move.vehicle_count
        total_deadhead_emissions_gco2e += (
            move.distance_km
            * move.vehicle_count
            * move.emissions_gco2e_per_km
        )

    for zone_name, zone in indexed_zones.items():
        if remaining_vehicles[zone_name] < zone.minimum_available_vehicles:
            reasons.append(
                f"{zone_name} would fall below its published minimum "
                f"availability floor."
            )

        if (
            remaining_accessibility_ready[zone_name]
            < zone.minimum_accessibility_ready_vehicles
        ):
            reasons.append(
                f"{zone_name} would fall below its published accessibility-ready "
                f"vehicle floor."
            )

    if not reasons:
        reasons.append(
            "The proposed moves preserve published availability and "
            "accessibility-ready fleet floors."
        )

    return RebalancingAssessment(
        approved=len(reasons) == 1,
        total_deadhead_km=total_deadhead_km,
        total_deadhead_emissions_gco2e=total_deadhead_emissions_gco2e,
        reasons=tuple(reasons),
    )
