from __future__ import annotations

from dataclasses import dataclass
from math import exp, log
from typing import Sequence


@dataclass(frozen=True)
class ProjectEvidence:
    carbon_score: float
    stormwater_score: float
    biodiversity_score: float
    benefit_distribution_score: float
    universal_accessibility_score: float
    community_governance_score: float
    measurement_quality: float
    provenance_reproducibility: float
    independent_review_quality: float
    uncertainty_quality: float
    ecological_risk: float
    rights_risk: float
    privacy_risk: float
    accessibility_risk: float
    displacement_risk: float
    rights_gate: bool
    accessibility_gate: bool
    community_gate: bool
    ecology_gate: bool
    evidence_gate: bool


@dataclass(frozen=True)
class EcoSocialValueResult:
    deployable: bool
    eco_social_good_value: float
    ecological_value: float
    social_value: float
    knowledge_confidence: float
    residual_harm_risk: float
    failed_gates: tuple[str, ...]


def clamp_unit(value: float) -> float:
    return max(0.0, min(1.0, float(value)))


def weighted_geometric_mean(values: Sequence[float], weights: Sequence[float]) -> float:
    if len(values) != len(weights) or not values:
        raise ValueError("values and weights must be non-empty and have equal length")

    total_weight = sum(weights)
    if total_weight <= 0.0:
        raise ValueError("weights must sum to a positive value")

    safe_values = [max(clamp_unit(value), 1e-9) for value in values]
    weighted_log_sum = sum(
        weight * log(value)
        for value, weight in zip(safe_values, weights)
    )
    return exp(weighted_log_sum / total_weight)


def calculate_eco_social_good_value(evidence: ProjectEvidence) -> EcoSocialValueResult:
    ecological_value = (
        0.30 * clamp_unit(evidence.carbon_score)
        + 0.35 * clamp_unit(evidence.stormwater_score)
        + 0.35 * clamp_unit(evidence.biodiversity_score)
    )

    social_value = (
        0.35 * clamp_unit(evidence.benefit_distribution_score)
        + 0.40 * clamp_unit(evidence.universal_accessibility_score)
        + 0.25 * clamp_unit(evidence.community_governance_score)
    )

    knowledge_confidence = weighted_geometric_mean(
        [
            evidence.measurement_quality,
            evidence.provenance_reproducibility,
            evidence.independent_review_quality,
            evidence.uncertainty_quality,
        ],
        [0.30, 0.30, 0.25, 0.15],
    )

    residual_harm_risk = max(
        clamp_unit(evidence.ecological_risk),
        clamp_unit(evidence.rights_risk),
        clamp_unit(evidence.privacy_risk),
        clamp_unit(evidence.accessibility_risk),
        clamp_unit(evidence.displacement_risk),
    )

    gates = {
        "rights": evidence.rights_gate,
        "accessibility": evidence.accessibility_gate,
        "community_governance": evidence.community_gate,
        "ecology": evidence.ecology_gate,
        "evidence": evidence.evidence_gate,
    }
    failed_gates = tuple(name for name, passed in gates.items() if not passed)
    deployable = len(failed_gates) == 0

    base_score = knowledge_confidence * (
        0.55 * ecological_value + 0.45 * social_value
    ) * (1.0 - residual_harm_risk)

    return EcoSocialValueResult(
        deployable=deployable,
        eco_social_good_value=round(base_score if deployable else 0.0, 6),
        ecological_value=round(ecological_value, 6),
        social_value=round(social_value, 6),
        knowledge_confidence=round(knowledge_confidence, 6),
        residual_harm_risk=round(residual_harm_risk, 6),
        failed_gates=failed_gates,
    )
