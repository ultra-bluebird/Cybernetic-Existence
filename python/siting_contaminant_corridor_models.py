from __future__ import annotations

from dataclasses import dataclass
from math import exp, isfinite
from typing import Iterable, Sequence


METRES_PER_MICROMETRE = 1_000_000.0
LITRES_PER_CUBIC_METRE = 1_000.0
CUBIC_METRES_PER_LITRE = 1.0 / LITRES_PER_CUBIC_METRE
WATER_DENSITY_KG_PER_M3 = 1_000.0


def _positive(name: str, value: float) -> None:
    if not isfinite(value) or value <= 0.0:
        raise ValueError(f"{name} must be finite and greater than zero.")


def _nonnegative(name: str, value: float) -> None:
    if not isfinite(value) or value < 0.0:
        raise ValueError(f"{name} must be finite and non-negative.")


def _bounded(name: str, value: float, lower: float, upper: float) -> None:
    if not isfinite(value) or not lower <= value <= upper:
        raise ValueError(f"{name} must be within [{lower}, {upper}].")


@dataclass(frozen=True)
class CoolingCandidateSite:
    """
    Candidate node location with aggregate demand and environmental constraints.

    resident_demand is an aggregate planning count or population-weighted
    demand score. It must not represent individually traceable location data.

    covered_demand_ids identifies spatial demand cells whose centroids or
    accessible-path distance lie within the 150 m effective-cooling radius.
    """

    site_name: str
    water_demand_m3_per_day: float
    water_available_m3_per_day: float
    aerosol_setback_available_m: float
    aerosol_setback_required_m: float
    equity_zone: str
    covered_demand_ids: frozenset[str]
    capital_cost_usd: float
    operating_cost_usd_per_day: float

    def __post_init__(self) -> None:
        for name, value in (
            ("water_demand_m3_per_day", self.water_demand_m3_per_day),
            ("water_available_m3_per_day", self.water_available_m3_per_day),
            ("aerosol_setback_available_m", self.aerosol_setback_available_m),
            ("aerosol_setback_required_m", self.aerosol_setback_required_m),
            ("capital_cost_usd", self.capital_cost_usd),
            ("operating_cost_usd_per_day", self.operating_cost_usd_per_day),
        ):
            _nonnegative(name, value)

        if not self.site_name.strip():
            raise ValueError("site_name must not be empty.")
        if not self.equity_zone.strip():
            raise ValueError("equity_zone must not be empty.")

    @property
    def environmentally_eligible(self) -> bool:
        return (
            self.water_available_m3_per_day >= self.water_demand_m3_per_day
            and self.aerosol_setback_available_m >= self.aerosol_setback_required_m
        )


@dataclass(frozen=True)
class DemandCell:
    """
    Aggregate 150 m service-area demand.

    equity_weight can reflect a community-governed vulnerability or heat-burden
    weighting rule. It cannot be used to restrict access to basic heat relief.
    """

    demand_id: str
    resident_demand: float
    equity_weight: float

    def __post_init__(self) -> None:
        _nonnegative("resident_demand", self.resident_demand)
        _nonnegative("equity_weight", self.equity_weight)
        if not self.demand_id.strip():
            raise ValueError("demand_id must not be empty.")

    @property
    def weighted_demand(self) -> float:
        return self.resident_demand * self.equity_weight


@dataclass(frozen=True)
class EquityDistributionRule:
    """
    Minimum node allocation by equity zone.

    Examples:
      {"high_heat_burden": 3, "other": 1}

    The rule encodes a service floor. It operates before optional marginal
    benefit maximization, preventing a pure coverage objective from excluding
    communities that need durable heat-relief access.
    """

    minimum_nodes_by_zone: dict[str, int]

    def __post_init__(self) -> None:
        for zone, count in self.minimum_nodes_by_zone.items():
            if not zone.strip():
                raise ValueError("Equity-zone names must not be empty.")
            if count < 0:
                raise ValueError("Minimum node counts must be non-negative.")


@dataclass(frozen=True)
class CoolingCoveragePlan:
    selected_sites: tuple[str, ...]
    selected_count: int
    total_water_demand_m3_per_day: float
    unweighted_covered_demand: float
    equity_weighted_covered_demand: float
    covered_demand_ids: frozenset[str]
    nodes_by_equity_zone: dict[str, int]
    all_constraints_satisfied: bool


