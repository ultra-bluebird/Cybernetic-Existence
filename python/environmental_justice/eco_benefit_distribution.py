from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from math import isfinite
from typing import Iterable


class JusticeStatus(str, Enum):
    SCREENING_ESTIMATE = "SCREENING_ESTIMATE"
    HOLD_FOR_REVIEW = "HOLD_FOR_REVIEW"
    NOT_CALCULATED = "NOT_CALCULATED"
    REJECT = "REJECT"


class JusticeRecommendation(str, Enum):
    OBSERVE = "OBSERVE"
    HOLD_FOR_REVIEW = "HOLD_FOR_REVIEW"
    ESCALATE = "ESCALATE"
    PASSIVE_DESIGN_REVIEW = "PASSIVE_DESIGN_REVIEW"
    REJECT = "REJECT"


@dataclass(frozen=True)
class EcoBenefitMetrics:
    tree_canopy_fraction: float | None
    green_space_access_score: float | None
    heat_island_intensity_c: float | None
    air_quality_score: float | None
    acoustic_quality_score: float | None
    uncertainty_state: str


@dataclass(frozen=True)
class AreaAggregateInputs:
    area_id: str
    eco_benefit_score: float | None
    disadvantage_index: float | None
    metrics: EcoBenefitMetrics
    aggregate_source_reference: str
    review_owner: str
    community_review_state: str


@dataclass(frozen=True)
class CityAggregateInputs:
    city_eco_benefit_score: float | None
    city_disadvantage_index: float | None
    source_reference: str
    review_owner: str


@dataclass(frozen=True)
class JusticeFinding:
    code: str
    recommendation: JusticeRecommendation
    summary: str


@dataclass(frozen=True)
class JusticeScreeningResult:
    area_id: str
    status: JusticeStatus
    recommendation: JusticeRecommendation
    justice_index: float | None
    findings: tuple[JusticeFinding, ...]
    limitations: tuple[str, ...]
    non_actuating: bool
    identity_neutral: bool
    aggregate_only: bool


def _is_valid_number(
    value: float | None,
    lower: float | None = None,
    upper: float | None = None
) -> bool:
    if value is None or not isfinite(value):
        return False
    if lower is not None and value < lower:
        return False
    if upper is not None and value > upper:
        return False
    return True


def _validate_area_inputs(inputs: AreaAggregateInputs) -> list[JusticeFinding]:
    findings: list[JusticeFinding] = []

    if inputs.area_id.strip() == "":
        findings.append(
            JusticeFinding(
                code="AREA_REFERENCE_MISSING",
                recommendation=JusticeRecommendation.REJECT,
                summary="A non-personal area reference is required."
            )
        )

    if inputs.aggregate_source_reference.strip() == "":
        findings.append(
            JusticeFinding(
                code="AGGREGATE_SOURCE_REFERENCE_MISSING",
                recommendation=JusticeRecommendation.HOLD_FOR_REVIEW,
                summary="Aggregate source reference is missing."
            )
        )

    if inputs.review_owner.strip() == "" or inputs.review_owner == "OWNER_ASSIGNMENT_REQUIRED":
        findings.append(
            JusticeFinding(
                code="REVIEW_OWNER_REQUIRED",
                recommendation=JusticeRecommendation.HOLD_FOR_REVIEW,
                summary="An accountable review role must be assigned."
            )
        )

    if inputs.community_review_state not in {
        "NOT_STARTED",
        "PENDING",
        "IN_REVIEW",
        "COMPLETED",
        "NOT_APPLICABLE",
        "REVIEW_REQUIRED",
    }:
        findings.append(
            JusticeFinding(
                code="INVALID_COMMUNITY_REVIEW_STATE",
                recommendation=JusticeRecommendation.REJECT,
                summary="Community review state is not in the approved vocabulary."
            )
        )

    if inputs.community_review_state in {
        "NOT_STARTED",
        "PENDING",
        "IN_REVIEW",
        "REVIEW_REQUIRED",
    }:
        findings.append(
            JusticeFinding(
                code="COMMUNITY_REVIEW_REQUIRED",
                recommendation=JusticeRecommendation.HOLD_FOR_REVIEW,
                summary="Area-level screening requires accessible community review before it informs investment prioritization."
            )
        )

    for field_name, value in (
        ("ECO_BENEFIT_SCORE", inputs.eco_benefit_score),
        ("DISADVANTAGE_INDEX", inputs.disadvantage_index),
        ("TREE_CANOPY_FRACTION", inputs.metrics.tree_canopy_fraction),
        ("GREEN_SPACE_ACCESS_SCORE", inputs.metrics.green_space_access_score),
        ("AIR_QUALITY_SCORE", inputs.metrics.air_quality_score),
        ("ACOUSTIC_QUALITY_SCORE", inputs.metrics.acoustic_quality_score),
    ):
        if value is None:
            findings.append(
                JusticeFinding(
                    code=f"MISSING_{field_name}",
                    recommendation=JusticeRecommendation.HOLD_FOR_REVIEW,
                    summary=f"{field_name} is unavailable. The screening model must not use a favorable default."
                )
            )
        elif not _is_valid_number(value, 0.0, 1.0):
            findings.append(
                JusticeFinding(
                    code=f"INVALID_{field_name}",
                    recommendation=JusticeRecommendation.REJECT,
                    summary=f"{field_name} must be finite and within the interval from 0 to 1."
                )
            )

    if inputs.metrics.heat_island_intensity_c is None:
        findings.append(
            JusticeFinding(
                code="MISSING_HEAT_ISLAND_INTENSITY",
                recommendation=JusticeRecommendation.HOLD_FOR_REVIEW,
                summary="Heat-island intensity is unavailable."
            )
        )
    elif not _is_valid_number(inputs.metrics.heat_island_intensity_c, -100.0, 100.0):
        findings.append(
            JusticeFinding(
                code="INVALID_HEAT_ISLAND_INTENSITY",
                recommendation=JusticeRecommendation.REJECT,
                summary="Heat-island intensity is outside the accepted input range."
            )
        )

    if inputs.metrics.uncertainty_state not in {
        "QUANTIFIED",
        "QUALITATIVE",
        "NOT_STATED",
        "NOT_CALCULATED",
        "NOT_APPLICABLE",
        "REVIEW_REQUIRED",
    }:
        findings.append(
            JusticeFinding(
                code="INVALID_UNCERTAINTY_STATE",
                recommendation=JusticeRecommendation.REJECT,
                summary="Metric uncertainty state is not in the approved controlled vocabulary."
            )
        )

    if inputs.metrics.uncertainty_state in {
        "NOT_STATED",
        "NOT_CALCULATED",
        "REVIEW_REQUIRED",
    }:
        findings.append(
            JusticeFinding(
                code="METRIC_UNCERTAINTY_REVIEW_REQUIRED",
                recommendation=JusticeRecommendation.HOLD_FOR_REVIEW,
                summary="Metric uncertainty is incomplete and requires review."
            )
        )

    return findings


