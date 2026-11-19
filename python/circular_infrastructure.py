from dataclasses import dataclass
from decimal import Decimal
from typing import Iterable


ZERO = Decimal("0")
ONE = Decimal("1")


@dataclass(frozen=True)
class CircularAssetEvidence:
    asset_ref: str
    reuse_readiness: Decimal
    modularity: Decimal
    repair_life_extension: Decimal
    disassembly_quality: Decimal
    end_of_life_recovery_quality: Decimal
    hazard_or_labor_risk: Decimal
    evidence_uncertainty: Decimal
    material_composition_evidence_present: bool
    repair_instructions_available: bool
    replaceable_component_list_available: bool
    disassembly_sequence_available: bool
    software_support_period_documented: bool
    reuse_path_assessed: bool
    refurbishment_path_assessed: bool
    recycling_path_assessed: bool
    hazardous_material_path_assessed: bool
    lifecycle_scope_documented: bool
    person_data_used: bool = False
    identity_inference_used: bool = False
    automatic_procurement_authorized: bool = False


@dataclass(frozen=True)
class CircularityAssessment:
    asset_ref: str
    circularity_score: Decimal | None
    reportable: bool
    human_review_required: bool
    reasons: tuple[str, ...]


def require_unit_interval(value: Decimal, name: str) -> None:
    if value < ZERO or value > ONE:
        raise ValueError(f"{name} must be between 0 and 1")


def assess_circularity(
    asset: CircularAssetEvidence,
) -> CircularityAssessment:
    for name, value in (
        ("reuse_readiness", asset.reuse_readiness),
        ("modularity", asset.modularity),
        ("repair_life_extension", asset.repair_life_extension),
        ("disassembly_quality", asset.disassembly_quality),
        ("end_of_life_recovery_quality", asset.end_of_life_recovery_quality),
        ("hazard_or_labor_risk", asset.hazard_or_labor_risk),
        ("evidence_uncertainty", asset.evidence_uncertainty),
    ):
        require_unit_interval(value, name)

    reasons: list[str] = []

    required_evidence = (
        asset.material_composition_evidence_present,
        asset.repair_instructions_available,
        asset.replaceable_component_list_available,
        asset.disassembly_sequence_available,
        asset.software_support_period_documented,
        asset.reuse_path_assessed,
        asset.refurbishment_path_assessed,
        asset.recycling_path_assessed,
        asset.hazardous_material_path_assessed,
        asset.lifecycle_scope_documented,
    )

    if not all(required_evidence):
        reasons.append("CIRCULARITY_EVIDENCE_INCOMPLETE")

    if asset.person_data_used:
        reasons.append("PERSON_DATA_PROHIBITED")

    if asset.identity_inference_used:
        reasons.append("IDENTITY_INFERENCE_PROHIBITED")

    if asset.automatic_procurement_authorized:
        reasons.append("AUTOMATIC_PROCUREMENT_PROHIBITED")

    if reasons:
        return CircularityAssessment(
            asset_ref=asset.asset_ref,
            circularity_score=None,
            reportable=False,
            human_review_required=True,
            reasons=tuple(reasons),
        )

    score = (
        Decimal("0.20") * asset.reuse_readiness
        + Decimal("0.20") * asset.modularity
        + Decimal("0.20") * asset.repair_life_extension
        + Decimal("0.15") * asset.disassembly_quality
        + Decimal("0.15") * asset.end_of_life_recovery_quality
        - Decimal("0.05") * asset.hazard_or_labor_risk
        - Decimal("0.05") * asset.evidence_uncertainty
    ).quantize(Decimal("0.001"))

    return CircularityAssessment(
        asset_ref=asset.asset_ref,
        circularity_score=score,
        reportable=True,
        human_review_required=True,
        reasons=(),
    )


def rank_assets(
    assets: Iterable[CircularAssetEvidence],
) -> tuple[CircularityAssessment, ...]:
    assessments = [assess_circularity(asset) for asset in assets]

    reportable = [
        assessment
        for assessment in assessments
        if assessment.reportable and assessment.circularity_score is not None
    ]

    return tuple(
        sorted(
            reportable,
            key=lambda assessment: assessment.circularity_score,
            reverse=True,
        )
    )
