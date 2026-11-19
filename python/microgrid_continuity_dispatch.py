from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal, ROUND_HALF_UP
from typing import Iterable


BASIS_POINTS_PER_UNIT = 10_000


class MicrogridValidationError(ValueError):
    pass


@dataclass(frozen=True)
class BuildingInput:
    building_key: str
    available_generation_wh: int
    critical_load_wh: int
    noncritical_load_wh: int
    battery_energy_wh: int
    battery_capacity_wh: int
    battery_discharge_limit_wh: int
    willingness_to_pay_microunits_per_wh: int
    minimum_critical_continuity_basis_points: int

    def validate(self) -> None:
        if not self.building_key.strip():
            raise MicrogridValidationError("building_key must not be blank")

        for field_name, value in (
            ("available_generation_wh", self.available_generation_wh),
            ("critical_load_wh", self.critical_load_wh),
            ("noncritical_load_wh", self.noncritical_load_wh),
            ("battery_energy_wh", self.battery_energy_wh),
            ("battery_capacity_wh", self.battery_capacity_wh),
            ("battery_discharge_limit_wh", self.battery_discharge_limit_wh),
            ("willingness_to_pay_microunits_per_wh", self.willingness_to_pay_microunits_per_wh),
        ):
            if value < 0:
                raise MicrogridValidationError(f"{field_name} must be non-negative")

        if self.battery_energy_wh > self.battery_capacity_wh:
            raise MicrogridValidationError(
                "battery_energy_wh must not exceed battery_capacity_wh"
            )

        if self.battery_discharge_limit_wh > self.battery_energy_wh:
            raise MicrogridValidationError(
                "battery_discharge_limit_wh must not exceed battery_energy_wh"
            )

        if not 0 <= self.minimum_critical_continuity_basis_points <= BASIS_POINTS_PER_UNIT:
            raise MicrogridValidationError(
                "minimum_critical_continuity_basis_points must be within [0, 10000]"
            )


@dataclass(frozen=True)
class Trade:
    seller_key: str
    buyer_key: str
    energy_wh: int
    clearing_price_microunits_per_wh: int


@dataclass(frozen=True)
class BuildingDispatch:
    building_key: str
    local_generation_used_wh: int
    battery_discharge_wh: int
    imported_energy_wh: int
    exported_energy_wh: int
    served_critical_load_wh: int
    unserved_critical_load_wh: int
    served_noncritical_load_wh: int
    critical_continuity_ratio_basis_points: int


@dataclass(frozen=True)
class DispatchSolution:
    trades: tuple[Trade, ...]
    building_dispatches: tuple[BuildingDispatch, ...]
    total_critical_load_wh: int
    total_served_critical_load_wh: int
    block_critical_continuity_ratio_basis_points: int
    objective_value_microunits: int


def ceil_division(numerator: int, denominator: int) -> int:
    if denominator <= 0:
        raise MicrogridValidationError("denominator must be positive")
    return (numerator + denominator - 1) // denominator


def continuity_ratio_basis_points(served_wh: int, required_wh: int) -> int:
    if required_wh == 0:
        return BASIS_POINTS_PER_UNIT
    if served_wh < 0 or served_wh > required_wh:
        raise MicrogridValidationError("served critical load must be within valid bounds")
    return (served_wh * BASIS_POINTS_PER_UNIT) // required_wh


def priority_weight(building: BuildingInput) -> int:
    return (
        building.willingness_to_pay_microunits_per_wh
        * (BASIS_POINTS_PER_UNIT + building.minimum_critical_continuity_basis_points)
    )


def calculate_available_supply_wh(building: BuildingInput) -> int:
    return (
        building.available_generation_wh
        + min(building.battery_energy_wh, building.battery_discharge_limit_wh)
    )


