from dataclasses import dataclass
from decimal import Decimal
from typing import Iterable


ZERO = Decimal("0")
ONE = Decimal("1")


@dataclass(frozen=True)
class ContextEvidence:
    context_ref: str
    access_equivalence: Decimal
    participation_availability: Decimal
    safeguard_coverage: Decimal
    representation_quality: Decimal
    voluntary_feedback_signal: Decimal
    governance_maturity: Decimal
    provenance_complete: bool
    aggregation_threshold_met: bool
    person_level_data_used: bool = False
    identity_inference_used: bool = False
    private_message_processing_used: bool = False
    external_action_authorized: bool = False


@dataclass(frozen=True)
class SocialAcceptanceAssessment:
    context_ref: str
    score: Decimal | None
    eligible_for_reporting: bool
    violations: tuple[str, ...]


WEIGHTS = {
    "access_equivalence": Decimal("0.25"),
    "participation_availability": Decimal("0.15"),
    "safeguard_coverage": Decimal("0.20"),
    "representation_quality": Decimal("0.10"),
    "voluntary_feedback_signal": Decimal("0.10"),
    "governance_maturity": Decimal("0.20"),
}


def validate_normalized(value: Decimal, field_name: str) -> None:
    if value < ZERO or value > ONE:
        raise ValueError(f"{field_name} must be between 0 and 1")


def assess_context(evidence: ContextEvidence) -> SocialAcceptanceAssessment:
    values = {
        "access_equivalence": evidence.access_equivalence,
        "participation_availability": evidence.participation_availability,
        "safeguard_coverage": evidence.safeguard_coverage,
        "representation_quality": evidence.representation_quality,
        "voluntary_feedback_signal": evidence.voluntary_feedback_signal,
        "governance_maturity": evidence.governance_maturity,
    }

    for field_name, value in values.items():
        validate_normalized(value, field_name)

    violations: list[str] = []

    if not evidence.provenance_complete:
        violations.append("MISSING_PROVENANCE")

    if not evidence.aggregation_threshold_met:
        violations.append("AGGREGATION_THRESHOLD_NOT_MET")

    if evidence.person_level_data_used:
        violations.append("PERSON_LEVEL_DATA_USED")

    if evidence.identity_inference_used:
        violations.append("IDENTITY_INFERENCE_USED")

    if evidence.private_message_processing_used:
        violations.append("PRIVATE_MESSAGE_PROCESSING_USED")

    if evidence.external_action_authorized:
        violations.append("EXTERNAL_ACTION_AUTHORIZED")

    if violations:
        return SocialAcceptanceAssessment(
            context_ref=evidence.context_ref,
            score=None,
            eligible_for_reporting=False,
            violations=tuple(violations),
        )

    score = sum(
        values[field_name] * weight
        for field_name, weight in WEIGHTS.items()
    )

    return SocialAcceptanceAssessment(
        context_ref=evidence.context_ref,
        score=score.quantize(Decimal("0.001")),
        eligible_for_reporting=True,
        violations=(),
    )


def assess_contexts(
    evidence_set: Iterable[ContextEvidence],
) -> tuple[SocialAcceptanceAssessment, ...]:
    return tuple(assess_context(evidence) for evidence in evidence_set)
