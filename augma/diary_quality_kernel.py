# SPDX-License-Identifier: MIT OR Apache-2.0
"""Local diary quality checks. No storage, tracking, release, or execution."""

from dataclasses import dataclass
from datetime import date
from enum import Enum
from fractions import Fraction
import unittest


VERSION = "1.0.0"


class Submission(Enum):
    ACTIVITY = "submitted_activity"
    NO_ACTIVITY = "submitted_no_activity"
    NOT_SUBMITTED = "not_submitted"


class Category(Enum):
    PRODUCTION = "production"
    COORDINATION = "coordination"
    REVIEW = "review"
    REWORK = "rework"
    MAINTENANCE = "maintenance"
    TRAVEL = "travel"
    WAITING = "occupied_waiting"
    MEASUREMENT = "measurement"
    UNCLASSIFIED = "unclassified"


TAGS = {
    Category.PRODUCTION: {"initial_requirement"},
    Category.COORDINATION: {"planning", "dependency_alignment"},
    Category.REVIEW: {"requirement_check"},
    Category.REWORK: {"existing_requirement_not_met"},
    Category.MAINTENANCE: {"changed_context_after_acceptance"},
    Category.TRAVEL: {"protocol_included_travel"},
    Category.WAITING: {"occupied_dependency_wait"},
    Category.MEASUREMENT: {"research_or_diary"},
    Category.UNCLASSIFIED: {"boundary_uncertain", "recall_uncertain"},
}


def integer(value, name, minimum=0):
    if type(value) is not int or value < minimum:
        raise ValueError(f"{name}: integer >= {minimum} required")


@dataclass(frozen=True)
class Period:
    start: date
    end_exclusive: date
    declared_participants: int
    maximum_occupied_person_minutes: int

    def __post_init__(self):
        if type(self.start) is not date or type(self.end_exclusive) is not date:
            raise ValueError("period requires dates, not datetimes")
        if self.end_exclusive <= self.start:
            raise ValueError("period must have positive duration")
        integer(self.declared_participants, "declared_participants", 1)
        integer(self.maximum_occupied_person_minutes, "period cap", 1)
        calendar_cap = (
            (self.end_exclusive - self.start).days
            * 1440 * self.declared_participants
        )
        if self.maximum_occupied_person_minutes > calendar_cap:
            raise ValueError("period cap exceeds calendar person-time")


@dataclass(frozen=True)
class Allocation:
    category: Category
    person_minutes: int
    boundary_tag: str

    def __post_init__(self):
        if type(self.category) is not Category:
            raise ValueError("typed category required")
        integer(self.person_minutes, "person_minutes", 1)
        if type(self.boundary_tag) is not str:
            raise ValueError("boundary tag must be text")
        if self.boundary_tag not in TAGS[self.category]:
            raise ValueError("incompatible classification boundary tag")


@dataclass(frozen=True)
class Diary:
    schema_version: str
    period: Period
    state: Submission
    elapsed_wall_minutes: int | None
    occupied_person_minutes: int | None
    allocations: tuple[Allocation, ...]

    def __post_init__(self):
        if self.schema_version != VERSION or type(self.schema_version) is not str:
            raise ValueError("unsupported schema version")
        if type(self.period) is not Period or type(self.state) is not Submission:
            raise ValueError("typed period and submission state required")
        if type(self.allocations) is not tuple:
            raise ValueError("immutable allocation tuple required")
        if any(type(item) is not Allocation for item in self.allocations):
            raise ValueError("typed allocations required")

        if self.state is Submission.NOT_SUBMITTED:
            if (
                self.elapsed_wall_minutes is not None
                or self.occupied_person_minutes is not None
                or self.allocations
            ):
                raise ValueError("absent diary must not contain imputed values")
            return

        integer(self.elapsed_wall_minutes, "elapsed_wall_minutes")
        integer(self.occupied_person_minutes, "occupied_person_minutes")
        elapsed_cap = (self.period.end_exclusive - self.period.start).days * 1440
        if self.elapsed_wall_minutes > elapsed_cap:
            raise ValueError("elapsed duration exceeds period")
        physical_cap = (
            self.elapsed_wall_minutes * self.period.declared_participants
        )
        if self.occupied_person_minutes > physical_cap:
            raise ValueError("occupied person-time exceeds declared session bound")
        if (
            self.occupied_person_minutes
            > self.period.maximum_occupied_person_minutes
        ):
            raise ValueError("occupied person-time exceeds period cap")
        if sum(item.person_minutes for item in self.allocations) != (
            self.occupied_person_minutes
        ):
            raise ValueError("allocations must partition occupied person-time")

        if self.state is Submission.NO_ACTIVITY:
            if self.occupied_person_minutes != 0 or self.allocations:
                raise ValueError("no-activity submission must have zero effort")
        elif self.occupied_person_minutes == 0:
            raise ValueError("activity submission requires positive effort")


