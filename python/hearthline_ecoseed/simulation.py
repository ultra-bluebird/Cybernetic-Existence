from __future__ import annotations

from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Literal, Sequence
import csv
import math
import random

SeedStorageClass = Literal["orthodox", "intermediate", "recalcitrant"]


@dataclass(frozen=True)
class SeedLot:
    lot_id: str
    species_label: str
    storage_class: SeedStorageClass
    initial_viability: float
    initial_quantity: int
    baseline_germination: float
    conservation_temperature_c: float
    equilibrium_relative_humidity_percent: float
    sealed_container: bool
    treatment_optimal_hours: float
    treatment_optimal_oxygen_mg_l: float
    treatment_optimal_flow_index: float


@dataclass(frozen=True)
class HydrationTreatment:
    duration_hours: float
    oxygen_mg_l: float
    flow_index: float
    water_temperature_c: float
    sanitation_protocol: Literal["validated", "unvalidated"]


@dataclass(frozen=True)
class CommunityNeed:
    community_id: str
    distance_km: float
    requested_seed_count: int
    priority_weight: float
    crop_suitability: float
    local_capacity: float
    consent_to_receive: bool
    restoration_priority: float


@dataclass(frozen=True)
class SimulationConfig:
    years_in_storage: int
    simulation_runs: int
    random_seed: int
    reserve_fraction: float
    maximum_vehicle_seed_capacity: int
    maximum_delivery_distance_km: float
    no_delivery_below_suitability: float


@dataclass(frozen=True)
class ViabilityResult:
    lot_id: str
    run_id: int
    viability_after_storage: float
    treatment_adjusted_germination: float
    viable_seed_count: int
    warnings: tuple[str, ...]


@dataclass(frozen=True)
class AllocationResult:
    community_id: str
    requested_seed_count: int
    allocated_seed_count: int
    unmet_seed_count: int
    estimated_viable_seed_count: int
    delivery_distance_km: float
    delivery_authorized: bool
    exclusion_reason: str | None


def clamp(value: float, lower: float, upper: float) -> float:
    return max(lower, min(value, upper))


def gaussian_penalty(
    observed: float,
    optimal: float,
    tolerated_spread: float,
) -> float:
    if tolerated_spread <= 0:
        raise ValueError("tolerated_spread must be greater than zero.")

    distance = (observed - optimal) / tolerated_spread
    return math.exp(-0.5 * distance * distance)


def validate_seed_lot(seed_lot: SeedLot) -> None:
    if not 0.0 < seed_lot.initial_viability <= 1.0:
        raise ValueError("initial_viability must be within (0, 1].")

    if seed_lot.initial_quantity <= 0:
        raise ValueError("initial_quantity must be greater than zero.")

    if not 0.0 <= seed_lot.baseline_germination <= 1.0:
        raise ValueError("baseline_germination must be within [0, 1].")

    if seed_lot.storage_class == "orthodox":
        if seed_lot.conservation_temperature_c > -15.0:
            raise ValueError(
                "Orthodox long-term seed-lot model requires a conservation "
                "temperature at or below -15°C. Review storage conditions."
            )

        if seed_lot.equilibrium_relative_humidity_percent > 25.0:
            raise ValueError(
                "Orthodox long-term seed-lot model requires controlled low "
                "relative humidity. Review drying and packaging conditions."
            )

        if not seed_lot.sealed_container:
            raise ValueError(
                "Orthodox long-term seed-lot model requires sealed storage."
            )


def storage_decay_rate_per_year(seed_lot: SeedLot) -> float:
    """
    Scenario model only. It is not a replacement for Ellis-Roberts parameters,
    accession testing, or species-specific storage protocols.

    The reference condition is dry, sealed orthodox seed at -18°C and 15% RH.
    Conditions outside this reference raise annual viability loss.
    """
    if seed_lot.storage_class == "recalcitrant":
        raise ValueError(
            "Recalcitrant seed must not be modeled with this dry-storage "
            "decay equation. Use species-specific hydrated-storage or "
            "cryobiology protocols."
        )

    base_rate = 0.0075 if seed_lot.storage_class == "orthodox" else 0.0225

    temperature_deviation = abs(seed_lot.conservation_temperature_c - (-18.0))
    humidity_deviation = abs(seed_lot.equilibrium_relative_humidity_percent - 15.0)

    temperature_multiplier = 1.0 + (0.065 * temperature_deviation)
    humidity_multiplier = 1.0 + (0.028 * humidity_deviation)
    packaging_multiplier = 1.0 if seed_lot.sealed_container else 2.4

    return base_rate * temperature_multiplier * humidity_multiplier * packaging_multiplier


