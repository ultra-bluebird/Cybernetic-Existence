from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, Iterable, Mapping, Sequence

import pulp


@dataclass(frozen=True)
class DemandGroup:
    zone: str
    group: str
    population: int
    heat_burden: float
    age_vulnerability: float
    income_vulnerability: float
    health_vulnerability: float
    opt_in_augmentation_service_need: float
    maximum_accessible_travel_minutes: float
    minimum_service_floor: float = 0.80


@dataclass(frozen=True)
class CoolingSite:
    site: str
    capacity: int
    activation_cost: float
    accessibility_certified: bool
    service_quality: float
    available: bool = True


def clamp_unit(value: float) -> float:
    return max(0.0, min(1.0, float(value)))


def vulnerability_weight(group: DemandGroup) -> float:
    return clamp_unit(
        0.34 * clamp_unit(group.heat_burden)
        + 0.22 * clamp_unit(group.age_vulnerability)
        + 0.18 * clamp_unit(group.income_vulnerability)
        + 0.18 * clamp_unit(group.health_vulnerability)
        + 0.08 * clamp_unit(group.opt_in_augmentation_service_need)
    )


def allocate_cooling_centers(
    groups: Sequence[DemandGroup],
    sites: Sequence[CoolingSite],
    accessible_travel_minutes: Mapping[tuple[str, str], float],
    budget: float,
    maximum_open_sites: int,
    fairness_multiplier: float = 1.25,
    tolerance: float = 0.02,
) -> dict[str, object]:
    if budget < 0.0 or maximum_open_sites < 0:
        raise ValueError("budget and maximum_open_sites must be non-negative")
    if not groups or not sites:
        raise ValueError("at least one demand group and one candidate site are required")
    if fairness_multiplier < 1.0 or tolerance < 0.0:
        raise ValueError("fairness_multiplier must be at least 1 and tolerance non-negative")

    valid_sites = [
        site for site in sites
        if site.available and site.accessibility_certified and site.capacity > 0
    ]
    if not valid_sites:
        raise ValueError("no available accessibility-certified cooling sites")

    group_keys = [(group.zone, group.group) for group in groups]
    site_names = [site.site for site in valid_sites]
    site_by_name = {site.site: site for site in valid_sites}
    group_by_key = {(group.zone, group.group): group for group in groups}

    eligible_pairs: list[tuple[tuple[str, str], str]] = []
    for key, group in group_by_key.items():
        for site_name in site_names:
            travel = accessible_travel_minutes.get((group.zone, site_name))
            if travel is None:
                continue
            if 0.0 <= travel <= group.maximum_accessible_travel_minutes:
                eligible_pairs.append((key, site_name))

    problem = pulp.LpProblem("equitable_cooling_center_allocation", pulp.LpMinimize)

    activate = pulp.LpVariable.dicts("activate", site_names, cat=pulp.LpBinary)
    assign = pulp.LpVariable.dicts(
        "assign",
        eligible_pairs,
        lowBound=0,
        cat=pulp.LpContinuous,
    )
    unmet = pulp.LpVariable.dicts("unmet", group_keys, lowBound=0, cat=pulp.LpContinuous)
    burden = pulp.LpVariable.dicts("burden", group_keys, lowBound=0, upBound=1, cat=pulp.LpContinuous)
    max_burden = pulp.LpVariable("max_burden", lowBound=0, upBound=1, cat=pulp.LpContinuous)
    mean_burden = pulp.LpVariable("mean_burden", lowBound=0, upBound=1, cat=pulp.LpContinuous)

    problem += max_burden

    problem += (
        pulp.lpSum(site_by_name[name].activation_cost * activate[name] for name in site_names)
        <= budget
    )
    problem += pulp.lpSum(activate[name] for name in site_names) <= maximum_open_sites

    for site_name in site_names:
        problem += (
            pulp.lpSum(assign[key, site_name] for key, candidate in eligible_pairs if candidate == site_name)
            <= site_by_name[site_name].capacity * activate[site_name]
        )

    total_population = sum(max(0, group.population) for group in groups)
    if total_population <= 0:
        raise ValueError("total demand population must be greater than zero")

    for key, group in group_by_key.items():
        assignments = [
            assign[key, site_name]
            for candidate_key, site_name in eligible_pairs
            if candidate_key == key
        ]
        assigned_total = pulp.lpSum(assignments)
        problem += assigned_total + unmet[key] == group.population

        required_floor = clamp_unit(group.minimum_service_floor) * group.population
        problem += assigned_total >= required_floor

        weighted_travel = pulp.lpSum(
            assign[key, site_name]
            * accessible_travel_minutes[(group.zone, site_name)]
            / max(group.maximum_accessible_travel_minutes, 1.0)
            for candidate_key, site_name in eligible_pairs
            if candidate_key == key
        )

        weighted_quality = pulp.lpSum(
            assign[key, site_name] * site_by_name[site_name].service_quality
            for candidate_key, site_name in eligible_pairs
            if candidate_key == key
        )

        population = max(group.population, 1)
        coverage_gap = unmet[key] / population
        quality_gap = 1.0 - weighted_quality / population
        travel_component = weighted_travel / population

        problem += burden[key] == vulnerability_weight(group) * (
            0.55 * travel_component
            + 0.25 * coverage_gap
            + 0.20 * quality_gap
        )
        problem += burden[key] <= max_burden

    problem += mean_burden == (
        pulp.lpSum(burden[key] * group_by_key[key].population for key in group_keys)
        / total_population
    )

    for key in group_keys:
        problem += burden[key] <= fairness_multiplier * mean_burden + tolerance

    solver = pulp.PULP_CBC_CMD(msg=False)
    status = problem.solve(solver)

    if pulp.LpStatus[status] != "Optimal":
        return {
            "status": pulp.LpStatus[status],
            "selected_sites": [],
            "assignments": [],
            "unmet_demand": [],
            "message": (
                "No feasible allocation satisfies the published accessibility, "
                "capacity, minimum-service, budget, and fairness constraints."
            ),
        }

    selected_sites = [
        site_name for site_name in site_names
        if pulp.value(activate[site_name]) >= 0.5
    ]

    assignments = [
        {
            "zone": key[0],
            "group": key[1],
            "site": site_name,
            "assigned_population": round(float(pulp.value(assign[key, site_name])), 3),
            "travel_minutes": accessible_travel_minutes[(key[0], site_name)],
        }
        for key, site_name in eligible_pairs
        if pulp.value(assign[key, site_name]) > 0.001
    ]

    unmet_demand = [
        {
            "zone": key[0],
            "group": key[1],
            "unmet_population": round(float(pulp.value(unmet[key])), 3),
            "normalized_burden": round(float(pulp.value(burden[key])), 6),
        }
        for key in group_keys
    ]

    return {
        "status": pulp.LpStatus[status],
        "selected_sites": selected_sites,
        "assignments": assignments,
        "unmet_demand": unmet_demand,
        "maximum_normalized_burden": round(float(pulp.value(max_burden)), 6),
        "mean_normalized_burden": round(float(pulp.value(mean_burden)), 6),
    }