def _validate_city_inputs(inputs: CityAggregateInputs) -> list[JusticeFinding]:
    findings: list[JusticeFinding] = []

    if inputs.source_reference.strip() == "":
        findings.append(
            JusticeFinding(
                code="CITY_SOURCE_REFERENCE_MISSING",
                recommendation=JusticeRecommendation.HOLD_FOR_REVIEW,
                summary="City aggregate source reference is missing."
            )
        )

    if inputs.review_owner.strip() == "" or inputs.review_owner == "OWNER_ASSIGNMENT_REQUIRED":
        findings.append(
            JusticeFinding(
                code="CITY_REVIEW_OWNER_REQUIRED",
                recommendation=JusticeRecommendation.HOLD_FOR_REVIEW,
                summary="City aggregate review owner must be assigned."
            )
        )

    if not _is_valid_number(inputs.city_eco_benefit_score, 0.0, 1.0):
        findings.append(
            JusticeFinding(
                code="INVALID_CITY_ECO_BENEFIT_SCORE",
                recommendation=JusticeRecommendation.HOLD_FOR_REVIEW,
                summary="City eco-benefit score is missing or outside the interval from 0 to 1."
            )
        )

    if not _is_valid_number(inputs.city_disadvantage_index, 0.0, 1.0):
        findings.append(
            JusticeFinding(
                code="INVALID_CITY_DISADVANTAGE_INDEX",
                recommendation=JusticeRecommendation.HOLD_FOR_REVIEW,
                summary="City disadvantage index is missing or outside the interval from 0 to 1."
            )
        )

    if inputs.city_eco_benefit_score == 0.0:
        findings.append(
            JusticeFinding(
                code="CITY_ECO_BENEFIT_DENOMINATOR_ZERO",
                recommendation=JusticeRecommendation.HOLD_FOR_REVIEW,
                summary="City eco-benefit score is zero and cannot be used as a denominator."
            )
        )

    if inputs.city_disadvantage_index == 0.0:
        findings.append(
            JusticeFinding(
                code="CITY_DISADVANTAGE_DENOMINATOR_ZERO",
                recommendation=JusticeRecommendation.HOLD_FOR_REVIEW,
                summary="City disadvantage index is zero and cannot be used as a denominator."
            )
        )

    return findings


