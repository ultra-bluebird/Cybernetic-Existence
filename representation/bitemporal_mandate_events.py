"""Research-only bitemporal mandate projection.

Run:
    python research/representation/bitemporal_mandate_events.py

No networking, persistence, signatures, or external actions.
Policy: review effective AND recorded by the acceptance deadline qualifies.
A later record cannot automatically revive a lapsed permission.
"""

from dataclasses import dataclass
from enum import Enum
import unittest


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
ATTRIBUTION_SCOPE = (
    "Document credit and workstream metadata only; not identity, "
    "consent, capability authorization, or execution evidence."
)


@dataclass(frozen=True)
class Tick:
    domain: str
    value: int

    def __post_init__(self):
        if not isinstance(self.domain, str) or not self.domain.strip():
            raise ValueError("A clock domain is required.")
        if type(self.value) is not int or self.value < 0:
            raise ValueError("Tick value must be a nonnegative integer.")


def comparable(*ticks):
    if any(not isinstance(t, Tick) for t in ticks):
        raise TypeError("Expected Tick values.")
    if len({t.domain for t in ticks}) != 1:
        raise ValueError("Cross-domain comparison requires explicit conversion.")


class EventKind(Enum):
    REVIEW_ACCEPTED = "review_accepted"
    WITHDRAWAL = "withdrawal"
    SUPERSESSION = "supersession"


@dataclass(frozen=True)
class MandateEvent:
    kind: EventKind
    occurred: Tick
    recorded: Tick
    effective: Tick
    assessor_role: str
    basis_record: str

    def __post_init__(self):
        if not isinstance(self.kind, EventKind):
            raise TypeError("Invalid event kind.")
        comparable(self.occurred, self.recorded, self.effective)
        if self.occurred.value > self.recorded.value:
            raise ValueError("Occurrence cannot follow its recording.")
        for text in (self.assessor_role, self.basis_record):
            if not isinstance(text, str) or not text.strip():
                raise ValueError("Assessor role and basis record are required.")


@dataclass(frozen=True)
class MandateTerms:
    start: Tick
    end: Tick
    review_due: Tick
    grace_ticks: int = 0

    def __post_init__(self):
        comparable(self.start, self.end, self.review_due)
        if not self.start.value <= self.review_due.value < self.end.value:
            raise ValueError("Require start <= review_due < end.")
        if type(self.grace_ticks) is not int or self.grace_ticks < 0:
            raise ValueError("grace_ticks must be a nonnegative integer.")

    def acceptance_deadline(self):
        return min(
            self.end.value,
            self.review_due.value + self.grace_ticks,
        )


@dataclass(frozen=True)
class Projection:
    local_temporal_conditions_hold: bool
    chain_temporal_conditions_hold: bool
    reasons: tuple[str, ...]
    duties: tuple[str, ...]
    notice: str


def project(terms, events, effective_at, known_at, parent=None):
    if not isinstance(terms, MandateTerms):
        raise TypeError("Expected MandateTerms.")
    if not isinstance(events, tuple):
        raise TypeError("events must be a tuple.")
    if any(not isinstance(e, MandateEvent) for e in events):
        raise TypeError("Invalid event.")
    comparable(terms.start, effective_at, known_at)
    if effective_at.value > known_at.value:
        raise ValueError("This projection does not forecast future states.")

    if parent is not None:
        if not isinstance(parent, tuple) or len(parent) != 2:
            raise TypeError("parent must contain terms and events.")
        parent_terms, parent_events = parent
        if not isinstance(parent_terms, MandateTerms):
            raise TypeError("Invalid parent terms.")
        comparable(terms.start, parent_terms.start)
        if not (
            parent_terms.start.value <= terms.start.value
            and terms.end.value <= parent_terms.end.value
        ):
            raise ValueError("Child time window exceeds parent.")

    known_events = []
    for event in events:
        comparable(terms.start, event.recorded)
        if event.effective.value < terms.start.value:
            raise ValueError("Event effect precedes mandate start.")
        if event.recorded.value <= known_at.value:
            known_events.append(event)

    now = effective_at.value
    cutoff = terms.acceptance_deadline()
    reasons = []
    duties = set()

    reviewed = any(
        event.kind is EventKind.REVIEW_ACCEPTED
        and event.occurred.value <= cutoff
        and event.recorded.value <= cutoff
        and event.effective.value <= min(now, cutoff)
        and event.effective.value < terms.end.value
        for event in known_events
    )

    if not terms.start.value <= now < terms.end.value:
        reasons.append("outside_effective_interval")

    if now >= terms.review_due.value and not reviewed:
        duties.add("escalate_uncompleted_review")

    if now >= cutoff and not reviewed:
        reasons.append("review_acceptance_deadline_missed")
        duties.add("notify_represented_party_of_lapse")

    for event in known_events:
        if event.kind in (EventKind.WITHDRAWAL, EventKind.SUPERSESSION):
            duties.add("provide_accessible_notice_of_pending_or_effective_change")
            if event.effective.value <= now:
                reasons.append(event.kind.value)

    local = not reasons
    parent_active = True
    if parent is not None:
        parent_projection = project(
            parent[0], parent[1], effective_at, known_at
        )
        parent_active = parent_projection.chain_temporal_conditions_hold
        if not parent_active:
            reasons.append("parent_temporal_basis_unavailable")
            duties.add("notify_party_and_delegate_of_parent_change")

    chain = local and parent_active
    if not chain:
        duties.add("offer_separately_authorized_continuity_assistance")

    return Projection(
        local_temporal_conditions_hold=local,
        chain_temporal_conditions_hold=chain,
        reasons=tuple(reasons),
        duties=tuple(sorted(duties)),
        notice=(
            "Temporal research projection only; no legal or operational "
            "authority is created."
        ),
    )


