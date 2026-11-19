from dataclasses import dataclass
from decimal import Decimal


ZERO = Decimal("0")
ONE = Decimal("1")


@dataclass(frozen=True)
class HubZoneEvidence:
    zone_ref: str
    aggregate_occupancy_count: int
    occupancy_capacity: int
    temperature_condition_score: Decimal
    humidity_condition_score: Decimal
    ventilation_evidence_score: Decimal
    accessibility_availability_score: Decimal
    provenance_complete: bool
    person_level_tracking_used: bool = False
    identity_inference_used: bool = False
    access_denial_automation_enabled: bool = False


@dataclass(frozen=True)
class HubConditionAssessment:
    zone_ref: str
    condition_score: Decimal | None
    crowding_ratio: Decimal | None
    reportable: bool
    review_required: bool
    reasons: tuple[str, ...]


def require_normalized(value: Decimal, field_name: str) -> None:
    if value < ZERO or value > ONE:
        raise ValueError(f"{field_name} must be between 0 and 1")


def assess_hub_zone(evidence: HubZoneEvidence) -> HubConditionAssessment:
    reasons: list[str] = []

    if evidence.aggregate_occupancy_count < 0:
        raise ValueError("aggregate_occupancy_count must not be negative")

    if evidence.occupancy_capacity <= 0:
        raise ValueError("occupancy_capacity must be positive")

    for name, value in (
        ("temperature_condition_score", evidence.temperature_condition_score),
        ("humidity_condition_score", evidence.humidity_condition_score),
        ("ventilation_evidence_score", evidence.ventilation_evidence_score),
        ("accessibility_availability_score", evidence.accessibility_availability_score),
    ):
        require_normalized(value, name)

    if not evidence.provenance_complete:
        reasons.append("MISSING_PROVENANCE")

    if evidence.person_level_tracking_used:
        reasons.append("PERSON_LEVEL_TRACKING_PROHIBITED")

    if evidence.identity_inference_used:
        reasons.append("IDENTITY_INFERENCE_PROHIBITED")

    if evidence.access_denial_automation_enabled:
        reasons.append("AUTOMATED_ACCESS_DENIAL_PROHIBITED")

    crowding_ratio = (
        Decimal(evidence.aggregate_occupancy_count)
        / Decimal(evidence.occupancy_capacity)
    )

    crowding_condition_score = max(
        ZERO,
        ONE - max(ZERO, crowding_ratio - ONE),
    )

    if reasons:
        return HubConditionAssessment(
            zone_ref=evidence.zone_ref,
            condition_score=None,
            crowding_ratio=crowding_ratio.quantize(Decimal("0.001")),
            reportable=False,
            review_required=True,
            reasons=tuple(reasons),
        )

    condition_score = (
        Decimal("0.20") * evidence.temperature_condition_score
        + Decimal("0.15") * evidence.humidity_condition_score
        + Decimal("0.25") * evidence.ventilation_evidence_score
        + Decimal("0.30") * evidence.accessibility_availability_score
        + Decimal("0.10") * crowding_condition_score
    ).quantize(Decimal("0.001"))

    return HubConditionAssessment(
        zone_ref=evidence.zone_ref,
        condition_score=condition_score,
        crowding_ratio=crowding_ratio.quantize(Decimal("0.001")),
        reportable=True,
        review_required=(
            evidence.accessibility_availability_score < Decimal("1.0")
            or crowding_ratio > ONE
        ),
        reasons=(),
    )
