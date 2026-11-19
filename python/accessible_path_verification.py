from dataclasses import dataclass
from decimal import Decimal


@dataclass(frozen=True)
class PathSegmentEvidence:
    segment_ref: str
    running_slope_ratio: Decimal
    cross_slope_ratio: Decimal
    obstruction_severity: Decimal
    surface_hazard_severity: Decimal
    route_criticality: Decimal
    eco_restoration_benefit: Decimal
    measurement_uncertainty: Decimal
    obstruction_evidence_present: bool
    surface_evidence_present: bool
    provenance_complete: bool
    accessible_detour_verified: bool | None = None


@dataclass(frozen=True)
class PathAssessment:
    segment_ref: str
    repair_priority: Decimal | None
    review_required: bool
    reasons: tuple[str, ...]


def normalized(value: Decimal, field_name: str) -> Decimal:
    if value < Decimal("0") or value > Decimal("1"):
        raise ValueError(f"{field_name} must be between 0 and 1")
    return value


def assess_path_segment(evidence: PathSegmentEvidence) -> PathAssessment:
    reasons: list[str] = []

    for field_name, value in (
        ("obstruction_severity", evidence.obstruction_severity),
        ("surface_hazard_severity", evidence.surface_hazard_severity),
        ("route_criticality", evidence.route_criticality),
        ("eco_restoration_benefit", evidence.eco_restoration_benefit),
        ("measurement_uncertainty", evidence.measurement_uncertainty),
    ):
        normalized(value, field_name)

    if not evidence.provenance_complete:
        reasons.append("MISSING_PROVENANCE")

    if evidence.obstruction_severity > Decimal("0") and not evidence.obstruction_evidence_present:
        reasons.append("OBSTRUCTION_EVIDENCE_MISSING")

    if evidence.surface_hazard_severity > Decimal("0") and not evidence.surface_evidence_present:
        reasons.append("SURFACE_EVIDENCE_MISSING")

    if evidence.accessible_detour_verified is False:
        reasons.append("ACCESSIBLE_DETOUR_NOT_VERIFIED")

    review_required = bool(reasons) or evidence.measurement_uncertainty > Decimal("0.25")

    if not evidence.provenance_complete:
        return PathAssessment(
            segment_ref=evidence.segment_ref,
            repair_priority=None,
            review_required=True,
            reasons=tuple(reasons),
        )

    repair_priority = (
        Decimal("0.30") * evidence.obstruction_severity
        + Decimal("0.25") * evidence.surface_hazard_severity
        + Decimal("0.25") * evidence.route_criticality
        + Decimal("0.20") * evidence.eco_restoration_benefit
        - Decimal("0.20") * evidence.measurement_uncertainty
    )

    return PathAssessment(
        segment_ref=evidence.segment_ref,
        repair_priority=repair_priority.quantize(Decimal("0.001")),
        review_required=review_required,
        reasons=tuple(reasons),
    )
