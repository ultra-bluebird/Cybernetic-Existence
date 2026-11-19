"""Research-only conjunctive procedural assessment.

Run:
    python research/governance/product_valued_assessment.py

No token verification, persistence, signing, or external actions.
"""

from dataclasses import dataclass
from enum import Enum
from itertools import combinations
import unittest


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
ATTRIBUTION_SCOPE = (
    "Document credit and workstream metadata only; not identity, consent, "
    "capability authorization, execution evidence, or legal authority."
)


class Action(Enum):
    DISCLOSE_RECORD = "disclose_record"
    ASSIST_COMMUNICATION = "assist_communication"


class Finding(Enum):
    STATUS_STALE = "status_stale"
    REVIEW_PENDING = "review_pending"
    DISCLOSURE_HOLD = "disclosure_hold"
    GRANT_EXPIRED = "grant_expired"
    AUTHORITY_UNRESOLVED = "authority_unresolved"
    UNKNOWN_ACTION = "unknown_action"


class Restriction(Enum):
    DO_NOT_RELY_ON_GRANT = "do_not_rely_on_grant"
    DISCLOSURE_HELD = "disclosure_held"


class Duty(Enum):
    REFRESH_STATUS = "refresh_status"
    INDEPENDENT_REVIEW = "independent_review"
    OBTAIN_CURRENT_BASIS = "obtain_current_basis"
    RESOLVE_AUTHORITY = "resolve_authority"
    CLARIFY_ACTION = "clarify_action"
    ASSESS_SEPARATE_CONTINUITY = "assess_separate_continuity"


def enum_set(value, expected):
    if not isinstance(value, frozenset):
        raise TypeError("Expected frozenset.")
    if any(not isinstance(item, expected) for item in value):
        raise TypeError(f"Expected {expected.__name__} members.")


@dataclass(frozen=True)
class Rule:
    actions: frozenset[Action]
    requires: frozenset[Finding]
    restrictions: frozenset[Restriction]
    unresolved: frozenset[Finding]
    duties: frozenset[Duty]

    def __post_init__(self):
        enum_set(self.actions, Action)
        enum_set(self.requires, Finding)
        enum_set(self.restrictions, Restriction)
        enum_set(self.unresolved, Finding)
        enum_set(self.duties, Duty)
        if not self.actions or not self.requires:
            raise ValueError("Rules require actions and antecedent findings.")


@dataclass(frozen=True)
class SafetyProfile:
    contract_version: str
    rules: tuple[Rule, ...]

    def __post_init__(self):
        if self.contract_version != "research-findings-v1":
            raise ValueError("Unsupported finding contract.")
        if not isinstance(self.rules, tuple):
            raise TypeError("Rules must be an immutable tuple.")
        if any(not isinstance(rule, Rule) for rule in self.rules):
            raise TypeError("Invalid rule.")


@dataclass(frozen=True)
class Assessment:
    recognized_action: bool
    findings: frozenset[Finding]
    restrictions: frozenset[Restriction]
    unresolved: frozenset[Finding]
    duties: frozenset[Duty]
    notice: str


def assess(profile, action, findings):
    if not isinstance(profile, SafetyProfile):
        raise TypeError("Expected SafetyProfile.")
    enum_set(findings, Finding)

    recognized = isinstance(action, Action)
    if not recognized:
        return Assessment(
            recognized_action=False,
            findings=findings | frozenset({Finding.UNKNOWN_ACTION}),
            restrictions=frozenset(),
            unresolved=frozenset({Finding.UNKNOWN_ACTION}),
            duties=frozenset({Duty.CLARIFY_ACTION}),
            notice="Research only; unknown action is not authorized.",
        )

    restrictions = set()
    unresolved = set()
    duties = set()

    for rule in profile.rules:
        if action in rule.actions and rule.requires <= findings:
            restrictions.update(rule.restrictions)
            unresolved.update(rule.unresolved)
            duties.update(rule.duties)

    return Assessment(
        recognized_action=True,
        findings=findings,
        restrictions=frozenset(restrictions),
        unresolved=frozenset(unresolved),
        duties=frozenset(duties),
        notice=(
            "Research assessment only. Absence of restrictions does not "
            "establish permission, legal authority, or substantive fairness."
        ),
    )


