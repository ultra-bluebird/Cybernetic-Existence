# SPDX-License-Identifier: MIT OR Apache-2.0
"""Local Augma attribution, overlap review, and comprehension arithmetic."""

from dataclasses import dataclass
from fractions import Fraction
from itertools import product
from typing import Mapping, Optional, Sequence
import unittest


MAX_COUNT = 9_007_199_254_740_991
TASKS = ("meaning", "derived", "inference", "consent", "correction")
COUNT_FIELDS = (
    "assigned", "correct", "incorrect", "explicit_uncertainty", "missing"
)


def nonnegative_integer(value: object, name: str) -> int:
    if type(value) is not int or value < 0:
        raise ValueError(f"{name} must be a nonnegative integer")
    return value


def count(value: object, name: str) -> int:
    result = nonnegative_integer(value, name)
    if result > MAX_COUNT:
        raise ValueError(f"{name} exceeds the supported count range")
    return result


def rate_fraction(value: str) -> Fraction:
    if not isinstance(value, str) or not value or len(value) > 64:
        raise ValueError("rate must be a nonempty string of at most 64 characters")
    try:
        result = Fraction(value)
    except (ValueError, ZeroDivisionError) as exc:
        raise ValueError("rate must encode a finite rational number") from exc
    if not 0 <= result <= 1:
        raise ValueError("rate must be between zero and one")
    return result


@dataclass(frozen=True)
class CashProposal:
    gain_low_minor: int
    gain_high_minor: int
    proposed_minor: int


def cash_proposal(
    actual_minor: int,
    baseline_low_minor: int,
    baseline_high_minor: int,
    incremental_cost_minor: int,
    rate: str,
    cap_minor: int,
    available_minor: int,
) -> CashProposal:
    """All monetary inputs must use one currency, period, and minor unit.

    actual_minor is realized revenue before the separately supplied cost.
    Costs already deducted from actual_minor must not be supplied again.
    Currency and accounting-basis reconciliation remain caller duties.
    """
    values = {
        "actual_minor": actual_minor,
        "baseline_low_minor": baseline_low_minor,
        "baseline_high_minor": baseline_high_minor,
        "incremental_cost_minor": incremental_cost_minor,
        "cap_minor": cap_minor,
        "available_minor": available_minor,
    }
    for name, value in values.items():
        nonnegative_integer(value, name)
    if baseline_low_minor > baseline_high_minor:
        raise ValueError("baseline bounds are reversed")

    chosen_rate = rate_fraction(rate)
    low = max(0, actual_minor - baseline_high_minor - incremental_cost_minor)
    high = max(0, actual_minor - baseline_low_minor - incremental_cost_minor)
    bounded = min(
        chosen_rate * low,
        Fraction(cap_minor),
        Fraction(available_minor),
    )
    proposed = bounded.numerator // bounded.denominator
    return CashProposal(low, high, proposed)


@dataclass(frozen=True)
class JournalEntry:
    kind: str
    workstream: Optional[str]
    relationship: str
    presented_as_independent: bool


@dataclass(frozen=True)
class AuditFinding:
    workstream: Optional[str]
    status: str
    independent_addition_supported: bool


def audit_overlap(entries: Sequence[JournalEntry]) -> tuple[AuditFinding, ...]:
    """Review declarations only; do not infer causal independence.

    Workstream labels are private grouping descriptions, not identity fields.
    Omission is allowed and produces an explicit incomplete-linkage warning.
    """
    groups: dict[str, list[JournalEntry]] = {}
    findings: list[AuditFinding] = []

    for entry in entries:
        if not isinstance(entry, JournalEntry):
            raise ValueError("entries must be JournalEntry instances")
        if entry.kind not in {"cash", "time"}:
            raise ValueError("unsupported entry kind")
        if entry.relationship not in {"co_produced", "independent", "unknown"}:
            raise ValueError("unsupported relationship")
        if type(entry.presented_as_independent) is not bool:
            raise ValueError("presented_as_independent must be Boolean")
        if entry.workstream is None:
            findings.append(AuditFinding(None, "linkage_incomplete", False))
            continue
        if (
            not isinstance(entry.workstream, str)
            or not entry.workstream.strip()
            or len(entry.workstream) > 160
            or entry.workstream != entry.workstream.strip()
        ):
            raise ValueError("workstream must be trimmed nonempty text")
        groups.setdefault(entry.workstream, []).append(entry)

    for workstream, group in groups.items():
        kinds = {entry.kind for entry in group}
        if kinds != {"cash", "time"}:
            findings.append(
                AuditFinding(workstream, "no_within_group_cross_type_pair", False)
            )
            continue

        relationships = {entry.relationship for entry in group}
        if relationships == {"independent"}:
            status = "declared_independent_not_verified"
        elif relationships == {"co_produced"}:
            status = (
                "declared_overlap_independent_claim"
                if any(entry.presented_as_independent for entry in group)
                else "declared_overlap_disclosed"
            )
        else:
            status = "unresolved"

        findings.append(AuditFinding(workstream, status, False))

    return tuple(findings)


def ratio_report(numerator: int, denominator: int) -> dict:
    if denominator == 0:
        return {"value": None, "status": "undefined"}
    return {
        "value": {
            "numerator": numerator,
            "denominator": denominator,
        },
        "status": "defined",
    }


