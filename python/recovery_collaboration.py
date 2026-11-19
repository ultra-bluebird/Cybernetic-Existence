from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from math import isfinite
from threading import RLock


def require_text(value: str, field: str, maximum: int = 4096) -> None:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{field} must be non-empty text.")
    if len(value) > maximum:
        raise ValueError(f"{field} exceeds the configured limit.")


def require_seconds(value: float, field: str) -> None:
    if (
        isinstance(value, bool)
        or not isinstance(value, (int, float))
        or not isfinite(value)
        or value < 0
    ):
        raise ValueError(f"{field} must be finite non-negative seconds.")


class InterruptClass(str, Enum):
    ROUTINE = "routine"
    TIME_SENSITIVE = "time_sensitive"
    ACCESS_CRITICAL = "access_critical"
    EMERGENCY = "emergency"


class Routing(str, Enum):
    ALLOW = "allow_through_declared_route"
    DEFER = "defer_without_discarding"


@dataclass(frozen=True)
class FocusPolicy:
    start_s: float
    duration_s: float
    allow_time_sensitive: bool
    essential_route: str
    emergency_route: str

    def __post_init__(self) -> None:
        require_seconds(self.start_s, "Start")
        require_seconds(self.duration_s, "Duration")
        if self.duration_s <= 0:
            raise ValueError("Focus duration must be positive.")
        if not isfinite(self.start_s + self.duration_s):
            raise ValueError("Focus end must be finite.")
        if type(self.allow_time_sensitive) is not bool:
            raise ValueError("Time-sensitive permission must be boolean.")
        require_text(self.essential_route, "Essential-contact route")
        require_text(self.emergency_route, "Emergency route")


class FocusWindow:
    """Local routing advice; does not suppress or send notifications."""

    def __init__(self, policy: FocusPolicy) -> None:
        if not isinstance(policy, FocusPolicy):
            raise ValueError("Use a validated focus policy.")
        self._policy = policy
        self._ended = False
        self._last_time = 0.0
        self._lock = RLock()

    def _check_time(self, now_s: float) -> None:
        require_seconds(now_s, "Current time")
        if now_s < self._last_time:
            raise ValueError("The local clock cannot move backwards.")
        self._last_time = now_s

    def active(self, now_s: float) -> bool:
        with self._lock:
            self._check_time(now_s)
            return (
                not self._ended
                and self._policy.start_s <= now_s
                < self._policy.start_s + self._policy.duration_s
            )

    def route(self, kind: InterruptClass, now_s: float) -> Routing:
        if not isinstance(kind, InterruptClass):
            raise ValueError("Use a declared interruption class.")
        with self._lock:
            protected = self.active(now_s)
            if not protected:
                return Routing.ALLOW
            if kind in {
                InterruptClass.ACCESS_CRITICAL,
                InterruptClass.EMERGENCY,
            }:
                return Routing.ALLOW
            if (
                kind == InterruptClass.TIME_SENSITIVE
                and self._policy.allow_time_sensitive
            ):
                return Routing.ALLOW
            return Routing.DEFER

    def end(self) -> None:
        with self._lock:
            self._ended = True


class RequestKind(str, Enum):
    PAUSE = "pause"
    MODE_CHANGE = "mode_change"


class CommunicationMode(str, Enum):
    TEXT = "text"
    SPEECH_ASSISTED = "speech_assisted"
    ASYNCHRONOUS = "asynchronous_text"
    HUMAN_ASSISTED = "human_assisted"


@dataclass(frozen=True)
class InteractionRequest:
    kind: RequestKind
    authored_text: str
    requested_mode: CommunicationMode | None = None

    def __post_init__(self) -> None:
        if not isinstance(self.kind, RequestKind):
            raise ValueError("Use a supported request kind.")
        require_text(self.authored_text, "Authored wording")
        if self.kind == RequestKind.MODE_CHANGE:
            if not isinstance(self.requested_mode, CommunicationMode):
                raise ValueError("A mode-change request requires a mode.")
        elif self.requested_mode is not None:
            raise ValueError("Pause requests do not require a mode.")


@dataclass(frozen=True)
class PreparedRequest:
    request: InteractionRequest
    recipient: str
    channel: str
    status: str = "prepared_not_notified"


def prepare_request(
    request: InteractionRequest,
    *,
    reviewed_request: InteractionRequest,
    recipient: str,
    channel: str,
    explicit: bool,
) -> PreparedRequest:
    if not isinstance(request, InteractionRequest):
        raise ValueError("Use a validated interaction request.")
    require_text(recipient, "Resolved recipient", 1024)
    require_text(channel, "Channel", 1024)
    if explicit is not True or reviewed_request != request:
        raise PermissionError("Review and approve the exact request.")
    return PreparedRequest(request, recipient, channel)


@dataclass(frozen=True)
class TaskHandoff:
    state: str
    open_questions: tuple[str, ...]
    next_steps: tuple[str, ...]
    requester_context: str
    uncertainty_or_contingency: str

    def __post_init__(self) -> None:
        for field in (
            "state", "requester_context", "uncertainty_or_contingency"
        ):
            require_text(getattr(self, field), field)
        for field in ("open_questions", "next_steps"):
            values = getattr(self, field)
            if type(values) is not tuple or len(values) > 20:
                raise ValueError(f"{field} must be a bounded immutable tuple.")
            for value in values:
                require_text(value, field)
        if not self.next_steps:
            raise ValueError("Declare a next step or explicitly state none.")


@dataclass(frozen=True)
class PreparedHandoff:
    handoff: TaskHandoff
    recipient: str
    channel: str
    status: str = "prepared_not_delivered"
    ownership_transferred: bool = False


def prepare_handoff(
    handoff: TaskHandoff,
    *,
    reviewed_handoff: TaskHandoff,
    recipient: str,
    channel: str,
    shared_content_confirmed: bool,
    explicit: bool,
) -> PreparedHandoff:
    if not isinstance(handoff, TaskHandoff):
        raise ValueError("Use a validated handoff.")
    require_text(recipient, "Resolved recipient", 1024)
    require_text(channel, "Channel", 1024)
    if (
        explicit is not True
        or shared_content_confirmed is not True
        or reviewed_handoff != handoff
    ):
        raise PermissionError(
            "Review exact handoff content and confirm it is shareable."
        )
    return PreparedHandoff(handoff, recipient, channel)
