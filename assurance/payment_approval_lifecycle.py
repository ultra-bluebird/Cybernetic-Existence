# SPDX-License-Identifier: MIT OR Apache-2.0
"""Sequential payment-approval model. No provider calls or fund custody."""

from dataclasses import dataclass, replace
from enum import Enum


ENGINE_VERSION = "1.0.0"


class Stage(Enum):
    DRAFT = "draft"
    REVIEW = "review"
    APPROVED = "approved"
    SUBMITTED = "submitted"
    PENDING = "pending"
    COMPLETED = "completed"
    CANCELLED = "cancelled"
    FAILED = "failed"
    REFUND_REQUESTED = "refund_requested"


class Event(Enum):
    REVIEW = "request_review"
    APPROVE = "record_approval"
    SUBMIT = "record_submission_attempt"
    TIMEOUT = "record_ambiguous_response"
    PROCESSING = "record_processing"
    COMPLETE = "record_completed"
    NO_OPERATION = "record_confirmed_no_operation"
    CANCEL = "request_cancellation"
    CANCEL_CONFIRMED = "record_provider_cancellation"
    REFUND = "request_refund"


@dataclass(frozen=True)
class Terms:
    recipient: str
    amount_minor: int
    currency: str
    schedule: str
    fees_minor: int
    source: str


@dataclass(frozen=True)
class Payment:
    terms: Terms
    stage: Stage = Stage.DRAFT
    approved_terms: Terms | None = None
    submission_attempts: int = 0
    cancel_requested: bool = False
    pending_reason: str | None = None


def change_terms(state, terms):
    if type(state) is not Payment or type(terms) is not Terms:
        raise ValueError("typed state and terms required")
    if state.stage not in {Stage.DRAFT, Stage.REVIEW, Stage.APPROVED}:
        raise ValueError("submitted or terminal terms cannot be changed")
    return Payment(terms)


def step(state, event):
    if type(state) is not Payment or type(event) is not Event:
        raise ValueError("typed state and event required")

    current = state.stage

    if event is Event.REVIEW and current is Stage.DRAFT:
        return replace(state, stage=Stage.REVIEW)

    if event is Event.APPROVE and current is Stage.REVIEW:
        return replace(
            state, stage=Stage.APPROVED, approved_terms=state.terms
        )

    if (
        event is Event.SUBMIT
        and current is Stage.APPROVED
        and state.approved_terms == state.terms
        and state.submission_attempts == 0
    ):
        return replace(
            state,
            stage=Stage.SUBMITTED,
            approved_terms=None,
            submission_attempts=1,
        )

    if event is Event.CANCEL:
        if current in {Stage.DRAFT, Stage.REVIEW, Stage.APPROVED}:
            return replace(
                state,
                stage=Stage.CANCELLED,
                approved_terms=None,
                cancel_requested=True,
            )
        if current in {Stage.SUBMITTED, Stage.PENDING}:
            return replace(state, cancel_requested=True)

    if (
        event in {Event.TIMEOUT, Event.PROCESSING}
        and current in {Stage.SUBMITTED, Stage.PENDING}
    ):
        return replace(
            state,
            stage=Stage.PENDING,
            pending_reason=(
                "unresolved"
                if event is Event.TIMEOUT
                else "processing_reported"
            ),
        )

    if event is Event.COMPLETE:
        if current in {Stage.COMPLETED, Stage.REFUND_REQUESTED}:
            return state
        if current in {Stage.SUBMITTED, Stage.PENDING}:
            return replace(
                state, stage=Stage.COMPLETED, pending_reason=None
            )

    if (
        event is Event.NO_OPERATION
        and current in {Stage.SUBMITTED, Stage.PENDING}
    ):
        return replace(state, stage=Stage.FAILED, pending_reason=None)

    if (
        event is Event.CANCEL_CONFIRMED
        and state.cancel_requested
        and current in {Stage.SUBMITTED, Stage.PENDING}
    ):
        return replace(state, stage=Stage.CANCELLED, pending_reason=None)

    if event is Event.REFUND and current is Stage.COMPLETED:
        return replace(state, stage=Stage.REFUND_REQUESTED)

    raise ValueError("transition_not_permitted")
