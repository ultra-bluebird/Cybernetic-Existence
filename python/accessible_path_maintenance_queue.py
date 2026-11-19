from dataclasses import dataclass
from decimal import Decimal
from typing import Iterable


ZERO = Decimal("0")
ONE = Decimal("1")


@dataclass(frozen=True)
class PathMaintenanceEvidence:
    segment_ref: str
    obstruction_severity: Decimal
    surface_hazard_severity: Decimal
    gradient_review_indicator: Decimal
    route_discontinuity_indicator: Decimal
    route_criticality: Decimal
    eco_restoration_benefit: Decimal
    measurement_uncertainty: Decimal
    obstruction_evidence_present: bool
    surface_evidence_present: bool
    gradient_measurement_present: bool
    provenance_complete: bool
    accessible_detour_verified: bool | None
    automated_dispatch_authorized: bool = False


@dataclass(frozen=True)
class PathMaintenanceRecommendation:
    segment_ref: str
    path_integrity_score: Decimal | None
    maintenance_priority: Decimal | None
    review_required: bool
    reasons: tuple[str, ...]


def require_unit_interval(value: Decimal, name: str) -> None:
    if value < ZERO or value > ONE:
        raise ValueError(f"{name} must be between 0 and 1")


def calculate_path_integrity(evidence: PathMaintenanceEvidence) -> Decimal:
    return (
        ONE
        - Decimal("0.30") * evidence.obstruction_severity
        - Decimal("0.30") * evidence.surface_hazard_severity
        - Decimal("0.15") * evidence.gradient_review_indicator
        - Decimal("0.25") * evidence.route_discontinuity_indicator
    ).quantize(Decimal("0.001"))


def recommend_maintenance(
    evidence: PathMaintenanceEvidence,
) -> PathMaintenanceRecommendation:
    for name, value in (
        ("obstruction_severity", evidence.obstruction_severity),
        ("surface_hazard_severity", evidence.surface_hazard_severity),
        ("gradient_review_indicator", evidence.gradient_review_indicator),
        ("route_discontinuity_indicator", evidence.route_discontinuity_indicator),
        ("route_criticality", evidence.route_criticality),
        ("eco_restoration_benefit", evidence.eco_restoration_benefit),
        ("measurement_uncertainty", evidence.measurement_uncertainty),
    ):
        require_unit_interval(value, name)

    reasons: list[str] = []

    if not evidence.provenance_complete:
        reasons.append("MISSING_PROVENANCE")

    if evidence.obstruction_severity > ZERO and not evidence.obstruction_evidence_present:
        reasons.append("OBSTRUCTION_EVIDENCE_MISSING")

    if evidence.surface_hazard_severity > ZERO and not evidence.surface_evidence_present:
        reasons.append("SURFACE_EVIDENCE_MISSING")

    if evidence.gradient_review_indicator > ZERO and not evidence.gradient_measurement_present:
        reasons.append("GRADIENT_MEASUREMENT_MISSING")

    if evidence.accessible_detour_verified is False:
        reasons.append("ACCESSIBLE_DETOUR_NOT_VERIFIED")

    if evidence.automated_dispatch_authorized:
        reasons.append("AUTOMATED_DISPATCH_PROHIBITED")

    review_required = (
        bool(reasons)
        or evidence.measurement_uncertainty > Decimal("0.25")
        or evidence.gradient_review_indicator > ZERO
    )

    if not evidence.provenance_complete or evidence.automated_dispatch_authorized:
        return PathMaintenanceRecommendation(
            segment_ref=evidence.segment_ref,
            path_integrity_score=None,
            maintenance_priority=None,
            review_required=True,
            reasons=tuple(reasons),
        )

    priority = (
        Decimal("0.25") * evidence.obstruction_severity
        + Decimal("0.25") * evidence.surface_hazard_severity
        + Decimal("0.15") * evidence.route_criticality
        + Decimal("0.20") * evidence.route_discontinuity_indicator
        + Decimal("0.15") * evidence.eco_restoration_benefit
        - Decimal("0.20") * evidence.measurement_uncertainty
    ).quantize(Decimal("0.001"))

    return PathMaintenanceRecommendation(
        segment_ref=evidence.segment_ref,
        path_integrity_score=calculate_path_integrity(evidence),
        maintenance_priority=priority,
        review_required=review_required,
        reasons=tuple(reasons),
    )


def rank_maintenance_queue(
    evidence_items: Iterable[PathMaintenanceEvidence],
) -> tuple[PathMaintenanceRecommendation, ...]:
    recommendations = [
        recommend_maintenance(evidence)
        for evidence in evidence_items
    ]

    reportable = [
        recommendation
        for recommendation in recommendations
        if recommendation.maintenance_priority is not None
    ]

    return tuple(
        sorted(
            reportable,
            key=lambda recommendation: recommendation.maintenance_priority,
            reverse=True,
        )
    )
