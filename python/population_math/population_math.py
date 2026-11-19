from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from hashlib import sha256
from math import ceil, isfinite
from typing import Iterable, Mapping, Sequence
import json


class PopulationMathError(ValueError):
    pass


def _finite_nonnegative(name: str, value: float) -> float:
    if not isinstance(value, (int, float)) or not isfinite(value) or value < 0:
        raise PopulationMathError(f"{name} must be a finite non-negative number")
    return float(value)


def _bounded(name: str, value: float, lower: float, upper: float) -> float:
    value = _finite_nonnegative(name, value)
    if value < lower or value > upper:
        raise PopulationMathError(f"{name} must be between {lower} and {upper}")
    return value


def _positive(name: str, value: float) -> float:
    value = _finite_nonnegative(name, value)
    if value == 0:
        raise PopulationMathError(f"{name} must be greater than zero")
    return value


@dataclass(frozen=True)
class Provenance:
    source_name: str
    retrieved_at: str
    license_or_authority: str
    aggregation_level: str
    sensitive_personal_data_present: bool = False

    def validate(self) -> None:
        if not self.source_name.strip():
            raise PopulationMathError("source_name is required")
        if not self.retrieved_at.strip():
            raise PopulationMathError("retrieved_at is required")
        if not self.license_or_authority.strip():
            raise PopulationMathError("license_or_authority is required")
        if not self.aggregation_level.strip():
            raise PopulationMathError("aggregation_level is required")
        if self.sensitive_personal_data_present:
            raise PopulationMathError(
                "Population.Math accepts aggregated or consent-authorized inputs only"
            )


@dataclass(frozen=True)
class WaterBalanceInput:
    starting_storage_m3: float
    inflow_m3: float
    demand_m3: float
    losses_m3: float
    evaporation_m3: float
    recovered_or_transfer_m3: float
    maximum_storage_m3: float
    provenance: Provenance

    def validate(self) -> None:
        self.provenance.validate()
        _finite_nonnegative("starting_storage_m3", self.starting_storage_m3)
        _finite_nonnegative("inflow_m3", self.inflow_m3)
        _finite_nonnegative("demand_m3", self.demand_m3)
        _finite_nonnegative("losses_m3", self.losses_m3)
        _finite_nonnegative("evaporation_m3", self.evaporation_m3)
        _finite_nonnegative(
            "recovered_or_transfer_m3", self.recovered_or_transfer_m3
        )
        maximum = _positive("maximum_storage_m3", self.maximum_storage_m3)
        if self.starting_storage_m3 > maximum:
            raise PopulationMathError(
                "starting_storage_m3 cannot exceed maximum_storage_m3"
            )


@dataclass(frozen=True)
class WaterBalanceResult:
    ending_storage_m3: float
    unmet_demand_m3: float
    spill_m3: float
    net_change_m3: float
    status: str
    assumptions: tuple[str, ...]
    reproducibility_hash: str


@dataclass(frozen=True)
class EnergyStorageInput:
    starting_energy_kwh: float
    capacity_kwh: float
    charging_energy_kwh: float
    discharge_demand_kwh: float
    charge_efficiency: float
    discharge_efficiency: float
    provenance: Provenance

    def validate(self) -> None:
        self.provenance.validate()
        starting = _finite_nonnegative("starting_energy_kwh", self.starting_energy_kwh)
        capacity = _positive("capacity_kwh", self.capacity_kwh)
        _finite_nonnegative("charging_energy_kwh", self.charging_energy_kwh)
        _finite_nonnegative("discharge_demand_kwh", self.discharge_demand_kwh)
        _bounded("charge_efficiency", self.charge_efficiency, 0.000001, 1.0)
        _bounded("discharge_efficiency", self.discharge_efficiency, 0.000001, 1.0)
        if starting > capacity:
            raise PopulationMathError("starting_energy_kwh cannot exceed capacity_kwh")


@dataclass(frozen=True)
class EnergyStorageResult:
    ending_energy_kwh: float
    unmet_discharge_demand_kwh: float
    curtailed_charge_kwh: float
    status: str
    assumptions: tuple[str, ...]
    reproducibility_hash: str


