from __future__ import annotations

from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from enum import Enum


class ObservationClass(str, Enum):
    EVIDENCE = "factual_or_evidence_issue"
    ACCESSIBILITY = "accessibility_barrier"
    PRIVACY = "privacy_or_consent_concern"
    SAFETY = "unsafe_or_unauthorized_behavior"
    UNCERTAINTY = "uncertainty_or_scope_problem"
    WORKFLOW = "communication_or_workflow_problem"


class ReviewState(str, Enum):
    PENDING = "pending"
    REVIEWED = "reviewed"
    DISPUTED = "disputed"


class Actionability(str, Enum):
    ACTIONABLE = "actionable"
    NOT_CURRENTLY = "not_currently_actionable"
    UNKNOWN = "unknown"


class ActionState(str, Enum):
    NONE = "none_recorded"
    PROPOSED = "proposed"
    COMPLETED = "completed"


class ReworkState(str, Enum):
    YES = "yes"
    NO = "no"
    UNKNOWN = "unknown"


@dataclass(frozen=True)
class Feedback:
    observation_class: ObservationClass
    review_state: ReviewState
    actionability: Actionability
    action_state: ActionState
    rework_indicated: ReworkState

    def __post_init__(self) -> None:
        typed_fields = (
            (self.observation_class, ObservationClass),
            (self.review_state, ReviewState),
            (self.actionability, Actionability),
            (self.action_state, ActionState),
            (self.rework_indicated, ReworkState),
        )
        if any(not isinstance(value, kind) for value, kind in typed_fields):
            raise ValueError("Use declared feedback states.")
        if self.review_state == ReviewState.PENDING:
            if (
                self.actionability != Actionability.UNKNOWN
                or self.action_state != ActionState.NONE
                or self.rework_indicated != ReworkState.UNKNOWN
            ):
                raise ValueError(
                    "Pending observations cannot claim reviewed findings."
                )


@dataclass(frozen=True)
class InputDecision:
    accepted: bool
    feedback: Feedback | None
    message: str
    alternative_path: str


def validate_feedback(candidate: object) -> InputDecision:
    refused = InputDecision(
        accepted=False,
        feedback=None,
        message=(
            "This structured route accepts only declared feedback fields "
            "and states. Private identity or system data are not required."
        ),
        alternative_path=(
            "Continue through an accessible human-review route "
            "without private disclosure."
        ),
    )
    expected = {
        "observation_class",
        "review_state",
        "actionability",
        "action_state",
        "rework_indicated",
    }

    if not isinstance(candidate, Mapping):
        return refused
    if set(candidate.keys()) != expected:
        return refused
    if any(type(candidate[field]) is not str for field in expected):
        return refused

    try:
        feedback = Feedback(
            observation_class=ObservationClass(candidate["observation_class"]),
            review_state=ReviewState(candidate["review_state"]),
            actionability=Actionability(candidate["actionability"]),
            action_state=ActionState(candidate["action_state"]),
            rework_indicated=ReworkState(candidate["rework_indicated"]),
        )
    except (ValueError, TypeError):
        return refused

    return InputDecision(
        accepted=True,
        feedback=feedback,
        message="Structured feedback accepted for local review.",
        alternative_path="An accessible human-review route remains available.",
    )


def fraction(numerator: int, denominator: int) -> float | None:
    return numerator / denominator if denominator else None


def feedback_report(records: Sequence[Feedback]) -> dict[str, object]:
    if any(not isinstance(record, Feedback) for record in records):
        raise ValueError("Use validated feedback records.")

    reviewed = [
        record for record in records
        if record.review_state == ReviewState.REVIEWED
    ]
    actionable = [
        record for record in reviewed
        if record.actionability == Actionability.ACTIONABLE
    ]
    rework_assessed = [
        record for record in reviewed
        if record.rework_indicated != ReworkState.UNKNOWN
    ]

    return {
        "status": "internal_aggregate_not_release_approved",
        "observation_count": len(records),
        "observation_class_counts": {
            kind.value: sum(
                record.observation_class == kind for record in records
            )
            for kind in ObservationClass
        },
        "review_state_counts": {
            state.value: sum(
                record.review_state == state for record in records
            )
            for state in ReviewState
        },
        "review_completion_fraction": fraction(len(reviewed), len(records)),
        "reviewed_actionability_counts": {
            state.value: sum(
                record.actionability == state for record in reviewed
            )
            for state in Actionability
        },
        "actionable_among_reviewed_fraction":
            fraction(len(actionable), len(reviewed)),
        "actionable_action_counts": {
            state.value: sum(
                record.action_state == state for record in actionable
            )
            for state in ActionState
        },
        "completed_action_fraction": fraction(
            sum(record.action_state == ActionState.COMPLETED
                for record in actionable),
            len(actionable),
        ),
        "reviewed_rework_counts": {
            state.value: sum(
                record.rework_indicated == state for record in reviewed
            )
            for state in ReworkState
        },
        "rework_indication_fraction": fraction(
            sum(record.rework_indicated == ReworkState.YES
                for record in rework_assessed),
            len(rework_assessed),
        ),
        "individual_ranking": False,
        "credibility_or_eligibility_established": False,
        "issue_resolution_established": False,
    }
