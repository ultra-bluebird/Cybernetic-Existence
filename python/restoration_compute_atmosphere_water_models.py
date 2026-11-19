from __future__ import annotations

from dataclasses import dataclass
from math import ceil, isfinite, sqrt
from statistics import NormalDist
from typing import Sequence


HOURS_PER_YEAR = 8_760.0
KWH_PER_MWH = 1_000.0
KG_PER_METRIC_TONNE = 1_000.0
STANDARD_NORMAL = NormalDist()


def _positive(name: str, value: float) -> None:
    if not isfinite(value) or value <= 0.0:
        raise ValueError(f"{name} must be finite and greater than zero.")


def _nonnegative(name: str, value: float) -> None:
    if not isfinite(value) or value < 0.0:
        raise ValueError(f"{name} must be finite and non-negative.")


def _probability(name: str, value: float) -> None:
    if not isfinite(value) or not 0.0 < value < 1.0:
        raise ValueError(f"{name} must be strictly between zero and one.")


@dataclass(frozen=True)
class AIWorkloadCarbonInputs:
    """
    Carbon-accounting inputs for one auditable AI workload boundary.

    Hardware embodied carbon is allocated by an explicit workload lifetime
    fraction, rather than treating a shared accelerator as fully embodied by
    one model run.

    The grid factor should normally be time-resolved marginal carbon intensity
    when the study asks whether the added workload causes additional emissions.
    Annual average intensity can be reported in parallel as an attributional
    accounting view.
    """

    accelerator_embodied_kgco2e: float
    host_embodied_kgco2e: float
    storage_embodied_kgco2e: float
    network_embodied_kgco2e: float
    workload_hardware_lifetime_hours: float
    workload_runtime_hours: float
    accelerator_power_kw: float
    host_power_kw: float
    storage_power_kw: float
    cooling_power_usage_effectiveness: float
    average_grid_kgco2e_per_kwh: float
    marginal_grid_kgco2e_per_kwh: float
    network_transfer_gb: float
    network_kwh_per_gb: float
    operational_water_l_per_kwh: float = 0.0
    water_treatment_kgco2e_per_l: float = 0.0

    def __post_init__(self) -> None:
        for name, value in (
            ("accelerator_embodied_kgco2e", self.accelerator_embodied_kgco2e),
            ("host_embodied_kgco2e", self.host_embodied_kgco2e),
            ("storage_embodied_kgco2e", self.storage_embodied_kgco2e),
            ("network_embodied_kgco2e", self.network_embodied_kgco2e),
            ("workload_hardware_lifetime_hours", self.workload_hardware_lifetime_hours),
            ("workload_runtime_hours", self.workload_runtime_hours),
            ("accelerator_power_kw", self.accelerator_power_kw),
            ("host_power_kw", self.host_power_kw),
            ("storage_power_kw", self.storage_power_kw),
            (
                "cooling_power_usage_effectiveness",
                self.cooling_power_usage_effectiveness,
            ),
            ("average_grid_kgco2e_per_kwh", self.average_grid_kgco2e_per_kwh),
            ("marginal_grid_kgco2e_per_kwh", self.marginal_grid_kgco2e_per_kwh),
            ("network_transfer_gb", self.network_transfer_gb),
            ("network_kwh_per_gb", self.network_kwh_per_gb),
            ("operational_water_l_per_kwh", self.operational_water_l_per_kwh),
            ("water_treatment_kgco2e_per_l", self.water_treatment_kgco2e_per_l),
        ):
            _nonnegative(name, value)

        _positive("workload_hardware_lifetime_hours", self.workload_hardware_lifetime_hours)
        _positive("workload_runtime_hours", self.workload_runtime_hours)

        if self.workload_runtime_hours > self.workload_hardware_lifetime_hours:
            raise ValueError(
                "workload_runtime_hours cannot exceed workload_hardware_lifetime_hours."
            )
        if self.cooling_power_usage_effectiveness < 1.0:
            raise ValueError(
                "cooling_power_usage_effectiveness must be at least one."
            )


