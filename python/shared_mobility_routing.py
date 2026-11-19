from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from math import isfinite
from typing import Iterable


class TravelMode(str, Enum):
    WALK = "walk"
    BICYCLE = "bicycle"
    SCOOTER = "scooter"
    CAR_SHARE = "car_share"
    TRANSIT = "transit"


class RouteProfile(str, Enum):
    FASTEST_ACCESSIBLE = "fastest_accessible"
    COOLER_SHADED = "cooler_shaded"
    LOWER_EXPOSURE = "lower_exposure"
    LOWER_CARBON = "lower_carbon"
    GREEN_CORRIDOR = "green_corridor"


@dataclass(frozen=True)
class RouteSegment:
    segment_id: str
    length_m: float
    travel_time_s: float
    elevation_gain_m: float
    canopy_fraction: float
    permeable_path_fraction: float
    bioswale_adjacency_fraction: float
    traffic_exposure_score: float
    noise_exposure_score: float
    thermal_exposure_score: float
    accessibility_barrier_score: float


@dataclass(frozen=True)
class VehicleEnergyProfile:
    mode: TravelMode
    traction_wh_per_km: float
    charging_efficiency: float
    lifecycle_gco2e_per_km: float
    maintenance_gco2e_per_km: float
    expected_rebalancing_gco2e_per_trip: float


@dataclass(frozen=True)
class GridCarbonEstimate:
    charging_carbon_gco2e_per_kwh: float
    uncertainty_fraction: float
    observed_at_unix_s: int


@dataclass(frozen=True)
class RouteAssessment:
    route_id: str
    profile: RouteProfile
    generalized_cost: float
    travel_time_s: float
    operational_emissions_gco2e: float
    lifecycle_emissions_gco2e: float
    green_corridor_score: float
    comfort_cost: float
    accessible: bool
    explanation: str


@dataclass(frozen=True)
class RoutingWeights:
    travel_time: float
    emissions: float
    green_corridor: float
    comfort: float
    accessibility: float


DEFAULT_WEIGHTS: dict[RouteProfile, RoutingWeights] = {
    RouteProfile.FASTEST_ACCESSIBLE: RoutingWeights(
        travel_time=1.00,
        emissions=0.15,
        green_corridor=0.10,
        comfort=0.35,
        accessibility=2.00,
    ),
    RouteProfile.COOLER_SHADED: RoutingWeights(
        travel_time=0.65,
        emissions=0.25,
        green_corridor=0.90,
        comfort=1.20,
        accessibility=1.50,
    ),
    RouteProfile.LOWER_EXPOSURE: RoutingWeights(
        travel_time=0.65,
        emissions=0.30,
        green_corridor=0.60,
        comfort=1.40,
        accessibility=1.50,
    ),
    RouteProfile.LOWER_CARBON: RoutingWeights(
        travel_time=0.55,
        emissions=1.40,
        green_corridor=0.45,
        comfort=0.65,
        accessibility=1.50,
    ),
    RouteProfile.GREEN_CORRIDOR: RoutingWeights(
        travel_time=0.60,
        emissions=0.35,
        green_corridor=1.35,
        comfort=0.95,
        accessibility=1.50,
    ),
}


def _bounded(value: float, minimum: float, maximum: float) -> float:
    return max(minimum, min(value, maximum))


def _require_finite(name: str, value: float) -> None:
    if not isfinite(value):
        raise ValueError(f"{name} must be finite")


def _require_range(name: str, value: float, minimum: float, maximum: float) -> None:
    _require_finite(name, value)
    if value < minimum or value > maximum:
        raise ValueError(f"{name} must be within [{minimum}, {maximum}]")


def validate_segments(segments: Iterable[RouteSegment]) -> tuple[RouteSegment, ...]:
    collected = tuple(segments)
    if not collected:
        raise ValueError("a route must contain at least one segment")

    for segment in collected:
        if not segment.segment_id.strip():
            raise ValueError("segment_id must be non-empty")
        _require_finite("length_m", segment.length_m)
        _require_finite("travel_time_s", segment.travel_time_s)
        _require_finite("elevation_gain_m", segment.elevation_gain_m)

        if segment.length_m <= 0.0:
            raise ValueError("length_m must be positive")
        if segment.travel_time_s <= 0.0:
            raise ValueError("travel_time_s must be positive")

        for name, value in {
            "canopy_fraction": segment.canopy_fraction,
            "permeable_path_fraction": segment.permeable_path_fraction,
            "bioswale_adjacency_fraction": segment.bioswale_adjacency_fraction,
            "traffic_exposure_score": segment.traffic_exposure_score,
            "noise_exposure_score": segment.noise_exposure_score,
            "thermal_exposure_score": segment.thermal_exposure_score,
            "accessibility_barrier_score": segment.accessibility_barrier_score,
        }.items():
            _require_range(name, value, 0.0, 1.0)

    return collected