def reference_profile():
    all_actions = frozenset(Action)
    empty = frozenset()

    return SafetyProfile(
        "research-findings-v1",
        (
            Rule(
                all_actions,
                frozenset({Finding.STATUS_STALE}),
                empty,
                frozenset({Finding.STATUS_STALE}),
                frozenset({Duty.REFRESH_STATUS}),
            ),
            Rule(
                all_actions,
                frozenset({Finding.REVIEW_PENDING}),
                empty,
                frozenset({Finding.REVIEW_PENDING}),
                frozenset({Duty.INDEPENDENT_REVIEW}),
            ),
            Rule(
                all_actions,
                frozenset({
                    Finding.STATUS_STALE,
                    Finding.REVIEW_PENDING,
                }),
                empty,
                frozenset({
                    Finding.STATUS_STALE,
                    Finding.REVIEW_PENDING,
                }),
                frozenset({Duty.ASSESS_SEPARATE_CONTINUITY}),
            ),
            Rule(
                frozenset({Action.DISCLOSE_RECORD}),
                frozenset({Finding.DISCLOSURE_HOLD}),
                frozenset({Restriction.DISCLOSURE_HELD}),
                empty,
                frozenset({Duty.INDEPENDENT_REVIEW}),
            ),
            Rule(
                all_actions,
                frozenset({Finding.GRANT_EXPIRED}),
                frozenset({Restriction.DO_NOT_RELY_ON_GRANT}),
                empty,
                frozenset({
                    Duty.OBTAIN_CURRENT_BASIS,
                    Duty.ASSESS_SEPARATE_CONTINUITY,
                }),
            ),
            Rule(
                all_actions,
                frozenset({Finding.AUTHORITY_UNRESOLVED}),
                empty,
                frozenset({Finding.AUTHORITY_UNRESOLVED}),
                frozenset({Duty.RESOLVE_AUTHORITY}),
            ),
        ),
    )


def subsets(values):
    values = tuple(values)
    for size in range(len(values) + 1):
        for selected in combinations(values, size):
            yield frozenset(selected)


class ProductAssessmentTests(unittest.TestCase):
    def setUp(self):
        self.profile = reference_profile()

    def test_stale_and_hold_are_preserved(self):
        result = assess(
            self.profile,
            Action.DISCLOSE_RECORD,
            frozenset({
                Finding.STATUS_STALE,
                Finding.DISCLOSURE_HOLD,
            }),
        )
        self.assertIn(Restriction.DISCLOSURE_HELD, result.restrictions)
        self.assertIn(Finding.STATUS_STALE, result.unresolved)
        self.assertIn(Duty.REFRESH_STATUS, result.duties)

    def test_conjunctive_rule_adds_a_distinct_duty(self):
        stale = assess(
            self.profile,
            Action.DISCLOSE_RECORD,
            frozenset({Finding.STATUS_STALE}),
        )
        combined = assess(
            self.profile,
            Action.DISCLOSE_RECORD,
            frozenset({
                Finding.STATUS_STALE,
                Finding.REVIEW_PENDING,
            }),
        )
        self.assertNotIn(Duty.ASSESS_SEPARATE_CONTINUITY, stale.duties)
        self.assertIn(Duty.ASSESS_SEPARATE_CONTINUITY, combined.duties)

    def test_disclosure_hold_does_not_become_a_general_service_hold(self):
        result = assess(
            self.profile,
            Action.ASSIST_COMMUNICATION,
            frozenset({Finding.DISCLOSURE_HOLD}),
        )
        self.assertNotIn(Restriction.DISCLOSURE_HELD, result.restrictions)

    def test_unknown_action_is_explicitly_unresolved(self):
        result = assess(self.profile, "unregistered-action", frozenset())
        self.assertFalse(result.recognized_action)
        self.assertIn(Finding.UNKNOWN_ACTION, result.unresolved)

    def test_additive_rules_preserve_effects_exhaustively(self):
        states = tuple(subsets(Finding))
        for action in Action:
            for smaller in states:
                left = assess(self.profile, action, smaller)
                for larger in states:
                    if smaller <= larger:
                        right = assess(self.profile, action, larger)
                        self.assertLessEqual(
                            left.restrictions, right.restrictions
                        )
                        self.assertLessEqual(
                            left.unresolved, right.unresolved
                        )
                        self.assertLessEqual(left.duties, right.duties)


if __name__ == "__main__":
    unittest.main()