@dataclass(frozen=True)
class RestorationBenefitInputs:
    """
    Benefits must be additional, counterfactual, and monitored.

    additional_sequestered_kgco2e:
        Carbon removal or avoided emissions attributable to AI-supported action
        beyond the verified non-AI baseline.

    water_saved_m3 and water_carbon_intensity:
        Water benefits are converted to carbon-equivalent only when the avoided
        treatment, delivery, pumping, or scarcity-related carbon factor is
        documented. Water volume is always retained as a separate metric.
    """

    additional_sequestered_kgco2e: float
    avoided_emissions_kgco2e: float
    water_saved_m3: float
    water_system_kgco2e_per_m3: float
    restoration_monitoring_kgco2e: float = 0.0
    restoration_implementation_kgco2e: float = 0.0

    def __post_init__(self) -> None:
        for name, value in (
            ("additional_sequestered_kgco2e", self.additional_sequestered_kgco2e),
            ("avoided_emissions_kgco2e", self.avoided_emissions_kgco2e),
            ("water_saved_m3", self.water_saved_m3),
            ("water_system_kgco2e_per_m3", self.water_system_kgco2e_per_m3),
            ("restoration_monitoring_kgco2e", self.restoration_monitoring_kgco2e),
            (
                "restoration_implementation_kgco2e",
                self.restoration_implementation_kgco2e,
            ),
        ):
            _nonnegative(name, value)


@dataclass(frozen=True)
class CarbonLedgerResult:
    embodied_kgco2e: float
    information_technology_kwh: float
    cooling_kwh: float
    network_kwh: float
    total_operational_kwh: float
    operational_average_kgco2e: float
    operational_marginal_kgco2e: float
    water_related_kgco2e: float
    total_average_kgco2e: float
    total_marginal_kgco2e: float
    verified_restoration_benefit_kgco2e: float
    net_benefit_average_kgco2e: float
    net_benefit_marginal_kgco2e: float
    avoided_water_m3: float
    exceeds_footprint_average: bool
    exceeds_footprint_marginal: bool


def calculate_ai_restoration_carbon_ledger(
    workload: AIWorkloadCarbonInputs,
    benefit: RestorationBenefitInputs,
) -> CarbonLedgerResult:
    """
    Carbon boundary:

      C_embodied = C_hardware * runtime/lifetime
      E_IT = runtime * (P_accelerator + P_host + P_storage)
      E_cooling = E_IT * (PUE - 1)
      E_network = GB * kWh/GB
      C_operational = (E_IT + E_cooling + E_network) * CI_grid
      C_water = E_operational * L/kWh * kgCO2e/L
      C_total = C_embodied + C_operational + C_water

    Restoration benefit is held to an additionality boundary:

      B = sequestration_additional + avoided_emissions +
          water_saved * water_system_factor -
          restoration_implementation -
          restoration_monitoring
    """
    embodied_total = (
        workload.accelerator_embodied_kgco2e
        + workload.host_embodied_kgco2e
        + workload.storage_embodied_kgco2e
        + workload.network_embodied_kgco2e
    )
    embodied_allocated = embodied_total * (
        workload.workload_runtime_hours / workload.workload_hardware_lifetime_hours
    )

    it_power_kw = (
        workload.accelerator_power_kw
        + workload.host_power_kw
        + workload.storage_power_kw
    )
    it_kwh = it_power_kw * workload.workload_runtime_hours
    cooling_kwh = it_kwh * (workload.cooling_power_usage_effectiveness - 1.0)
    network_kwh = workload.network_transfer_gb * workload.network_kwh_per_gb
    total_kwh = it_kwh + cooling_kwh + network_kwh

    average_operational = total_kwh * workload.average_grid_kgco2e_per_kwh
    marginal_operational = total_kwh * workload.marginal_grid_kgco2e_per_kwh
    water_related = (
        total_kwh
        * workload.operational_water_l_per_kwh
        * workload.water_treatment_kgco2e_per_l
    )

    total_average = embodied_allocated + average_operational + water_related
    total_marginal = embodied_allocated + marginal_operational + water_related

    verified_benefit = (
        benefit.additional_sequestered_kgco2e
        + benefit.avoided_emissions_kgco2e
        + benefit.water_saved_m3 * benefit.water_system_kgco2e_per_m3
        - benefit.restoration_monitoring_kgco2e
        - benefit.restoration_implementation_kgco2e
    )

    return CarbonLedgerResult(
        embodied_kgco2e=embodied_allocated,
        information_technology_kwh=it_kwh,
        cooling_kwh=cooling_kwh,
        network_kwh=network_kwh,
        total_operational_kwh=total_kwh,
        operational_average_kgco2e=average_operational,
        operational_marginal_kgco2e=marginal_operational,
        water_related_kgco2e=water_related,
        total_average_kgco2e=total_average,
        total_marginal_kgco2e=total_marginal,
        verified_restoration_benefit_kgco2e=verified_benefit,
        net_benefit_average_kgco2e=verified_benefit - total_average,
        net_benefit_marginal_kgco2e=verified_benefit - total_marginal,
        avoided_water_m3=benefit.water_saved_m3,
        exceeds_footprint_average=verified_benefit > total_average,
        exceeds_footprint_marginal=verified_benefit > total_marginal,
    )


