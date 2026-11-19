"""Research-only bounded restriction-renewal assessment.

Run:
    python research/restrictions/bounded_renewal_assessment.py

No legal authority, token issuance, persistence, or external action.
Policy values in tests are synthetic, not recommended legal thresholds.
"""

from dataclasses import dataclass
from enum import Enum
import unittest


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
ATTRIBUTION_SCOPE = (
    "Document credit and workstream metadata only; not identity, consent, "
    "capability authorization, execution evidence, or legal authority."
)


class Condition(Enum):
    AUTHORITY = "authority"
    PURPOSE = "legitimate_purpose"
    EVIDENCE = "evidence"
    NECESSITY = "necessity"
    ALTERNATIVES = "alternatives"
    PROPORTIONALITY = "proportionality"
    DURATION = "duration"
    REVIEW = "review"


class AssessmentState(Enum):
    SUPPORTED = "supported"
    UNSUPPORTED = "unsupported"
    UNRESOLVED = "unresolved"


@dataclass(frozen=True)
class Period:
    scope: str
    clock_domain: str
    start: int
    end: int

    def __post_init__(self) -> None:
        for value in (self.scope, self.clock_domain):
            if not isinstance(value, str) or not value.strip():
                raise ValueError("Scope and clock domain are required.")
        if type(self.start) is not int or type(self.end) is not int:
            raise TypeError("Period endpoints must be integer ticks.")
        if not 0 <= self.start < self.end:
            raise ValueError("Expected a nonempty half-open period.")


@dataclass(frozen=True)
class ConditionAssessment:
    condition: Condition
    state: AssessmentState
    basis_record: str

    def __post_init__(self) -> None:
        if not isinstance(self.condition, Condition):
            raise TypeError("Invalid condition.")
        if not isinstance(self.state, AssessmentState):
            raise TypeError("Invalid assessment state.")
        if not isinstance(self.basis_record, str) or not self.basis_record.strip():
            raise ValueError("An assessment basis is required.")


@dataclass(frozen=True)
class RenewalPolicy:
    maximum_periods: int
    maximum_cumulative_duration: int

    def __post_init__(self) -> None:
        for value in (
            self.maximum_periods,
            self.maximum_cumulative_duration,
        ):
            if type(value) is not int or value <= 0:
                raise ValueError("Policy limits must be positive integers.")


@dataclass(frozen=True)
class RenewalResult:
    unmet_conditions: frozenset[Condition]
    findings: tuple[str, ...]
    proposed_union_duration: int
    proposed_period_count: int
    notice_key: str


def union_duration(periods: tuple[Period, ...]) -> int:
    if not isinstance(periods, tuple):
        raise TypeError("Periods must be a tuple.")
    if any(not isinstance(period, Period) for period in periods):
        raise TypeError("Invalid period.")
    if not periods:
        return 0
    if len({(p.scope, p.clock_domain) for p in periods}) != 1:
        raise ValueError("Periods require one declared scope and clock domain.")

    ordered = sorted((p.start, p.end) for p in periods)
    left, right = ordered[0]
    total = 0
    for start, end in ordered[1:]:
        if start <= right:
            right = max(right, end)
        else:
            total += right - left
            left, right = start, end
    return total + right - left


def assess_proposal(
    previous: tuple[Period, ...],
    proposed: Period,
    assessments: tuple[ConditionAssessment, ...],
    policy: RenewalPolicy,
    now: int,
) -> RenewalResult:
    if not isinstance(proposed, Period) or not isinstance(policy, RenewalPolicy):
        raise TypeError("Expected typed proposal and policy.")
    if type(now) is not int or now < 0:
        raise ValueError("now must be a nonnegative integer tick.")
    if not isinstance(previous, tuple):
        raise TypeError("Previous periods must be a tuple.")
    if not isinstance(assessments, tuple):
        raise TypeError("Assessments must be a tuple.")
    if any(not isinstance(item, ConditionAssessment) for item in assessments):
        raise TypeError("Invalid condition assessment.")

    conditions = [item.condition for item in assessments]
    if len(conditions) != len(set(conditions)):
        raise ValueError("Duplicate condition assessment.")
    if set(conditions) != set(Condition):
        raise ValueError("Every justification condition must be addressed.")

    periods = previous + (proposed,)
    duration = union_duration(periods)
    unmet = frozenset(
        item.condition
        for item in assessments
        if item.state is not AssessmentState.SUPPORTED
    )

    findings = []
    if proposed.start < now:
        findings.append("retroactive_proposal")
    if len(periods) > policy.maximum_periods:
        findings.append("period_count_limit_exceeded")
    if duration > policy.maximum_cumulative_duration:
        findings.append("cumulative_duration_limit_exceeded")
    if unmet:
        findings.append("current_justification_not_established")

    return RenewalResult(
        unmet_conditions=unmet,
        findings=tuple(findings),
        proposed_union_duration=duration,
        proposed_period_count=len(periods),
        notice_key="proposal-assessment-is-not-authorization",
    )


class RenewalTests(unittest.TestCase):
    def period(self, start, end):
        return Period("synthetic restriction scope", "synthetic-seconds", start, end)

    def assessments(self, unresolved=None):
        return tuple(
            ConditionAssessment(
                condition,
                (
                    AssessmentState.UNRESOLVED
                    if condition is unresolved
                    else AssessmentState.SUPPORTED
                ),
                "Controlled synthetic current assessment.",
            )
            for condition in Condition
        )

    def test_adjacent_periods_do_not_reset_duration(self):
        result = assess_proposal(
            (self.period(0, 10),),
            self.period(10, 20),
            self.assessments(),
            RenewalPolicy(3, 15),
            now=10,
        )
        self.assertEqual(result.proposed_union_duration, 20)
        self.assertIn(
            "cumulative_duration_limit_exceeded",
            result.findings,
        )

    def test_overlap_is_not_double_counted(self):
        self.assertEqual(
            union_duration((self.period(0, 10), self.period(5, 15))),
            15,
        )

    def test_unresolved_necessity_is_preserved(self):
        result = assess_proposal(
            (),
            self.period(10, 15),
            self.assessments(Condition.NECESSITY),
            RenewalPolicy(2, 20),
            now=10,
        )
        self.assertIn(Condition.NECESSITY, result.unmet_conditions)

    def test_retrospective_proposal_is_flagged(self):
        result = assess_proposal(
            (),
            self.period(5, 15),
            self.assessments(),
            RenewalPolicy(2, 20),
            now=10,
        )
        self.assertIn("retroactive_proposal", result.findings)

    def test_empty_findings_do_not_create_authority(self):
        result = assess_proposal(
            (),
            self.period(10, 15),
            self.assessments(),
            RenewalPolicy(2, 20),
            now=10,
        )
        self.assertEqual(result.findings, ())
        self.assertEqual(
            result.notice_key,
            "proposal-assessment-is-not-authorization",
        )


if __name__ == "__main__":
    unittest.main()