def _covered_scores(
    selected: Sequence[CoolingCandidateSite],
    demand_cells: dict[str, DemandCell],
) -> tuple[frozenset[str], float, float]:
    covered_ids = frozenset().union(
        *(site.covered_demand_ids for site in selected)
    ) if selected else frozenset()

    missing = covered_ids.difference(demand_cells)
    if missing:
        raise ValueError(
            "Candidate sites reference demand IDs absent from demand_cells: "
            + ", ".join(sorted(missing))
        )

    unweighted = sum(demand_cells[cell_id].resident_demand for cell_id in covered_ids)
    weighted = sum(demand_cells[cell_id].weighted_demand for cell_id in covered_ids)
    return covered_ids, unweighted, weighted


def maximum_coverage_plan(
    candidates: Sequence[CoolingCandidateSite],
    demand_cells: Sequence[DemandCell],
    water_budget_m3_per_day: float,
    max_nodes: int,
    equity_rule: EquityDistributionRule,
) -> CoolingCoveragePlan:
    """
    Greedy constrained maximum-coverage solver.

    Formal objective:

      maximize sum_d q_d * I[d covered]

      subject to:
        sum_s x_s <= K
        sum_s x_s * water_s <= W_budget
        x_s = 0 for water- or setback-ineligible sites
        sum_{s in zone z} x_s >= floor_z

    The greedy implementation is transparent and scalable. For exact optimality
    at larger scale, encode these constraints as a mixed-integer program.
    """
    _nonnegative("water_budget_m3_per_day", water_budget_m3_per_day)
    if max_nodes < 0:
        raise ValueError("max_nodes must be non-negative.")

    demand_map = {cell.demand_id: cell for cell in demand_cells}
    if len(demand_map) != len(demand_cells):
        raise ValueError("demand_id values must be unique.")

    eligible = [site for site in candidates if site.environmentally_eligible]
    selected: list[CoolingCandidateSite] = []
    selected_names: set[str] = set()
    water_used = 0.0

    def can_add(site: CoolingCandidateSite) -> bool:
        return (
            site.site_name not in selected_names
            and len(selected) < max_nodes
            and water_used + site.water_demand_m3_per_day <= water_budget_m3_per_day
        )

    def add(site: CoolingCandidateSite) -> None:
        nonlocal water_used
        selected.append(site)
        selected_names.add(site.site_name)
        water_used += site.water_demand_m3_per_day

    for zone, minimum in equity_rule.minimum_nodes_by_zone.items():
        for _ in range(minimum):
            _, _, current_weighted = _covered_scores(selected, demand_map)
            options = [
                site
                for site in eligible
                if site.equity_zone == zone and can_add(site)
            ]
            if not options:
                break

            def zone_gain(site: CoolingCandidateSite) -> float:
                prospective = selected + [site]
                _, _, prospective_weighted = _covered_scores(prospective, demand_map)
                return prospective_weighted - current_weighted

            add(max(options, key=zone_gain))

    while len(selected) < max_nodes:
        _, _, current_weighted = _covered_scores(selected, demand_map)
        options = [site for site in eligible if can_add(site)]
        if not options:
            break

        def marginal_gain_per_water(site: CoolingCandidateSite) -> float:
            prospective = selected + [site]
            _, _, prospective_weighted = _covered_scores(prospective, demand_map)
            gain = prospective_weighted - current_weighted
            return gain / max(site.water_demand_m3_per_day, 1e-12)

        best = max(options, key=marginal_gain_per_water)
        before = current_weighted
        prospective = selected + [best]
        _, _, after = _covered_scores(prospective, demand_map)
        if after <= before:
            break
        add(best)

    covered_ids, unweighted, weighted = _covered_scores(selected, demand_map)
    counts: dict[str, int] = {}
    for site in selected:
        counts[site.equity_zone] = counts.get(site.equity_zone, 0) + 1

    floor_ok = all(
        counts.get(zone, 0) >= minimum
        for zone, minimum in equity_rule.minimum_nodes_by_zone.items()
    )

    return CoolingCoveragePlan(
        selected_sites=tuple(site.site_name for site in selected),
        selected_count=len(selected),
        total_water_demand_m3_per_day=water_used,
        unweighted_covered_demand=unweighted,
        equity_weighted_covered_demand=weighted,
        covered_demand_ids=covered_ids,
        nodes_by_equity_zone=counts,
        all_constraints_satisfied=floor_ok,
    )