def comprehension_report(tasks: Mapping[str, Mapping[str, object]]) -> dict:
    """Validate arithmetic for the five-task payload, not the full schema.

    This does not validate provenance, scope, instrument validity, or consent.
    It does not mutate inputs or produce a composite comprehension score.
    """
    if not isinstance(tasks, Mapping) or set(tasks) != set(TASKS):
        raise ValueError("exactly the five supported tasks are required")

    output = {}
    required = set(COUNT_FIELDS) | {"rubric_revision"}

    for task_name in TASKS:
        task = tasks[task_name]
        if not isinstance(task, Mapping) or set(task) != required:
            raise ValueError("unsupported task fields")
        rubric = task["rubric_revision"]
        if (
            not isinstance(rubric, str)
            or not rubric.strip()
            or len(rubric) > 128
        ):
            raise ValueError("invalid rubric_revision")

        checked = {
            field: count(task[field], field)
            for field in COUNT_FIELDS
        }
        partition = sum(checked[field] for field in COUNT_FIELDS[1:])
        if partition > MAX_COUNT or checked["assigned"] != partition:
            raise ValueError("response partition mismatch or overflow")

        scorable = checked["correct"] + checked["incorrect"]
        output[task_name] = {
            **checked,
            "rubric_revision": rubric,
            "scorable": scorable,
            "correct_rate": ratio_report(checked["correct"], scorable),
            "scorable_coverage": ratio_report(scorable, checked["assigned"]),
        }
    return output


def fixture_tasks(correct: int = 1) -> dict:
    return {
        name: {
            "assigned": 1,
            "correct": correct,
            "incorrect": 1 - correct,
            "explicit_uncertainty": 0,
            "missing": 0,
            "rubric_revision": "synthetic-rubric",
        }
        for name in TASKS
    }


class AttributionTests(unittest.TestCase):
    def test_worked_cash_example(self):
        result = cash_proposal(
            800_000, 600_000, 700_000, 20_000, "0.10", 10_000, 6_000
        )
        self.assertEqual(result, CashProposal(80_000, 180_000, 6_000))

    def test_exact_rounding_and_zero_rate(self):
        self.assertEqual(
            cash_proposal(101, 0, 0, 0, "0.10", 1000, 1000).proposed_minor,
            10,
        )
        self.assertEqual(
            cash_proposal(101, 0, 0, 0, "0", 1000, 1000).proposed_minor,
            0,
        )

    def test_bounded_exhaustive_cash_properties(self):
        rates = ("0", "1/3", "1")
        for actual, low, high, cost in product(range(5), repeat=4):
            if low > high:
                continue
            for chosen_rate in rates:
                result = cash_proposal(
                    actual, low, high, cost, chosen_rate, 3, 2
                )
                self.assertLessEqual(result.gain_low_minor, result.gain_high_minor)
                self.assertGreaterEqual(result.proposed_minor, 0)
                self.assertLessEqual(result.proposed_minor, 2)
                self.assertLessEqual(
                    result.proposed_minor,
                    rate_fraction(chosen_rate) * result.gain_low_minor,
                )
                increased_cost = cash_proposal(
                    actual, low, high, cost + 1, chosen_rate, 3, 2
                )
                self.assertLessEqual(
                    increased_cost.proposed_minor, result.proposed_minor
                )

    def test_invalid_inputs(self):
        for bad in (True, -1, 1.5):
            with self.assertRaises(ValueError):
                cash_proposal(bad, 0, 0, 0, "0.1", 1, 1)
        for bad_rate in ("NaN", "Infinity", "1.1", "-0.1", "1/0"):
            with self.assertRaises(ValueError):
                cash_proposal(1, 0, 0, 0, bad_rate, 1, 1)
        with self.assertRaises(ValueError):
            cash_proposal(1, 2, 1, 0, "1", 1, 1)

    def test_declared_overlap_and_missing_linkage(self):
        findings = audit_overlap((
            JournalEntry("cash", "shared activity", "co_produced", True),
            JournalEntry("time", "shared activity", "co_produced", True),
            JournalEntry("time", None, "unknown", False),
        ))
        statuses = {item.status for item in findings}
        self.assertIn("declared_overlap_independent_claim", statuses)
        self.assertIn("linkage_incomplete", statuses)
        self.assertTrue(
            all(not item.independent_addition_supported for item in findings)
        )

    def test_declared_independence_is_not_verification(self):
        findings = audit_overlap((
            JournalEntry("cash", "activity", "independent", True),
            JournalEntry("time", "activity", "independent", True),
        ))
        self.assertEqual(
            findings[0].status, "declared_independent_not_verified"
        )
        self.assertFalse(findings[0].independent_addition_supported)

    def test_comprehension_isolation_and_input_preservation(self):
        tasks = fixture_tasks()
        before = {name: dict(task) for name, task in tasks.items()}
        initial = comprehension_report(tasks)
        self.assertEqual(tasks, before)
        tasks["inference"]["correct"] = 0
        tasks["inference"]["incorrect"] = 1
        changed = comprehension_report(tasks)
        self.assertEqual(initial["consent"], changed["consent"])
        self.assertNotEqual(initial["inference"], changed["inference"])

    def test_undefined_and_partition_rejection(self):
        tasks = fixture_tasks()
        for task in tasks.values():
            for field in COUNT_FIELDS:
                task[field] = 0
        result = comprehension_report(tasks)
        self.assertEqual(
            result["meaning"]["correct_rate"],
            {"value": None, "status": "undefined"},
        )
        tasks["meaning"]["assigned"] = 1
        with self.assertRaises(ValueError):
            comprehension_report(tasks)

    def test_boolean_count_rejection(self):
        tasks = fixture_tasks()
        tasks["meaning"]["correct"] = True
        with self.assertRaises(ValueError):
            comprehension_report(tasks)


if __name__ == "__main__":
    unittest.main()
