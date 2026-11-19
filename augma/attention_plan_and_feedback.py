# SPDX-License-Identifier: MIT OR Apache-2.0
"""Local attention planning and non-conditional feedback routing."""

from dataclasses import dataclass
from enum import Enum
import unittest


VERSION = "1.0.0"


def integer(value, name, minimum=0, maximum=1440):
    if type(value) is not int or not minimum <= value <= maximum:
        raise ValueError(f"{name}: integer in [{minimum}, {maximum}] required")


@dataclass(frozen=True)
class Interval:
    start: int
    end: int

    def __post_init__(self):
        integer(self.start, "start")
        integer(self.end, "end")
        if self.start >= self.end:
            raise ValueError("interval must have positive duration")


def overlaps(first, second):
    return first.start < second.end and second.start < first.end


@dataclass(frozen=True)
class PlanRequest:
    available: tuple[Interval, ...]
    protected: tuple[Interval, ...]
    occupied: tuple[Interval, ...]
    session_minutes: int
    recovery_buffer_minutes: int
    contribution_cap_minutes: int
    paused: bool

    def __post_init__(self):
        for name in ("available", "protected", "occupied"):
            collection = getattr(self, name)
            if type(collection) is not tuple:
                raise ValueError(f"{name}: immutable tuple required")
            if any(type(item) is not Interval for item in collection):
                raise ValueError(f"{name}: typed intervals required")
            if len(collection) > 100:
                raise ValueError(f"{name}: too many intervals")
        integer(self.session_minutes, "session_minutes", 1)
        integer(self.recovery_buffer_minutes, "recovery_buffer_minutes")
        integer(self.contribution_cap_minutes, "contribution_cap_minutes")
        if type(self.paused) is not bool:
            raise ValueError("paused must be Boolean")


def propose_session(request):
    """Return an in-memory proposal, never a booking or approval.

    Offsets refer to one explicitly selected 1440-minute planning grid.
    Timezone conversion and daylight-saving-day handling are out of scope.
    session_minutes includes preparation, delivery, and follow-up.
    """
    if type(request) is not PlanRequest:
        raise ValueError("typed request required")

    base = {
        "engine_version": VERSION,
        "booking_authority": "not_granted",
        "contribution_authority": "not_granted",
        "clinical_recovery": "not_assessed",
    }
    if request.paused:
        return {**base, "status": "suppressed_paused", "session": None}
    if request.session_minutes > request.contribution_cap_minutes:
        return {**base, "status": "exceeds_chosen_cap", "session": None}

    duration = request.session_minutes
    buffer = request.recovery_buffer_minutes
    barriers = request.protected + request.occupied

    for available in sorted(request.available, key=lambda item: item.start):
        first_start = available.start + buffer
        last_start = available.end - buffer - duration

        for start in range(first_start, last_start + 1):
            session = Interval(start, start + duration)
            reserved = Interval(start - buffer, start + duration + buffer)
            if any(overlaps(reserved, barrier) for barrier in barriers):
                continue
            return {
                **base,
                "status": "proposal_only",
                "session": {"start": session.start, "end": session.end},
                "buffered_interval": {
                    "start": reserved.start, "end": reserved.end
                },
                "actual_minutes_completed": "not_established",
            }

    return {**base, "status": "no_matching_slot", "session": None}


class FeedbackMode(Enum):
    OPTIONAL_ATTRIBUTED = "optional_attributed"
    OPTIONAL_ANONYMOUS = "optional_anonymous"
    NO_PROACTIVE_RESEARCH_REQUEST = "no_proactive_research_request"


class FeedbackChoice(Enum):
    PROVIDE = "provide"
    DECLINE = "decline"
    UNDECIDED = "undecided"


def feedback_route(mode, choice, anonymous_channel_reviewed=False):
    if type(mode) is not FeedbackMode or type(choice) is not FeedbackChoice:
        raise ValueError("typed feedback mode and choice required")
    if type(anonymous_channel_reviewed) is not bool:
        raise ValueError("anonymous_channel_reviewed must be Boolean")

    result = {
        "engine_version": VERSION,
        "aid_access": "unchanged",
        "ordinary_support": "unchanged",
        "complaint_and_correction_route": "must_remain_available",
        "publication_authority": "not_granted",
    }
    if mode is FeedbackMode.NO_PROACTIVE_RESEARCH_REQUEST:
        return {**result, "research_route": "no_proactive_request"}
    if choice is not FeedbackChoice.PROVIDE:
        return {**result, "research_route": "no_submission_requested"}
    if mode is FeedbackMode.OPTIONAL_ANONYMOUS:
        return {
            **result,
            "research_route": (
                "anonymous_channel_eligible_for_separate_submission"
                if anonymous_channel_reviewed
                else "anonymous_channel_review_required"
            ),
        }
    return {
        **result,
        "research_route": "attributed_channel_eligible_for_separate_submission",
    }


class AttentionTests(unittest.TestCase):
    def request(self, paused=False):
        return PlanRequest(
            available=(Interval(540, 660),),
            protected=(Interval(540, 570),),
            occupied=(),
            session_minutes=30,
            recovery_buffer_minutes=10,
            contribution_cap_minutes=30,
            paused=paused,
        )

    def test_buffer_avoids_protected_time(self):
        result = propose_session(self.request())
        self.assertEqual(result["session"], {"start": 580, "end": 610})
        self.assertEqual(
            result["buffered_interval"], {"start": 570, "end": 620}
        )

    def test_pause_suppresses_proposal(self):
        self.assertEqual(
            propose_session(self.request(True))["status"],
            "suppressed_paused",
        )

    def test_no_slot_is_not_squeezed(self):
        request = PlanRequest(
            (Interval(600, 630),), (), (), 30, 10, 30, False
        )
        self.assertEqual(propose_session(request)["status"], "no_matching_slot")

    def test_feedback_decline_preserves_aid(self):
        for mode in FeedbackMode:
            result = feedback_route(mode, FeedbackChoice.DECLINE)
            self.assertEqual(result["aid_access"], "unchanged")
            self.assertEqual(result["ordinary_support"], "unchanged")

    def test_anonymous_label_requires_review(self):
        result = feedback_route(
            FeedbackMode.OPTIONAL_ANONYMOUS, FeedbackChoice.PROVIDE
        )
        self.assertEqual(
            result["research_route"], "anonymous_channel_review_required"
        )

    def test_boolean_time_rejected(self):
        with self.assertRaises(ValueError):
            Interval(True, 60)


if __name__ == "__main__":
    unittest.main()
