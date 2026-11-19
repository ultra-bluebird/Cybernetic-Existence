from __future__ import annotations

from dataclasses import dataclass
import math


@dataclass(frozen=True)
class HeatMitigationScenario:
    scenario_code: str
    modeled_temperature_reduction_celsius: float
    temperature_reduction_uncertainty_celsius: float
    modeled_energy_reduction_kwh: float
    modeled_water_demand_liters: float
    available_water_budget_liters: float
    accessible_cooling_access_baseline: float
    accessible_cooling_access_scenario: float
    displacement_risk: float
    displacement_risk_limit: float
    habitat_protection_satisfied: bool
    community_review_ready: bool
    calibration_rmse_celsius: float


@dataclass(frozen=True)
class ScenarioGateResult:
    eligible_for_planner_review: bool
    reasons: tuple[str, ...]
    estimated_temperature_reduction_interval: tuple[float, float]


def evaluate_scenario(
    scenario: HeatMitigationScenario,
) -> ScenarioGateResult:
    _validate_scenario(scenario)

    reasons: list[str] = []

    reduction_low = (
        scenario.modeled_temperature_reduction_celsius
        - 1.96 * scenario.temperature_reduction_uncertainty_celsius
    )
    reduction_high = (
        scenario.modeled_temperature_reduction_celsius
        + 1.96 * scenario.temperature_reduction_uncertainty_celsius
    )

    if reduction_low <= 0.0:
        reasons.append(
            "The lower confidence-bound temperature reduction is not positive."
        )

    if scenario.modeled_water_demand_liters > scenario.available_water_budget_liters:
        reasons.append(
            "Scenario water demand exceeds the approved planning water budget."
        )

    if (
        scenario.accessible_cooling_access_scenario
        < scenario.accessible_cooling_access_baseline
    ):
        reasons.append(
            "Scenario reduces accessible cooling or shade access and is not eligible."
        )

    if scenario.displacement_risk > scenario.displacement_risk_limit:
        reasons.append(
            "Scenario displacement or exclusion risk exceeds the approved limit."
        )

    if not scenario.habitat_protection_satisfied:
        reasons.append(
            "Scenario does not satisfy habitat-protection requirements."
        )

    if not scenario.community_review_ready:
        reasons.append(
            "Scenario is not ready for participatory community review."
        )

    if scenario.calibration_rmse_celsius > 3.0:
        reasons.append(
            "Twin calibration error exceeds the configured planning-confidence limit."
        )

    return ScenarioGateResult(
        eligible_for_planner_review=not reasons,
        reasons=tuple(reasons) or (
            "Scenario passes planning gates and may proceed to human planner review.",
        ),
        estimated_temperature_reduction_interval=(
            reduction_low,
            reduction_high,
        ),
    )


def _validate_scenario(scenario: HeatMitigationScenario) -> None:
    if not scenario.scenario_code.strip():
        raise ValueError("scenario_code is required.")

    for field_name, value in {
        "modeled_temperature_reduction_celsius": (
            scenario.modeled_temperature_reduction_celsius
        ),
        "temperature_reduction_uncertainty_celsius": (
            scenario.temperature_reduction_uncertainty_celsius
        ),
        "modeled_energy_reduction_kwh": scenario.modeled_energy_reduction_kwh,
        "modeled_water_demand_liters": scenario.modeled_water_demand_liters,
        "available_water_budget_liters": scenario.available_water_budget_liters,
        "accessible_cooling_access_baseline": (
            scenario.accessible_cooling_access_baseline
        ),
        "accessible_cooling_access_scenario": (
            scenario.accessible_cooling_access_scenario
        ),
        "displacement_risk": scenario.displacement_risk,
        "displacement_risk_limit": scenario.displacement_risk_limit,
        "calibration_rmse_celsius": scenario.calibration_rmse_celsius,
    }.items():
        if not math.isfinite(value):
            raise ValueError(f"{field_name} must be finite.")

    if scenario.temperature_reduction_uncertainty_celsius < 0.0:
        raise ValueError(
            "temperature_reduction_uncertainty_celsius must be non-negative."
        )

    if scenario.modeled_water_demand_liters < 0.0:
        raise ValueError("modeled_water_demand_liters must be non-negative.")

    if scenario.available_water_budget_liters < 0.0:
        raise ValueError("available_water_budget_liters must be non-negative.")

    for field_name, value in {
        "accessible_cooling_access_baseline": (
            scenario.accessible_cooling_access_baseline
        ),
        "accessible_cooling_access_scenario": (
            scenario.accessible_cooling_access_scenario
        ),
        "displacement_risk": scenario.displacement_risk,
        "displacement_risk_limit": scenario.displacement_risk_limit,
    }.items():
        if not 0.0 <= value <= 1.0:
            raise ValueError(f"{field_name} must be within [0, 1].")

    if scenario.calibration_rmse_celsius < 0.0:
        raise ValueError("calibration_rmse_celsius must be non-negative.")