def fraction_record(value):
    if value is None:
        return {"status": "undefined", "value": None}
    return {
        "status": "defined",
        "value": {
            "numerator": value.numerator,
            "denominator": value.denominator,
        },
    }


def assess(diary, coverage_floor, exception_reviewed=False):
    if type(diary) is not Diary:
        raise ValueError("typed diary required")
    if type(coverage_floor) is not Fraction or not 0 <= coverage_floor <= 1:
        raise ValueError("exact coverage floor between zero and one required")
    if type(exception_reviewed) is not bool:
        raise ValueError("exception_reviewed must be Boolean")

    base = {
        "engine_version": VERSION,
        "submission_state": diary.state.value,
        "missingness_policy": "not_submitted_is_not_zero",
        "release_permission": "not_granted",
        "contribution_authority": "not_granted",
        "standing_effect": "none",
    }
    if diary.state is Submission.NOT_SUBMITTED:
        return {
            **base,
            "quality": "not_assessable_missing_diary",
            "project_person_minutes": None,
            "research_person_minutes": None,
        }

    totals = {category: 0 for category in Category}
    for item in diary.allocations:
        totals[item.category] += item.person_minutes

    occupied = diary.occupied_person_minutes
    research = totals[Category.MEASUREMENT]
    project = occupied - research
    unclassified = totals[Category.UNCLASSIFIED]
    coverage = Fraction(project - unclassified, project) if project else None

    if coverage is None:
        quality = "no_project_denominator"
    elif coverage < coverage_floor:
        quality = (
            "below_floor_reviewed_exception"
            if exception_reviewed else "below_floor_review_required"
        )
    else:
        quality = "coverage_floor_met_not_proof_of_accuracy"

    return {
        **base,
        "quality": quality,
        "unit": "person_minute",
        "weighting": "occupied_project_person_minutes",
        "project_person_minutes": project,
        "research_person_minutes": research,
        "unclassified_person_minutes": unclassified,
        "classified_coverage": fraction_record(coverage),
        "unclassified_share": fraction_record(
            Fraction(unclassified, project) if project else None
        ),
        "research_burden_share": fraction_record(
            Fraction(research, occupied) if occupied else None
        ),
        "mean_occupied_minutes_per_declared_participant": fraction_record(
            Fraction(occupied, diary.period.declared_participants)
        ),
        "project_cost_excludes": "measurement",
    }


class QualityTests(unittest.TestCase):
    def period(self):
        return Period(date(2026, 11, 9), date(2026, 11, 10), 4, 240)

    def diary(self, allocations):
        total = sum(item.person_minutes for item in allocations)
        return Diary(
            VERSION, self.period(), Submission.ACTIVITY,
            60, total, tuple(allocations),
        )

    def test_all_unclassified_is_valid_but_flagged(self):
        diary = self.diary([
            Allocation(Category.UNCLASSIFIED, 120, "recall_uncertain")
        ])
        result = assess(diary, Fraction(3, 4))
        self.assertEqual(result["quality"], "below_floor_review_required")
        self.assertEqual(result["unclassified_person_minutes"], 120)

    def test_measurement_excluded_from_project_cost(self):
        diary = self.diary([
            Allocation(Category.PRODUCTION, 90, "initial_requirement"),
            Allocation(Category.MEASUREMENT, 30, "research_or_diary"),
        ])
        result = assess(diary, Fraction(3, 4))
        self.assertEqual(result["project_person_minutes"], 90)
        self.assertEqual(result["research_person_minutes"], 30)

    def test_absent_and_no_activity_are_distinct(self):
        absent = Diary(
            VERSION, self.period(), Submission.NOT_SUBMITTED, None, None, ()
        )
        zero = Diary(
            VERSION, self.period(), Submission.NO_ACTIVITY, 0, 0, ()
        )
        self.assertIsNone(assess(absent, Fraction(0))["project_person_minutes"])
        self.assertEqual(assess(zero, Fraction(0))["project_person_minutes"], 0)

    def test_person_time_bound(self):
        with self.assertRaises(ValueError):
            Diary(
                VERSION, self.period(), Submission.ACTIVITY, 10, 50,
                (Allocation(Category.PRODUCTION, 50, "initial_requirement"),),
            )

    def test_bounded_partition_properties(self):
        for production in range(1, 10):
            for uncertain in range(10):
                items = [
                    Allocation(Category.PRODUCTION, production, "initial_requirement")
                ]
                if uncertain:
                    items.append(Allocation(
                        Category.UNCLASSIFIED, uncertain, "boundary_uncertain"
                    ))
                result = assess(self.diary(items), Fraction(1, 2))
                self.assertEqual(
                    result["project_person_minutes"], production + uncertain
                )

    def test_boolean_minutes_rejected(self):
        with self.assertRaises(ValueError):
            Allocation(Category.REVIEW, True, "requirement_check")


if __name__ == "__main__":
    unittest.main()