def calculate_justice_index(
    area_eco_benefit_score: float,
    city_eco_benefit_score: float,
    area_disadvantage_index: float,
    city_disadvantage_index: float
) -> float:
    denominator = city_eco_benefit_score * (
        1.0 + area_disadvantage_index / city_disadvantage_index
    )

    if denominator <= 0.0:
        raise ValueError("Justice-index denominator must be greater than zero.")

    return area_eco_benefit_score / denominator


def evaluate_eco_benefit_distribution(
    area: AreaAggregateInputs,
    city: CityAggregateInputs
) -> JusticeScreeningResult:
    findings = [
        *_validate_area_inputs(area),
        *_validate_city_inputs(city),
    ]

    if any(
        finding.recommendation == JusticeRecommendation.REJECT
        for finding in findings
    ):
        return JusticeScreeningResult(
            area_id=area.area_id,
            status=JusticeStatus.REJECT,
            recommendation=JusticeRecommendation.REJECT,
            justice_index=None,
            findings=tuple(findings),
            limitations=_limitations(),
            non_actuating=True,
            identity_neutral=True,
            aggregate_only=True,
        )

    if any(
        finding.recommendation == JusticeRecommendation.HOLD_FOR_REVIEW
        for finding in findings
    ):
        return JusticeScreeningResult(
            area_id=area.area_id,
            status=JusticeStatus.HOLD_FOR_REVIEW,
            recommendation=JusticeRecommendation.HOLD_FOR_REVIEW,
            justice_index=None,
            findings=tuple(findings),
            limitations=_limitations(),
            non_actuating=True,
            identity_neutral=True,
            aggregate_only=True,
        )

    assert area.eco_benefit_score is not None
    assert area.disadvantage_index is not None
    assert city.city_eco_benefit_score is not None
    assert city.city_disadvantage_index is not None

    justice_index = calculate_justice_index(
        area.eco_benefit_score,
        city.city_eco_benefit_score,
        area.disadvantage_index,
        city.city_disadvantage_index,
    )

    if justice_index < 1.0:
        findings.append(
            JusticeFinding(
                code="ECO_BENEFIT_DISTRIBUTION_REVIEW_REQUIRED",
                recommendation=JusticeRecommendation.ESCALATE,
                summary="The aggregate screening index is below 1. This identifies a potential eco-benefit distribution gap for accessible community and accountable planning review."
            )
        )

        return JusticeScreeningResult(
            area_id=area.area_id,
            status=JusticeStatus.SCREENING_ESTIMATE,
            recommendation=JusticeRecommendation.ESCALATE,
            justice_index=justice_index,
            findings=tuple(findings),
            limitations=_limitations(),
            non_actuating=True,
            identity_neutral=True,
            aggregate_only=True,
        )

    findings.append(
        JusticeFinding(
            code="SCREENING_INDEX_AT_OR_ABOVE_REFERENCE",
            recommendation=JusticeRecommendation.OBSERVE,
            summary="The aggregate screening index is at or above the stated reference. This is not a conclusion about equity, adequacy, health, service quality, or community priorities."
        )
    )

    return JusticeScreeningResult(
        area_id=area.area_id,
        status=JusticeStatus.SCREENING_ESTIMATE,
        recommendation=JusticeRecommendation.OBSERVE,
        justice_index=justice_index,
        findings=tuple(findings),
        limitations=_limitations(),
        non_actuating=True,
        identity_neutral=True,
        aggregate_only=True,
    )


def compare_areas(
    areas: Iterable[AreaAggregateInputs],
    city: CityAggregateInputs
) -> tuple[JusticeScreeningResult, ...]:
    results = [
        evaluate_eco_benefit_distribution(area, city)
        for area in areas
    ]

    return tuple(
        sorted(
            results,
            key=lambda result: (
                result.justice_index is None,
                result.justice_index if result.justice_index is not None else float("inf"),
                result.area_id,
            ),
        )
    )


def _limitations() -> tuple[str, ...]:
    return (
        "This is an aggregate area-level screening estimate based on supplied non-personal data.",
        "This result does not identify, profile, rank, or track individual residents, households, disability status, health status, immigration status, race, ethnicity, or augmentation status.",
        "This result does not establish that an area, community, or resident is deficient, unsafe, underserved, compliant, non-compliant, eligible, or ineligible.",
        "This result does not determine investment, land use, funding, benefit allocation, enforcement, service access, or community representation.",
        "This result requires accessible community review and accountable public-interest planning before it informs decisions.",
        "This result does not authorize surveillance, infrastructure control, resource restriction, displacement, or any physical-system action.",
        "Unknown, unmodeled, expired, incomplete, or uncertain inputs must remain explicit and may not be converted into favorable assumptions.",
    )
