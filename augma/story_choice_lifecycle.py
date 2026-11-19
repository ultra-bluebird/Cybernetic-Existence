# SPDX-License-Identifier: MIT OR Apache-2.0
"""Local story-choice lifecycle; no publication, storage, or takedown execution."""

from dataclasses import dataclass, replace
from datetime import datetime
from enum import Enum
import unittest


VERSION = "1.0.0"


class Purpose(Enum):
    DRAFTING = "drafting"
    PUBLICATION = "publication"
    TRANSLATION = "translation"
    LATER_REUSE = "later_reuse"


class Placement(Enum):
    NONE = "none"
    QUEUED = "queued"
    SUBMISSION_UNRESOLVED = "submission_unresolved"
    PUBLISHED_REPORTED = "published_reported"
    STOPPED_BEFORE_SUBMISSION = "stopped_before_submission"
    REMOVAL_PENDING = "removal_pending"
    CONTROLLED_REMOVAL_REPORTED = "controlled_removal_reported"


class ThirdParty(Enum):
    NOT_ASSESSED = "not_assessed"
    REQUEST_SENT = "request_sent"
    REMOVAL_REPORTED = "removal_reported"
    UNRESOLVED = "unresolved"


def aware(value, name):
    if type(value) is not datetime or value.utcoffset() is None:
        raise ValueError(f"{name}: timezone-aware datetime required")


@dataclass(frozen=True)
class StoryState:
    revision: int
    channel: str
    granted_purposes: frozenset[Purpose]
    consent_expires_at: datetime | None
    withdrawn: bool = False
    material_review_pending: bool = False
    approved_revision: int | None = None
    approved_channel: str | None = None
    placement: Placement = Placement.NONE
    third_party: ThirdParty = ThirdParty.NOT_ASSESSED

    def __post_init__(self):
        if type(self.revision) is not int or self.revision < 1:
            raise ValueError("positive revision required")
        if type(self.channel) is not str or self.channel not in {
            "controlled_web", "controlled_print", "controlled_report"
        }:
            raise ValueError("unsupported channel")
        if type(self.granted_purposes) is not frozenset:
            raise ValueError("immutable purpose set required")
        if any(type(purpose) is not Purpose for purpose in self.granted_purposes):
            raise ValueError("typed purposes required")
        if self.consent_expires_at is not None:
            aware(self.consent_expires_at, "consent expiry")
        elif self.granted_purposes:
            raise ValueError("granted purposes require an explicit expiry")
        if type(self.withdrawn) is not bool:
            raise ValueError("withdrawn must be Boolean")
        if type(self.material_review_pending) is not bool:
            raise ValueError("material review state must be Boolean")
        if type(self.placement) is not Placement:
            raise ValueError("typed placement required")
        if type(self.third_party) is not ThirdParty:
            raise ValueError("typed third-party state required")
        if (self.approved_revision is None) != (self.approved_channel is None):
            raise ValueError("approval revision and channel must appear together")
        if self.approved_revision is not None:
            if (
                type(self.approved_revision) is not int
                or self.approved_revision != self.revision
                or self.approved_channel != self.channel
                or self.withdrawn
                or self.material_review_pending
            ):
                raise ValueError("approval must match current reviewed scope")


def publication_assessment(state, now):
    if type(state) is not StoryState:
        raise ValueError("typed story state required")
    aware(now, "now")
    reasons = []
    if state.withdrawn:
        reasons.append("withdrawn")
    if Purpose.PUBLICATION not in state.granted_purposes:
        reasons.append("publication_consent_absent")
    if state.consent_expires_at is None or now >= state.consent_expires_at:
        reasons.append("consent_absent_or_expired")
    if state.material_review_pending:
        reasons.append("material_review_pending")
    if state.approved_revision != state.revision:
        reasons.append("exact_content_approval_absent")
    if state.approved_channel != state.channel:
        reasons.append("exact_channel_approval_absent")
    if state.placement not in {Placement.NONE, Placement.QUEUED}:
        reasons.append("placement_requires_reconciliation")

    return {
        "engine_version": VERSION,
        "status": (
            "blocked_for_local_workflow" if reasons
            else "eligible_for_separate_authoritative_dispatch_review"
        ),
        "reasons": reasons,
        "external_action_authorized": False,
        "ordinary_support": "unchanged",
    }


