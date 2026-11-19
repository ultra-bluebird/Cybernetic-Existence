from __future__ import annotations

from dataclasses import dataclass
from math import exp, isfinite, log
from typing import Iterable, Sequence


SECONDS_PER_DAY = 86_400.0
LATENT_HEAT_WATER_J_PER_KG = 2_450_000.0
WATER_DENSITY_KG_PER_M3 = 1_000.0


def _require_finite_nonnegative(name: str, value: float) -> None:
    if not isfinite(value) or value < 0.0:
        raise ValueError(f"{name} must be finite and non-negative.")


def _require_positive(name: str, value: float) -> None:
    if not isfinite(value) or value <= 0.0:
        raise ValueError(f"{name} must be finite and greater than zero.")


@dataclass(frozen=True)
class StreetCanyonGeometry:
    """
    Idealized canyon cross-section, normalized per metre of street length.

    H/W is fixed to 1.5 by the Object 19 design condition. The box volume per
    metre of street length is W*H and rooftop exchange area is W.
    """

    width_m: float
    height_m: float

    def __post_init__(self) -> None:
        _require_positive("width_m", self.width_m)
        _require_positive("height_m", self.height_m)
        if abs(self.aspect_ratio - 1.5) > 1e-9:
            raise ValueError("Object 19 requires height_m / width_m = 1.5.")

    @property
    def aspect_ratio(self) -> float:
        return self.height_m / self.width_m

    @property
    def box_volume_per_m_street_m3(self) -> float:
        return self.width_m * self.height_m

    @property
    def rooftop_exchange_area_per_m_street_m2(self) -> float:
        return self.width_m


@dataclass(frozen=True)
class BioaerosolTransportInputs:
    """
    Inputs for a longitudinal plug-flow/box hybrid model.

    source_strength_particles_per_s:
        Line-source release rate assigned per metre of street length.

    longitudinal_speed_m_per_s:
        Mean positive along-canyon transport speed. This must be measured or
        represented from CFD/wind-tunnel calibration; it is distinct from roof
        wind speed used to parameterize u_e.

    exchange_velocity_m_per_s:
        Effective pollutant exchange velocity at the canyon roof, including
        resolved and turbulent vertical transfer.

    settling_velocity_m_per_s:
        Terminal settling velocity adjusted to the relevant particle ensemble.
        It can be set to zero for near-neutral ultrafine particles.

    background_concentration_particles_per_m3:
        Ambient upwind/background concentration.
    """

    source_strength_particles_per_s: float
    longitudinal_speed_m_per_s: float
    exchange_velocity_m_per_s: float
    settling_velocity_m_per_s: float
    background_concentration_particles_per_m3: float = 0.0

    def __post_init__(self) -> None:
        _require_finite_nonnegative(
            "source_strength_particles_per_s", self.source_strength_particles_per_s
        )
        _require_positive(
            "longitudinal_speed_m_per_s", self.longitudinal_speed_m_per_s
        )
        _require_finite_nonnegative(
            "exchange_velocity_m_per_s", self.exchange_velocity_m_per_s
        )
        _require_finite_nonnegative(
            "settling_velocity_m_per_s", self.settling_velocity_m_per_s
        )
        _require_finite_nonnegative(
            "background_concentration_particles_per_m3",
            self.background_concentration_particles_per_m3,
        )


@dataclass(frozen=True)
class BioaerosolProfile:
    source_concentration_particles_per_m3: float
    e_folding_distance_m: float
    flushing_time_s: float
    settling_time_s: float
    critical_exchange_velocity_m_per_s: float