@dataclass(frozen=True)
class BoundaryLayerPowerInputs:
    """
    Difference-in-means design for a paired intervention/control comparison.

    sigma_h_m:
        Standard deviation of daily, quality-controlled paired h_BL differences,
        not the raw within-day ceilometer sample standard deviation.

    rho_lag_1:
        Lag-one autocorrelation of the daily paired difference series. The
        effective sample size approximation is:

          N_eff = N * (1-rho)/(1+rho)

        for a first-order autoregressive dependence structure.

    locations:
        Independent or adequately spatially separated matched locations.
        Spatial correlation must be included through design_effect if locations
        are not independent.
    """

    detectable_change_m: float
    sigma_h_m: float
    alpha: float
    beta: float
    rho_lag_1: float
    locations: int
    spatial_design_effect: float = 1.0

    def __post_init__(self) -> None:
        _positive("detectable_change_m", self.detectable_change_m)
        _positive("sigma_h_m", self.sigma_h_m)
        _probability("alpha", self.alpha)
        _probability("beta", self.beta)
        if not isfinite(self.rho_lag_1) or not -1.0 < self.rho_lag_1 < 1.0:
            raise ValueError("rho_lag_1 must be strictly between -1 and 1.")
        if self.locations < 1:
            raise ValueError("locations must be at least one.")
        if self.spatial_design_effect < 1.0:
            raise ValueError("spatial_design_effect must be at least one.")


@dataclass(frozen=True)
class BoundaryLayerPowerResult:
    standardized_effect_size: float
    effective_independent_observations_required: int
    temporal_autocorrelation_inflation: float
    total_location_days_required: int
    calendar_days_per_location_required: int
    minimum_detectable_change_m: float