@dataclass(frozen=True)
class DeliveryStop:
    stop_id: str
    demand_mass_kg: float
    demand_volume_m3: float
    service_minutes: float
    earliest_arrival_minute: float
    latest_arrival_minute: float

    def validate(self) -> None:
        if not self.stop_id.strip():
            raise PopulationMathError("stop_id is required")
        _finite_nonnegative("demand_mass_kg", self.demand_mass_kg)
        _finite_nonnegative("demand_volume_m3", self.demand_volume_m3)
        _finite_nonnegative("service_minutes", self.service_minutes)
        earliest = _finite_nonnegative(
            "earliest_arrival_minute", self.earliest_arrival_minute
        )
        latest = _finite_nonnegative(
            "latest_arrival_minute", self.latest_arrival_minute
        )
        if earliest > latest:
            raise PopulationMathError(
                "earliest_arrival_minute cannot exceed latest_arrival_minute"
            )


@dataclass(frozen=True)
class DeliveryFleet:
    vehicle_count: int
    payload_mass_kg: float
    payload_volume_m3: float
    operating_minutes_per_vehicle: float
    estimated_km_per_vehicle: float
    fuel_liters_per_km: float
    kg_co2e_per_liter: float

    def validate(self) -> None:
        if not isinstance(self.vehicle_count, int) or self.vehicle_count < 1:
            raise PopulationMathError("vehicle_count must be a positive integer")
        _positive("payload_mass_kg", self.payload_mass_kg)
        _positive("payload_volume_m3", self.payload_volume_m3)
        _positive(
            "operating_minutes_per_vehicle", self.operating_minutes_per_vehicle
        )
        _finite_nonnegative("estimated_km_per_vehicle", self.estimated_km_per_vehicle)
        _finite_nonnegative("fuel_liters_per_km", self.fuel_liters_per_km)
        _finite_nonnegative("kg_co2e_per_liter", self.kg_co2e_per_liter)


@dataclass(frozen=True)
class DeliveryCapacityResult:
    minimum_vehicle_loads: int
    vehicle_load_capacity: int
    time_capacity: int
    feasible: bool
    estimated_fuel_liters: float
    estimated_kg_co2e: float
    constraints: tuple[str, ...]
    reproducibility_hash: str


@dataclass(frozen=True)
class QueueInput:
    arrival_rate_per_hour: float
    service_rate_per_hour_per_channel: float
    channels: int
    provenance: Provenance

    def validate(self) -> None:
        self.provenance.validate()
        _finite_nonnegative("arrival_rate_per_hour", self.arrival_rate_per_hour)
        _positive(
            "service_rate_per_hour_per_channel",
            self.service_rate_per_hour_per_channel,
        )
        if not isinstance(self.channels, int) or self.channels < 1:
            raise PopulationMathError("channels must be a positive integer")


@dataclass(frozen=True)
class QueueCapacityResult:
    utilization: float
    stability: str
    additional_channels_for_stability: int
    assumptions: tuple[str, ...]
    reproducibility_hash: str


@dataclass(frozen=True)
class ServiceAccessInput:
    total_weight: float
    accessible_within_threshold_weight: float
    provenance: Provenance

    def validate(self) -> None:
        self.provenance.validate()
        total = _positive("total_weight", self.total_weight)
        reachable = _finite_nonnegative(
            "accessible_within_threshold_weight",
            self.accessible_within_threshold_weight,
        )
        if reachable > total:
            raise PopulationMathError(
                "accessible_within_threshold_weight cannot exceed total_weight"
            )


@dataclass(frozen=True)
class ServiceAccessResult:
    access_index: float
    status: str
    assumptions: tuple[str, ...]
    reproducibility_hash: str


@dataclass(frozen=True)
class ResultEnvelope:
    calculation_name: str
    calculation_version: str
    computed_at: str
    result: Mapping[str, object]
    rights_protections: tuple[str, ...]
    accessibility_impact: str
    eco_impact_value: float
    harm_risk: float
    knowledge_factor: float
    rights_alignment: float
    human_review_required: bool