def bioaerosol_profile_parameters(
    geometry: StreetCanyonGeometry,
    inputs: BioaerosolTransportInputs,
) -> BioaerosolProfile:
    """
    Derive steady profile parameters.

    Per metre street length, the cross-canyon box balance is

        U_c H dC/dx = - (u_e + v_s) (C - C_b)

    and an idealized source-plane condition is

        C(0+) - C_b = Q' / (U_c H).

    Thus:

        C(x) = C_b + [Q'/(U_c H)] exp[-x/L_d]

        L_d = U_c H / (u_e + v_s)

    The residence times are H/u_e for roof flushing and H/v_s for settling.
    Flushing is faster than settling precisely when u_e > v_s.
    """
    total_removal_velocity = (
        inputs.exchange_velocity_m_per_s + inputs.settling_velocity_m_per_s
    )
    _require_positive("exchange_velocity_m_per_s + settling_velocity_m_per_s",
                      total_removal_velocity)

    source_excess = (
        inputs.source_strength_particles_per_s
        / (inputs.longitudinal_speed_m_per_s * geometry.height_m)
    )
    e_folding_distance = (
        inputs.longitudinal_speed_m_per_s
        * geometry.height_m
        / total_removal_velocity
    )
    flushing_time = (
        geometry.height_m / inputs.exchange_velocity_m_per_s
        if inputs.exchange_velocity_m_per_s > 0.0
        else float("inf")
    )
    settling_time = (
        geometry.height_m / inputs.settling_velocity_m_per_s
        if inputs.settling_velocity_m_per_s > 0.0
        else float("inf")
    )

    return BioaerosolProfile(
        source_concentration_particles_per_m3=(
            inputs.background_concentration_particles_per_m3 + source_excess
        ),
        e_folding_distance_m=e_folding_distance,
        flushing_time_s=flushing_time,
        settling_time_s=settling_time,
        critical_exchange_velocity_m_per_s=inputs.settling_velocity_m_per_s,
    )


def street_level_concentration(
    distance_m: float,
    geometry: StreetCanyonGeometry,
    inputs: BioaerosolTransportInputs,
) -> float:
    """
    Return the steady street-level, vertically mixed concentration C(x).
    """
    _require_finite_nonnegative("distance_m", distance_m)
    profile = bioaerosol_profile_parameters(geometry, inputs)
    background = inputs.background_concentration_particles_per_m3
    source_excess = profile.source_concentration_particles_per_m3 - background
    return background + source_excess * exp(-distance_m / profile.e_folding_distance_m)


def critical_roof_wind_speed(
    settling_velocity_m_per_s: float,
    exchange_efficiency: float,
) -> float:
    """
    Return U_roof,crit for u_e = exchange_efficiency * U_roof.

    U_roof,crit = v_s / beta_e

    beta_e must be locally calibrated from anemometry, tracer release, CFD, or
    a defensible literature transfer relation. It is intentionally explicit:
    roof wind speed is not universally interchangeable with canyon exchange.
    """
    _require_finite_nonnegative(
        "settling_velocity_m_per_s", settling_velocity_m_per_s
    )
    _require_positive("exchange_efficiency", exchange_efficiency)
    return settling_velocity_m_per_s / exchange_efficiency


@dataclass(frozen=True)
class TreatmentUnit:
    name: str
    capital_cost_usd: float
    operating_cost_usd_per_m3: float
    energy_kwh_per_m3: float
    virus_log_removal: float
    tthm_formation_ug_per_l: float
    haa5_formation_ug_per_l: float
    enabled: bool = True

    def __post_init__(self) -> None:
        for label, value in (
            ("capital_cost_usd", self.capital_cost_usd),
            ("operating_cost_usd_per_m3", self.operating_cost_usd_per_m3),
            ("energy_kwh_per_m3", self.energy_kwh_per_m3),
            ("virus_log_removal", self.virus_log_removal),
            ("tthm_formation_ug_per_l", self.tthm_formation_ug_per_l),
            ("haa5_formation_ug_per_l", self.haa5_formation_ug_per_l),
        ):
            _require_finite_nonnegative(label, value)