def approve_current_scope(state):
    if type(state) is not StoryState:
        raise ValueError("typed state required")
    if state.withdrawn or state.material_review_pending:
        raise ValueError("current scope is not eligible for approval recording")
    return replace(
        state,
        approved_revision=state.revision,
        approved_channel=state.channel,
    )


def withdraw(state):
    if type(state) is not StoryState:
        raise ValueError("typed state required")
    placement = state.placement
    if placement in {Placement.NONE, Placement.QUEUED}:
        placement = Placement.STOPPED_BEFORE_SUBMISSION
    elif placement is Placement.PUBLISHED_REPORTED:
        placement = Placement.REMOVAL_PENDING
    # An unresolved submission stays unresolved until reconciled.
    return replace(
        state,
        withdrawn=True,
        granted_purposes=frozenset(),
        approved_revision=None,
        approved_channel=None,
        placement=placement,
    )


def propose_changed_scope(state, new_channel):
    if type(state) is not StoryState:
        raise ValueError("typed state required")
    if state.placement not in {
        Placement.NONE, Placement.QUEUED, Placement.STOPPED_BEFORE_SUBMISSION
    }:
        raise ValueError("use a separate draft; reconcile the existing placement")
    return replace(
        state,
        revision=state.revision + 1,
        channel=new_channel,
        granted_purposes=frozenset(),
        consent_expires_at=None,
        approved_revision=None,
        approved_channel=None,
        material_review_pending=True,
        placement=Placement.NONE,
    )


def report_controlled_removal(state):
    if type(state) is not StoryState:
        raise ValueError("typed state required")
    if state.placement is not Placement.REMOVAL_PENDING:
        raise ValueError("controlled removal was not pending")
    return replace(state, placement=Placement.CONTROLLED_REMOVAL_REPORTED)


class LifecycleTests(unittest.TestCase):
    def state(self, placement=Placement.NONE):
        return StoryState(
            revision=1,
            channel="controlled_web",
            granted_purposes=frozenset({Purpose.PUBLICATION}),
            consent_expires_at=datetime.fromisoformat("2026-12-01T00:00:00+00:00"),
            placement=placement,
        )

    def now(self):
        return datetime.fromisoformat("2026-11-09T15:00:00+00:00")

    def test_consent_does_not_supply_approval(self):
        result = publication_assessment(self.state(), self.now())
        self.assertIn("exact_content_approval_absent", result["reasons"])

    def test_eligible_assessment_is_not_authority(self):
        state = approve_current_scope(self.state())
        result = publication_assessment(state, self.now())
        self.assertEqual(
            result["status"],
            "eligible_for_separate_authoritative_dispatch_review",
        )
        self.assertFalse(result["external_action_authorized"])

    def test_withdrawal_stops_local_queue_and_preserves_support(self):
        state = withdraw(approve_current_scope(self.state(Placement.QUEUED)))
        self.assertEqual(state.placement, Placement.STOPPED_BEFORE_SUBMISSION)
        self.assertEqual(
            publication_assessment(state, self.now())["ordinary_support"],
            "unchanged",
        )

    def test_published_withdrawal_does_not_claim_removal(self):
        state = withdraw(self.state(Placement.PUBLISHED_REPORTED))
        self.assertEqual(state.placement, Placement.REMOVAL_PENDING)
        self.assertEqual(state.third_party, ThirdParty.NOT_ASSESSED)

    def test_unresolved_submission_is_not_safe_to_retry(self):
        state = withdraw(self.state(Placement.SUBMISSION_UNRESOLVED))
        self.assertEqual(state.placement, Placement.SUBMISSION_UNRESOLVED)
        self.assertIn(
            "placement_requires_reconciliation",
            publication_assessment(state, self.now())["reasons"],
        )

    def test_change_invalidates_old_scope(self):
        state = propose_changed_scope(
            approve_current_scope(self.state()), "controlled_report"
        )
        self.assertEqual(state.revision, 2)
        self.assertIsNone(state.approved_revision)
        self.assertFalse(state.granted_purposes)
        self.assertTrue(state.material_review_pending)

    def test_controlled_removal_does_not_recall_third_party_copies(self):
        state = report_controlled_removal(
            withdraw(self.state(Placement.PUBLISHED_REPORTED))
        )
        self.assertEqual(
            state.placement, Placement.CONTROLLED_REMOVAL_REPORTED
        )
        self.assertEqual(state.third_party, ThirdParty.NOT_ASSESSED)


if __name__ == "__main__":
    unittest.main()
