from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Iterable


BASIS_POINTS_PER_UNIT = 10_000


class PoeAllocationError(ValueError):
    pass


@dataclass(frozen=True)
class PoePortDevice:
    port_key: str
    device_kind: str
    required_power_watts: float
    maximum_port_power_watts: float
    minimum_operating_voltage_volts: float
    switch_supply_voltage_volts: float
    cable_length_meters: float
    loop_resistance_ohms_per_meter: float
    continuity_weight: int
    critical: bool

    def validate(self) -> None:
        if not self.port_key.strip():
            raise PoeAllocationError("port_key must not be blank")

        if self.device_kind not in {"sensor", "camera", "door_controller"}:
            raise PoeAllocationError("device_kind is unsupported")

        for field_name, value in (
            ("required_power_watts", self.required_power_watts),
            ("maximum_port_power_watts", self.maximum_port_power_watts),
            ("minimum_operating_voltage_volts", self.minimum_operating_voltage_volts),
            ("switch_supply_voltage_volts", self.switch_supply_voltage_volts),
            ("cable_length_meters", self.cable_length_meters),
            ("loop_resistance_ohms_per_meter", self.loop_resistance_ohms_per_meter),
        ):
            if not isfinite(value) or value <= 0:
                raise PoeAllocationError(f"{field_name} must be finite and positive")

        if self.required_power_watts > self.maximum_port_power_watts:
            raise PoeAllocationError(
                "required_power_watts must not exceed maximum_port_power_watts"
            )

        if self.minimum_operating_voltage_volts >= self.switch_supply_voltage_volts:
            raise PoeAllocationError(
                "minimum_operating_voltage_volts must be below switch_supply_voltage_volts"
            )

        if self.continuity_weight <= 0:
            raise PoeAllocationError("continuity_weight must be positive")


@dataclass(frozen=True)
class PoePortDispatch:
    port_key: str
    allocated_power_watts: float
    delivered_voltage_volts: float
    powered: bool
    continuity_score_basis_points: int


@dataclass(frozen=True)
class PoeAllocationSolution:
    switch_power_budget_watts: float
    allocated_power_watts: float
    weighted_continuity_score: int
    continuity_ratio_basis_points: int
    port_dispatches: tuple[PoePortDispatch, ...]


def voltage_drop_volts(device: PoePortDevice, allocated_power_watts: float) -> float:
    if allocated_power_watts < 0:
        raise PoeAllocationError("allocated_power_watts must be non-negative")

    current_amps = allocated_power_watts / device.switch_supply_voltage_volts
    total_loop_resistance_ohms = (
        device.cable_length_meters * device.loop_resistance_ohms_per_meter
    )

    return current_amps * total_loop_resistance_ohms


def maximum_deliverable_power_watts(device: PoePortDevice) -> float:
    device.validate()

    voltage_headroom_volts = (
        device.switch_supply_voltage_volts - device.minimum_operating_voltage_volts
    )

    maximum_current_amps = voltage_headroom_volts / (
        device.cable_length_meters * device.loop_resistance_ohms_per_meter
    )

    voltage_drop_limited_power_watts = (
        maximum_current_amps * device.switch_supply_voltage_volts
    )

    return min(
        device.required_power_watts,
        device.maximum_port_power_watts,
        voltage_drop_limited_power_watts,
    )