def _hash_payload(payload: object) -> str:
    canonical = json.dumps(
        payload,
        sort_keys=True,
        separators=(",", ":"),
        default=lambda value: asdict(value) if hasattr(value, "__dataclass_fields__") else str(value),
    )
    return sha256(canonical.encode("utf-8")).hexdigest()


def calculate_water_balance(data: WaterBalanceInput) -> WaterBalanceResult:
    data.validate()

    unconstrained = (
        data.starting_storage_m3
        + data.inflow_m3
        - data.demand_m3
        - data.losses_m3
        - data.evaporation_m3
        + data.recovered_or_transfer_m3
    )
    ending = min(max(unconstrained, 0.0), data.maximum_storage_m3)
    unmet = max(0.0, -unconstrained)
    spill = max(0.0, unconstrained - data.maximum_storage_m3)
    status = "balanced"

    if unmet > 0:
        status = "shortage"
    elif spill > 0:
        status = "spill_or_overflow"

    payload = {"input": data, "ending": ending, "unmet": unmet, "spill": spill}
    return WaterBalanceResult(
        ending_storage_m3=ending,
        unmet_demand_m3=unmet,
        spill_m3=spill,
        net_change_m3=ending - data.starting_storage_m3,
        status=status,
        assumptions=(
            "All quantities cover one consistent time interval.",
            "Potable, reclaimed, ecological, and emergency allocations must be modeled separately.",
            "The result is an accounting projection, not a water-rights determination.",
        ),
        reproducibility_hash=_hash_payload(payload),
    )


def calculate_energy_storage(data: EnergyStorageInput) -> EnergyStorageResult:
    data.validate()

    stored_after_charge = min(
        data.capacity_kwh,
        data.starting_energy_kwh + data.charging_energy_kwh * data.charge_efficiency,
    )
    curtailed = max(
        0.0,
        data.starting_energy_kwh
        + data.charging_energy_kwh * data.charge_efficiency
        - data.capacity_kwh,
    )
    available_to_load = stored_after_charge * data.discharge_efficiency
    served = min(data.discharge_demand_kwh, available_to_load)
    unmet = data.discharge_demand_kwh - served
    ending = stored_after_charge - served / data.discharge_efficiency

    status = "demand_served" if unmet == 0 else "unmet_demand"
    payload = {
        "input": data,
        "ending": ending,
        "unmet": unmet,
        "curtailed": curtailed,
    }

    return EnergyStorageResult(
        ending_energy_kwh=ending,
        unmet_discharge_demand_kwh=unmet,
        curtailed_charge_kwh=curtailed,
        status=status,
        assumptions=(
            "Efficiencies represent the selected operating interval.",
            "Critical loads must be reported separately from discretionary loads.",
            "The result does not authorize interruption of essential services.",
        ),
        reproducibility_hash=_hash_payload(payload),
    )


def calculate_delivery_capacity(
    stops: Sequence[DeliveryStop],
    fleet: DeliveryFleet,
    provenance: Provenance,
) -> DeliveryCapacityResult:
    provenance.validate()
    fleet.validate()

    if not stops:
        raise PopulationMathError("at least one delivery stop is required")

    for stop in stops:
        stop.validate()

    total_mass = sum(stop.demand_mass_kg for stop in stops)
    total_volume = sum(stop.demand_volume_m3 for stop in stops)
    total_service_minutes = sum(stop.service_minutes for stop in stops)
    earliest = min(stop.earliest_arrival_minute for stop in stops)
    latest = max(stop.latest_arrival_minute for stop in stops)
    available_window_minutes = max(0.0, latest - earliest)

    loads_by_mass = ceil(total_mass / fleet.payload_mass_kg)
    loads_by_volume = ceil(total_volume / fleet.payload_volume_m3)
    minimum_loads = max(loads_by_mass, loads_by_volume)
    time_capacity = int(
        (
            fleet.vehicle_count * fleet.operating_minutes_per_vehicle
        )
        // max(total_service_minutes, 1.0)
    )

    feasible = (
        minimum_loads <= fleet.vehicle_count
        and total_service_minutes <= fleet.vehicle_count * fleet.operating_minutes_per_vehicle
        and available_window_minutes >= 0.0
    )
    fuel = (
        fleet.vehicle_count
        * fleet.estimated_km_per_vehicle
        * fleet.fuel_liters_per_km
    )
    emissions = fuel * fleet.kg_co2e_per_liter

    payload = {
        "stops": list(stops),
        "fleet": fleet,
        "provenance": provenance,
        "minimum_loads": minimum_loads,
        "time_capacity": time_capacity,
    }

    return DeliveryCapacityResult(
        minimum_vehicle_loads=minimum_loads,
        vehicle_load_capacity=fleet.vehicle_count,
        time_capacity=time_capacity,
        feasible=feasible,
        estimated_fuel_liters=fuel,
        estimated_kg_co2e=emissions,
        constraints=(
            "This capacity screen does not replace road-safety, axle-load, work-zone, accessibility, or permitting review.",
            "Vehicle and material limits must include mass, volume, securement, road restrictions, and site staging capacity.",
            "Fuel and carbon estimates depend on declared factors and route-distance assumptions.",
        ),
        reproducibility_hash=_hash_payload(payload),
    )


