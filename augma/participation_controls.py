# SPDX-License-Identifier: MIT OR Apache-2.0
"""Local Augma participation controls and missing-aware retention summaries."""

from dataclasses import dataclass, replace
from fractions import Fraction
from typing import Optional, Sequence
import unittest


EVENTS = frozenset({
    "realized_invoice_declared",
    "learning_milestone_declared",
    "time_surplus_threshold_declared",
    "scheduled_invitation",
})
OUTCOMES = frozenset({"completed", "confirmed_none", "unknown"})


def require_integer(value: object, name: str, minimum: int = 0) -> int:
    if type(value) is not int or value < minimum:
        raise ValueError(f"{name} must be an integer >= {minimum}")
    return value


def parse_rate(text: str) -> Fraction:
    if not isinstance(text, str) or not text or len(text) > 64:
        raise ValueError("rate must be a nonempty string of at most 64 characters")
    try:
        value = Fraction(text)
    except (ValueError, ZeroDivisionError) as exc:
        raise ValueError("invalid finite rational rate") from exc
    if not 0 <= value <= 1:
        raise ValueError("rate must be between zero and one")
    return value


@dataclass(frozen=True)
class Controls:
    rate: Fraction = Fraction(0)
    paused: bool = False
    invitation_consent: bool = False
    permitted_events: frozenset[str] = frozenset()
    max_invitations_per_window: int = 1
    cooldown_minutes: int = 1440

    def __post_init__(self):
        if type(self.rate) is not Fraction or not 0 <= self.rate <= 1:
            raise ValueError("rate must be a Fraction between zero and one")
        if type(self.paused) is not bool:
            raise ValueError("paused must be Boolean")
        if type(self.invitation_consent) is not bool:
            raise ValueError("invitation_consent must be Boolean")
        if type(self.permitted_events) is not frozenset:
            raise ValueError("permitted_events must be a frozenset")
        if not self.permitted_events <= EVENTS:
            raise ValueError("unsupported event")
        require_integer(
            self.max_invitations_per_window, "max_invitations_per_window"
        )
        require_integer(self.cooldown_minutes, "cooldown_minutes")


@dataclass(frozen=True)
class InvitationContext:
    """Elapsed durations and counts are supplied by a separate local caller.

    No timestamps, participant identity, or event payloads are required.
    The caller must define the reporting window and maintain accurate counts.
    """
    invitations_in_window: int
    minutes_since_last_invitation: Optional[int]

    def __post_init__(self):
        require_integer(self.invitations_in_window, "invitations_in_window")
        if self.minutes_since_last_invitation is not None:
            require_integer(
                self.minutes_since_last_invitation,
                "minutes_since_last_invitation",
            )


def set_rate(controls: Controls, text: str) -> Controls:
    """Changing rate never resumes a paused workflow."""
    return replace(controls, rate=parse_rate(text))


def pause(controls: Controls) -> Controls:
    """Indefinite: no expiry, penalty, reminder, or automatic reactivation."""
    return replace(controls, paused=True)


def resume(controls: Controls, *, explicit_request: bool) -> Controls:
    if explicit_request is not True:
        raise ValueError("resuming requires an explicit participant request")
    return replace(controls, paused=False)


def invitation_status(
    controls: Controls,
    event: str,
    context: InvitationContext,
) -> str:
    if event not in EVENTS:
        raise ValueError("unsupported event")
    if controls.paused:
        return "suppressed_paused"
    if controls.rate == 0:
        return "suppressed_zero_rate"
    if not controls.invitation_consent:
        return "suppressed_no_invitation_consent"
    if event not in controls.permitted_events:
        return "suppressed_event_not_permitted"
    if context.invitations_in_window >= controls.max_invitations_per_window:
        return "suppressed_frequency_cap"
    elapsed = context.minutes_since_last_invitation
    if elapsed is not None and elapsed < controls.cooldown_minutes:
        return "suppressed_cooldown"
    return "invitation_only_no_execution_authorized"


def exact_ratio(numerator: int, denominator: int) -> dict:
    if denominator == 0:
        return {"status": "undefined", "value": None}
    return {
        "status": "defined",
        "value": {
            "numerator": numerator,
            "denominator": denominator,
        },
    }


