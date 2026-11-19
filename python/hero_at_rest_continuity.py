from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256
from typing import Literal


RecognitionState = Literal["candidate", "hero_active", "hero_at_rest"]
ContinuityState = Literal["preserved", "review_pending", "corrected"]


@dataclass(frozen=True)
class HeroContinuityRecord:
    recognition_state: RecognitionState
    tier_continuity_state: ContinuityState
    underlying_tier_preserved: bool
    associated_access_rights_preserved: bool
    inactivity_is_not_change_ground: bool
    permitted_change_ground: str | None
    evidence_attached: bool
    human_review_recorded: bool
    notice_delivered: bool
    appeal_path_available: bool
    signed_change_record_valid: bool
    previous_record_hash: str


@dataclass(frozen=True)
class ContinuityDecision:
    accepted: bool
    reason: str
    record_commitment: str


PERMITTED_CHANGE_GROUNDS = {
    "material_evidence_fraud",
    "material_authorship_misrepresentation",
    "material_consent_violation",
    "serious_rights_violation",
    "objective_record_correction",
    "narrow_lawful_safety_action",
}


def canonical_record(record: HeroContinuityRecord) -> bytes:
    fields = (
        record.recognition_state,
        record.tier_continuity_state,
        str(record.underlying_tier_preserved),
        str(record.associated_access_rights_preserved),
        str(record.inactivity_is_not_change_ground),
        record.permitted_change_ground or "",
        str(record.evidence_attached),
        str(record.human_review_recorded),
        str(record.notice_delivered),
        str(record.appeal_path_available),
        str(record.signed_change_record_valid),
        record.previous_record_hash,
    )
    return "|".join(fields).encode("utf-8")


def commitment(record: HeroContinuityRecord) -> str:
    return sha256(canonical_record(record)).hexdigest()


def validate_continuity_transition(record: HeroContinuityRecord) -> ContinuityDecision:
    record_commitment = commitment(record)

    if record.recognition_state == "hero_at_rest":
        if (
            record.tier_continuity_state != "preserved"
            or not record.underlying_tier_preserved
            or not record.associated_access_rights_preserved
            or not record.inactivity_is_not_change_ground
        ):
            return ContinuityDecision(
                accepted=False,
                reason="Hero at Rest requires preserved tier, preserved access rights, and inactivity protection.",
                record_commitment=record_commitment,
            )

        return ContinuityDecision(
            accepted=True,
            reason="Hero at Rest continuity assertion preserves tier and associated access rights.",
            record_commitment=record_commitment,
        )

    if (
        record.tier_continuity_state == "corrected"
        or not record.underlying_tier_preserved
        or not record.associated_access_rights_preserved
    ):
        if record.permitted_change_ground not in PERMITTED_CHANGE_GROUNDS:
            return ContinuityDecision(
                accepted=False,
                reason="Tier or access change lacks a permitted due-process ground.",
                record_commitment=record_commitment,
            )

        if not all((
            record.evidence_attached,
            record.human_review_recorded,
            record.notice_delivered,
            record.appeal_path_available,
            record.signed_change_record_valid,
        )):
            return ContinuityDecision(
                accepted=False,
                reason="Tier or access change lacks required evidence, review, notice, appeal, or signature.",
                record_commitment=record_commitment,
            )

    return ContinuityDecision(
        accepted=True,
        reason="Continuity transition satisfies the configured policy conditions.",
        record_commitment=record_commitment,
    )