def simulate_storage_viability(
    seed_lot: SeedLot,
    years: int,
    rng: random.Random,
) -> float:
    if years < 0:
        raise ValueError("years must not be negative.")

    mean_decay = storage_decay_rate_per_year(seed_lot)
    viability = seed_lot.initial_viability

    for _ in range(years):
        annual_decay = clamp(
            rng.gauss(mean_decay, mean_decay * 0.25),
            0.0,
            0.80,
        )
        viability *= 1.0 - annual_decay

    return clamp(viability, 0.0, 1.0)


def treatment_germination_modifier(
    seed_lot: SeedLot,
    treatment: HydrationTreatment,
    rng: random.Random,
) -> tuple[float, tuple[str, ...]]:
    """
    Hypothesis-oriented treatment model.

    This represents a bounded experimental design:
    - oxygen may support hydrated seed respiration;
    - duration, flow, and temperature can help or harm;
    - unvalidated sanitation adds a risk penalty;
    - outcomes must be calibrated with local, species-specific controls.
    """
    warnings: list[str] = []

    if treatment.duration_hours <= 0:
        raise ValueError("duration_hours must be greater than zero.")

    if treatment.oxygen_mg_l <= 0:
        raise ValueError("oxygen_mg_l must be greater than zero.")

    if treatment.flow_index < 0:
        raise ValueError("flow_index must not be negative.")

    duration_fit = gaussian_penalty(
        treatment.duration_hours,
        seed_lot.treatment_optimal_hours,
        max(1.0, seed_lot.treatment_optimal_hours * 0.60),
    )

    oxygen_fit = gaussian_penalty(
        treatment.oxygen_mg_l,
        seed_lot.treatment_optimal_oxygen_mg_l,
        max(0.5, seed_lot.treatment_optimal_oxygen_mg_l * 0.45),
    )

    flow_fit = gaussian_penalty(
        treatment.flow_index,
        seed_lot.treatment_optimal_flow_index,
        max(0.10, seed_lot.treatment_optimal_flow_index * 0.75),
    )

    water_temperature_fit = gaussian_penalty(
        treatment.water_temperature_c,
        18.0,
        7.0,
    )

    calibrated_benefit = (
        0.18
        * duration_fit
        * oxygen_fit
        * flow_fit
        * water_temperature_fit
    )

    overstimulation = max(0.0, treatment.flow_index - 1.5) * 0.06
    prolonged_soak_penalty = max(
        0.0,
        treatment.duration_hours - seed_lot.treatment_optimal_hours * 2.0,
    ) * 0.012

    sanitation_penalty = 0.0
    if treatment.sanitation_protocol != "validated":
        sanitation_penalty = 0.08
        warnings.append(
            "Treatment sanitation is unvalidated; pathogen and contamination "
            "risk must be evaluated before field use."
        )

    stochastic_error = rng.gauss(0.0, 0.035)
    modifier = 1.0 + calibrated_benefit - overstimulation - prolonged_soak_penalty
    modifier += stochastic_error - sanitation_penalty

    if treatment.flow_index > 2.5:
        warnings.append(
            "Flow index exceeds the demonstration model's gentle-treatment "
            "range; mechanical damage risk may be under-estimated."
        )

    return clamp(modifier, 0.10, 1.20), tuple(warnings)


def simulate_seed_lot(
    seed_lot: SeedLot,
    treatment: HydrationTreatment,
    config: SimulationConfig,
) -> list[ViabilityResult]:
    validate_seed_lot(seed_lot)

    if config.simulation_runs <= 0:
        raise ValueError("simulation_runs must be greater than zero.")

    results: list[ViabilityResult] = []

    for run_id in range(config.simulation_runs):
        rng = random.Random(config.random_seed + run_id)
        viability_after_storage = simulate_storage_viability(
            seed_lot,
            config.years_in_storage,
            rng,
        )
        modifier, warnings = treatment_germination_modifier(
            seed_lot,
            treatment,
            rng,
        )

        treatment_adjusted_germination = clamp(
            seed_lot.baseline_germination * modifier,
            0.0,
            1.0,
        )

        viable_seed_count = round(
            seed_lot.initial_quantity
            * viability_after_storage
            * treatment_adjusted_germination
        )

        results.append(
            ViabilityResult(
                lot_id=seed_lot.lot_id,
                run_id=run_id,
                viability_after_storage=viability_after_storage,
                treatment_adjusted_germination=treatment_adjusted_germination,
                viable_seed_count=viable_seed_count,
                warnings=warnings,
            )
        )

    return results


def expected_viable_seed_count(
    viability_results: Sequence[ViabilityResult],
) -> int:
    if not viability_results:
        raise ValueError("viability_results must not be empty.")

    return round(
        sum(result.viable_seed_count for result in viability_results)
        / len(viability_results)
    )