def build_deterministic_dispatch(
    buildings: Iterable[BuildingInput],
    clearing_price_microunits_per_wh: int,
) -> DispatchSolution:
    building_list = tuple(buildings)

    if not building_list:
        raise MicrogridValidationError("at least one building is required")

    if clearing_price_microunits_per_wh < 0:
        raise MicrogridValidationError(
            "clearing_price_microunits_per_wh must be non-negative"
        )

    for building in building_list:
        building.validate()

    supply_by_building = {
        building.building_key: calculate_available_supply_wh(building)
        for building in building_list
    }

    critical_served_by_building = {
        building.building_key: min(
            building.critical_load_wh,
            supply_by_building[building.building_key],
        )
        for building in building_list
    }

    surplus_by_building = {
        building.building_key: max(
            0,
            supply_by_building[building.building_key]
            - critical_served_by_building[building.building_key],
        )
        for building in building_list
    }

    critical_deficit_by_building = {
        building.building_key: max(
            0,
            building.critical_load_wh
            - critical_served_by_building[building.building_key],
        )
        for building in building_list
    }

    sellers = sorted(
        (
            building
            for building in building_list
            if surplus_by_building[building.building_key] > 0
        ),
        key=lambda building: building.building_key,
    )

    buyers = sorted(
        (
            building
            for building in building_list
            if critical_deficit_by_building[building.building_key] > 0
        ),
        key=lambda building: (
            -priority_weight(building),
            building.building_key,
        ),
    )

    mutable_surplus = dict(surplus_by_building)
    mutable_deficit = dict(critical_deficit_by_building)
    imported_by_building = {building.building_key: 0 for building in building_list}
    exported_by_building = {building.building_key: 0 for building in building_list}
    trades: list[Trade] = []

    for buyer in buyers:
        for seller in sellers:
            buyer_key = buyer.building_key
            seller_key = seller.building_key

            transferable_energy_wh = min(
                mutable_deficit[buyer_key],
                mutable_surplus[seller_key],
            )

            if transferable_energy_wh <= 0:
                continue

            trades.append(
                Trade(
                    seller_key=seller_key,
                    buyer_key=buyer_key,
                    energy_wh=transferable_energy_wh,
                    clearing_price_microunits_per_wh=clearing_price_microunits_per_wh,
                )
            )

            mutable_deficit[buyer_key] -= transferable_energy_wh
            mutable_surplus[seller_key] -= transferable_energy_wh
            imported_by_building[buyer_key] += transferable_energy_wh
            exported_by_building[seller_key] += transferable_energy_wh

            if mutable_deficit[buyer_key] == 0:
                break

    building_dispatches: list[BuildingDispatch] = []

    for building in sorted(building_list, key=lambda item: item.building_key):
        building_key = building.building_key
        usable_battery_wh = min(
            building.battery_energy_wh,
            building.battery_discharge_limit_wh,
        )

        local_generation_used_wh = min(
            building.available_generation_wh,
            building.critical_load_wh,
        )

        remaining_critical_after_generation_wh = max(
            0,
            building.critical_load_wh - local_generation_used_wh,
        )

        battery_discharge_wh = min(
            usable_battery_wh,
            remaining_critical_after_generation_wh,
        )

        served_critical_load_wh = min(
            building.critical_load_wh,
            local_generation_used_wh
            + battery_discharge_wh
            + imported_by_building[building_key],
        )

        unserved_critical_load_wh = (
            building.critical_load_wh - served_critical_load_wh
        )

        remaining_supply_after_critical_wh = max(
            0,
            supply_by_building[building_key]
            + imported_by_building[building_key]
            - exported_by_building[building_key]
            - served_critical_load_wh,
        )

        served_noncritical_load_wh = min(
            building.noncritical_load_wh,
            remaining_supply_after_critical_wh,
        )

        building_dispatches.append(
            BuildingDispatch(
                building_key=building_key,
                local_generation_used_wh=local_generation_used_wh,
                battery_discharge_wh=battery_discharge_wh,
                imported_energy_wh=imported_by_building[building_key],
                exported_energy_wh=exported_by_building[building_key],
                served_critical_load_wh=served_critical_load_wh,
                unserved_critical_load_wh=unserved_critical_load_wh,
                served_noncritical_load_wh=served_noncritical_load_wh,
                critical_continuity_ratio_basis_points=continuity_ratio_basis_points(
                    served_critical_load_wh,
                    building.critical_load_wh,
                ),
            )
        )

    total_critical_load_wh = sum(
        building.critical_load_wh for building in building_list
    )
    total_served_critical_load_wh = sum(
        dispatch.served_critical_load_wh for dispatch in building_dispatches
    )

    objective_value_microunits = sum(
        trade.energy_wh * priority_weight(
            next(
                building
                for building in building_list
                if building.building_key == trade.buyer_key
            )
        )
        for trade in trades
    )

    solution = DispatchSolution(
        trades=tuple(trades),
        building_dispatches=tuple(building_dispatches),
        total_critical_load_wh=total_critical_load_wh,
        total_served_critical_load_wh=total_served_critical_load_wh,
        block_critical_continuity_ratio_basis_points=continuity_ratio_basis_points(
            total_served_critical_load_wh,
            total_critical_load_wh,
        ),
        objective_value_microunits=objective_value_microunits,
    )

    validate_solution(building_list, solution, clearing_price_microunits_per_wh)

    return solution


