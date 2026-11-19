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


def require_time(value: float) -> None:
    if (
        isinstance(value, bool)
        or not isinstance(value, (int, float))
        or not isfinite(value)
        or value < 0
    ):
        raise ValueError("Time must be finite non-negative elapsed seconds.")


def require_count(value: int, field: str) -> None:
    if type(value) is not int or value < 0:
        raise ValueError(f"{field} must be a non-negative integer.")


class Party(str, Enum):
    FIRST = "first"
    SECOND = "second"


@dataclass(frozen=True)
class IntroductionProposal:
    text: str
    recipients: tuple[str, str]
    channel: str
    purpose: str
    expires_s: float

    def __post_init__(self) -> None:
        require_text(self.text, "Introduction text", 100_000)
        if type(self.recipients) is not tuple or len(self.recipients) != 2:
            raise ValueError("Provide exactly two resolved recipients.")
        for recipient in self.recipients:
            require_text(recipient, "Recipient", 1024)
        if self.recipients[0] == self.recipients[1]:
            raise ValueError("Recipients must be distinct.")
        require_text(self.channel, "Channel", 1024)
        require_text(self.purpose, "Purpose")
        require_time(self.expires_s)


class MutualIntroduction:
    """Exact-proposal approvals supplied by separately authorized parties."""

    def __init__(self, proposal: IntroductionProposal) -> None:
        if not isinstance(proposal, IntroductionProposal):
            raise ValueError("Use a validated proposal.")
        self._proposal = proposal
        self._approvals: set[Party] = set()
        self._closed = False
        self._last_time = 0.0
        self._lock = RLock()

    def _check(self, now_s: float) -> None:
        require_time(now_s)
        if now_s < self._last_time:
            raise ValueError("The local clock cannot move backwards.")
        self._last_time = now_s
        if now_s >= self._proposal.expires_s:
            self._closed = True
            self._approvals.clear()
        if self._closed:
            raise PermissionError("Introduction not proceeding.")

    def review(self, now_s: float) -> IntroductionProposal:
        with self._lock:
            self._check(now_s)
            return self._proposal

    def approve(
        self,
        party: Party,
        reviewed: IntroductionProposal,
        *,
        explicit: bool,
        now_s: float,
    ) -> None:
        with self._lock:
            self._check(now_s)
            if not isinstance(party, Party):
                raise ValueError("Use a supported party designation.")
            if explicit is not True or reviewed != self._proposal:
                raise PermissionError("Exact-proposal approval is required.")
            self._approvals.add(party)

    def cancel_approval(self, party: Party) -> None:
        if not isinstance(party, Party):
            raise ValueError("Use a supported party designation.")
        with self._lock:
            self._approvals.discard(party)

    def decline(self) -> None:
        with self._lock:
            self._approvals.clear()
            self._closed = True

    def prepare(self, now_s: float) -> IntroductionProposal:
        with self._lock:
            self._check(now_s)
            if self._approvals != {Party.FIRST, Party.SECOND}:
                raise PermissionError("Both parties must approve.")
            self._approvals.clear()
            self._closed = True
            return self._proposal


@dataclass(frozen=True)
class ApprovedSummary:
    text: str
    scope: str
    expires_s: float
    status: str = "approved_locally_not_shared"