def distribution_score(community: CommunityNeed) -> float:
    """
    A transparent, reviewable allocation score.

    It prioritizes:
    - a community's stated need;
    - local crop suitability;
    - community capacity;
    - ecological restoration value;
    - lower transport distance.

    It must not ingest protected traits, identities, health information,
    behavioral profiles, or inferred personal attributes.
    """
    distance_cost = 1.0 / (1.0 + community.distance_km)
    need_component = math.log1p(community.requested_seed_count)

    return (
        need_component
        * clamp(community.priority_weight, 0.0, 5.0)
        * clamp(community.crop_suitability, 0.0, 1.0)
        * clamp(community.local_capacity, 0.0, 1.0)
        * (1.0 + clamp(community.restoration_priority, 0.0, 1.0))
        * distance_cost
    )


def allocate_seed_distribution(
    communities: Sequence[CommunityNeed],
    expected_viable_seeds: int,
    config: SimulationConfig,
) -> list[AllocationResult]:
    if not 0.0 <= config.reserve_fraction < 1.0:
        raise ValueError("reserve_fraction must be within [0, 1).")

    distributable_seed_count = math.floor(
        expected_viable_seeds * (1.0 - config.reserve_fraction)
    )

    eligible: list[CommunityNeed] = []
    excluded: list[AllocationResult] = []

    for community in communities:
        if community.requested_seed_count < 0:
            raise ValueError("requested_seed_count must not be negative.")

        if not community.consent_to_receive:
            excluded.append(
                AllocationResult(
                    community_id=community.community_id,
                    requested_seed_count=community.requested_seed_count,
                    allocated_seed_count=0,
                    unmet_seed_count=community.requested_seed_count,
                    estimated_viable_seed_count=0,
                    delivery_distance_km=community.distance_km,
                    delivery_authorized=False,
                    exclusion_reason="community_delivery_consent_not_recorded",
                )
            )
            continue

        if community.distance_km > config.maximum_delivery_distance_km:
            excluded.append(
                AllocationResult(
                    community_id=community.community_id,
                    requested_seed_count=community.requested_seed_count,
                    allocated_seed_count=0,
                    unmet_seed_count=community.requested_seed_count,
                    estimated_viable_seed_count=0,
                    delivery_distance_km=community.distance_km,
                    delivery_authorized=True,
                    exclusion_reason="outside_declared_delivery_distance",
                )
            )
            continue

        if community.crop_suitability < config.no_delivery_below_suitability:
            excluded.append(
                AllocationResult(
                    community_id=community.community_id,
                    requested_seed_count=community.requested_seed_count,
                    allocated_seed_count=0,
                    unmet_seed_count=community.requested_seed_count,
                    estimated_viable_seed_count=0,
                    delivery_distance_km=community.distance_km,
                    delivery_authorized=True,
                    exclusion_reason="crop_suitability_below_declared_threshold",
                )
            )
            continue

        eligible.append(community)

    ranked = sorted(
        eligible,
        key=lambda community: (
            -distribution_score(community),
            community.distance_km,
            community.community_id,
        ),
    )

    allocation: list[AllocationResult] = []
    remaining_seed_count = distributable_seed_count

    for community in ranked:
        maximum_single_delivery = min(
            community.requested_seed_count,
            config.maximum_vehicle_seed_capacity,
        )

        allocated_seed_count = max(
            0,
            min(maximum_single_delivery, remaining_seed_count),
        )

        remaining_seed_count -= allocated_seed_count

        allocation.append(
            AllocationResult(
                community_id=community.community_id,
                requested_seed_count=community.requested_seed_count,
                allocated_seed_count=allocated_seed_count,
                unmet_seed_count=(
                    community.requested_seed_count - allocated_seed_count
                ),
                estimated_viable_seed_count=allocated_seed_count,
                delivery_distance_km=community.distance_km,
                delivery_authorized=True,
                exclusion_reason=None,
            )
        )

    return sorted(
        [*allocation, *excluded],
        key=lambda result: result.community_id,
    )


