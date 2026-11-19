from dataclasses import dataclass
from decimal import Decimal


ZERO = Decimal("0")
ONE = Decimal("1")


@dataclass(frozen=True)
class ResponseQualityEvidence:
    response_ref: str
    source_provenance_present: bool
    jurisdiction_scope_present: bool
    plain_language_available: bool
    accessible_presentation_available: bool
    limitations_disclosed: bool
    correction_or_human_fallback_available: bool
    user_identity_inference_used: bool = False
    individual_legal_outcome_claimed: bool = False
    external_action_authorized: bool = False


@dataclass(frozen=True)
class KnowledgeAccessibilityAssessment:
    response_ref: str
    score: Decimal | None
    reportable: bool
    reasons: tuple[str, ...]


def assess_response_quality(
    evidence: ResponseQualityEvidence,
) -> KnowledgeAccessibilityAssessment:
    reasons: list[str] = []

    if evidence.user_identity_inference_used:
        reasons.append("IDENTITY_INFERENCE_PROHIBITED")

    if evidence.individual_legal_outcome_claimed:
        reasons.append("LEGAL_OUTCOME_CLAIM_PROHIBITED")

    if evidence.external_action_authorized:
        reasons.append("EXTERNAL_ACTION_AUTHORIZATION_PROHIBITED")

    if reasons:
        return KnowledgeAccessibilityAssessment(
            response_ref=evidence.response_ref,
            score=None,
            reportable=False,
            reasons=tuple(reasons),
        )

    score = (
        Decimal("0.25") * Decimal(evidence.source_provenance_present)
        + Decimal("0.15") * Decimal(evidence.jurisdiction_scope_present)
        + Decimal("0.20") * Decimal(evidence.plain_language_available)
        + Decimal("0.20") * Decimal(evidence.accessible_presentation_available)
        + Decimal("0.10") * Decimal(evidence.limitations_disclosed)
        + Decimal("0.10")
        * Decimal(evidence.correction_or_human_fallback_available)
    )

    return KnowledgeAccessibilityAssessment(
        response_ref=evidence.response_ref,
        score=min(ONE, max(ZERO, score)).quantize(Decimal("0.001")),
        reportable=True,
        reasons=(),
    )
