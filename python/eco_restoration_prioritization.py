from dataclasses import dataclass
from decimal import Decimal
from typing import Iterable


ZERO = Decimal("0")
ONE = Decimal("1")


@dataclass(frozen=True)
class RestorationProjectEvidence:
    project_ref: str
    habitat_biodiversity_benefit: Decimal
    water_soil_benefit: Decimal
    heat_adaptation_benefit: Decimal
    ecological_connectivity: Decimal
    stewardship_feasibility: Decimal
    access_equivalence_quality: Decimal
    community_stewardship_benefit: Decimal
    displacement_or_disturbance_risk: Decimal
    evidence_uncertainty: Decimal
    ecological_evidence_present: bool
    maintenance_plan_present: bool
    risk_assessment_present: bool
    accessible_participation_available: bool
    low_disclosure_feedback_available: bool
    non_displacement_review_completed: bool
    provenance_complete: bool
    automatic_funding_authorized: bool = False


@dataclass(frozen=True)
class RestorationWeights:
    habitat_biodiversity: Decimal
    water_soil: Decimal
    heat_adaptation: Decimal
    connectivity: Decimal
    stewardship: Decimal
    access_equivalence: Decimal
    community_stewardship: Decimal
    risk: Decimal
    uncertainty: Decimal


@dataclass(frozen=True)
class RestorationRecommendation:
    project_ref: str
    priority_score: Decimal | None
    reportable: bool
    human_review_required: bool
    reasons: tuple[str, ...]


def validate_unit_interval(value: Decimal, name: str) -> None:
    if value < ZERO or value > ONE:
        raise ValueError(f"{name} must be between 0 and 1")


def validate_weights(weights: RestorationWeights) -> None:
    for name, value in (
        ("habitat_biodiversity", weights.habitat_biodiversity),
        ("water_soil", weights.water_soil),
        ("heat_adaptation", weights.heat_adaptation),
        ("connectivity", weights.connectivity),
        ("stewardship", weights.stewardship),
        ("access_equivalence", weights.access_equivalence),
        ("community_stewardship", weights.community_stewardship),
        ("risk", weights.risk),
        ("uncertainty", weights.uncertainty),
    ):
        if value < ZERO:
            raise ValueError(f"{name} must not be negative")


def recommend_restoration(
    project: RestorationProjectEvidence,
    weights: RestorationWeights,
) -> RestorationRecommendation:
    validate_weights(weights)

    for name, value in (
        ("habitat_biodiversity_benefit", project.habitat_biodiversity_benefit),
        ("water_soil_benefit", project.water_soil_benefit),
        ("heat_adaptation_benefit", project.heat_adaptation_benefit),
        ("ecological_connectivity", project.ecological_connectivity),
        ("stewardship_feasibility", project.stewardship_feasibility),
        ("access_equivalence_quality", project.access_equivalence_quality),
        ("community_stewardship_benefit", project.community_stewardship_benefit),
        ("displacement_or_disturbance_risk", project.displacement_or_disturbance_risk),
        ("evidence_uncertainty", project.evidence_uncertainty),
    ):
        validate_unit_interval(value, name)

    reasons: list[str] = []

    if not project.ecological_evidence_present:
        reasons.append("ECOLOGICAL_EVIDENCE_MISSING")

    if not project.maintenance_plan_present:
        reasons.append("MAINTENANCE_PLAN_MISSING")

    if not project.risk_assessment_present:
        reasons.append("RISK_ASSESSMENT_MISSING")

    if not project.accessible_participation_available:
        reasons.append("ACCESSIBLE_PARTICIPATION_UNAVAILABLE")

    if not project.low_disclosure_feedback_available:
        reasons.append("LOW_DISCLOSURE_FEEDBACK_UNAVAILABLE")

    if not project.non_displacement_review_completed:
        reasons.append("NON_DISPLACEMENT_REVIEW_INCOMPLETE")

    if not project.provenance_complete:
        reasons.append("MISSING_PROVENANCE")

    if project.automatic_funding_authorized:
        reasons.append("AUTOMATIC_FUNDING_PROHIBITED")

    if reasons:
        return RestorationRecommendation(
            project_ref=project.project_ref,
            priority_score=None,
            reportable=False,
            human_review_required=True,
            reasons=tuple(reasons),
        )

    score = (
        weights.habitat_biodiversity * project.habitat_biodiversity_benefit
        + weights.water_soil * project.water_soil_benefit
        + weights.heat_adaptation * project.heat_adaptation_benefit
        + weights.connectivity * project.ecological_connectivity
        + weights.stewardship * project.stewardship_feasibility
        + weights.access_equivalence * project.access_equivalence_quality
        + weights.community_stewardship * project.community_stewardship_benefit
        - weights.risk * project.displacement_or_disturbance_risk
        - weights.uncertainty * project.evidence_uncertainty
    )

    return RestorationRecommendation(
        project_ref=project.project_ref,
        priority_score=score.quantize(Decimal("0.001")),
        reportable=True,
        human_review_required=True,
        reasons=(),
    )


def rank_projects(
    projects: Iterable[RestorationProjectEvidence],
    weights: RestorationWeights,
) -> tuple[RestorationRecommendation, ...]:
    recommendations = [
        recommend_restoration(project, weights)
        for project in projects
    ]

    reportable = [
        recommendation
        for recommendation in recommendations
        if recommendation.reportable
        and recommendation.priority_score is not None
    ]

    return tuple(
        sorted(
            reportable,
            key=lambda recommendation: recommendation.priority_score,
            reverse=True,
        )
    )