def validate_solution(
    buildings: Iterable[BuildingInput],
    solution: DispatchSolution,
    expected_clearing_price_microunits_per_wh: int,
) -> None:
    building_list = tuple(buildings)
    buildings_by_key = {
        building.building_key: building for building in building_list
    }

    if set(buildings_by_key) != {
        dispatch.building_key for dispatch in solution.building_dispatches
    }:
        raise MicrogridValidationError(
            "solution must contain exactly one dispatch result per building"
        )

    imports_by_building = {building.building_key: 0 for building in building_list}
    exports_by_building = {building.building_key: 0 for building in building_list}

    for trade in solution.trades:
        if trade.seller_key == trade.buyer_key:
            raise MicrogridValidationError("self-trading is not allowed")

        if trade.seller_key not in buildings_by_key:
            raise MicrogridValidationError("trade references unknown seller")

        if trade.buyer_key not in buildings_by_key:
            raise MicrogridValidationError("trade references unknown buyer")

        if trade.energy_wh <= 0:
            raise MicrogridValidationError("trade energy must be positive")

        if (
            trade.clearing_price_microunits_per_wh
            != expected_clearing_price_microunits_per_wh
        ):
            raise MicrogridValidationError("trade clearing price does not match")

        exports_by_building[trade.seller_key] += trade.energy_wh
        imports_by_building[trade.buyer_key] += trade.energy_wh

    for dispatch in solution.building_dispatches:
        building = buildings_by_key[dispatch.building_key]
        available_supply_wh = calculate_available_supply_wh(building)

        if dispatch.imported_energy_wh != imports_by_building[building.building_key]:
            raise MicrogridValidationError("import accounting mismatch")

        if dispatch.exported_energy_wh != exports_by_building[building.building_key]:
            raise MicrogridValidationError("export accounting mismatch")

        if dispatch.exported_energy_wh > available_supply_wh:
            raise MicrogridValidationError(
                "building exports more energy than locally available"
            )

        if dispatch.served_critical_load_wh < 0:
            raise MicrogridValidationError("served critical load must be non-negative")

        if dispatch.served_critical_load_wh > building.critical_load_wh:
            raise MicrogridValidationError(
                "served critical load cannot exceed critical load"
            )

        if (
            dispatch.unserved_critical_load_wh
            != building.critical_load_wh - dispatch.served_critical_load_wh
        ):
            raise MicrogridValidationError("unserved critical load mismatch")

        expected_ratio = continuity_ratio_basis_points(
            dispatch.served_critical_load_wh,
            building.critical_load_wh,
        )

        if dispatch.critical_continuity_ratio_basis_points != expected_ratio:
            raise MicrogridValidationError("critical continuity ratio mismatch")

        energy_balance_limit_wh = (
            available_supply_wh
            + dispatch.imported_energy_wh
            - dispatch.exported_energy_wh
        )

        total_served_wh = (
            dispatch.served_critical_load_wh + dispatch.served_noncritical_load_wh
        )

        if total_served_wh > energy_balance_limit_wh:
            raise MicrogridValidationError(
                "building serves more energy than its local balance permits"
            )

    if sum(imports_by_building.values()) != sum(exports_by_building.values()):
        raise MicrogridValidationError("market imports and exports do not balance")

    expected_block_ratio = continuity_ratio_basis_points(
        solution.total_served_critical_load_wh,
        solution.total_critical_load_wh,
    )

    if solution.block_critical_continuity_ratio_basis_points != expected_block_ratio:
        raise MicrogridValidationError("block continuity ratio mismatch")


def format_ratio(basis_points: int) -> str:
    return str(
        (Decimal(basis_points) / Decimal(100))
        .quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    ) + "%"
