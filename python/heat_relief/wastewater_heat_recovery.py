from __future__ import annotations

from dataclasses import dataclass
from math import isfinite


class WastewaterHeatRecoveryValidationError(ValueError):
    pass


WATER_LIKE_SPECIFIC_HEAT_J_KG_C = 4180.0


@dataclass(frozen=True)
class DistrictThermalObservation:
    mass_flow_kg_s: float
    influent_temperature_c: float
    effluent_temperature_c: float
    clean_heat_transfer_coefficient_w_m2_c: float
    current_heat_transfer_coefficient_w_m2_c: float
    clean_pressure_drop_pa: float
    current_pressure_drop_pa: float
    household_data_used: bool = False
    property_data_used: bool = False
    identity_data_used: bool = False

    def __post_init__(self) -> None:
        for field_name, value in (
            ("mass_flow_kg_s", self.mass_flow_kg_s),
            ("influent_temperature_c", self.influent_temperature_c),
            ("effluent_temperature_c", self.effluent_temperature_c),
            (
                "clean_heat_transfer_coefficient_w_m2_c",
                self.clean_heat_transfer_coefficient_w_m2_c,
            ),
            (
                "current_heat_transfer_coefficient_w_m2_c",
                self.current_heat_transfer_coefficient_w_m2_c,
            ),
            ("clean_pressure_drop_pa", self.clean_pressure_drop_pa),
            ("current_pressure_drop_pa", self.current_pressure_drop_pa),
        ):
            if not isfinite(value):
                raise WastewaterHeatRecoveryValidationError(
                    f"{field_name} must be finite."
                )

        if self.mass_flow_kg_s < 0.0:
            raise WastewaterHeatRecoveryValidationError(
                "mass_flow_kg_s must be non-negative."
            )
        if self.clean_heat_transfer_coefficient_w_m2_c <= 0.0:
            raise WastewaterHeatRecoveryValidationError(
                "clean heat-transfer coefficient must be positive."
            )
        if self.current_heat_transfer_coefficient_w_m2_c <= 0.0:
            raise WastewaterHeatRecoveryValidationError(
                "current heat-transfer coefficient must be positive."
            )
        if self.clean_pressure_drop_pa < 0.0 or self.current_pressure_drop_pa < 0.0:
            raise WastewaterHeatRecoveryValidationError(
                "Pressure-drop values must be non-negative."
            )


@dataclass(frozen=True)
class HeatRecoveryDecision:
    eligible: bool
    temperature_drop_c: float
    recovered_thermal_power_w: float
    performance_loss_fraction: float
    pressure_drop_increase_pa: float
    fouling_review_required: bool
    reason: str


def evaluate_district_heat_recovery(
    observation: DistrictThermalObservation,
    minimum_temperature_drop_c: float = 5.0,
    maximum_performance_loss_fraction: float = 0.20,
    maximum_pressure_drop_increase_pa: float = 5000.0,
) -> HeatRecoveryDecision:
    for field_name, value in (
        ("minimum_temperature_drop_c", minimum_temperature_drop_c),
        ("maximum_performance_loss_fraction", maximum_performance_loss_fraction),
        ("maximum_pressure_drop_increase_pa", maximum_pressure_drop_increase_pa),
    ):
        if not isfinite(value):
            raise WastewaterHeatRecoveryValidationError(
                f"{field_name} must be finite."
            )

    if minimum_temperature_drop_c <= 0.0:
        raise WastewaterHeatRecoveryValidationError(
            "minimum_temperature_drop_c must be positive."
        )
    if not 0.0 <= maximum_performance_loss_fraction < 1.0:
        raise WastewaterHeatRecoveryValidationError(
            "maximum_performance_loss_fraction must be in the range from zero to below one."
        )
    if maximum_pressure_drop_increase_pa < 0.0:
        raise WastewaterHeatRecoveryValidationError(
            "maximum_pressure_drop_increase_pa must be non-negative."
        )

    if (
        observation.household_data_used
        or observation.property_data_used
        or observation.identity_data_used
    ):
        return HeatRecoveryDecision(
            eligible=False,
            temperature_drop_c=0.0,
            recovered_thermal_power_w=0.0,
            performance_loss_fraction=0.0,
            pressure_drop_increase_pa=0.0,
            fouling_review_required=True,
            reason=(
                "District heat recovery must use aggregate infrastructure data and cannot "
                "use household, property, or identity data."
            ),
        )

    temperature_drop = (
        observation.influent_temperature_c - observation.effluent_temperature_c
    )
    recovered_power = (
        observation.mass_flow_kg_s
        * WATER_LIKE_SPECIFIC_HEAT_J_KG_C
        * temperature_drop
    )
    performance_loss = 1.0 - (
        observation.current_heat_transfer_coefficient_w_m2_c
        / observation.clean_heat_transfer_coefficient_w_m2_c
    )
    pressure_drop_increase = (
        observation.current_pressure_drop_pa - observation.clean_pressure_drop_pa
    )

    temperature_target_met = temperature_drop >= minimum_temperature_drop_c
    fouling_review_required = (
        performance_loss >= maximum_performance_loss_fraction
        or pressure_drop_increase >= maximum_pressure_drop_increase_pa
    )

    if fouling_review_required:
        return HeatRecoveryDecision(
            eligible=False,
            temperature_drop_c=temperature_drop,
            recovered_thermal_power_w=recovered_power,
            performance_loss_fraction=performance_loss,
            pressure_drop_increase_pa=pressure_drop_increase,
            fouling_review_required=True,
            reason=(
                "Thermal-performance loss or pressure-drop increase requires maintenance "
                "review before further operational reliance."
            ),
        )

    if not temperature_target_met:
        return HeatRecoveryDecision(
            eligible=False,
            temperature_drop_c=temperature_drop,
            recovered_thermal_power_w=recovered_power,
            performance_loss_fraction=performance_loss,
            pressure_drop_increase_pa=pressure_drop_increase,
            fouling_review_required=False,
            reason="The observed temperature drop is below the configured recovery target.",
        )

    return HeatRecoveryDecision(
        eligible=True,
        temperature_drop_c=temperature_drop,
        recovered_thermal_power_w=recovered_power,
        performance_loss_fraction=performance_loss,
        pressure_drop_increase_pa=pressure_drop_increase,
        fouling_review_required=False,
        reason=(
            "Aggregate district measurements meet the thermal target and no fouling review "
            "threshold is crossed."
        ),
    )
