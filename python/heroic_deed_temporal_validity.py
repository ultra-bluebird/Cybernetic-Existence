from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import FrozenSet


class ProceduralResult(str, Enum):
    TEMPORAL_VALIDITY_RECORD_PRESERVED = "temporal_validity_record_preserved"
    REVERIFICATION_REQUIRES_INSTITUTIONAL_REVIEW = (
        "reverification_requires_institutional_review"
    )
    INVALID_FOR_REVIEW_UNTIL_CORRECTED = "invalid_for_review_until_corrected"


class ReverificationTrigger(str, Enum):
    MATERIAL_NEW_EVIDENCE = "material_new_evidence"
    CREDIBLE_EVIDENCE_INTEGRITY_CONCERN = "credible_evidence_integrity_concern"
    MATERIAL_ATTRIBUTION_DISPUTE = "material_attribution_dispute"
    SUBSTANTIAL_HISTORICAL_CONTEXT_UPDATE = "substantial_historical_context_update"
    HOLDER_REQUESTED_CORRECTION = "holder_requested_correction"
    INSTITUTIONAL_RECORD_MIGRATION = "institutional_record_migration"
    APPEAL_OR_NEUTRAL_REVIEW_REQUEST = "appeal_or_neutral_review_request"


@dataclass(frozen=True)
class TemporalValidityRecord:
    automated_final_decision: bool
    status_does_not_expire_by_time: bool
    inactivity_not_adverse: bool
    rest_retirement_or_withdrawal_protected: bool
    renewal_or_reperformance_not_required: bool
    institutional_neglect_not_adverse: bool
    privacy_limited_evidence_permitted: bool
    reverification_is_not_automatic_revocation: bool
    human_review_required: bool
    append_only_correction_required: bool
    prior_record_preserved: bool
    notice_required_for_material_change: bool
    evidence_access_available: bool
    neutral_review_available: bool
    appeal_available: bool
    no_time_based_revocation: bool
    no_inactivity_based_revocation: bool
    no_adverse_inference_from_private_evidence: bool
    accessible_communication_available: bool
    human_final_authority: bool
    reverification_triggers: FrozenSet[ReverificationTrigger]


@dataclass(frozen=True)
class TemporalValidityAssessment:
    result: ProceduralResult
    automated_final_decision: bool
    recognition_continuity_preserved: bool
    time_based_revocation_permitted: bool
    inactivity_based_revocation_permitted: bool
    appeal_eligibility: str
    reasons: tuple[str, ...]


def assess_temporal_validity(
    record: TemporalValidityRecord,
) -> TemporalValidityAssessment:
    requirements = {
        "automated_final_decision_must_be_false": not record.automated_final_decision,
        "status_must_not_expire_by_time": record.status_does_not_expire_by_time,
        "inactivity_must_not_be_adverse": record.inactivity_not_adverse,
        "rest_retirement_or_withdrawal_must_be_protected": (
            record.rest_retirement_or_withdrawal_protected
        ),
        "renewal_or_reperformance_must_not_be_required": (
            record.renewal_or_reperformance_not_required
        ),
        "institutional_neglect_must_not_be_adverse": (
            record.institutional_neglect_not_adverse
        ),
        "privacy_limited_evidence_must_be_permitted": (
            record.privacy_limited_evidence_permitted
        ),
        "reverification_must_not_be_automatic_revocation": (
            record.reverification_is_not_automatic_revocation
        ),
        "reverification_requires_human_review": record.human_review_required,
        "corrections_must_be_append_only": record.append_only_correction_required,
        "prior_record_must_be_preserved": record.prior_record_preserved,
        "material_change_requires_notice": (
            record.notice_required_for_material_change
        ),
        "evidence_access_must_be_available": record.evidence_access_available,
        "neutral_review_must_be_available": record.neutral_review_available,
        "appeal_must_be_available": record.appeal_available,
        "time_based_revocation_must_be_prohibited": (
            record.no_time_based_revocation
        ),
        "inactivity_based_revocation_must_be_prohibited": (
            record.no_inactivity_based_revocation
        ),
        "private_evidence_must_not_create_adverse_inference": (
            record.no_adverse_inference_from_private_evidence
        ),
        "accessible_communication_must_be_available": (
            record.accessible_communication_available
        ),
        "human_final_authority_must_be_preserved": (
            record.human_final_authority
        ),
    }

    reasons = tuple(
        requirement_name
        for requirement_name, satisfied in requirements.items()
        if not satisfied
    )

    base = {
        "automated_final_decision": False,
        "recognition_continuity_preserved": True,
        "time_based_revocation_permitted": False,
        "inactivity_based_revocation_permitted": False,
        "appeal_eligibility": "preserved",
    }

    if reasons:
        return TemporalValidityAssessment(
            result=ProceduralResult.INVALID_FOR_REVIEW_UNTIL_CORRECTED,
            reasons=reasons,
            **base,
        )

    material_triggers = {
        ReverificationTrigger.MATERIAL_NEW_EVIDENCE,
        ReverificationTrigger.CREDIBLE_EVIDENCE_INTEGRITY_CONCERN,
        ReverificationTrigger.MATERIAL_ATTRIBUTION_DISPUTE,
        ReverificationTrigger.SUBSTANTIAL_HISTORICAL_CONTEXT_UPDATE,
        ReverificationTrigger.HOLDER_REQUESTED_CORRECTION,
        ReverificationTrigger.APPEAL_OR_NEUTRAL_REVIEW_REQUEST,
    }

    if record.reverification_triggers.intersection(material_triggers):
        return TemporalValidityAssessment(
            result=ProceduralResult.REVERIFICATION_REQUIRES_INSTITUTIONAL_REVIEW,
            reasons=(),
            **base,
        )

    return TemporalValidityAssessment(
        result=ProceduralResult.TEMPORAL_VALIDITY_RECORD_PRESERVED,
        reasons=(),
        **base,
    )