@dataclass(frozen=True)
class TreatmentOptimizationInputs:
    """
    All concentration inputs are µg/L, numerically equivalent to ppb in water.

    A validated, site-specific chlorine CT model should be represented as a
    TreatmentUnit or added upstream before use. This model does not treat
    nominal chlorination as automatic virus credit: its log removal must be
    assigned from actual CT, temperature, pH, residual, and validation basis.
    """

    annual_volume_m3: float
    influent_tthm_ug_per_l: float
    influent_haa5_ug_per_l: float
    tthm_limit_ug_per_l: float = 40.0
    haa5_limit_ug_per_l: float = 60.0
    minimum_virus_log_removal: float = 4.0
    electricity_cost_usd_per_kwh: float = 0.12

    def __post_init__(self) -> None:
        for label, value in (
            ("annual_volume_m3", self.annual_volume_m3),
            ("influent_tthm_ug_per_l", self.influent_tthm_ug_per_l),
            ("influent_haa5_ug_per_l", self.influent_haa5_ug_per_l),
            ("tthm_limit_ug_per_l", self.tthm_limit_ug_per_l),
            ("haa5_limit_ug_per_l", self.haa5_limit_ug_per_l),
            ("minimum_virus_log_removal", self.minimum_virus_log_removal),
            ("electricity_cost_usd_per_kwh", self.electricity_cost_usd_per_kwh),
        ):
            _require_finite_nonnegative(label, value)


@dataclass(frozen=True)
class TreatmentEvaluation:
    configuration: tuple[str, ...]
    feasible: bool
    total_annual_cost_usd: float
    total_energy_kwh_per_year: float
    virus_log_removal: float
    finished_tthm_ug_per_l: float
    finished_haa5_ug_per_l: float
    constraint_explanation: str


def evaluate_treatment_configuration(
    units: Sequence[TreatmentUnit],
    inputs: TreatmentOptimizationInputs,
) -> TreatmentEvaluation:
    """
    Evaluate a treatment configuration as a transparent constrained objective.

    The basic optimization is:

        minimize  C_total = sum(C_cap,annualized) +
                            V * sum(c_op,i + p_e E_i)

        subject to:
          sum(LRV_virus,i) >= 4
          TTHM_in + sum(DeltaTTHM_i) <= 40 ug/L
          HAA5_in + sum(DeltaHAA5_i) <= HAA5_limit
          E_total <= an operator-specified energy corridor, when applicable.

    Sand filtration and GAC may earn validated physical-removal credit; UV and
    chlorination must use validation/CT-specific credits rather than defaults.
    """
    active = [unit for unit in units if unit.enabled]
    total_capital = sum(unit.capital_cost_usd for unit in active)
    per_m3_operating = sum(unit.operating_cost_usd_per_m3 for unit in active)
    per_m3_energy = sum(unit.energy_kwh_per_m3 for unit in active)
    lrv = sum(unit.virus_log_removal for unit in active)
    tthm = inputs.influent_tthm_ug_per_l + sum(
        unit.tthm_formation_ug_per_l for unit in active
    )
    haa5 = inputs.influent_haa5_ug_per_l + sum(
        unit.haa5_formation_ug_per_l for unit in active
    )
    annual_energy = per_m3_energy * inputs.annual_volume_m3
    annual_cost = total_capital + inputs.annual_volume_m3 * (
        per_m3_operating + per_m3_energy * inputs.electricity_cost_usd_per_kwh
    )

    conditions = {
        "virus": lrv >= inputs.minimum_virus_log_removal,
        "tthm": tthm <= inputs.tthm_limit_ug_per_l,
        "haa5": haa5 <= inputs.haa5_limit_ug_per_l,
    }
    failed = [name for name, passed in conditions.items() if not passed]
    explanation = (
        "All pathogen and disinfection-byproduct constraints are satisfied."
        if not failed
        else "Unsatisfied constraints: " + ", ".join(failed) + "."
    )

    return TreatmentEvaluation(
        configuration=tuple(unit.name for unit in active),
        feasible=not failed,
        total_annual_cost_usd=annual_cost,
        total_energy_kwh_per_year=annual_energy,
        virus_log_removal=lrv,
        finished_tthm_ug_per_l=tthm,
        finished_haa5_ug_per_l=haa5,
        constraint_explanation=explanation,
    )