def participation_summary(outcomes: Sequence[str]) -> dict:
    """One outcome per randomized participant for a prespecified window.

    The caller must establish roster completeness and one-person-one-row.
    Bounds are missing-outcome bounds, not confidence intervals.
    """
    if isinstance(outcomes, (str, bytes)):
        raise ValueError("outcomes must be a sequence of outcome labels")
    counts = {label: 0 for label in OUTCOMES}
    for outcome in outcomes:
        if not isinstance(outcome, str) or outcome not in OUTCOMES:
            raise ValueError("unsupported outcome")
        counts[outcome] += 1

    assigned = sum(counts.values())
    completed = counts["completed"]
    unknown = counts["unknown"]
    known = assigned - unknown

    return {
        "assigned": assigned,
        **counts,
        "known_outcome_coverage": exact_ratio(known, assigned),
        "observed_case_participation": exact_ratio(completed, known),
        "participation_lower_bound": exact_ratio(completed, assigned),
        "participation_upper_bound": exact_ratio(completed + unknown, assigned),
        "bounds_are_confidence_intervals": False,
    }


class ParticipationTests(unittest.TestCase):
    def active_controls(self) -> Controls:
        return Controls(
            rate=Fraction(1, 10),
            invitation_consent=True,
            permitted_events=frozenset({"learning_milestone_declared"}),
        )

    def test_default_is_zero_and_not_consented(self):
        self.assertEqual(Controls().rate, 0)
        self.assertFalse(Controls().invitation_consent)

    def test_zero_and_pause_suppress_all_supported_events(self):
        context = InvitationContext(0, None)
        for event in EVENTS:
            self.assertEqual(
                invitation_status(Controls(), event, context),
                "suppressed_zero_rate",
            )
            self.assertEqual(
                invitation_status(pause(self.active_controls()), event, context),
                "suppressed_paused",
            )

    def test_rate_change_does_not_resume(self):
        controls = pause(self.active_controls())
        changed = set_rate(controls, "0.20")
        self.assertTrue(changed.paused)
        self.assertTrue(controls.paused)
        self.assertEqual(controls.rate, Fraction(1, 10))

    def test_resume_requires_explicit_request(self):
        controls = pause(self.active_controls())
        with self.assertRaises(ValueError):
            resume(controls, explicit_request=False)
        self.assertFalse(resume(controls, explicit_request=True).paused)

    def test_invitation_is_not_execution(self):
        result = invitation_status(
            self.active_controls(),
            "learning_milestone_declared",
            InvitationContext(0, None),
        )
        self.assertEqual(result, "invitation_only_no_execution_authorized")

    def test_caps_and_cooldown(self):
        controls = self.active_controls()
        event = "learning_milestone_declared"
        self.assertEqual(
            invitation_status(controls, event, InvitationContext(1, 2000)),
            "suppressed_frequency_cap",
        )
        self.assertEqual(
            invitation_status(controls, event, InvitationContext(0, 10)),
            "suppressed_cooldown",
        )

    def test_unpermitted_event(self):
        self.assertEqual(
            invitation_status(
                self.active_controls(),
                "realized_invoice_declared",
                InvitationContext(0, None),
            ),
            "suppressed_event_not_permitted",
        )

    def test_missing_outcomes_are_not_failures(self):
        result = participation_summary(["completed", "confirmed_none", "unknown"])
        self.assertEqual(
            result["participation_lower_bound"]["value"],
            {"numerator": 1, "denominator": 3},
        )
        self.assertEqual(
            result["participation_upper_bound"]["value"],
            {"numerator": 2, "denominator": 3},
        )
        self.assertEqual(result["unknown"], 1)

    def test_empty_denominator_is_undefined(self):
        result = participation_summary([])
        self.assertIsNone(result["participation_lower_bound"]["value"])

    def test_invalid_values_rejected(self):
        with self.assertRaises(ValueError):
            InvitationContext(True, None)
        with self.assertRaises(ValueError):
            set_rate(Controls(), "NaN")
        with self.assertRaises(ValueError):
            participation_summary(["paused"])
        with self.assertRaises(ValueError):
            Controls(permitted_events=frozenset({"private_health_inference"}))


if __name__ == "__main__":
    unittest.main()
