from __future__ import annotations

from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from enum import Enum
from types import MappingProxyType


class PromptKind(str, Enum):
    CLARIFICATION = "clarification"
    REPAIR = "repair"
    INTERPRETATION = "interpretation"
    PAUSE = "pause"
    MODE_CHANGE = "mode_change"


PROMPT_TEXT = MappingProxyType({
    PromptKind.CLARIFICATION: "Would you like clarification?",
    PromptKind.REPAIR: "Would you like to rephrase?",
    PromptKind.INTERPRETATION: "Would you like to check understanding?",
    PromptKind.PAUSE: "Would you like a pause?",
    PromptKind.MODE_CHANGE: "Would another communication mode help?",
})


@dataclass(frozen=True)
class PromptSurface:
    question_text: str
    reason_text: str
    optional: bool = True
    evaluation_encoded: bool = False
    external_delivery: bool = False


@dataclass(frozen=True)
class PromptSelection:
    question_text: str
    status: str = "selected_locally_not_delivered"


class OptionalPrompt:
    """One local suggestion, with no inferred trigger or usage logging."""

    def __init__(self, kind: PromptKind) -> None:
        if not isinstance(kind, PromptKind):
            raise ValueError("Use a reviewed prompt kind.")
        self._kind = kind
        self._enabled = True
        self._visible = False

    def show(self, *, participant_requested: bool) -> PromptSurface:
        if participant_requested is not True or not self._enabled:
            raise PermissionError("A participant request is required.")
        self._visible = True
        return PromptSurface(
            question_text=PROMPT_TEXT[self._kind],
            reason_text="Available when you choose communication support.",
        )

    def accept(self, *, explicit: bool) -> PromptSelection:
        if explicit is not True or not self._visible or not self._enabled:
            raise PermissionError("Review and explicitly choose this prompt.")
        self._visible = False
        return PromptSelection(PROMPT_TEXT[self._kind])

    def decline(self) -> None:
        self._visible = False

    def disable(self) -> None:
        self._visible = False
        self._enabled = False


class RequestKind(str, Enum):
    COMMUNICATION_MODE = "preferred_communication_mode"
    PAUSE = "pause_preference"
    CLARIFICATION = "clarification_preference"


REQUEST_TEXT = MappingProxyType({
    RequestKind.COMMUNICATION_MODE:
        "Would you like to choose a communication mode?",
    RequestKind.PAUSE:
        "Would you like to choose a pause option?",
    RequestKind.CLARIFICATION:
        "Would you like a clarification option?",
})


@dataclass(frozen=True)
class RequestDecision:
    allowed: bool
    question_text: str | None
    optional: bool
    reason_required: bool
    message: str
    fallback: str


def validate_request(candidate: object) -> RequestDecision:
    refusal = RequestDecision(
        allowed=False,
        question_text=None,
        optional=True,
        reason_required=False,
        message=(
            "This companion does not request private system or health "
            "information."
        ),
        fallback=(
            "Continue without disclosure or choose a human-assisted route "
            "that preserves the same privacy boundary."
        ),
    )

    if not isinstance(candidate, Mapping):
        return refusal
    if set(candidate.keys()) != {"kind"}:
        return refusal

    raw_kind = candidate["kind"]
    if type(raw_kind) is not str:
        return refusal

    try:
        kind = RequestKind(raw_kind)
    except ValueError:
        return refusal

    return RequestDecision(
        allowed=True,
        question_text=REQUEST_TEXT[kind],
        optional=True,
        reason_required=False,
        message="You may skip this choice without explaining why.",
        fallback="Use the existing pathway without this companion.",
    )


class Evidence(str, Enum):
    TRANSFER_TRUNCATION = "transfer_truncation_observed"
    VERSION_MISMATCH = "approved_received_version_mismatch"
    REQUIREMENT_CHANGE = "requirement_change_documented"
    REFERENCE_UNAVAILABLE = "required_reference_unavailable"
    RECIPIENT_UNAVAILABLE = "recipient_unavailable_in_agreed_period"
    CONDITIONS_NOT_MET = "agreed_communication_conditions_not_met"


class Attribution(str, Enum):
    PATHWAY = "pathway"
    CONTENT = "content_specification"
    CONTEXT = "interaction_context"
    UNKNOWN = "unknown"


EVIDENCE_CATEGORY = MappingProxyType({
    Evidence.TRANSFER_TRUNCATION: Attribution.PATHWAY,
    Evidence.VERSION_MISMATCH: Attribution.PATHWAY,
    Evidence.REQUIREMENT_CHANGE: Attribution.CONTENT,
    Evidence.REFERENCE_UNAVAILABLE: Attribution.CONTENT,
    Evidence.RECIPIENT_UNAVAILABLE: Attribution.CONTEXT,
    Evidence.CONDITIONS_NOT_MET: Attribution.CONTEXT,
})


@dataclass(frozen=True)
class ReworkObservation:
    evidence: frozenset[Evidence]
    reviewed: bool
    disputed: bool = False
    unresolved: bool = False

    def __post_init__(self) -> None:
        if not isinstance(self.evidence, frozenset):
            raise ValueError("Evidence must be an immutable set.")
        if any(not isinstance(item, Evidence) for item in self.evidence):
            raise ValueError("Unsupported evidence category.")
        if any(
            type(value) is not bool
            for value in (self.reviewed, self.disputed, self.unresolved)
        ):
            raise ValueError("Review flags must be booleans.")

    def labels(self) -> frozenset[Attribution]:
        if not self.reviewed or self.disputed:
            return frozenset({Attribution.UNKNOWN})
        labels = {EVIDENCE_CATEGORY[item] for item in self.evidence}
        if not labels or self.unresolved:
            labels.add(Attribution.UNKNOWN)
        return frozenset(labels)


@dataclass(frozen=True)
class ReworkReport:
    status: str
    reviewed_count: int | None
    unreviewed_count: int | None
    pathway_count: int | None
    content_count: int | None
    context_count: int | None
    unknown_count: int | None
    attribution_coverage: float | None


def rework_report(
    observations: Sequence[ReworkObservation],
    *,
    minimum_reviewed: int,
) -> ReworkReport:
    if type(minimum_reviewed) is not int or minimum_reviewed < 1:
        raise ValueError("Minimum reviewed count must be a positive integer.")
    if any(not isinstance(item, ReworkObservation) for item in observations):
        raise ValueError("Use validated rework observations.")

    reviewed = [item for item in observations if item.reviewed]

    if len(reviewed) < minimum_reviewed:
        return ReworkReport(
            status="suppressed_insufficient_reviewed_events",
            reviewed_count=None,
            unreviewed_count=None,
            pathway_count=None,
            content_count=None,
            context_count=None,
            unknown_count=None,
            attribution_coverage=None,
        )

    label_sets = [item.labels() for item in reviewed]
    counts = {
        category: sum(category in labels for labels in label_sets)
        for category in Attribution
    }
    supported = sum(
        bool(labels - {Attribution.UNKNOWN})
        for labels in label_sets
    )

    return ReworkReport(
        status="aggregate_descriptive_not_causal",
        reviewed_count=len(reviewed),
        unreviewed_count=len(observations) - len(reviewed),
        pathway_count=counts[Attribution.PATHWAY],
        content_count=counts[Attribution.CONTENT],
        context_count=counts[Attribution.CONTEXT],
        unknown_count=counts[Attribution.UNKNOWN],
        attribution_coverage=supported / len(reviewed),
    )