def select_lowest_cost_feasible_train(
    candidate_trains: Iterable[Sequence[TreatmentUnit]],
    inputs: TreatmentOptimizationInputs,
) -> TreatmentEvaluation:
    """
    Select the feasible candidate with the smallest annualized total cost.

    This routine deliberately requires site-specific candidate performance
    values; it does not fabricate a universal optimal dose, UV fluence, GAC
    bed-life, or chlorine CT.
    """
    evaluated = [
        evaluate_treatment_configuration(candidate, inputs)
        for candidate in candidate_trains
    ]
    feasible = [result for result in evaluated if result.feasible]
    if not feasible:
        raise ValueError(
            "No candidate treatment configuration satisfies the stated constraints."
        )
    return min(feasible, key=lambda result: result.total_annual_cost_usd)


@dataclass(frozen=True)
class LifecycleBenefits:
    """
    All annual values are benefit units selected by the project sponsor.

    Suggested unit normalization:
      avoided_heat_j / J_reference,
      avoided_or_sequestered_co2e_kg / kgCO2e_reference,
      captured_pm_kg / kg_reference,
      habitat_service_unit / habitat_reference,
      useful_latent_heat_j / J_reference.

    The model makes weights and normalization visible rather than asserting
    false interchangeability across heat, carbon, air quality, and habitat.
    """

    annual_water_m3: Sequence[float]
    annual_latent_heat_j: Sequence[float]
    annual_co2e_kg: Sequence[float]
    annual_pm_capture_kg: Sequence[float]
    annual_shade_heat_avoided_j: Sequence[float]
    annual_habitat_units: Sequence[float]
    annual_cost_usd: Sequence[float]

    def __post_init__(self) -> None:
        series = (
            self.annual_water_m3,
            self.annual_latent_heat_j,
            self.annual_co2e_kg,
            self.annual_pm_capture_kg,
            self.annual_shade_heat_avoided_j,
            self.annual_habitat_units,
            self.annual_cost_usd,
        )
        if not all(len(item) == 20 for item in series):
            raise ValueError("A 20-year lifecycle requires exactly 20 annual values.")
        for values in series:
            for value in values:
                _require_finite_nonnegative("lifecycle value", value)


@dataclass(frozen=True)
class BenefitWeights:
    latent_heat_per_j: float
    co2e_per_kg: float
    particulate_per_kg: float
    shade_per_j: float
    habitat_per_unit: float
    cost_per_usd: float

    def __post_init__(self) -> None:
        for label, value in (
            ("latent_heat_per_j", self.latent_heat_per_j),
            ("co2e_per_kg", self.co2e_per_kg),
            ("particulate_per_kg", self.particulate_per_kg),
            ("shade_per_j", self.shade_per_j),
            ("habitat_per_unit", self.habitat_per_unit),
            ("cost_per_usd", self.cost_per_usd),
        ):
            _require_finite_nonnegative(label, value)


def latent_heat_per_m3() -> float:
    """
    The physical water-to-latent-heat efficiency ceiling for evaporation.

    1 m³ water corresponds approximately to 1000 kg, yielding:
        1000 kg * 2.45 MJ/kg = 2.45 GJ/m³
    before sensible-heat effects, non-evaporative losses, or mechanical energy.
    """
    return WATER_DENSITY_KG_PER_M3 * LATENT_HEAT_WATER_J_PER_KG