class NoCaptureSummary:
    """Participant-entered points only; no conversation ingestion."""

    def __init__(self) -> None:
        self._points: tuple[str, ...] = ()
        self._draft = ""
        self._scope = ""
        self._expiry = 0.0
        self._approved = False
        self._last_time = 0.0
        self._lock = RLock()

    def _check_time(self, now_s: float) -> None:
        require_time(now_s)
        if now_s < self._last_time:
            raise ValueError("The local clock cannot move backwards.")
        self._last_time = now_s

    def edit(
        self,
        *,
        points: tuple[str, ...],
        text: str,
        scope: str,
        expires_s: float,
        now_s: float,
    ) -> None:
        if type(points) is not tuple or len(points) > 50:
            raise ValueError("Supply up to fifty participant-entered points.")
        for point in points:
            require_text(point, "Lesson point")
        require_text(text, "Summary", 100_000)
        require_text(scope, "Scope")
        require_time(expires_s)

        with self._lock:
            self._check_time(now_s)
            if expires_s <= now_s:
                raise ValueError("Expiry must be in the future.")
            self._points = points
            self._draft = text
            self._scope = scope
            self._expiry = expires_s
            self._approved = False

    def approve(
        self,
        *,
        reviewed_text: str,
        reviewed_scope: str,
        reviewed_expiry_s: float,
        explicit: bool,
        now_s: float,
    ) -> None:
        with self._lock:
            self._check_time(now_s)
            if now_s >= self._expiry:
                self.delete()
                raise PermissionError("Summary unavailable or expired.")
            if (
                explicit is not True
                or reviewed_text != self._draft
                or reviewed_scope != self._scope
                or reviewed_expiry_s != self._expiry
            ):
                raise PermissionError("Review exact content, scope, and expiry.")
            self._points = ()
            self._approved = True

    def read_approved(self, now_s: float) -> ApprovedSummary:
        with self._lock:
            self._check_time(now_s)
            if now_s >= self._expiry:
                self.delete()
                raise PermissionError("Summary unavailable or expired.")
            if not self._approved:
                raise PermissionError("Summary has not been approved.")
            return ApprovedSummary(self._draft, self._scope, self._expiry)

    def delete(self) -> None:
        with self._lock:
            self._points = ()
            self._draft = ""
            self._scope = ""
            self._expiry = 0.0
            self._approved = False


@dataclass(frozen=True)
class ReuseBatch:
    guide_title: str
    revision: str
    scope: str
    declared_uses: int
    corroborated_uses: int
    successful_outcomes: int
    unsuccessful_outcomes: int
    outcome_unknown: int

    def __post_init__(self) -> None:
        for field in ("guide_title", "revision", "scope"):
            require_text(getattr(self, field), field)
        for field in (
            "declared_uses", "corroborated_uses", "successful_outcomes",
            "unsuccessful_outcomes", "outcome_unknown",
        ):
            require_count(getattr(self, field), field)
        if self.corroborated_uses > self.declared_uses:
            raise ValueError("Corroboration cannot exceed declared uses.")
        if (
            self.successful_outcomes
            + self.unsuccessful_outcomes
            + self.outcome_unknown
            != self.declared_uses
        ):
            raise ValueError("Outcome categories must partition declared uses.")


def reuse_report(
    batch: ReuseBatch,
    *,
    privacy_review_approved: bool,
    distinct_contributor_threshold_verified: bool,
    minimum_uses: int,
    minimum_nonzero_cell: int,
) -> dict[str, object]:
    if not isinstance(batch, ReuseBatch):
        raise ValueError("Use a validated reuse batch.")
    for value in (minimum_uses, minimum_nonzero_cell):
        if type(value) is not int or value < 1:
            raise ValueError("Thresholds must be positive integers.")

    cells = (
        batch.corroborated_uses,
        batch.declared_uses - batch.corroborated_uses,
        batch.successful_outcomes,
        batch.unsuccessful_outcomes,
        batch.outcome_unknown,
    )
    permitted = (
        privacy_review_approved is True
        and distinct_contributor_threshold_verified is True
        and batch.declared_uses >= minimum_uses
        and all(
            value == 0 or value >= minimum_nonzero_cell
            for value in cells
        )
    )
    if not permitted:
        return {"status": "aggregate_release_withheld"}

    evaluated = batch.successful_outcomes + batch.unsuccessful_outcomes
    return {
        "status": "declared_reuse_not_unique_user_or_causal_measure",
        "guide_title": batch.guide_title,
        "revision": batch.revision,
        "scope": batch.scope,
        "declared_uses": batch.declared_uses,
        "corroborated_uses": batch.corroborated_uses,
        "successful_outcomes": batch.successful_outcomes,
        "unsuccessful_outcomes": batch.unsuccessful_outcomes,
        "outcome_unknown": batch.outcome_unknown,
        "reported_success_among_evaluated":
            batch.successful_outcomes / evaluated if evaluated else None,
    }
