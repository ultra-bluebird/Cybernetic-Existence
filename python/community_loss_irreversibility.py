from __future__ import annotations

from dataclasses import dataclass
from math import exp


@dataclass(frozen=True)
class CommunityLossScenario:
    recovery_years: float | None
    accessible_substitute_count: float
    best_substitute_quality_ratio: float
    directly_affected_units: float
    indirectly_affected_units: float
    indirect_effect_weight: float
    essential_life_support: float
    essential_public_service: float
    cultural_continuity: float
    future_optionality: float
    permanent_loss_probability: float
    evidence_confidence: float
    recovery_reference_years: float = 25.0
    substitute_reference_count: float = 3.0
    affected_reference_units: float = 10000.0


@dataclass(frozen=True)
class IrreversibilityResult:
    score: float
    time_to_recovery_score: float
    lack_of_substitutability_score: float
    affected_scale_score: float
    essential_dependency_score: float


def clamp_unit(value: float) -> float:
    return max(0.0, min(1.0, float(value)))


def calculate_community_loss_irreversibility(
    scenario: CommunityLossScenario,
) -> IrreversibilityResult:
    if scenario.recovery_reference_years <= 0.0:
        raise ValueError("recovery_reference_years must be greater than zero")
    if scenario.substitute_reference_count <= 0.0:
        raise ValueError("substitute_reference_count must be greater than zero")
    if scenario.affected_reference_units <= 0.0:
        raise ValueError("affected_reference_units must be greater than zero")
    if scenario.recovery_years is not None and scenario.recovery_years < 0.0:
        raise ValueError("recovery_years must be non-negative or None")

    if scenario.recovery_years is None:
        time_to_recovery = 1.0
    else:
        time_to_recovery = 1.0 - exp(
            -scenario.recovery_years / scenario.recovery_reference_years
        )

    accessible_substitutes = max(0.0, scenario.accessible_substitute_count)
    substitute_quality = clamp_unit(scenario.best_substitute_quality_ratio)
    lack_of_substitutability = 1.0 - clamp_unit(
        accessible_substitutes
        / scenario.substitute_reference_count
        * substitute_quality
    )

    direct = max(0.0, scenario.directly_affected_units)
    indirect = max(0.0, scenario.indirectly_affected_units)
    affected_scale = clamp_unit(
        (direct + clamp_unit(scenario.indirect_effect_weight) * indirect)
        / scenario.affected_reference_units
    )

    essential_dependency = (
        0.40 * clamp_unit(scenario.essential_life_support)
        + 0.30 * clamp_unit(scenario.essential_public_service)
        + 0.20 * clamp_unit(scenario.cultural_continuity)
        + 0.10 * clamp_unit(scenario.future_optionality)
    )

    score = (
        clamp_unit(scenario.evidence_confidence)
        * clamp_unit(scenario.permanent_loss_probability)
        * (
            0.35 * time_to_recovery
            + 0.25 * lack_of_substitutability
            + 0.20 * affected_scale
            + 0.20 * essential_dependency
        )
    )

    return IrreversibilityResult(
        score=round(clamp_unit(score), 6),
        time_to_recovery_score=round(clamp_unit(time_to_recovery), 6),
        lack_of_substitutability_score=round(clamp_unit(lack_of_substitutability), 6),
        affected_scale_score=round(affected_scale, 6),
        essential_dependency_score=round(clamp_unit(essential_dependency), 6),
    )
