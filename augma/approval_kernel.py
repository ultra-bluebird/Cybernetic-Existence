# SPDX-License-Identifier: MIT OR Apache-2.0
"""Bounded local approval model. No persistence or external execution."""

from dataclasses import dataclass, replace
from enum import Enum
from fractions import Fraction
import re
import unittest


VERSION = "1.0.0"
RATE_PATTERN = re.compile(r"(?:0|1|0\.[0-9]{0,5}[1-9])", re.ASCII)
MAX_DENOMINATOR = 1_000_000


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def bounded_text(value: object, name: str) -> str:
    require(isinstance(value, str), f"{name} must be text")
    require(1 <= len(value) <= 256, f"{name} length is invalid")
    require(value == value.strip(), f"{name} must be trimmed")
    require(
        all(ord(char) >= 32 and ord(char) != 127 for char in value),
        f"{name} contains control characters",
    )
    return value


def parse_rate(text: str) -> Fraction:
    """Canonical ASCII decimal: 0, 1, or 0.xxx, no trailing zero.

    At most six fractional digits. Examples: 0.1, 0.125, 0.000001.
    Rejects 0.10, 1.0, fractions, locale commas, signs, and exponents.
    """
    require(isinstance(text, str), "rate must be text")
    require(len(text) <= 8, "rate is too long")
    require(RATE_PATTERN.fullmatch(text) is not None, "noncanonical rate")
    return Fraction(text)


def encode_rate(value: Fraction) -> dict:
    require(type(value) is Fraction, "rate must be Fraction")
    require(0 <= value <= 1, "rate out of range")
    require(
        MAX_DENOMINATOR % value.denominator == 0,
        "rate is not representable with six decimal places",
    )
    return {
        "schema_version": VERSION,
        "numerator": value.numerator,
        "denominator": value.denominator,
    }


def decode_rate(record: dict) -> Fraction:
    require(type(record) is dict, "rate record must be a dictionary")
    require(
        set(record) == {"schema_version", "numerator", "denominator"},
        "unsupported rate fields",
    )
    require(record["schema_version"] == VERSION, "unsupported rate version")
    numerator = record["numerator"]
    denominator = record["denominator"]
    require(type(numerator) is int, "numerator must be an integer")
    require(type(denominator) is int, "denominator must be an integer")
    require(0 <= numerator <= denominator <= MAX_DENOMINATOR, "invalid ratio")
    require(denominator > 0, "denominator must be positive")
    value = Fraction(numerator, denominator)
    require(
        (value.numerator, value.denominator) == (numerator, denominator),
        "ratio must be reduced",
    )
    encode_rate(value)
    return value


class Stage(str, Enum):
    DRAFT = "draft"
    REVIEW = "review"
    APPROVED = "approved"
    SUBMISSION_RECORDED = "submission_recorded"
    UNRESOLVED = "unresolved"
    COMPLETED = "completed"
    FAILED = "failed"


class Event(str, Enum):
    REQUEST_REVIEW = "request_review"
    APPROVE = "approve"
    PAUSE = "pause"
    RESUME = "resume"
    RECORD_SUBMISSION = "record_submission"
    RECORD_UNRESOLVED = "record_unresolved"
    RECORD_COMPLETION = "record_completion"
    RECORD_FAILURE = "record_failure"


@dataclass(frozen=True)
class Terms:
    recipient: str
    amount_minor: int
    currency: str
    schedule: str
    fees_minor: int
    source: str

    def __post_init__(self):
        for name in ("recipient", "schedule", "source"):
            bounded_text(getattr(self, name), name)
        require(
            isinstance(self.currency, str)
            and re.fullmatch(r"[A-Z]{3}", self.currency, re.ASCII) is not None,
            "currency must be three uppercase ASCII letters",
        )
        for name in ("amount_minor", "fees_minor"):
            value = getattr(self, name)
            require(type(value) is int and 0 <= value <= 10**15,
                    f"invalid {name}")


@dataclass(frozen=True)
class Approval:
    terms: Terms
    stage: Stage = Stage.DRAFT
    paused: bool = False
    approved_terms: Terms | None = None

    def __post_init__(self):
        require(type(self.terms) is Terms, "invalid terms")
        require(type(self.stage) is Stage, "invalid stage")
        require(type(self.paused) is bool, "invalid pause value")
        if self.stage is Stage.APPROVED:
            require(not self.paused, "paused approval cannot remain active")
            require(self.approved_terms == self.terms, "approval terms mismatch")
        else:
            require(self.approved_terms is None, "unexpected active approval")


PRE_SUBMISSION = frozenset({Stage.DRAFT, Stage.REVIEW, Stage.APPROVED})
POST_SUBMISSION = frozenset({
    Stage.SUBMISSION_RECORDED, Stage.UNRESOLVED
})


def revise(state: Approval, terms: Terms) -> Approval:
    require(type(state) is Approval, "invalid approval state")
    require(type(terms) is Terms, "invalid replacement terms")
    require(state.stage in PRE_SUBMISSION,
            "submitted terms require reconciliation, not mutation")
    return Approval(terms=terms, paused=state.paused)