def calculate_queue_capacity(data: QueueInput) -> QueueCapacityResult:
    data.validate()

    capacity = data.channels * data.service_rate_per_hour_per_channel
    utilization = (
        data.arrival_rate_per_hour / capacity if capacity > 0 else float("inf")
    )
    required_channels = ceil(
        data.arrival_rate_per_hour / data.service_rate_per_hour_per_channel
    )
    additional = max(0, required_channels - data.channels)
    stability = "stable" if utilization < 1.0 else "unstable"

    payload = {
        "input": data,
        "utilization": utilization,
        "additional_channels": additional,
    }

    return QueueCapacityResult(
        utilization=utilization,
        stability=stability,
        additional_channels_for_stability=additional,
        assumptions=(
            "This is a first-order utilization screen, not a full waiting-time distribution.",
            "Staff breaks, skill mix, accessibility support, arrival bursts, and emergency demand require a more detailed model.",
            "Capacity warnings must trigger service improvement planning rather than restricting public access.",
        ),
        reproducibility_hash=_hash_payload(payload),
    )


def calculate_service_access(data: ServiceAccessInput) -> ServiceAccessResult:
    data.validate()

    access = data.accessible_within_threshold_weight / data.total_weight
    status = "full_access" if access == 1.0 else "access_gap_detected"
    payload = {"input": data, "access": access}

    return ServiceAccessResult(
        access_index=access,
        status=status,
        assumptions=(
            "Accessibility must describe the entire journey, including physical paths, information, payment, communication, and fallback access.",
            "Input weights must be aggregated and must not reveal protected traits or individual locations.",
            "An access gap is a planning signal requiring review, not an eligibility classification.",
        ),
        reproducibility_hash=_hash_payload(payload),
    )


def build_result_envelope(
    calculation_name: str,
    result: object,
    *,
    eco_impact_value: float,
    harm_risk: float,
    knowledge_factor: float,
    rights_alignment: float,
    accessibility_impact: str,
    human_review_required: bool = True,
) -> ResultEnvelope:
    if not calculation_name.strip():
        raise PopulationMathError("calculation_name is required")
    if not accessibility_impact.strip():
        raise PopulationMathError("accessibility_impact is required")

    return ResultEnvelope(
        calculation_name=calculation_name,
        calculation_version="0.1.0",
        computed_at=datetime.now(timezone.utc).isoformat(),
        result=asdict(result) if hasattr(result, "__dataclass_fields__") else {"value": result},
        rights_protections=(
            "Aggregated or consent-authorized inputs only",
            "Purpose limitation and data minimization",
            "No resident-level scoring or eligibility determination",
            "Accessible explanation and human review path",
            "Scenario comparison rather than opaque single-answer optimization",
        ),
        accessibility_impact=accessibility_impact,
        eco_impact_value=_bounded("eco_impact_value", eco_impact_value, 0.0, 1.0),
        harm_risk=_bounded("harm_risk", harm_risk, 0.0, 1.0),
        knowledge_factor=_bounded("knowledge_factor", knowledge_factor, 0.0, 1.0),
        rights_alignment=_bounded("rights_alignment", rights_alignment, 0.0, 1.0),
        human_review_required=human_review_required,
    )
