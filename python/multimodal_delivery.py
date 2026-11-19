from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from math import isfinite
from threading import RLock


class Mode(str, Enum):
    TEXT = "text"
    SPEECH_ASSISTED = "speech_assisted"
    ASYNCHRONOUS_TEXT = "asynchronous_text"


class ReceiptState(str, Enum):
    PREPARED = "prepared"
    SUBMISSION_STARTED = "submission_started"
    CHANNEL_ACCEPTED = "channel_accepted"
    CONFIRMED = "delivery_confirmed"
    FAILED = "failed"
    UNKNOWN = "unknown"


def require_text(value: str, field: str, maximum: int) -> None:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{field} must be non-empty text.")
    if len(value) > maximum:
        raise ValueError(f"{field} exceeds the configured limit.")


def require_time(value: float) -> None:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError("Time must be numeric elapsed seconds.")
    if not isfinite(value) or value < 0:
        raise ValueError("Time must be finite and non-negative.")


@dataclass(frozen=True)
class DeliveryScope:
    text: str
    revision: int
    recipient: str
    mode: Mode
    channel: str
    purpose: str

    def __post_init__(self) -> None:
        require_text(self.text, "Content", 100_000)
        require_text(self.recipient, "Resolved recipient", 1_024)
        require_text(self.channel, "Channel", 256)
        require_text(self.purpose, "Purpose", 1_024)
        if type(self.revision) is not int or self.revision < 0:
            raise ValueError("Revision must be a non-negative integer.")
        if not isinstance(self.mode, Mode):
            raise ValueError("Use a supported presentation mode.")


@dataclass(frozen=True)
class ReceiptEvidence:
    source: str
    criterion: str

    def __post_init__(self) -> None:
        require_text(self.source, "Evidence source", 1_024)
        require_text(self.criterion, "Delivery criterion", 2_048)


@dataclass(frozen=True)
class DeliverySnapshot:
    state: ReceiptState
    submission_started_s: float | None
    channel_accepted_s: float | None
    confirmed_s: float | None
    acknowledged_s: float | None
    receipt_evidence: ReceiptEvidence | None
    acknowledgement_evidence: ReceiptEvidence | None


