from dataclasses import dataclass
from decimal import Decimal
from typing import Iterable


ZERO = Decimal("0")
ONE = Decimal("1")


@dataclass(frozen=True)
class LoadScenario:
    load_ref: str
    demand_kw: Decimal
    declared_critical: bool
    accessibility_critical: bool
    shedding_allowed: bool
    authority_ref_present: bool


@dataclass(frozen=True)
class BatteryScenario:
    state_of_charge: Decimal
    usable_capacity_kwh: Decimal
    charge_efficiency: Decimal
    discharge_efficiency: Decimal
    minimum_state_of_charge: Decimal
    maximum_state_of_charge: Decimal


@dataclass(frozen=True)
class ResilienceAssessment:
    critical_demand_kw: Decimal
    noncritical_demand_kw: Decimal
    available_generation_kw: Decimal
    critical_load_covered: bool
    candidate_shed_loads: tuple[str, ...]
    review_required: bool
    reasons: tuple[str, ...]


def bounded(value: Decimal, field_name: str) -> None:
    if value < ZERO or value > ONE:
        raise ValueError(f"{field_name} must be between 0 and 1")


def next_state_of_charge(
    battery: BatteryScenario,
    charge_power_kw: Decimal,
    discharge_power_kw: Decimal,
    interval_hours: Decimal,
) -> Decimal:
    bounded(battery.state_of_charge, "state_of_charge")
    bounded(battery.charge_efficiency, "charge_efficiency")
    bounded(battery.discharge_efficiency, "discharge_efficiency")
    bounded(battery.minimum_state_of_charge, "minimum_state_of_charge")
    bounded(battery.maximum_state_of_charge, "maximum_state_of_charge")

    if battery.usable_capacity_kwh <= ZERO:
        raise ValueError("usable_capacity_kwh must be positive")

    if battery.minimum_state_of_charge > battery.maximum_state_of_charge:
        raise ValueError("invalid state of charge bounds")

    energy_delta_kwh = (
        battery.charge_efficiency * charge_power_kw * interval_hours
        - (discharge_power_kw * interval_hours) / battery.discharge_efficiency
    )

    next_soc = battery.state_of_charge + (
        energy_delta_kwh / battery.usable_capacity_kwh
    )

    return min(
        battery.maximum_state_of_charge,
        max(battery.minimum_state_of_charge, next_soc),
    )


def assess_resilience(
    loads: Iterable[LoadScenario],
    available_generation_kw: Decimal,
) -> ResilienceAssessment:
    critical_demand = ZERO
    noncritical_demand = ZERO
    candidate_shed_loads: list[str] = []
    reasons: list[str] = []

    for load in loads:
        if load.demand_kw < ZERO:
            raise ValueError("demand_kw must not be negative")

        if not load.authority_ref_present:
            reasons.append(f"MISSING_LOAD_AUTHORITY:{load.load_ref}")

        if load.declared_critical or load.accessibility_critical:
            critical_demand += load.demand_kw

            if load.shedding_allowed:
                reasons.append(f"CRITICAL_LOAD_SHEDDING_PROHIBITED:{load.load_ref}")
        else:
            noncritical_demand += load.demand_kw

            if load.shedding_allowed:
                candidate_shed_loads.append(load.load_ref)

    return ResilienceAssessment(
        critical_demand_kw=critical_demand,
        noncritical_demand_kw=noncritical_demand,
        available_generation_kw=available_generation_kw,
        critical_load_covered=available_generation_kw >= critical_demand,
        candidate_shed_loads=tuple(candidate_shed_loads),
        review_required=bool(reasons) or available_generation_kw < critical_demand,
        reasons=tuple(reasons),
    )
