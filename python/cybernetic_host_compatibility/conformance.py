from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from secrets import token_urlsafe
from time import monotonic
from typing import Final


MAX_MESSAGE_BYTES: Final[int] = 512
MAX_INTENTS_PER_SECOND: Final[int] = 12
SESSION_TIMEOUT_SECONDS: Final[float] = 60.0

ALLOWED_INTENTS: Final[frozenset[str]] = frozenset(
    {
        "focus-next",
        "focus-previous",
        "activate",
        "back",
        "home",
        "repeat",
        "increase-volume",
        "decrease-volume",
        "increase-text-size",
        "decrease-text-size",
        "toggle-contrast",
        "start-over",
        "request-help",
        "end-session",
    }
)


class SessionStatus(str, Enum):
    IDLE = "idle"
    ACTIVE = "active"
    ENDED = "ended"


class IntentStatus(str, Enum):
    ACCEPTED = "accepted"
    REJECTED = "rejected"
    SESSION_ENDED = "session-ended"
    FALLBACK_AVAILABLE = "fallback-available"


@dataclass(frozen=True)
class IntentRequest:
    protocol: str
    session_nonce: str
    intent: str
    sequence: int
    issued_at_monotonic_ms: int

    def serialized_size_hint(self) -> int:
        return (
            len(self.protocol)
            + len(self.session_nonce)
            + len(self.intent)
            + len(str(self.sequence))
            + len(str(self.issued_at_monotonic_ms))
            + 96
        )


@dataclass(frozen=True)
class IntentResponse:
    status: IntentStatus
    feedback: str


@dataclass
class CompatibilitySession:
    nonce: str
    created_at: float
    last_activity_at: float
    next_sequence: int = 0
    accepted_intents_in_window: int = 0
    window_started_at: float = 0.0
    status: SessionStatus = SessionStatus.ACTIVE

    @classmethod
    def begin(cls, now: float | None = None) -> "CompatibilitySession":
        timestamp = monotonic() if now is None else now
        return cls(
            nonce=token_urlsafe(24),
            created_at=timestamp,
            last_activity_at=timestamp,
            window_started_at=timestamp,
        )

    def handle(
        self,
        request: IntentRequest,
        now: float | None = None,
    ) -> IntentResponse:
        timestamp = monotonic() if now is None else now

        if self.status is not SessionStatus.ACTIVE:
            return IntentResponse(
                status=IntentStatus.SESSION_ENDED,
                feedback="Optional assistive session has ended. Standard controls remain available.",
            )

        if timestamp - self.last_activity_at > SESSION_TIMEOUT_SECONDS:
            self.end()
            return IntentResponse(
                status=IntentStatus.FALLBACK_AVAILABLE,
                feedback="Optional assistive session timed out. Standard controls remain available.",
            )

        if request.serialized_size_hint() > MAX_MESSAGE_BYTES:
            return IntentResponse(
                status=IntentStatus.REJECTED,
                feedback="The request is too large. Standard controls remain available.",
            )

        if request.protocol != "chcs.intent.v1":
            return IntentResponse(
                status=IntentStatus.REJECTED,
                feedback="The requested compatibility protocol is not supported.",
            )

        if request.session_nonce != self.nonce:
            return IntentResponse(
                status=IntentStatus.REJECTED,
                feedback="The session reference does not match the active local session.",
            )

        if request.sequence != self.next_sequence:
            return IntentResponse(
                status=IntentStatus.REJECTED,
                feedback="The request sequence is invalid. Standard controls remain available.",
            )

        if request.intent not in ALLOWED_INTENTS:
            return IntentResponse(
                status=IntentStatus.REJECTED,
                feedback="This control request is not permitted.",
            )

        if timestamp - self.window_started_at >= 1.0:
            self.window_started_at = timestamp
            self.accepted_intents_in_window = 0

        if self.accepted_intents_in_window >= MAX_INTENTS_PER_SECOND:
            return IntentResponse(
                status=IntentStatus.REJECTED,
                feedback="Control requests are arriving too quickly. Standard controls remain available.",
            )

        self.next_sequence += 1
        self.accepted_intents_in_window += 1
        self.last_activity_at = timestamp

        if request.intent in {"start-over", "end-session"}:
            self.end()
            return IntentResponse(
                status=IntentStatus.SESSION_ENDED,
                feedback="The optional assistive session has ended and this screen has been reset.",
            )

        return IntentResponse(
            status=IntentStatus.ACCEPTED,
            feedback="The requested screen action has been accepted.",
        )

    def end(self) -> None:
        self.nonce = ""
        self.next_sequence = 0
        self.accepted_intents_in_window = 0
        self.status = SessionStatus.ENDED


@dataclass(frozen=True)
class ConformanceAttempt:
    mode: str
    task: str
    successful: bool
    augmentation_failure_case: bool = False
    fallback_successful: bool = False


def compatibility_score(attempts: list[ConformanceAttempt]) -> float:
    if not attempts:
        raise ValueError("At least one conformance attempt is required.")

    successful = sum(attempt.successful for attempt in attempts)
    return successful / len(attempts)


def fallback_score(attempts: list[ConformanceAttempt]) -> float:
    failure_cases = [
        attempt for attempt in attempts if attempt.augmentation_failure_case
    ]

    if not failure_cases:
        raise ValueError("At least one augmentation-failure case is required.")

    successful_fallbacks = sum(
        attempt.fallback_successful for attempt in failure_cases
    )

    return successful_fallbacks / len(failure_cases)


def meets_baseline_conformance(attempts: list[ConformanceAttempt]) -> bool:
    return compatibility_score(attempts) >= 0.95 and fallback_score(attempts) == 1.0
