# SPDX-License-Identifier: MIT OR Apache-2.0
"""Local diary reconciliation and separate capacity-response validation."""

from dataclasses import dataclass
from enum import Enum
from fractions import Fraction
import unittest


VERSION = "1.0.0"
MAX_MINUTES = 1_000_000


class Category(Enum):
    PRODUCTION = "production"
    COORDINATION = "coordination"
    REVIEW = "review"
    REWORK = "rework"
    MAINTENANCE = "maintenance"
    MEASUREMENT = "measurement"
    UNCLASSIFIED = "unclassified"


class ResponseState(Enum):
    ANSWERED = "answered"
    UNCERTAIN = "uncertain"
    PREFER_NOT_TO_ANSWER = "prefer_not_to_answer"


class ContributionChoice(Enum):
    RETAIN_ALL = "retain_all"
    MAY_OFFER_SOME = "may_offer_some"
    UNDECIDED = "undecided"


def minutes(value, name):
    if type(value) is not int or not 0 <= value <= MAX_MINUTES:
        raise ValueError(f"{name}: bounded nonnegative integer required")


@dataclass(frozen=True)
class Allocation:
    category: Category
    person_minutes: int

    def __post_init__(self):
        if type(self.category) is not Category:
            raise ValueError("typed category required")
        minutes(self.person_minutes, "person_minutes")


@dataclass(frozen=True)
class SessionDiary:
    occupied_person_minutes: int
    allocations: tuple[Allocation, ...]

    def __post_init__(self):
        minutes(self.occupied_person_minutes, "occupied_person_minutes")
        if type(self.allocations) is not tuple:
            raise ValueError("allocations must be an immutable tuple")
        if any(type(item) is not Allocation for item in self.allocations):
            raise ValueError("typed allocations required")
        categories = [item.category for item in self.allocations]
        if len(categories) != len(set(categories)):
            raise ValueError("one aggregate allocation per category required")
        allocated = sum(item.person_minutes for item in self.allocations)
        if allocated != self.occupied_person_minutes:
            raise ValueError("allocations must partition occupied person-time")


@dataclass(frozen=True)
class CapacityResponse:
    state: ResponseState
    available_minutes: int | None
    choice: ContributionChoice | None

    def __post_init__(self):
        if type(self.state) is not ResponseState:
            raise ValueError("typed response state required")
        if self.state is ResponseState.ANSWERED:
            minutes(self.available_minutes, "available_minutes")
            if type(self.choice) is not ContributionChoice:
                raise ValueError("answered response requires a typed choice")
        elif self.available_minutes is not None or self.choice is not None:
            raise ValueError("unanswered response must not contain inferred values")


def exact_ratio(numerator, denominator):
    if denominator == 0:
        return None
    value = Fraction(numerator, denominator)
    return {
        "numerator": value.numerator,
        "denominator": value.denominator,
    }


def diary_report(diary):
    """Describe an allocation, not benefit, competence, or causal overhead."""
    if type(diary) is not SessionDiary:
        raise ValueError("typed diary required")
    allocated = {
        category: 0 for category in Category
    }
    for item in diary.allocations:
        allocated[item.category] = item.person_minutes

    total = diary.occupied_person_minutes
    return {
        "schema_version": VERSION,
        "unit": "person_minute",
        "occupied_person_minutes": total,
        "categories": {
            category.value: allocated[category] for category in Category
        },
        "classified_coverage": exact_ratio(
            total - allocated[Category.UNCLASSIFIED], total
        ),
        "recipient_benefit": "not_established",
        "contribution_authority": "not_granted",
    }


def capacity_report(response):
    if type(response) is not CapacityResponse:
        raise ValueError("typed capacity response required")
    return {
        "schema_version": VERSION,
        "response_state": response.state.value,
        "available_minutes": response.available_minutes,
        "contribution_choice": (
            response.choice.value if response.choice is not None else None
        ),
        "availability_is_obligation": False,
        "augmentation_attribution": "not_established",
        "operational_authority": "not_granted",
    }


class DiaryTests(unittest.TestCase):
    def test_meeting_person_time_is_counted_once(self):
        diary = SessionDiary(
            120, (Allocation(Category.COORDINATION, 120),)
        )
        self.assertEqual(
            diary_report(diary)["occupied_person_minutes"], 120
        )

    def test_overallocation_rejected(self):
        with self.assertRaises(ValueError):
            SessionDiary(
                30,
                (
                    Allocation(Category.PRODUCTION, 30),
                    Allocation(Category.COORDINATION, 30),
                ),
            )

    def test_unclassified_time_remains_visible(self):
        diary = SessionDiary(
            60,
            (
                Allocation(Category.PRODUCTION, 45),
                Allocation(Category.UNCLASSIFIED, 15),
            ),
        )
        self.assertEqual(
            diary_report(diary)["classified_coverage"],
            {"numerator": 3, "denominator": 4},
        )

    def test_zero_denominator_is_undefined(self):
        report = diary_report(SessionDiary(0, ()))
        self.assertIsNone(report["classified_coverage"])

    def test_duplicate_categories_rejected(self):
        with self.assertRaises(ValueError):
            SessionDiary(
                20,
                (
                    Allocation(Category.REVIEW, 10),
                    Allocation(Category.REVIEW, 10),
                ),
            )

    def test_available_time_does_not_require_contribution(self):
        response = CapacityResponse(
            ResponseState.ANSWERED, 60, ContributionChoice.RETAIN_ALL
        )
        report = capacity_report(response)
        self.assertEqual(report["available_minutes"], 60)
        self.assertFalse(report["availability_is_obligation"])

    def test_missing_is_not_zero(self):
        response = CapacityResponse(
            ResponseState.PREFER_NOT_TO_ANSWER, None, None
        )
        self.assertIsNone(capacity_report(response)["available_minutes"])

    def test_unanswered_values_cannot_be_imputed(self):
        with self.assertRaises(ValueError):
            CapacityResponse(
                ResponseState.UNCERTAIN,
                0,
                ContributionChoice.RETAIN_ALL,
            )

    def test_boolean_minutes_rejected(self):
        with self.assertRaises(ValueError):
            Allocation(Category.PRODUCTION, True)


if __name__ == "__main__":
    unittest.main()