def validate_vehicle_profile(profile: VehicleEnergyProfile) -> None:
    _require_finite("traction_wh_per_km", profile.traction_wh_per_km)
    _require_range("charging_efficiency", profile.charging_efficiency, 0.01, 1.0)
    _require_finite("lifecycle_gco2e_per_km", profile.lifecycle_gco2e_per_km)
    _require_finite("maintenance_gco2e_per_km", profile.maintenance_gco2e_per_km)
    _require_finite(
        "expected_rebalancing_gco2e_per_trip",
        profile.expected_rebalancing_gco2e_per_trip,
    )

    if profile.traction_wh_per_km < 0.0:
        raise ValueError("traction_wh_per_km must not be negative")
    if profile.lifecycle_gco2e_per_km < 0.0:
        raise ValueError("lifecycle_gco2e_per_km must not be negative")
    if profile.maintenance_gco2e_per_km < 0.0:
        raise ValueError("maintenance_gco2e_per_km must not be negative")
    if profile.expected_rebalancing_gco2e_per_trip < 0.0:
        raise ValueError("expected_rebalancing_gco2e_per_trip must not be negative")


def assess_route(
    route_id: str,
    profile: RouteProfile,
    segments: Iterable[RouteSegment],
    vehicle_profile: VehicleEnergyProfile,
    grid: GridCarbonEstimate,
    weights: RoutingWeights | None = None,
) -> RouteAssessment:
    if not route_id.strip():
        raise ValueError("route_id must be non-empty")

    route_segments = validate_segments(segments)
    validate_vehicle_profile(vehicle_profile)
    _require_finite(
        "charging_carbon_gco2e_per_kwh",
        grid.charging_carbon_gco2e_per_kwh,
    )
    _require_range("uncertainty_fraction", grid.uncertainty_fraction, 0.0, 1.0)

    if grid.charging_carbon_gco2e_per_kwh < 0.0:
        raise ValueError("charging_carbon_gco2e_per_kwh must not be negative")
    if grid.observed_at_unix_s <= 0:
        raise ValueError("observed_at_unix_s must be positive")

    active_weights = weights or DEFAULT_WEIGHTS[profile]
    for name, value in {
        "travel_time": active_weights.travel_time,
        "emissions": active_weights.emissions,
        "green_corridor": active_weights.green_corridor,
        "comfort": active_weights.comfort,
        "accessibility": active_weights.accessibility,
    }.items():
        _require_finite(name, value)
        if value < 0.0:
            raise ValueError(f"{name} weight must not be negative")

    distance_km = sum(segment.length_m for segment in route_segments) / 1000.0
    travel_time_s = sum(segment.travel_time_s for segment in route_segments)

    green_corridor_score = sum(
        segment.length_m
        * (
            0.55 * segment.canopy_fraction
            + 0.25 * segment.permeable_path_fraction
            + 0.20 * segment.bioswale_adjacency_fraction
        )
        for segment in route_segments
    ) / sum(segment.length_m for segment in route_segments)

    comfort_cost = sum(
        segment.length_m
        * (
            0.40 * segment.traffic_exposure_score
            + 0.25 * segment.noise_exposure_score
            + 0.25 * segment.thermal_exposure_score
            + 0.10 * min(segment.elevation_gain_m / 20.0, 1.0)
        )
        for segment in route_segments
    ) / sum(segment.length_m for segment in route_segments)

    accessibility_cost = sum(
        segment.length_m * segment.accessibility_barrier_score
        for segment in route_segments
    ) / sum(segment.length_m for segment in route_segments)

    traction_kwh = (
        distance_km * vehicle_profile.traction_wh_per_km / 1000.0
    )
    operational_emissions_gco2e = (
        traction_kwh
        / vehicle_profile.charging_efficiency
        * grid.charging_carbon_gco2e_per_kwh
    )
    lifecycle_emissions_gco2e = (
        operational_emissions_gco2e
        + distance_km * vehicle_profile.lifecycle_gco2e_per_km
        + distance_km * vehicle_profile.maintenance_gco2e_per_km
        + vehicle_profile.expected_rebalancing_gco2e_per_trip
    )

    normalized_time = travel_time_s / 1800.0
    normalized_emissions = lifecycle_emissions_gco2e / 1000.0
    generalized_cost = (
        active_weights.travel_time * normalized_time
        + active_weights.emissions * normalized_emissions
        - active_weights.green_corridor * green_corridor_score
        + active_weights.comfort * comfort_cost
        + active_weights.accessibility * accessibility_cost
    )

    accessible = accessibility_cost <= 0.10
    emissions_uncertainty_gco2e = (
        lifecycle_emissions_gco2e * grid.uncertainty_fraction
    )
    explanation = (
        f"Estimated lifecycle route emissions are "
        f"{lifecycle_emissions_gco2e:.1f} gCO2e with an input-based uncertainty "
        f"range of ±{emissions_uncertainty_gco2e:.1f} gCO2e. The route has a "
        f"green-corridor score of {green_corridor_score:.2f}, a comfort cost of "
        f"{comfort_cost:.2f}, and an accessibility status of "
        f"{'available' if accessible else 'requires an accessible-route alternative'}."
    )

    return RouteAssessment(
        route_id=route_id,
        profile=profile,
        generalized_cost=generalized_cost,
        travel_time_s=travel_time_s,
        operational_emissions_gco2e=operational_emissions_gco2e,
        lifecycle_emissions_gco2e=lifecycle_emissions_gco2e,
        green_corridor_score=green_corridor_score,
        comfort_cost=comfort_cost,
        accessible=accessible,
        explanation=explanation,
    )
