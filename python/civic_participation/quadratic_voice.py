from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Mapping


class QuadraticVoiceValidationError(ValueError):
    pass


@dataclass(frozen=True)
class BallotValidation:
    accepted: bool
    total_cost: int
    voice_credit_budget: int
    reason: str


@dataclass(frozen=True)
class ModerationReport:
    action: str
    human_review_required: bool
    appeal_available: bool
    reason: str


PROHIBITED_MODERATION_BASES = frozenset(
    {
        "augmentation_status",
        "self_described_cybernetic_host_status",
        "appearance",
        "device_ownership",
        "assistive_technology_use",
        "disability_inference",
        "biometric_inference",
        "health_status",
        "participation_frequency",
        "reputation_score",
        "social_rank",
    }
)

ACTIONABLE_CONDUCT_CATEGORIES = frozenset(
    {
        "credible_threat",
        "targeted_harassment",
        "doxxing",
        "nonconsensual_personal_data_disclosure",
        "deceptive_impersonation",
        "malware_distribution",
        "spam",
        "coordinated_disruption",
    }
)


def quadratic_cost(votes_by_issue: Mapping[str, int]) -> int:
    if not votes_by_issue:
        raise QuadraticVoiceValidationError("At least one issue vote is required.")

    total = 0
    for issue_id, votes in votes_by_issue.items():
        if not isinstance(issue_id, str) or not issue_id.strip():
            raise QuadraticVoiceValidationError("Each issue identifier must be a non-empty string.")
        if isinstance(votes, bool) or not isinstance(votes, int):
            raise QuadraticVoiceValidationError("Each vote quantity must be an integer.")
        total += votes * votes

    return total


def validate_equal_voice_ballot(
    votes_by_issue: Mapping[str, int],
    voice_credit_budget: int,
    maximum_absolute_votes_per_issue: int,
) -> BallotValidation:
    if isinstance(voice_credit_budget, bool) or not isinstance(voice_credit_budget, int):
        raise QuadraticVoiceValidationError("voice_credit_budget must be an integer.")
    if isinstance(maximum_absolute_votes_per_issue, bool) or not isinstance(
        maximum_absolute_votes_per_issue, int
    ):
        raise QuadraticVoiceValidationError(
            "maximum_absolute_votes_per_issue must be an integer."
        )
    if voice_credit_budget <= 0:
        raise QuadraticVoiceValidationError("voice_credit_budget must be positive.")
    if maximum_absolute_votes_per_issue <= 0:
        raise QuadraticVoiceValidationError(
            "maximum_absolute_votes_per_issue must be positive."
        )

    for votes in votes_by_issue.values():
        if abs(votes) > maximum_absolute_votes_per_issue:
            return BallotValidation(
                accepted=False,
                total_cost=quadratic_cost(votes_by_issue),
                voice_credit_budget=voice_credit_budget,
                reason="A vote quantity exceeds the equal per-issue maximum.",
            )

    total_cost = quadratic_cost(votes_by_issue)
    if total_cost > voice_credit_budget:
        return BallotValidation(
            accepted=False,
            total_cost=total_cost,
            voice_credit_budget=voice_credit_budget,
            reason="The ballot exceeds the equal non-transferable voice-credit budget.",
        )

    return BallotValidation(
        accepted=True,
        total_cost=total_cost,
        voice_credit_budget=voice_credit_budget,
        reason="The ballot uses no more than the equal non-transferable voice-credit budget.",
    )


def evaluate_moderation_request(
    reported_conduct: str,
    proposed_bases: set[str],
    evidence_reviewable: bool,
) -> ModerationReport:
    if not isinstance(reported_conduct, str) or not reported_conduct.strip():
        raise QuadraticVoiceValidationError("reported_conduct must be a non-empty string.")
    if not isinstance(proposed_bases, set) or not all(
        isinstance(basis, str) for basis in proposed_bases
    ):
        raise QuadraticVoiceValidationError("proposed_bases must be a set of strings.")

    if PROHIBITED_MODERATION_BASES.intersection(proposed_bases):
        return ModerationReport(
            action="REJECT_PROFILE_BASED_MODERATION",
            human_review_required=True,
            appeal_available=True,
            reason=(
                "The proposed moderation basis includes identity, health, device, "
                "augmentation, appearance, participation-frequency, reputation, or social-rank data."
            ),
        )

    if reported_conduct not in ACTIONABLE_CONDUCT_CATEGORIES:
        return ModerationReport(
            action="NO_RESTRICTION_WITHOUT_ACTIONABLE_CONDUCT",
            human_review_required=False,
            appeal_available=True,
            reason="The report does not identify a defined actionable conduct category.",
        )

    if not evidence_reviewable:
        return ModerationReport(
            action="HUMAN_REVIEW_REQUIRED",
            human_review_required=True,
            appeal_available=True,
            reason="A defined conduct category requires reviewable evidence before any boundary is imposed.",
        )

    return ModerationReport(
        action="NARROW_TEMPORARY_BOUNDARY_WITH_REVIEW",
        human_review_required=True,
        appeal_available=True,
        reason=(
            "A narrow temporary boundary may be considered for the defined conduct, "
            "subject to accessible notice, human review, appeal, and expiration."
        ),
    )


def validate_measurement_target(field_strength_v_m: float, target_v_m: float = 0.1) -> bool:
    if not isinstance(field_strength_v_m, (int, float)) or not isfinite(field_strength_v_m):
        raise QuadraticVoiceValidationError(
            "field_strength_v_m must be a finite numeric measurement."
        )
    if not isinstance(target_v_m, (int, float)) or not isfinite(target_v_m) or target_v_m <= 0:
        raise QuadraticVoiceValidationError("target_v_m must be a finite positive measurement.")
    return field_strength_v_m < target_v_m
