from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class SurfaceEnergyBalance:
    net_radiation_w_m2: float
    sensible_heat_w_m2: float
    latent_heat_w_m2: float
    ground_heat_w_m2: float
    storage_change_w_m2: float

    def residual_w_m2(self) -> float:
        return (
            self.net_radiation_w_m2
            - self.sensible_heat_w_m2
            - self.latent_heat_w_m2
            - self.ground_heat_w_m2
            - self.storage_change_w_m2
        )

    def closes_within(self, tolerance_w_m2: float) -> bool:
        if tolerance_w_m2 < 0.0:
            raise ValueError("tolerance_w_m2 must be non-negative.")

        return abs(self.residual_w_m2()) <= tolerance_w_m2


@dataclass(frozen=True)
class InterventionScenario:
    reflective_roof_fraction: float
    canopy_fraction_change: float
    green_wall_fraction: float
    green_roof_fraction: float
    shade_structure_fraction: float
    irrigation_water_m3_day: float
    sustainable_water_limit_m3_day: float
    accessible_route_preserved: bool
    privacy_safe_inputs_only: bool
    community_review_complete: bool

    def __post_init__(self) -> None:
        for name, value in (
            ("reflective_roof_fraction", self.reflective_roof_fraction),
            ("canopy_fraction_change", self.canopy_fraction_change),
            ("green_wall_fraction", self.green_wall_fraction),
            ("green_roof_fraction", self.green_roof_fraction),
            ("shade_structure_fraction", self.shade_structure_fraction),
        ):
            if not 0.0 <= value <= 1.0:
                raise ValueError(f"{name} must be within 0.0..=1.0.")

        if self.irrigation_water_m3_day < 0.0:
            raise ValueError("irrigation_water_m3_day must be non-negative.")

        if self.sustainable_water_limit_m3_day < 0.0:
            raise ValueError(
                "sustainable_water_limit_m3_day must be non-negative."
            )


@dataclass(frozen=True)
class ThermalResponseCoefficients:
    reflective_roof_c_per_fraction: float
    canopy_c_per_fraction: float
    green_wall_c_per_fraction: float
    green_roof_c_per_fraction: float
    shade_structure_c_per_fraction: float
    roof_canopy_interaction_c: float = 0.0
    canopy_green_roof_interaction_c: float = 0.0


@dataclass(frozen=True)
class ScenarioEstimate:
    air_temperature_change_c: float
    absorbed_solar_change_w_m2: float
    ecological_feasible: bool
    promotion_eligible: bool


def absorbed_solar_change_w_m2(
    incoming_shortwave_w_m2: float,
    baseline_albedo: float,
    intervention_albedo: float,
) -> float:
    if incoming_shortwave_w_m2 < 0.0:
        raise ValueError("incoming_shortwave_w_m2 must be non-negative.")

    _unit_interval("baseline_albedo", baseline_albedo)
    _unit_interval("intervention_albedo", intervention_albedo)

    return -(
        intervention_albedo - baseline_albedo
    ) * incoming_shortwave_w_m2


def control_volume_temperature_change_c(
    sensible_heat_change_w_m2: float,
    duration_seconds: float,
    air_density_kg_m3: float,
    air_specific_heat_j_kg_k: float,
    mixing_height_m: float,
) -> float:
    if duration_seconds < 0.0:
        raise ValueError("duration_seconds must be non-negative.")

    if air_density_kg_m3 <= 0.0:
        raise ValueError("air_density_kg_m3 must be positive.")

    if air_specific_heat_j_kg_k <= 0.0:
        raise ValueError("air_specific_heat_j_kg_k must be positive.")

    if mixing_height_m <= 0.0:
        raise ValueError("mixing_height_m must be positive.")

    return (
        sensible_heat_change_w_m2 * duration_seconds
    ) / (
        air_density_kg_m3
        * air_specific_heat_j_kg_k
        * mixing_height_m
    )


def scenario_temperature_change_c(
    scenario: InterventionScenario,
    coefficients: ThermalResponseCoefficients,
) -> float:
    return (
        coefficients.reflective_roof_c_per_fraction
        * scenario.reflective_roof_fraction
        + coefficients.canopy_c_per_fraction
        * scenario.canopy_fraction_change
        + coefficients.green_wall_c_per_fraction
        * scenario.green_wall_fraction
        + coefficients.green_roof_c_per_fraction
        * scenario.green_roof_fraction
        + coefficients.shade_structure_c_per_fraction
        * scenario.shade_structure_fraction
        + coefficients.roof_canopy_interaction_c
        * scenario.reflective_roof_fraction
        * scenario.canopy_fraction_change
        + coefficients.canopy_green_roof_interaction_c
        * scenario.canopy_fraction_change
        * scenario.green_roof_fraction
    )


def ecological_feasibility(scenario: InterventionScenario) -> bool:
    return (
        scenario.irrigation_water_m3_day
        <= scenario.sustainable_water_limit_m3_day
    )


def promotion_eligible(scenario: InterventionScenario) -> bool:
    return (
        ecological_feasibility(scenario)
        and scenario.accessible_route_preserved
        and scenario.privacy_safe_inputs_only
        and scenario.community_review_complete
    )


def estimate_scenario(
    scenario: InterventionScenario,
    coefficients: ThermalResponseCoefficients,
    incoming_shortwave_w_m2: float,
    baseline_albedo: float,
    intervention_albedo: float,
) -> ScenarioEstimate:
    return ScenarioEstimate(
        air_temperature_change_c=scenario_temperature_change_c(
            scenario,
            coefficients,
        ),
        absorbed_solar_change_w_m2=absorbed_solar_change_w_m2(
            incoming_shortwave_w_m2,
            baseline_albedo,
            intervention_albedo,
        ),
        ecological_feasible=ecological_feasibility(scenario),
        promotion_eligible=promotion_eligible(scenario),
    )


def _unit_interval(name: str, value: float) -> None:
    if not 0.0 <= value <= 1.0:
        raise ValueError(f"{name} must be within 0.0..=1.0.")
