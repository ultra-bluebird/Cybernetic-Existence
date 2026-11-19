"""Research-only cache planning.

Run:
    python research/authorization/status_cache_boundaries.py

No network, storage, signing, token validation, or external action.
Times are integer ticks in a declared common clock domain.
"""

from dataclasses import dataclass
from enum import Enum
import unittest


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
ATTRIBUTION_SCOPE = (
    "Document credit and workstream metadata only; not identity, consent, "
    "capability authorization, execution evidence, or legal authority."
)


@dataclass(frozen=True)
class Tick:
    domain: str
    value: int

    def __post_init__(self):
        if not isinstance(self.domain, str) or not self.domain.strip():
            raise ValueError("Clock domain is required.")
        if type(self.value) is not int or self.value < 0:
            raise ValueError("Tick value must be a nonnegative integer.")


def same_clock(*ticks):
    if any(not isinstance(tick, Tick) for tick in ticks):
        raise TypeError("Expected Tick values.")
    if len({tick.domain for tick in ticks}) != 1:
        raise ValueError("Clock conversion must be explicit.")


@dataclass(frozen=True)
class NamedBoundary:
    name: str
    deadline: Tick

    def __post_init__(self):
        if not isinstance(self.name, str) or not self.name.strip():
            raise ValueError("Boundary name is required.")
        if not isinstance(self.deadline, Tick):
            raise TypeError("Boundary deadline must be a Tick.")


@dataclass(frozen=True)
class AssessedExtension:
    maximum_deadline: Tick
    decision_record: str
    reason: str

    def __post_init__(self):
        if not isinstance(self.maximum_deadline, Tick):
            raise TypeError("Extension deadline must be a Tick.")
        for value in (self.decision_record, self.reason):
            if not isinstance(value, str) or not value.strip():
                raise ValueError("Extension provenance is required.")


@dataclass(frozen=True)
class CachePlan:
    assessed_at: Tick
    ordinary_until: Tick
    reusable_until: Tick
    hard_until: Tick | None
    extension_record: str | None


class ReuseState(Enum):
    BEFORE_ASSESSMENT = "before_assessment"
    ORDINARY_REUSE = "ordinary_reuse_window"
    EXTENDED_REUSE = "assessed_extension_window"
    REFRESH_REQUIRED = "refresh_required"
    HARD_LIMIT_REACHED = "hard_limit_reached"


def make_plan(
    assessed_at,
    maximum_age,
    hard_boundaries=(),
    ordinary_boundaries=(),
    extension=None,
):
    if not isinstance(assessed_at, Tick):
        raise TypeError("assessed_at must be a Tick.")
    if type(maximum_age) is not int or maximum_age < 0:
        raise ValueError("A finite nonnegative maximum_age is required.")

    for group in (hard_boundaries, ordinary_boundaries):
        if not isinstance(group, tuple):
            raise TypeError("Boundary groups must be tuples.")
        if any(not isinstance(item, NamedBoundary) for item in group):
            raise TypeError("Invalid boundary.")
        for item in group:
            same_clock(assessed_at, item.deadline)

    ordinary = min(
        [assessed_at.value + maximum_age]
        + [item.deadline.value for item in ordinary_boundaries]
    )
    hard = min(
        (item.deadline.value for item in hard_boundaries),
        default=None,
    )

    candidate = ordinary
    extension_record = None
    if extension is not None:
        if not isinstance(extension, AssessedExtension):
            raise TypeError("Invalid extension.")
        same_clock(assessed_at, extension.maximum_deadline)
        if extension.maximum_deadline.value < ordinary:
            raise ValueError("Extension cannot precede the ordinary deadline.")
        candidate = extension.maximum_deadline.value
        extension_record = extension.decision_record

    reusable = candidate if hard is None else min(candidate, hard)
    domain = assessed_at.domain

    return CachePlan(
        assessed_at=assessed_at,
        ordinary_until=Tick(domain, ordinary),
        reusable_until=Tick(domain, reusable),
        hard_until=None if hard is None else Tick(domain, hard),
        extension_record=extension_record,
    )


def classify_reuse(plan, now):
    if not isinstance(plan, CachePlan) or not isinstance(now, Tick):
        raise TypeError("Expected CachePlan and Tick.")
    same_clock(plan.assessed_at, now)

    if now.value < plan.assessed_at.value:
        return ReuseState.BEFORE_ASSESSMENT
    if plan.hard_until is not None and now.value >= plan.hard_until.value:
        return ReuseState.HARD_LIMIT_REACHED
    if now.value >= plan.reusable_until.value:
        return ReuseState.REFRESH_REQUIRED
    if now.value >= plan.ordinary_until.value:
        return ReuseState.EXTENDED_REUSE
    return ReuseState.ORDINARY_REUSE


class CacheBoundaryTests(unittest.TestCase):
    def tick(self, value):
        return Tick("synthetic-clock", value)

    def test_finite_default_without_other_boundaries(self):
        plan = make_plan(self.tick(10), maximum_age=3)
        self.assertEqual(plan.reusable_until.value, 13)
        self.assertIs(
            classify_reuse(plan, self.tick(13)),
            ReuseState.REFRESH_REQUIRED,
        )

    def test_extension_never_exceeds_hard_limit(self):
        plan = make_plan(
            self.tick(10),
            maximum_age=3,
            hard_boundaries=(
                NamedBoundary("token_expiry", self.tick(15)),
            ),
            extension=AssessedExtension(
                self.tick(20),
                "controlled synthetic extension record",
                "Synthetic independently assessed exception.",
            ),
        )
        self.assertEqual(plan.reusable_until.value, 15)
        self.assertIs(
            classify_reuse(plan, self.tick(14)),
            ReuseState.EXTENDED_REUSE,
        )
        self.assertIs(
            classify_reuse(plan, self.tick(15)),
            ReuseState.HARD_LIMIT_REACHED,
        )

    def test_recheck_can_require_refresh_before_expiry(self):
        plan = make_plan(
            self.tick(10),
            maximum_age=10,
            hard_boundaries=(
                NamedBoundary("token_expiry", self.tick(30)),
            ),
            ordinary_boundaries=(
                NamedBoundary("hold_recheck", self.tick(12)),
            ),
        )
        self.assertIs(
            classify_reuse(plan, self.tick(12)),
            ReuseState.REFRESH_REQUIRED,
        )

    def test_zero_age_disables_reuse(self):
        plan = make_plan(self.tick(10), maximum_age=0)
        self.assertIs(
            classify_reuse(plan, self.tick(10)),
            ReuseState.REFRESH_REQUIRED,
        )

    def test_other_clock_rejected(self):
        plan = make_plan(self.tick(10), maximum_age=3)
        with self.assertRaises(ValueError):
            classify_reuse(plan, Tick("different-clock", 11))

    def test_expired_boundary_prevents_reuse(self):
        plan = make_plan(
            self.tick(10),
            maximum_age=3,
            hard_boundaries=(
                NamedBoundary("already_expired", self.tick(9)),
            ),
        )
        self.assertIs(
            classify_reuse(plan, self.tick(10)),
            ReuseState.HARD_LIMIT_REACHED,
        )


if __name__ == "__main__":
    unittest.main()
