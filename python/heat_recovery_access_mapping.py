from dataclasses import dataclass
from decimal import Decimal
from typing import Iterable


ZERO = Decimal("0")
ONE = Decimal("1")


@dataclass(frozen=True)
class HeatRecoveryAreaEvidence:
    area_ref: str
    heat_exposure: Decimal
    cooling_resource_gap: Decimal
    shaded_route_gap: Decimal
    accessible_heat_information_gap: Decimal
    public_service_continuity_gap: Decimal
    accessible_facility_gap: Decimal
    ecological_recovery_benefit: Decimal
    stewardship_readiness: Decimal
    displacement_or_disruption_risk: Decimal
    evidence_uncertainty: Decimal
    thermal_provenance_complete: bool
    access_provenance_complete: bool
    accessible_participation_available: bool
    low_disclosure_feedback_available: bool
    displacement_review_completed: bool
    person_level_data_used: bool = False
    identity_inference_used: bool = False
    external_action_authorized: bool = False


@dataclass(frozen=True)
class HeatRecoveryRecommendation:
    area_ref: str
    access_condition_gap: Decimal | None
    planning_priority: Decimal | None
    reportable: bool
    human_review_required: bool
    reasons: tuple[str, ...]


def validate_unit_interval(value: Decimal, name: str) -> None:
    if value < ZERO or value > ONE:
        raise ValueError(f"{name} must be between 0 and 1")


def evaluate_area(
    evidence: HeatRecoveryAreaEvidence,
) -> HeatRecoveryRecommendation:
    for name, value in (
        ("heat_exposure", evidence.heat_exposure),
        ("cooling_resource_gap", evidence.cooling_resource_gap),
        ("shaded_route_gap", evidence.shaded_route_gap),
        ("accessible_heat_information_gap", evidence.accessible_heat_information_gap),
        ("public_service_continuity_gap", evidence.public_service_continuity_gap),
        ("accessible_facility_gap", evidence.accessible_facility_gap),
        ("ecological_recovery_benefit", evidence.ecological_recovery_benefit),
        ("stewardship_readiness", evidence.stewardship_readiness),
        ("displacement_or_disruption_risk", evidence.displacement_or_disruption_risk),
        ("evidence_uncertainty", evidence.evidence_uncertainty),
    ):
        validate_unit_interval(value, name)

    reasons: list[str] = []

    if not evidence.thermal_provenance_complete:
        reasons.append("THERMAL_PROVENANCE_MISSING")

    if not evidence.access_provenance_complete:
        reasons.append("ACCESS_PROVENANCE_MISSING")

    if not evidence.accessible_participation_available:
        reasons.append("ACCESSIBLE_PARTICIPATION_UNAVAILABLE")

    if not evidence.low_disclosure_feedback_available:
        reasons.append("LOW_DISCLOSURE_FEEDBACK_UNAVAILABLE")

    if not evidence.displacement_review_completed:
        reasons.append("DISPLACEMENT_REVIEW_INCOMPLETE")

    if evidence.person_level_data_used:
        reasons.append("PERSON_LEVEL_DATA_PROHIBITED")

    if evidence.identity_inference_used:
        reasons.append("IDENTITY_INFERENCE_PROHIBITED")

    if evidence.external_action_authorized:
        reasons.append("EXTERNAL_ACTION_AUTHORIZATION_PROHIBITED")

    access_condition_gap = (
        Decimal("0.20") * evidence.cooling_resource_gap
        + Decimal("0.20") * evidence.shaded_route_gap
        + Decimal("0.20") * evidence.accessible_heat_information_gap
        + Decimal("0.20") * evidence.public_service_continuity_gap
        + Decimal("0.20") * evidence.accessible_facility_gap
    ).quantize(Decimal("0.001"))

    if reasons:
        return HeatRecoveryRecommendation(
            area_ref=evidence.area_ref,
            access_condition_gap=access_condition_gap,
            planning_priority=None,
            reportable=False,
            human_review_required=True,
            reasons=tuple(reasons),
        )

    planning_priority = (
        Decimal("0.30") * evidence.heat_exposure
        + Decimal("0.25") * access_condition_gap
        + Decimal("0.20") * evidence.ecological_recovery_benefit
        + Decimal("0.10") * evidence.stewardship_readiness
        - Decimal("0.10") * evidence.displacement_or_disruption_risk
        - Decimal("0.15") * evidence.evidence_uncertainty
    ).quantize(Decimal("0.001"))

    return HeatRecoveryRecommendation(
        area_ref=evidence.area_ref,
        access_condition_gap=access_condition_gap,
        planning_priority=planning_priority,
        reportable=True,
        human_review_required=True,
        reasons=(),
    )


def rank_areas(
    areas: Iterable[HeatRecoveryAreaEvidence],
) -> tuple[HeatRecoveryRecommendation, ...]:
    recommendations = [
        evaluate_area(area)
        for area in areas
    ]

    reportable = [
        recommendation
        for recommendation in recommendations
        if recommendation.reportable
        and recommendation.planning_priority is not None
    ]

    return tuple(
        sorted(
            reportable,
            key=lambda recommendation: recommendation.planning_priority,
            reverse=True,
        )
    )