@dataclass(frozen=True)
class DiminishingReturnsCurve:
    """
    Empirical marginal-benefit curve for the k-th node.

    marginal_benefit[k-1] is the estimated newly covered, equity-weighted
    cooling benefit added by node k after prior coverage overlap is accounted
    for using Phoenix heat-distribution data.
    """

    marginal_benefit: Sequence[float]

    def __post_init__(self) -> None:
        if not self.marginal_benefit:
            raise ValueError("marginal_benefit must not be empty.")
        previous = float("inf")
        for benefit in self.marginal_benefit:
            _nonnegative("marginal_benefit value", benefit)
            if benefit > previous:
                raise ValueError(
                    "marginal_benefit must be non-increasing for a "
                    "diminishing-returns curve."
                )
            previous = benefit


def optimal_node_count_for_water_budget(
    curve: DiminishingReturnsCurve,
    average_water_m3_per_day_per_node: float,
    water_budget_m3_per_day: float,
    minimum_marginal_benefit: float = 0.0,
) -> int:
    """
    Select K from the empirical diminishing-returns curve:

      K_water = floor(W_budget / w_node)

      K* = max k <= K_water such that MB_k >= B_min.

    The output is an economic/ecological operating optimum under an explicit
    minimum marginal benefit threshold, not an arbitrary maximization of node
    count.
    """
    _positive("average_water_m3_per_day_per_node", average_water_m3_per_day_per_node)
    _nonnegative("water_budget_m3_per_day", water_budget_m3_per_day)
    _nonnegative("minimum_marginal_benefit", minimum_marginal_benefit)

    water_limited_count = int(
        water_budget_m3_per_day // average_water_m3_per_day_per_node
    )
    upper = min(water_limited_count, len(curve.marginal_benefit))

    selected = 0
    for index in range(upper):
        if curve.marginal_benefit[index] < minimum_marginal_benefit:
            break
        selected = index + 1
    return selected


@dataclass(frozen=True)
class THMDropletInputs:
    """
    Semi-volatile contaminant fate for fully evaporating droplets.

    initial_thm_ug_per_l:
        Parent-water concentration for the particular TTHM species. A total
        TTHM value should not be assigned to a single Henry constant; evaluate
        chloroform, bromodichloromethane, dibromochloromethane, and bromoform
        separately, then sum masses only after species-specific calculation.

    dimensionless_henry_air_water:
        H_aw = C_air / C_water at equilibrium in compatible concentration units.

    air_mixing_volume_m3:
        Effective 10 m downwind plume-control volume, derived from measured or
        validated dispersion geometry. It is not assumed to be a fixed sphere.
    """

    droplet_diameter_um: float
    initial_thm_ug_per_l: float
    dimensionless_henry_air_water: float
    air_mixing_volume_m3: float
    entrainment_air_to_water_volume_ratio: float
    evaporation_completion_fraction: float = 1.0

    def __post_init__(self) -> None:
        for name, value in (
            ("droplet_diameter_um", self.droplet_diameter_um),
            ("initial_thm_ug_per_l", self.initial_thm_ug_per_l),
            ("dimensionless_henry_air_water", self.dimensionless_henry_air_water),
            ("air_mixing_volume_m3", self.air_mixing_volume_m3),
            (
                "entrainment_air_to_water_volume_ratio",
                self.entrainment_air_to_water_volume_ratio,
            ),
            ("evaporation_completion_fraction", self.evaporation_completion_fraction),
        ):
            _nonnegative(name, value)

        _positive("droplet_diameter_um", self.droplet_diameter_um)
        _positive("air_mixing_volume_m3", self.air_mixing_volume_m3)
        _bounded("evaporation_completion_fraction", self.evaporation_completion_fraction, 0.0, 1.0)


@dataclass(frozen=True)
class THMDropletFateResult:
    initial_droplet_volume_l: float
    initial_thm_mass_ug: float
    equilibrium_vapor_fraction: float
    vapor_transferred_mass_ug: float
    residual_liquid_mass_ug: float
    downwind_incremental_air_concentration_ug_per_m3: float


