from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Iterable


class CommunityStorageValidationError(ValueError):
    pass


ESSENTIAL_RESERVE_FRACTION = 0.30


@dataclass(frozen=True)
class BatteryState:
    state_of_charge_fraction: float
    nominal_usable_energy_kwh: float
    charging_power_kw: float
    requested_nonessential_discharge_kw: float
    interval_hours: float
    charging_efficiency: float
    discharge_efficiency: float

    def __post_init__(self) -> None:
        for field_name, value in (
            ("state_of_charge_fraction", self.state_of_charge_fraction),
            ("nominal_usable_energy_kwh", self.nominal_usable_energy_kwh),
            ("charging_power_kw", self.charging_power_kw),
            (
                "requested_nonessential_discharge_kw",
                self.requested_nonessential_discharge_kw,
            ),
            ("interval_hours", self.interval_hours),
            ("charging_efficiency", self.charging_efficiency),
            ("discharge_efficiency", self.discharge_efficiency),
        ):
            if not isfinite(value):
                raise CommunityStorageValidationError(f"{field_name} must be finite.")

        if not 0.0 <= self.state_of_charge_fraction <= 1.0:
            raise CommunityStorageValidationError(
                "state_of_charge_fraction must be in the range from zero through one."
            )
        if self.nominal_usable_energy_kwh <= 0.0:
            raise CommunityStorageValidationError(
                "nominal_usable_energy_kwh must be positive."
            )
        if self.charging_power_kw < 0.0:
            raise CommunityStorageValidationError(
                "charging_power_kw must be non-negative."
            )
        if self.requested_nonessential_discharge_kw < 0.0:
            raise CommunityStorageValidationError(
                "requested_nonessential_discharge_kw must be non-negative."
            )
        if self.interval_hours <= 0.0:
            raise CommunityStorageValidationError("interval_hours must be positive.")
        if not 0.0 < self.charging_efficiency <= 1.0:
            raise CommunityStorageValidationError(
                "charging_efficiency must be in the interval (0, 1]."
            )
        if not 0.0 < self.discharge_efficiency <= 1.0:
            raise CommunityStorageValidationError(
                "discharge_efficiency must be in the interval (0, 1]."
            )


@dataclass(frozen=True)
class ReserveDecision:
    approved_nonessential_discharge_kw: float
    projected_state_of_charge_fraction: float
    essential_reserve_preserved: bool
    household_data_used: bool
    residential_ranking_used: bool
    reason: str


def approve_nonessential_discharge(
    battery: BatteryState,
    essential_reserve_fraction: float = ESSENTIAL_RESERVE_FRACTION,
) -> ReserveDecision:
    if (
        not isfinite(essential_reserve_fraction)
        or not 0.0 < essential_reserve_fraction < 1.0
    ):
        raise CommunityStorageValidationError(
            "essential_reserve_fraction must be in the interval (0, 1)."
        )

    charged_kwh = (
        battery.charging_power_kw
        * battery.interval_hours
        * battery.charging_efficiency
    )
    available_above_reserve_kwh = max(
        0.0,
        (
            battery.state_of_charge_fraction
            * battery.nominal_usable_energy_kwh
            + charged_kwh
            - essential_reserve_fraction * battery.nominal_usable_energy_kwh
        ),
    )

    maximum_discharge_kw = (
        available_above_reserve_kwh
        * battery.discharge_efficiency
        / battery.interval_hours
    )
    approved_discharge_kw = min(
        battery.requested_nonessential_discharge_kw,
        maximum_discharge_kw,
    )

    discharged_kwh = (
        approved_discharge_kw
        * battery.interval_hours
        / battery.discharge_efficiency
    )
    projected_state_of_charge = (
        battery.state_of_charge_fraction
        * battery.nominal_usable_energy_kwh
        + charged_kwh
        - discharged_kwh
    ) / battery.nominal_usable_energy_kwh

    return ReserveDecision(
        approved_nonessential_discharge_kw=approved_discharge_kw,
        projected_state_of_charge_fraction=projected_state_of_charge,
        essential_reserve_preserved=projected_state_of_charge >= essential_reserve_fraction,
        household_data_used=False,
        residential_ranking_used=False,
        reason=(
            "Non-essential discharge is limited to energy above the protected community "
            "essential-services reserve."
        ),
    )


def consensus_satisfied(
    approved_role_classes: Iterable[str],
    minimum_distinct_roles: int = 3,
) -> bool:
    roles = {role.strip() for role in approved_role_classes if role.strip()}
    permitted = {
        "technical_operator",
        "public_emergency_authority",
        "community_governance",
        "independent_safety_reviewer",
        "accessibility_representative",
    }

    if minimum_distinct_roles < 3:
        raise CommunityStorageValidationError(
            "minimum_distinct_roles must preserve multi-role approval."
        )

    return len(roles.intersection(permitted)) >= minimum_distinct_roles
