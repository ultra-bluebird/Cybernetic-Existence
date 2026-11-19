from __future__ import annotations

from dataclasses import dataclass
from math import isfinite


@dataclass(frozen=True)
class WaterState:
    available_reclaimed_water_m3: float
    essential_reserve_m3: float
    ecological_reserve_m3: float
    drought_reserve_m3: float
    tree_irrigation_quality_approved: bool
    evaporative_cooling_quality_approved: bool
    recharge_quality_approved: bool
    tree_heat_benefit_per_m3: float
    cooling_heat_benefit_per_m3: float
    recharge_resilience_benefit_per_m3: float
    tree_scarcity_cost_per_m3: float
    cooling_scarcity_cost_per_m3: float
    recharge_scarcity_cost_per_m3: float
    tree_max_m3: float
    cooling_max_m3: float
    recharge_max_m3: float


@dataclass(frozen=True)
class Allocation:
    tree_irrigation_m3: float
    evaporative_cooling_m3: float
    managed_recharge_m3: float
    unallocated_m3: float
    heat_benefit: float
    scarcity_cost: float
    feasible: bool
    rationale: str


def _finite_nonnegative(name: str, value: float) -> None:
    if not isfinite(value) or value < 0.0:
        raise ValueError(f"{name} must be finite and non-negative.")


def safe_allocable_water_m3(state: WaterState) -> float:
    values = (
        state.available_reclaimed_water_m3,
        state.essential_reserve_m3,
        state.ecological_reserve_m3,
        state.drought_reserve_m3,
    )

    for value in values:
        _finite_nonnegative("water balance value", value)

    available = (
        state.available_reclaimed_water_m3
        - state.essential_reserve_m3
        - state.ecological_reserve_m3
        - state.drought_reserve_m3
    )

    return max(0.0, available)


def allocate_reclaimed_water(
    state: WaterState,
    heat_weight: float,
    scarcity_weight: float,
) -> Allocation:
    _finite_nonnegative("heat_weight", heat_weight)
    _finite_nonnegative("scarcity_weight", scarcity_weight)

    for name, value in (
        ("tree_heat_benefit_per_m3", state.tree_heat_benefit_per_m3),
        ("cooling_heat_benefit_per_m3", state.cooling_heat_benefit_per_m3),
        ("recharge_resilience_benefit_per_m3", state.recharge_resilience_benefit_per_m3),
        ("tree_scarcity_cost_per_m3", state.tree_scarcity_cost_per_m3),
        ("cooling_scarcity_cost_per_m3", state.cooling_scarcity_cost_per_m3),
        ("recharge_scarcity_cost_per_m3", state.recharge_scarcity_cost_per_m3),
        ("tree_max_m3", state.tree_max_m3),
        ("cooling_max_m3", state.cooling_max_m3),
        ("recharge_max_m3", state.recharge_max_m3),
    ):
        _finite_nonnegative(name, value)

    remaining = safe_allocable_water_m3(state)

    options = []

    if state.tree_irrigation_quality_approved:
        options.append(
            (
                "tree",
                heat_weight * state.tree_heat_benefit_per_m3
                - scarcity_weight * state.tree_scarcity_cost_per_m3,
                state.tree_max_m3,
            )
        )

    if state.evaporative_cooling_quality_approved:
        options.append(
            (
                "cooling",
                heat_weight * state.cooling_heat_benefit_per_m3
                - scarcity_weight * state.cooling_scarcity_cost_per_m3,
                state.cooling_max_m3,
            )
        )

    if state.recharge_quality_approved:
        options.append(
            (
                "recharge",
                heat_weight * state.recharge_resilience_benefit_per_m3
                - scarcity_weight * state.recharge_scarcity_cost_per_m3,
                state.recharge_max_m3,
            )
        )

    tree = 0.0
    cooling = 0.0
    recharge = 0.0

    for destination, utility, maximum in sorted(
        options,
        key=lambda option: option[1],
        reverse=True,
    ):
        if utility <= 0.0 or remaining <= 0.0:
            continue

        allocation = min(remaining, maximum)

        if destination == "tree":
            tree = allocation
        elif destination == "cooling":
            cooling = allocation
        else:
            recharge = allocation

        remaining -= allocation

    heat_benefit = (
        tree * state.tree_heat_benefit_per_m3
        + cooling * state.cooling_heat_benefit_per_m3
        + recharge * state.recharge_resilience_benefit_per_m3
    )

    scarcity_cost = (
        tree * state.tree_scarcity_cost_per_m3
        + cooling * state.cooling_scarcity_cost_per_m3
        + recharge * state.recharge_scarcity_cost_per_m3
    )

    return Allocation(
        tree_irrigation_m3=tree,
        evaporative_cooling_m3=cooling,
        managed_recharge_m3=recharge,
        unallocated_m3=remaining,
        heat_benefit=heat_benefit,
        scarcity_cost=scarcity_cost,
        feasible=True,
        rationale=(
            "Allocation is restricted to approved water-quality pathways and "
            "preserves essential, ecological, and drought reserves. A future "
            "RL policy may rank only these pre-filtered feasible actions."
        ),
    )