def allocate_poe_budget(
    switch_power_budget_watts: float,
    devices: Iterable[PoePortDevice],
) -> PoeAllocationSolution:
    if not isfinite(switch_power_budget_watts) or switch_power_budget_watts <= 0:
        raise PoeAllocationError(
            "switch_power_budget_watts must be finite and positive"
        )

    device_list = tuple(devices)

    if not device_list:
        raise PoeAllocationError("at least one device is required")

    for device in device_list:
        device.validate()

    ordered_devices = sorted(
        device_list,
        key=lambda device: (
            not device.critical,
            -device.continuity_weight,
            device.device_kind,
            device.port_key,
        ),
    )

    remaining_budget_watts = switch_power_budget_watts
    dispatches: list[PoePortDispatch] = []

    for device in ordered_devices:
        available_device_power_watts = maximum_deliverable_power_watts(device)

        allocated_power_watts = (
            device.required_power_watts
            if (
                available_device_power_watts >= device.required_power_watts
                and remaining_budget_watts >= device.required_power_watts
            )
            else 0.0
        )

        delivered_voltage_volts = (
            device.switch_supply_voltage_volts
            - voltage_drop_volts(device, allocated_power_watts)
        )

        powered = (
            allocated_power_watts >= device.required_power_watts
            and allocated_power_watts <= device.maximum_port_power_watts
            and delivered_voltage_volts >= device.minimum_operating_voltage_volts
        )

        if powered:
            remaining_budget_watts -= allocated_power_watts

        dispatches.append(
            PoePortDispatch(
                port_key=device.port_key,
                allocated_power_watts=allocated_power_watts,
                delivered_voltage_volts=delivered_voltage_volts,
                powered=powered,
                continuity_score_basis_points=(
                    BASIS_POINTS_PER_UNIT if powered else 0
                ),
            )
        )

    dispatches.sort(key=lambda dispatch: dispatch.port_key)

    total_weight = sum(device.continuity_weight for device in device_list)

    powered_weight = sum(
        device.continuity_weight
        for device in device_list
        if next(
            dispatch
            for dispatch in dispatches
            if dispatch.port_key == device.port_key
        ).powered
    )

    solution = PoeAllocationSolution(
        switch_power_budget_watts=switch_power_budget_watts,
        allocated_power_watts=(
            switch_power_budget_watts - remaining_budget_watts
        ),
        weighted_continuity_score=powered_weight,
        continuity_ratio_basis_points=(
            powered_weight * BASIS_POINTS_PER_UNIT // total_weight
        ),
        port_dispatches=tuple(dispatches),
    )

    validate_solution(switch_power_budget_watts, device_list, solution)

    return solution


def validate_solution(
    switch_power_budget_watts: float,
    devices: Iterable[PoePortDevice],
    solution: PoeAllocationSolution,
) -> None:
    device_list = tuple(devices)
    device_by_port = {device.port_key: device for device in device_list}

    if set(device_by_port) != {
        dispatch.port_key for dispatch in solution.port_dispatches
    }:
        raise PoeAllocationError(
            "solution must contain exactly one dispatch for every device"
        )

    total_allocated_power_watts = 0.0

    for dispatch in solution.port_dispatches:
        device = device_by_port[dispatch.port_key]

        if dispatch.allocated_power_watts < 0:
            raise PoeAllocationError("allocated power must be non-negative")

        if dispatch.allocated_power_watts > device.maximum_port_power_watts:
            raise PoeAllocationError("maximum per-port power exceeded")

        expected_voltage = (
            device.switch_supply_voltage_volts
            - voltage_drop_volts(device, dispatch.allocated_power_watts)
        )

        if abs(dispatch.delivered_voltage_volts - expected_voltage) > 1e-9:
            raise PoeAllocationError("delivered voltage calculation mismatch")

        if dispatch.powered:
            if dispatch.allocated_power_watts < device.required_power_watts:
                raise PoeAllocationError(
                    "powered device does not receive required power"
                )

            if dispatch.delivered_voltage_volts < device.minimum_operating_voltage_volts:
                raise PoeAllocationError(
                    "powered device does not receive minimum operating voltage"
                )

        total_allocated_power_watts += dispatch.allocated_power_watts

    if total_allocated_power_watts > switch_power_budget_watts + 1e-9:
        raise PoeAllocationError("switch power budget exceeded")

    if abs(solution.allocated_power_watts - total_allocated_power_watts) > 1e-9:
        raise PoeAllocationError("solution allocation total mismatch")