def required_boundary_layer_observations(
    inputs: BoundaryLayerPowerInputs,
) -> BoundaryLayerPowerResult:
    """
    Two-sided normal-approximation power analysis:

      N_eff = [(z_(1-alpha/2) + z_(1-beta)) * sigma / Delta]^2

      N_raw = N_eff * (1+rho)/(1-rho) * design_effect

      days_per_location = ceil(N_raw / locations)

    This is suitable for preliminary planning. A final study should use a
    hierarchical repeated-measures simulation with observed seasonal,
    meteorological, instrument, and spatial covariance.
    """
    z_alpha = STANDARD_NORMAL.inv_cdf(1.0 - inputs.alpha / 2.0)
    z_beta = STANDARD_NORMAL.inv_cdf(1.0 - inputs.beta)
    standardized_effect = inputs.detectable_change_m / inputs.sigma_h_m
    independent_required = ceil(((z_alpha + z_beta) / standardized_effect) ** 2)
    autocorrelation_inflation = (
        (1.0 + inputs.rho_lag_1) / (1.0 - inputs.rho_lag_1)
    )
    total_location_days = ceil(
        independent_required
        * autocorrelation_inflation
        * inputs.spatial_design_effect
    )
    days_per_location = ceil(total_location_days / inputs.locations)

    minimum_detectable_change = (
        (z_alpha + z_beta)
        * inputs.sigma_h_m
        * sqrt(
            autocorrelation_inflation
            * inputs.spatial_design_effect
            / total_location_days
        )
    )

    return BoundaryLayerPowerResult(
        standardized_effect_size=standardized_effect,
        effective_independent_observations_required=independent_required,
        temporal_autocorrelation_inflation=autocorrelation_inflation,
        total_location_days_required=total_location_days,
        calendar_days_per_location_required=days_per_location,
        minimum_detectable_change_m=minimum_detectable_change,
    )


@dataclass(frozen=True)
class ChickWatsonInputs:
    """
    Temperature-adjusted Chick-Watson model:

      log10(N/N0) = -k20 * theta^(T-20) * C_ox^n * t

    k20 must match the disinfectant, pathogen state, water matrix, pH,
    measurement endpoint, and oxidant concentration unit used by C_ox.

    n defaults to 1.0, reproducing the requested first-order oxidant form.
    """

    k20_log10_per_mg_l_min: float
    theta: float
    temperature_c: float
    oxidant_mg_per_l: float
    target_log10_inactivation: float
    concentration_exponent: float = 1.0

    def __post_init__(self) -> None:
        _positive("k20_log10_per_mg_l_min", self.k20_log10_per_mg_l_min)
        _positive("theta", self.theta)
        _positive("oxidant_mg_per_l", self.oxidant_mg_per_l)
        _positive("target_log10_inactivation", self.target_log10_inactivation)
        _positive("concentration_exponent", self.concentration_exponent)
        if not isfinite(self.temperature_c):
            raise ValueError("temperature_c must be finite.")


@dataclass(frozen=True)
class DisinfectionContactResult:
    temperature_adjusted_k: float
    log10_inactivation_per_minute: float
    required_contact_time_minutes: float
    required_ct_mg_min_per_l: float
    storage_residence_time_minutes: float | None
    residence_time_satisfies_model: bool | None


def chick_watson_contact_time(
    inputs: ChickWatsonInputs,
    storage_residence_time_minutes: float | None = None,
) -> DisinfectionContactResult:
    """
    Solve the temperature-corrected Chick-Watson equation for time:

      t_required =
        L_target / [k20 * theta^(T-20) * C_ox^n]

    The resulting value is a modeling calculation, not a compliance credit.
    Hydraulic short-circuiting, residual decay, demand, pH, biofilm shielding,
    temperature gradients, and organism attachment all require independent
    validation in a reclaimed-water storage system.
    """
    if storage_residence_time_minutes is not None:
        _positive("storage_residence_time_minutes", storage_residence_time_minutes)

    temperature_adjusted_k = (
        inputs.k20_log10_per_mg_l_min
        * (inputs.theta ** (inputs.temperature_c - 20.0))
    )
    inactivation_rate = (
        temperature_adjusted_k
        * (inputs.oxidant_mg_per_l ** inputs.concentration_exponent)
    )
    required_time = inputs.target_log10_inactivation / inactivation_rate
    required_ct = inputs.oxidant_mg_per_l * required_time
    satisfies = (
        None
        if storage_residence_time_minutes is None
        else storage_residence_time_minutes >= required_time
    )

    return DisinfectionContactResult(
        temperature_adjusted_k=temperature_adjusted_k,
        log10_inactivation_per_minute=inactivation_rate,
        required_contact_time_minutes=required_time,
        required_ct_mg_min_per_l=required_ct,
        storage_residence_time_minutes=storage_residence_time_minutes,
        residence_time_satisfies_model=satisfies,
    )