def discounted_total_benefit(
    lifecycle: LifecycleBenefits,
    weights: BenefitWeights,
    discount_rate: float,
) -> float:
    """
    Return the discounted, weighted lifecycle benefit net of annual cost.

    B_t = w_L L_t + w_C C_t + w_PM PM_t + w_S S_t + w_H H_t - w_cost Cost_t

    NPV_B(r) = sum_{t=1}^{20} B_t/(1+r)^t
    """
    if not isfinite(discount_rate) or discount_rate <= -1.0:
        raise ValueError("discount_rate must be finite and greater than -1.")

    total = 0.0
    for year in range(20):
        annual_benefit = (
            weights.latent_heat_per_j * lifecycle.annual_latent_heat_j[year]
            + weights.co2e_per_kg * lifecycle.annual_co2e_kg[year]
            + weights.particulate_per_kg * lifecycle.annual_pm_capture_kg[year]
            + weights.shade_per_j * lifecycle.annual_shade_heat_avoided_j[year]
            + weights.habitat_per_unit * lifecycle.annual_habitat_units[year]
            - weights.cost_per_usd * lifecycle.annual_cost_usd[year]
        )
        total += annual_benefit / ((1.0 + discount_rate) ** (year + 1))
    return total


def discounted_benefit_per_m3(
    lifecycle: LifecycleBenefits,
    weights: BenefitWeights,
    discount_rate: float,
) -> float:
    """
    Return discounted total-benefit-per-m³-water:

        R(r) = NPV_B(r) / sum_t[W_t/(1+r)^t].
    """
    denominator = sum(
        water / ((1.0 + discount_rate) ** (year + 1))
        for year, water in enumerate(lifecycle.annual_water_m3)
    )
    if denominator <= 0.0:
        raise ValueError("Discounted lifecycle water use must be greater than zero.")
    return discounted_total_benefit(lifecycle, weights, discount_rate) / denominator


def break_even_discount_rate(
    tree: LifecycleBenefits,
    cyboquatic_node: LifecycleBenefits,
    weights: BenefitWeights,
    lower_rate: float = 0.0,
    upper_rate: float = 1.0,
    iterations: int = 200,
) -> float | None:
    """
    Solve NPV_tree(r) - NPV_node(r) = 0 with bisection.

    Returns None when the supplied range has no sign change. The method is
    appropriate for a transparent sensitivity analysis; results depend on
    measured/validated service trajectories and the community-approved weights.
    """
    _require_finite_nonnegative("lower_rate", lower_rate)
    _require_positive("upper_rate", upper_rate)
    if lower_rate >= upper_rate:
        raise ValueError("lower_rate must be less than upper_rate.")
    if iterations < 1:
        raise ValueError("iterations must be at least one.")

    def difference(rate: float) -> float:
        return discounted_total_benefit(tree, weights, rate) - discounted_total_benefit(
            cyboquatic_node, weights, rate
        )

    left, right = lower_rate, upper_rate
    f_left, f_right = difference(left), difference(right)

    if f_left == 0.0:
        return left
    if f_right == 0.0:
        return right
    if f_left * f_right > 0.0:
        return None

    for _ in range(iterations):
        midpoint = (left + right) / 2.0
        f_midpoint = difference(midpoint)
        if abs(f_midpoint) < 1e-12:
            return midpoint
        if f_left * f_midpoint < 0.0:
            right, f_right = midpoint, f_midpoint
        else:
            left, f_left = midpoint, f_midpoint

    return (left + right) / 2.0


def cyboquatic_mechanical_evaporation_efficiency(
    evaporated_water_m3: float,
    useful_latent_heat_j: float,
    electricity_input_kwh: float,
) -> tuple[float, float]:
    """
    Return:
      1. Useful latent heat per m³ of water [J/m³]
      2. Water-to-electricity energy ratio [dimensionless]

    The first is comparable to canopy latent heat per m³. The second exposes
    the electrical burden of mechanical evaporation and must not be conflated
    with the thermodynamic latent heat transferred from the local environment.
    """
    _require_positive("evaporated_water_m3", evaporated_water_m3)
    _require_finite_nonnegative("useful_latent_heat_j", useful_latent_heat_j)
    _require_positive("electricity_input_kwh", electricity_input_kwh)

    useful_heat_per_m3 = useful_latent_heat_j / evaporated_water_m3
    electricity_input_j = electricity_input_kwh * 3_600_000.0
    energy_ratio = useful_latent_heat_j / electricity_input_j
    return useful_heat_per_m3, energy_ratio