def thm_droplet_fate(inputs: THMDropletInputs) -> THMDropletFateResult:
    """
    Single-droplet equilibrium screening model.

    Henry partition relation:
      C_air = H_aw * C_water

    With an entrained-air-to-water volume ratio R = V_air/V_water, the mass
    fraction in air at equilibrium is:

      f_air = H_aw * R / (1 + H_aw * R)

    The result represents equilibrium partitioning coupled to full evaporation
    completion. It should be bounded by a measured mass-transfer timescale and
    replaced by a plume-resolved model for exposure assessment.
    """
    radius_m = inputs.droplet_diameter_um / (2.0 * METRES_PER_MICROMETRE)
    volume_m3 = (4.0 / 3.0) * 3.141592653589793 * radius_m**3
    volume_l = volume_m3 * LITRES_PER_CUBIC_METRE
    initial_mass_ug = inputs.initial_thm_ug_per_l * volume_l

    air_fraction = (
        inputs.dimensionless_henry_air_water
        * inputs.entrainment_air_to_water_volume_ratio
        / (
            1.0
            + inputs.dimensionless_henry_air_water
            * inputs.entrainment_air_to_water_volume_ratio
        )
    )
    vapor_mass = initial_mass_ug * air_fraction * inputs.evaporation_completion_fraction
    residual_mass = initial_mass_ug - vapor_mass
    air_concentration = vapor_mass / inputs.air_mixing_volume_m3

    return THMDropletFateResult(
        initial_droplet_volume_l=volume_l,
        initial_thm_mass_ug=initial_mass_ug,
        equilibrium_vapor_fraction=air_fraction,
        vapor_transferred_mass_ug=vapor_mass,
        residual_liquid_mass_ug=residual_mass,
        downwind_incremental_air_concentration_ug_per_m3=air_concentration,
    )


@dataclass(frozen=True)
class CorridorEdgeContext:
    """
    Land-use-adjusted edge-effect parameters.

    base_edge_width_m is estimated from species-specific field observations.
    The multiplier captures the surrounding stressor context: impervious heat,
    night lighting, traffic, domestic predators, invasive propagule pressure,
    irrigation discontinuity, noise, and other measured edge pressures.
    """

    target_species: str
    minimum_viable_core_width_m: float
    base_edge_width_m: float
    land_use_multiplier: float
    heat_stress_multiplier: float = 1.0
    invasive_pressure_multiplier: float = 1.0
    traffic_noise_multiplier: float = 1.0

    def __post_init__(self) -> None:
        if not self.target_species.strip():
            raise ValueError("target_species must not be empty.")
        for name, value in (
            ("minimum_viable_core_width_m", self.minimum_viable_core_width_m),
            ("base_edge_width_m", self.base_edge_width_m),
            ("land_use_multiplier", self.land_use_multiplier),
            ("heat_stress_multiplier", self.heat_stress_multiplier),
            (
                "invasive_pressure_multiplier",
                self.invasive_pressure_multiplier,
            ),
            ("traffic_noise_multiplier", self.traffic_noise_multiplier),
        ):
            _nonnegative(name, value)

        _positive("minimum_viable_core_width_m", self.minimum_viable_core_width_m)
        _positive("base_edge_width_m", self.base_edge_width_m)
        _positive("land_use_multiplier", self.land_use_multiplier)
        _positive("heat_stress_multiplier", self.heat_stress_multiplier)
        _positive("invasive_pressure_multiplier", self.invasive_pressure_multiplier)
        _positive("traffic_noise_multiplier", self.traffic_noise_multiplier)


@dataclass(frozen=True)
class CorridorWidthResult:
    effective_edge_width_m: float
    required_total_width_m: float
    resulting_core_width_m: float


def required_corridor_width(context: CorridorEdgeContext) -> CorridorWidthResult:
    """
    Effective edge width:

      W_edge = W_edge,base * L_landuse * L_heat * L_invasive * L_traffic

    Required total width:

      W_total = W_core,min + 2*W_edge
    """
    effective_edge = (
        context.base_edge_width_m
        * context.land_use_multiplier
        * context.heat_stress_multiplier
        * context.invasive_pressure_multiplier
        * context.traffic_noise_multiplier
    )
    total_width = context.minimum_viable_core_width_m + 2.0 * effective_edge
    resulting_core = total_width - 2.0 * effective_edge

    return CorridorWidthResult(
        effective_edge_width_m=effective_edge,
        required_total_width_m=total_width,
        resulting_core_width_m=resulting_core,
    )
