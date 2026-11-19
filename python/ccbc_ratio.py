from __future__ import annotations

from dataclasses import dataclass
from math import isfinite


@dataclass(frozen=True)
class ReferenceScenario:
    avoided_weighted_heat_exposure_person_hours: float
    equity_weighted_population: float
    reclaimed_water_consumed_m3: float
    lifecycle_carbon_kgco2e: float


@dataclass(frozen=True)
class CoolingScenario:
    baseline_wbgt_c: tuple[float, ...]
    intervention_wbgt_c: tuple[float, ...]
    wbgt_threshold_c: float
    interval_hours: float
    occupancy_weights: tuple[float, ...]
    heat_vulnerability_weights: tuple[float, ...]
    access_weights: tuple[float, ...]
    reclaimed_water_withdrawn_m3: float
    reclaimed_water_recovered_m3: float
    authorized_return_m3: float
    verified_recharge_credit_m3: float
    treatment_carbon_kgco2e: float
    pumping_carbon_kgco2e: float
    disinfection_carbon_kgco2e: float
    embodied_material_carbon_kgco2e: float
    maintenance_carbon_kgco2e: float
    displaced_carbon_kgco2e: float


@dataclass(frozen=True)
class CcbcrResult:
    avoided_weighted_heat_exposure_person_hours: float
    equity_weighted_population: float
    water_consumed_m3: float
    lifecycle_carbon_kgco2e: float
    raw_benefit_cost_score: float
    dimensionless_ccbcr: float


def _require_finite(name: str, value: float, minimum: float = 0.0) -> None:
    if not isfinite(value) or value < minimum:
        raise ValueError(f"{name} must be finite and at least {minimum}.")


def _require_equal_lengths(*series: tuple[float, ...]) -> None:
    if not series or any(len(values) == 0 for values in series):
        raise ValueError("All measurement series must be non-empty.")

    lengths = {len(values) for values in series}
    if len(lengths) != 1:
        raise ValueError("All measurement series must have identical lengths.")


def avoided_weighted_heat_exposure(
    baseline_wbgt_c: tuple[float, ...],
    intervention_wbgt_c: tuple[float, ...],
    wbgt_threshold_c: float,
    interval_hours: float,
    occupancy_weights: tuple[float, ...],
    heat_vulnerability_weights: tuple[float, ...],
    access_weights: tuple[float, ...],
) -> float:
    _require_equal_lengths(
        baseline_wbgt_c,
        intervention_wbgt_c,
        occupancy_weights,
        heat_vulnerability_weights,
        access_weights,
    )
    _require_finite("wbgt_threshold_c", wbgt_threshold_c, -100.0)
    _require_finite("interval_hours", interval_hours, 0.000001)

    avoided = 0.0

    for values in zip(
        baseline_wbgt_c,
        intervention_wbgt_c,
        occupancy_weights,
        heat_vulnerability_weights,
        access_weights,
    ):
        baseline, intervention, occupancy, vulnerability, access = values

        _require_finite("baseline_wbgt_c", baseline, -100.0)
        _require_finite("intervention_wbgt_c", intervention, -100.0)
        _require_finite("occupancy_weight", occupancy)
        _require_finite("heat_vulnerability_weight", vulnerability)
        _require_finite("access_weight", access)

        baseline_excess = max(0.0, baseline - wbgt_threshold_c)
        intervention_excess = max(0.0, intervention - wbgt_threshold_c)
        avoided_excess = max(0.0, baseline_excess - intervention_excess)

        avoided += (
            avoided_excess
            * interval_hours
            * occupancy
            * vulnerability
            * access
        )

    return avoided


def equity_weighted_population(
    occupancy_weights: tuple[float, ...],
    heat_vulnerability_weights: tuple[float, ...],
    access_weights: tuple[float, ...],
) -> float:
    _require_equal_lengths(
        occupancy_weights,
        heat_vulnerability_weights,
        access_weights,
    )

    total = 0.0

    for occupancy, vulnerability, access in zip(
        occupancy_weights,
        heat_vulnerability_weights,
        access_weights,
    ):
        _require_finite("occupancy_weight", occupancy)
        _require_finite("heat_vulnerability_weight", vulnerability)
        _require_finite("access_weight", access)
        total += occupancy * vulnerability * access

    return total


