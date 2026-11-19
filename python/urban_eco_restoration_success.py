from __future__ import annotations

from dataclasses import dataclass
from math import isfinite


@dataclass(frozen=True)
class RestorationInputs:
    species_richness_score: float
    native_plant_coverage_score: float
    soil_organic_matter_score: float
    pollinator_abundance_score: float
    community_engagement_score: float
    evidence_quality_score: float
    ecological_harm_risk: float
    water_harm_risk: float
    accessibility_harm_risk: float
    displacement_harm_risk: float
    maintenance_harm_risk: float


@dataclass(frozen=True)
class RestorationResult:
    success_index: float
    ecological_subscore: float
    community_subscore: float
    evidence_quality: float
    residual_harm_risk: float
    review_status: str


def clamp_unit(value: float) -> float:
    if not isfinite(value):
        raise ValueError("all restoration inputs must be finite")
    return max(0.0, min(1.0, value))


def calculate_urban_eco_restoration_success(
    inputs: RestorationInputs,
) -> RestorationResult:
    species_richness = clamp_unit(inputs.species_richness_score)
    native_coverage = clamp_unit(inputs.native_plant_coverage_score)
    soil_organic_matter = clamp_unit(inputs.soil_organic_matter_score)
    pollinator_abundance = clamp_unit(inputs.pollinator_abundance_score)
    community_engagement = clamp_unit(inputs.community_engagement_score)
    evidence_quality = clamp_unit(inputs.evidence_quality_score)

    residual_harm_risk = max(
        clamp_unit(inputs.ecological_harm_risk),
        clamp_unit(inputs.water_harm_risk),
        clamp_unit(inputs.accessibility_harm_risk),
        clamp_unit(inputs.displacement_harm_risk),
        clamp_unit(inputs.maintenance_harm_risk),
    )

    ecological_subscore = (
        0.24 * species_richness
        + 0.24 * native_coverage
        + 0.18 * soil_organic_matter
        + 0.20 * pollinator_abundance
    )

    base_score = (
        ecological_subscore
        + 0.14 * community_engagement
    )
    success_index = 100.0 * evidence_quality * base_score * (1.0 - residual_harm_risk)

    if residual_harm_risk >= 0.50:
        review_status = "hold_for_review"
    elif evidence_quality < 0.60:
        review_status = "monitoring_strengthening_needed"
    else:
        review_status = "measured"

    return RestorationResult(
        success_index=round(max(0.0, min(100.0, success_index)), 2),
        ecological_subscore=round(ecological_subscore, 6),
        community_subscore=round(community_engagement, 6),
        evidence_quality=round(evidence_quality, 6),
        residual_harm_risk=round(residual_harm_risk, 6),
        review_status=review_status,
    )