def write_csv(
    output_path: Path,
    viability_results: Sequence[ViabilityResult],
    allocation_results: Sequence[AllocationResult],
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with output_path.open("w", newline="", encoding="utf-8") as output_file:
        fieldnames = [
            "record_type",
            "identifier",
            "run_id",
            "viability_after_storage",
            "treatment_adjusted_germination",
            "viable_seed_count",
            "requested_seed_count",
            "allocated_seed_count",
            "unmet_seed_count",
            "delivery_distance_km",
            "delivery_authorized",
            "exclusion_reason",
            "warnings",
        ]

        writer = csv.DictWriter(output_file, fieldnames=fieldnames)
        writer.writeheader()

        for result in viability_results:
            writer.writerow(
                {
                    "record_type": "viability",
                    "identifier": result.lot_id,
                    "run_id": result.run_id,
                    "viability_after_storage": f"{result.viability_after_storage:.6f}",
                    "treatment_adjusted_germination": (
                        f"{result.treatment_adjusted_germination:.6f}"
                    ),
                    "viable_seed_count": result.viable_seed_count,
                    "requested_seed_count": "",
                    "allocated_seed_count": "",
                    "unmet_seed_count": "",
                    "delivery_distance_km": "",
                    "delivery_authorized": "",
                    "exclusion_reason": "",
                    "warnings": " | ".join(result.warnings),
                }
            )

        for result in allocation_results:
            writer.writerow(
                {
                    "record_type": "allocation",
                    "identifier": result.community_id,
                    "run_id": "",
                    "viability_after_storage": "",
                    "treatment_adjusted_germination": "",
                    "viable_seed_count": result.estimated_viable_seed_count,
                    "requested_seed_count": result.requested_seed_count,
                    "allocated_seed_count": result.allocated_seed_count,
                    "unmet_seed_count": result.unmet_seed_count,
                    "delivery_distance_km": f"{result.delivery_distance_km:.3f}",
                    "delivery_authorized": result.delivery_authorized,
                    "exclusion_reason": result.exclusion_reason or "",
                    "warnings": "",
                }
            )


def demonstration() -> None:
    seed_lot = SeedLot(
        lot_id="demo-orthodox-lot-001",
        species_label="Demonstration annual crop seed",
        storage_class="orthodox",
        initial_viability=0.94,
        initial_quantity=50_000,
        baseline_germination=0.85,
        conservation_temperature_c=-18.0,
        equilibrium_relative_humidity_percent=15.0,
        sealed_container=True,
        treatment_optimal_hours=8.0,
        treatment_optimal_oxygen_mg_l=8.5,
        treatment_optimal_flow_index=0.65,
    )

    treatment = HydrationTreatment(
        duration_hours=8.0,
        oxygen_mg_l=8.5,
        flow_index=0.65,
        water_temperature_c=18.0,
        sanitation_protocol="validated",
    )

    config = SimulationConfig(
        years_in_storage=10,
        simulation_runs=10_000,
        random_seed=20260926,
        reserve_fraction=0.20,
        maximum_vehicle_seed_capacity=7_500,
        maximum_delivery_distance_km=300.0,
        no_delivery_below_suitability=0.35,
    )

    communities = [
        CommunityNeed(
            community_id="community-a",
            distance_km=42.0,
            requested_seed_count=6_000,
            priority_weight=1.4,
            crop_suitability=0.84,
            local_capacity=0.86,
            consent_to_receive=True,
            restoration_priority=0.35,
        ),
        CommunityNeed(
            community_id="community-b",
            distance_km=165.0,
            requested_seed_count=7_500,
            priority_weight=1.8,
            crop_suitability=0.72,
            local_capacity=0.80,
            consent_to_receive=True,
            restoration_priority=0.65,
        ),
        CommunityNeed(
            community_id="community-c",
            distance_km=260.0,
            requested_seed_count=4_500,
            priority_weight=1.2,
            crop_suitability=0.61,
            local_capacity=0.78,
            consent_to_receive=True,
            restoration_priority=0.90,
        ),
        CommunityNeed(
            community_id="community-without-consent",
            distance_km=50.0,
            requested_seed_count=3_000,
            priority_weight=2.0,
            crop_suitability=0.92,
            local_capacity=0.90,
            consent_to_receive=False,
            restoration_priority=0.40,
        ),
    ]

    viability_results = simulate_seed_lot(seed_lot, treatment, config)
    expected_viable = expected_viable_seed_count(viability_results)

    allocation_results = allocate_seed_distribution(
        communities,
        expected_viable,
        config,
    )

    output_path = Path("output/hearthline_ecoseed_simulation.csv")
    write_csv(output_path, viability_results, allocation_results)

    mean_storage_viability = (
        sum(item.viability_after_storage for item in viability_results)
        / len(viability_results)
    )

    mean_treatment_germination = (
        sum(item.treatment_adjusted_germination for item in viability_results)
        / len(viability_results)
    )

    print(
        {
            "expected_viable_seed_count": expected_viable,
            "mean_storage_viability": round(mean_storage_viability, 6),
            "mean_treatment_adjusted_germination": round(
                mean_treatment_germination,
                6,
            ),
            "reserved_seed_count": math.floor(
                expected_viable * config.reserve_fraction
            ),
            "output_file": str(output_path),
        }
    )


if __name__ == "__main__":
    demonstration()