class EventProjectionTests(unittest.TestCase):
    def tick(self, value):
        return Tick("synthetic-clock", value)

    def setUp(self):
        self.terms = MandateTerms(
            self.tick(0), self.tick(20), self.tick(5)
        )

    def event(self, kind, occurred, recorded, effective):
        return MandateEvent(
            kind,
            self.tick(occurred),
            self.tick(recorded),
            self.tick(effective),
            "synthetic independent assessor",
            "controlled synthetic basis record",
        )

    def test_review_exactly_at_deadline_qualifies(self):
        events = (
            self.event(EventKind.REVIEW_ACCEPTED, 5, 5, 5),
        )
        result = project(
            self.terms, events, self.tick(6), self.tick(6)
        )
        self.assertTrue(result.chain_temporal_conditions_hold)

    def test_late_record_does_not_revive(self):
        events = (
            self.event(EventKind.REVIEW_ACCEPTED, 4, 6, 4),
        )
        result = project(
            self.terms, events, self.tick(7), self.tick(7)
        )
        self.assertFalse(result.chain_temporal_conditions_hold)

    def test_future_effective_withdrawal(self):
        events = (
            self.event(EventKind.WITHDRAWAL, 1, 1, 3),
        )
        before = project(
            self.terms, events, self.tick(2), self.tick(2)
        )
        after = project(
            self.terms, events, self.tick(3), self.tick(3)
        )
        self.assertTrue(before.chain_temporal_conditions_hold)
        self.assertFalse(after.chain_temporal_conditions_hold)

    def test_known_as_of_excludes_later_record(self):
        events = (
            self.event(EventKind.WITHDRAWAL, 1, 4, 2),
        )
        earlier_knowledge = project(
            self.terms, events, self.tick(2), self.tick(2)
        )
        later_knowledge = project(
            self.terms, events, self.tick(2), self.tick(4)
        )
        self.assertTrue(earlier_knowledge.chain_temporal_conditions_hold)
        self.assertFalse(later_knowledge.chain_temporal_conditions_hold)

    def test_parent_lapse_stops_child_temporal_chain(self):
        child = MandateTerms(
            self.tick(1), self.tick(15), self.tick(10)
        )
        result = project(
            child, (), self.tick(6), self.tick(6),
            parent=(self.terms, ()),
        )
        self.assertTrue(result.local_temporal_conditions_hold)
        self.assertFalse(result.chain_temporal_conditions_hold)

    def test_cross_domain_query_rejected(self):
        with self.assertRaises(ValueError):
            project(
                self.terms, (), Tick("other-clock", 2), self.tick(2)
            )

    def test_fixed_expiry_is_not_extended_by_review(self):
        events = (
            self.event(EventKind.REVIEW_ACCEPTED, 4, 4, 4),
        )
        result = project(
            self.terms, events, self.tick(20), self.tick(20)
        )
        self.assertFalse(result.chain_temporal_conditions_hold)


if __name__ == "__main__":
    unittest.main()