def transition(state: Approval, event: Event) -> Approval:
    require(type(state) is Approval, "invalid approval state")
    require(type(event) is Event, "event must be a versioned Event enum")

    if event is Event.PAUSE:
        if state.stage is Stage.APPROVED:
            return Approval(state.terms, Stage.REVIEW, True)
        return replace(state, paused=True)

    if event is Event.RESUME:
        return replace(state, paused=False)

    if event is Event.REQUEST_REVIEW:
        require(state.stage is Stage.DRAFT, "review requires draft")
        return replace(state, stage=Stage.REVIEW)

    if event is Event.APPROVE:
        require(not state.paused, "approval blocked while paused")
        require(state.stage is Stage.REVIEW, "approval requires review")
        return Approval(state.terms, Stage.APPROVED, False, state.terms)

    if event is Event.RECORD_SUBMISSION:
        require(not state.paused, "submission blocked while paused")
        require(state.stage is Stage.APPROVED, "submission requires approval")
        return Approval(state.terms, Stage.SUBMISSION_RECORDED)

    if event is Event.RECORD_UNRESOLVED:
        require(state.stage is Stage.SUBMISSION_RECORDED,
                "unresolved result requires recorded submission")
        return replace(state, stage=Stage.UNRESOLVED)

    if event in {Event.RECORD_COMPLETION, Event.RECORD_FAILURE}:
        require(state.stage in POST_SUBMISSION,
                "provider result requires recorded submission")
        result = (Stage.COMPLETED if event is Event.RECORD_COMPLETION
                  else Stage.FAILED)
        return replace(state, stage=result)

    raise ValueError("unsupported transition")


class KernelTests(unittest.TestCase):
    def terms(self) -> Terms:
        return Terms("Reviewed recipient", 1000, "USD",
                     "One-time proposed action", 0, "Reviewed source")

    def approved(self) -> Approval:
        state = transition(Approval(self.terms()), Event.REQUEST_REVIEW)
        return transition(state, Event.APPROVE)

    def test_rate_round_trip(self):
        for text in ("0", "1", "0.1", "0.125", "0.000001", "0.999999"):
            value = parse_rate(text)
            self.assertEqual(decode_rate(encode_rate(value)), value)

    def test_ambiguous_rates_rejected(self):
        for text in ("0.10", "1.0", ".1", "1/2", "0,1", " 0.1",
                     "+0.1", "1e-1", "NaN", "0.0000001"):
            with self.assertRaises(ValueError):
                parse_rate(text)

    def test_codec_rejects_unreduced_and_boolean(self):
        for numerator, denominator in ((2, 4), (True, 1), (0, 0)):
            with self.assertRaises(ValueError):
                decode_rate({
                    "schema_version": VERSION,
                    "numerator": numerator,
                    "denominator": denominator,
                })

    def test_every_terms_change_invalidates_approval(self):
        changes = {
            "recipient": "Different recipient",
            "amount_minor": 2000,
            "currency": "EUR",
            "schedule": "Different schedule",
            "fees_minor": 100,
            "source": "Different source",
        }
        for field, value in changes.items():
            changed = revise(
                self.approved(), replace(self.terms(), **{field: value})
            )
            self.assertEqual(changed.stage, Stage.DRAFT)
            self.assertIsNone(changed.approved_terms)

    def test_pause_clears_approval_and_resume_does_not_restore_it(self):
        state = transition(self.approved(), Event.PAUSE)
        state = transition(state, Event.RESUME)
        self.assertEqual(state.stage, Stage.REVIEW)
        with self.assertRaises(ValueError):
            transition(state, Event.RECORD_SUBMISSION)

    def test_ambiguous_submission_cannot_retry(self):
        state = transition(self.approved(), Event.RECORD_SUBMISSION)
        state = transition(state, Event.RECORD_UNRESOLVED)
        with self.assertRaises(ValueError):
            transition(state, Event.RECORD_SUBMISSION)
        with self.assertRaises(ValueError):
            revise(state, self.terms())

    def test_reconciliation_can_finish_while_paused(self):
        state = transition(self.approved(), Event.RECORD_SUBMISSION)
        state = transition(state, Event.PAUSE)
        state = transition(state, Event.RECORD_COMPLETION)
        self.assertTrue(state.paused)
        self.assertEqual(state.stage, Stage.COMPLETED)

    def test_invitation_is_not_an_approval_event(self):
        with self.assertRaises(ValueError):
            transition(Approval(self.terms()), "invitation")

    def test_bounded_transition_invariants(self):
        frontier = {Approval(self.terms())}
        seen = set()
        for _ in range(7):
            following = set()
            for state in frontier:
                seen.add(state)
                for event in Event:
                    try:
                        result = transition(state, event)
                    except ValueError:
                        continue
                    if result.stage is Stage.APPROVED:
                        self.assertFalse(result.paused)
                        self.assertEqual(result.approved_terms, result.terms)
                    following.add(result)
            frontier = following - seen


if __name__ == "__main__":
    unittest.main()