class DeliveryAttempt:
    """One local attempt; no transport, persistence, or automatic retry."""

    def __init__(self, scope: DeliveryScope) -> None:
        if not isinstance(scope, DeliveryScope):
            raise ValueError("Use a validated delivery scope.")
        self._scope = scope
        self._lock = RLock()
        self._state = ReceiptState.PREPARED
        self._approved = False
        self._last_time = 0.0
        self._started: float | None = None
        self._accepted: float | None = None
        self._confirmed: float | None = None
        self._acknowledged: float | None = None
        self._receipt: ReceiptEvidence | None = None
        self._ack_evidence: ReceiptEvidence | None = None

    def review(self) -> DeliveryScope:
        return self._scope

    def approve(
        self, reviewed_scope: DeliveryScope, *, explicit: bool
    ) -> None:
        with self._lock:
            self._approved = False
            if self._state != ReceiptState.PREPARED:
                raise PermissionError("This attempt has already started.")
            if explicit is not True or reviewed_scope != self._scope:
                raise PermissionError("Exact-scope approval is required.")
            self._approved = True

    def cancel_approval(self) -> None:
        with self._lock:
            self._approved = False

    def _check_time(self, elapsed_s: float) -> None:
        require_time(elapsed_s)
        if elapsed_s < self._last_time:
            raise ValueError("Observation time cannot move backwards.")

    def begin_submission(self, elapsed_s: float) -> DeliveryScope:
        with self._lock:
            self._check_time(elapsed_s)
            if self._state != ReceiptState.PREPARED or not self._approved:
                raise PermissionError("Review and approve this attempt first.")
            self._approved = False
            self._started = elapsed_s
            self._last_time = elapsed_s
            self._state = ReceiptState.SUBMISSION_STARTED
            return self._scope

    def channel_accepted(self, elapsed_s: float) -> None:
        with self._lock:
            self._check_time(elapsed_s)
            if self._state not in {
                ReceiptState.SUBMISSION_STARTED,
                ReceiptState.UNKNOWN,
            }:
                raise ValueError("Channel acceptance is not valid here.")
            if self._accepted is not None:
                raise ValueError("Channel acceptance already recorded.")
            self._accepted = elapsed_s
            self._last_time = elapsed_s
            self._state = ReceiptState.CHANNEL_ACCEPTED

    def confirm_delivery(
        self, elapsed_s: float, evidence: ReceiptEvidence
    ) -> None:
        if not isinstance(evidence, ReceiptEvidence):
            raise ValueError("Documented delivery evidence is required.")
        with self._lock:
            self._check_time(elapsed_s)
            if self._state not in {
                ReceiptState.SUBMISSION_STARTED,
                ReceiptState.CHANNEL_ACCEPTED,
                ReceiptState.UNKNOWN,
            }:
                raise ValueError("Delivery confirmation is not valid here.")
            self._confirmed = elapsed_s
            self._receipt = evidence
            self._last_time = elapsed_s
            self._state = ReceiptState.CONFIRMED

    def mark_unknown(self, elapsed_s: float) -> None:
        with self._lock:
            self._check_time(elapsed_s)
            if self._state not in {
                ReceiptState.SUBMISSION_STARTED,
                ReceiptState.CHANNEL_ACCEPTED,
                ReceiptState.UNKNOWN,
            }:
                raise ValueError("Uncertainty is not valid here.")
            self._last_time = elapsed_s
            self._state = ReceiptState.UNKNOWN

    def mark_failed(self, elapsed_s: float) -> None:
        with self._lock:
            self._check_time(elapsed_s)
            if self._state not in {
                ReceiptState.SUBMISSION_STARTED,
                ReceiptState.CHANNEL_ACCEPTED,
                ReceiptState.UNKNOWN,
            }:
                raise ValueError("Failure is not valid here.")
            self._last_time = elapsed_s
            self._state = ReceiptState.FAILED

    def acknowledge(
        self, elapsed_s: float, evidence: ReceiptEvidence
    ) -> None:
        if not isinstance(evidence, ReceiptEvidence):
            raise ValueError("Documented acknowledgement evidence is required.")
        with self._lock:
            self._check_time(elapsed_s)
            if self._started is None or self._state == ReceiptState.FAILED:
                raise ValueError("Acknowledgement is not valid here.")
            if self._acknowledged is not None:
                raise ValueError("Acknowledgement already recorded.")
            self._acknowledged = elapsed_s
            self._ack_evidence = evidence
            self._last_time = elapsed_s

    def snapshot(self) -> DeliverySnapshot:
        with self._lock:
            return DeliverySnapshot(
                state=self._state,
                submission_started_s=self._started,
                channel_accepted_s=self._accepted,
                confirmed_s=self._confirmed,
                acknowledged_s=self._acknowledged,
                receipt_evidence=self._receipt,
                acknowledgement_evidence=self._ack_evidence,
            )

    def accessible_status(self) -> str:
        with self._lock:
            messages = {
                ReceiptState.PREPARED: "Prepared. Not submitted.",
                ReceiptState.SUBMISSION_STARTED:
                    "Submission started. Delivery unconfirmed.",
                ReceiptState.CHANNEL_ACCEPTED:
                    "Channel accepted. Delivery unconfirmed.",
                ReceiptState.CONFIRMED:
                    "Delivery confirmed.",
                ReceiptState.FAILED:
                    "Delivery attempt failed. Draft retained.",
                ReceiptState.UNKNOWN:
                    "Delivery unconfirmed. Check before retrying.",
            }
            acknowledgement = (
                " Recipient acknowledgement recorded."
                if self._acknowledged is not None
                else " Recipient acknowledgement not recorded."
            )
            return messages[self._state] + acknowledgement