def reclaimed_water_consumed_m3(scenario: CoolingScenario) -> float:
    components = (
        scenario.reclaimed_water_withdrawn_m3,
        scenario.reclaimed_water_recovered_m3,
        scenario.authorized_return_m3,
        scenario.verified_recharge_credit_m3,
    )

    for component in components:
        _require_finite("water balance component", component)

    consumed = (
        scenario.reclaimed_water_withdrawn_m3
        - scenario.reclaimed_water_recovered_m3
        - scenario.authorized_return_m3
        - scenario.verified_recharge_credit_m3
    )

    if consumed <= 0.0:
        raise ValueError(
            "Water consumed must be positive after verified recovery, return, "
            "and recharge credits."
        )

    return consumed


def lifecycle_carbon_kgco2e(scenario: CoolingScenario) -> float:
    components = (
        scenario.treatment_carbon_kgco2e,
        scenario.pumping_carbon_kgco2e,
        scenario.disinfection_carbon_kgco2e,
        scenario.embodied_material_carbon_kgco2e,
        scenario.maintenance_carbon_kgco2e,
        scenario.displaced_carbon_kgco2e,
    )

    for component in components:
        _require_finite("lifecycle carbon component", component)

    carbon = (
        scenario.treatment_carbon_kgco2e
        + scenario.pumping_carbon_kgco2e
        + scenario.disinfection_carbon_kgco2e
        + scenario.embodied_material_carbon_kgco2e
        + scenario.maintenance_carbon_kgco2e
        - scenario.displaced_carbon_kgco2e
    )

    if carbon <= 0.0:
        raise ValueError(
            "Lifecycle carbon must be positive for this comparative index. "
            "Report net-negative claims separately with an independently "
            "reviewed lifecycle model."
        )

    return carbon


def calculate_ccbcr(
    scenario: CoolingScenario,
    reference: ReferenceScenario,
) -> CcbcrResult:
    reference_values = (
        reference.avoided_weighted_heat_exposure_person_hours,
        reference.equity_weighted_population,
        reference.reclaimed_water_consumed_m3,
        reference.lifecycle_carbon_kgco2e,
    )

    for value in reference_values:
        _require_finite("reference value", value, 0.000001)

    avoided = avoided_weighted_heat_exposure(
        scenario.baseline_wbgt_c,
        scenario.intervention_wbgt_c,
        scenario.wbgt_threshold_c,
        scenario.interval_hours,
        scenario.occupancy_weights,
        scenario.heat_vulnerability_weights,
        scenario.access_weights,
    )
    protected_population = equity_weighted_population(
        scenario.occupancy_weights,
        scenario.heat_vulnerability_weights,
        scenario.access_weights,
    )
    water = reclaimed_water_consumed_m3(scenario)
    carbon = lifecycle_carbon_kgco2e(scenario)

    raw_score = (avoided * protected_population) / (water * carbon)

    normalized_benefit = (
        avoided / reference.avoided_weighted_heat_exposure_person_hours
    )
    normalized_equity = (
        protected_population / reference.equity_weighted_population
    )
    normalized_water = water / reference.reclaimed_water_consumed_m3
    normalized_carbon = carbon / reference.lifecycle_carbon_kgco2e

    dimensionless_score = (
        normalized_benefit * normalized_equity
    ) / (normalized_water * normalized_carbon)

    return CcbcrResult(
        avoided_weighted_heat_exposure_person_hours=avoided,
        equity_weighted_population=protected_population,
        water_consumed_m3=water,
        lifecycle_carbon_kgco2e=carbon,
        raw_benefit_cost_score=raw_score,
        dimensionless_ccbcr=dimensionless_score,
    )
