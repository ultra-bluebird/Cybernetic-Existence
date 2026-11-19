from __future__ import annotations

from dataclasses import dataclass
from typing import Mapping
import math


@dataclass(frozen=True)
class DistrictState:
    district_code: str
    inclusive_practice_share: float
    baseline_learning_rate: float
    peer_learning_rate: float
    opinion_leader_factor: float
    legal_protection_factor: float
    media_quality_factor: float
    exclusion_incident_factor: float


@dataclass(frozen=True)
class SimulationResult:
    district_code: str
    prior_share: float
    exposure_share: float
    adoption_rate: float
    next_share: float


def advance_one_step(
    districts: Mapping[str, DistrictState],
    connectivity: Mapping[str, Mapping[str, float]],
    time_step: float,
    opinion_weight: float,
    legal_weight: float,
    media_weight: float,
    exclusion_weight: float,
) -> list[SimulationResult]:
    if not districts:
        raise ValueError("At least one district is required.")
    if not 0.0 < time_step <= 1.0:
        raise ValueError("time_step must be within (0, 1].")

    for name, value in {
        "opinion_weight": opinion_weight,
        "legal_weight": legal_weight,
        "media_weight": media_weight,
        "exclusion_weight": exclusion_weight,
    }.items():
        if not math.isfinite(value) or value < 0.0:
            raise ValueError(f"{name} must be finite and non-negative.")

    results: list[SimulationResult] = []

    for district_code, state in districts.items():
        _validate_state(state)
        exposure = _weighted_exposure(
            district_code,
            districts,
            connectivity.get(district_code, {}),
        )

        adoption_rate = (
            state.baseline_learning_rate
            + state.peer_learning_rate * exposure
            + opinion_weight * state.opinion_leader_factor
            + legal_weight * state.legal_protection_factor
            + media_weight * state.media_quality_factor
            - exclusion_weight * state.exclusion_incident_factor
        )

        next_share = _clip(
            state.inclusive_practice_share
            + time_step * adoption_rate * (1.0 - state.inclusive_practice_share),
            0.0,
            1.0,
        )

        results.append(
            SimulationResult(
                district_code=district_code,
                prior_share=state.inclusive_practice_share,
                exposure_share=exposure,
                adoption_rate=adoption_rate,
                next_share=next_share,
            )
        )

    return results


def _weighted_exposure(
    district_code: str,
    districts: Mapping[str, DistrictState],
    edges: Mapping[str, float],
) -> float:
    weighted_sum = 0.0
    total_weight = 0.0

    for neighbor_code, weight in edges.items():
        if neighbor_code not in districts:
            raise ValueError(
                f"Connectivity references unknown district: {neighbor_code}"
            )
        if not math.isfinite(weight) or weight < 0.0:
            raise ValueError("Connectivity weights must be finite and non-negative.")

        weighted_sum += weight * districts[neighbor_code].inclusive_practice_share
        total_weight += weight

    if total_weight == 0.0:
        return districts[district_code].inclusive_practice_share

    return weighted_sum / total_weight


def _validate_state(state: DistrictState) -> None:
    if not state.district_code:
        raise ValueError("district_code is required.")

    for name, value in {
        "inclusive_practice_share": state.inclusive_practice_share,
        "baseline_learning_rate": state.baseline_learning_rate,
        "peer_learning_rate": state.peer_learning_rate,
        "opinion_leader_factor": state.opinion_leader_factor,
        "legal_protection_factor": state.legal_protection_factor,
        "media_quality_factor": state.media_quality_factor,
        "exclusion_incident_factor": state.exclusion_incident_factor,
    }.items():
        if not math.isfinite(value) or not 0.0 <= value <= 1.0:
            raise ValueError(f"{name} must be finite and within [0, 1].")


def _clip(value: float, minimum: float, maximum: float) -> float:
    return min(maximum, max(minimum, value))
