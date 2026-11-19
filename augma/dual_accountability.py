# SPDX-License-Identifier: MIT OR Apache-2.0
"""Local dual-accountability model for ecological and social contributions."""

from dataclasses import dataclass
from enum import Enum
from fractions import Fraction
import unittest


VERSION = "1.0.0"


class Unit(Enum):
    PERSON_HOUR = "person_hour"
    KILOWATT_HOUR = "kilowatt_hour"
    LITRE = "litre"
    KILOGRAM = "kilogram"
    SQUARE_METRE = "square_metre"


class Status(Enum):
    PASS = "pass"
    FAIL = "fail"
    UNKNOWN = "unknown"
    NOT_APPLICABLE = "not_applicable"


class ReviewResult(Enum):
    BLOCKED = "blocked"
    UNRESOLVED = "unresolved"
    INPUTS_PRESENT_NO_AUTHORITY = "inputs_present_no_authority"


def checked_text(value: object, name: str) -> str:
    if not isinstance(value, str):
        raise ValueError(f"{name} must be text")
    if not 1 <= len(value) <= 512 or value != value.strip():
        raise ValueError(f"{name} must be trimmed nonempty text")
    if any(ord(char) < 32 or ord(char) == 127 for char in value):
        raise ValueError(f"{name} contains control characters")
    return value


@dataclass(frozen=True)
class Boundary:
    dimension: str
    population_or_resource: str
    follow_up: str
    comparison_basis: str
    system_boundary: str

    def __post_init__(self):
        for name in self.__dataclass_fields__:
            checked_text(getattr(self, name), name)


@dataclass(frozen=True)
class QuantityInterval:
    lower: Fraction
    upper: Fraction
    unit: Unit
    boundary: Boundary

    def __post_init__(self):
        if type(self.lower) is not Fraction or type(self.upper) is not Fraction:
            raise ValueError("interval endpoints must be exact Fractions")
        if not 0 <= self.lower <= self.upper:
            raise ValueError("gross benefit and burden must be nonnegative")
        if type(self.unit) is not Unit:
            raise ValueError("typed unit required")
        if type(self.boundary) is not Boundary:
            raise ValueError("typed boundary required")


@dataclass(frozen=True)
class NetInterval:
    lower: Fraction
    upper: Fraction
    unit: Unit
    boundary: Boundary

    @property
    def interpretation(self) -> str:
        if self.lower > 0:
            return "positive_under_declared_inputs"
        if self.upper < 0:
            return "negative_under_declared_inputs"
        return "includes_zero_under_declared_inputs"


def net_interval(
    benefit: QuantityInterval,
    burden: QuantityInterval,
) -> NetInterval:
    if type(benefit) is not QuantityInterval or type(burden) is not QuantityInterval:
        raise ValueError("typed intervals required")
    if benefit.unit is not burden.unit:
        raise ValueError("cannot subtract unlike units")
    if benefit.boundary != burden.boundary:
        raise ValueError("comparison boundaries differ")
    return NetInterval(
        benefit.lower - burden.upper,
        benefit.upper - burden.lower,
        benefit.unit,
        benefit.boundary,
    )


@dataclass(frozen=True)
class Requirement:
    dimension: str
    status: Status
    basis: str

    def __post_init__(self):
        checked_text(self.dimension, "requirement dimension")
        checked_text(self.basis, "review basis")
        if type(self.status) is not Status:
            raise ValueError("typed status required")


@dataclass(frozen=True)
class RequirementReview:
    result: ReviewResult
    missing_dimensions: tuple[str, ...]
    failed_dimensions: tuple[str, ...]
    unknown_dimensions: tuple[str, ...]


def review_requirements(
    expected_dimensions: tuple[str, ...],
    requirements: tuple[Requirement, ...],
) -> RequirementReview:
    if type(expected_dimensions) is not tuple or not expected_dimensions:
        raise ValueError("nonempty expected dimension tuple required")
    if type(requirements) is not tuple:
        raise ValueError("requirements must be a tuple")
    for dimension in expected_dimensions:
        checked_text(dimension, "expected dimension")
    if len(set(expected_dimensions)) != len(expected_dimensions):
        raise ValueError("duplicate expected dimension")

    supplied = {}
    for requirement in requirements:
        if type(requirement) is not Requirement:
            raise ValueError("typed requirement required")
        if requirement.dimension not in expected_dimensions:
            raise ValueError("unsupported requirement dimension")
        if requirement.dimension in supplied:
            raise ValueError("duplicate requirement dimension")
        supplied[requirement.dimension] = requirement

    missing = tuple(
        dimension for dimension in expected_dimensions
        if dimension not in supplied
    )
    failed = tuple(
        dimension for dimension in expected_dimensions
        if dimension in supplied
        and supplied[dimension].status is Status.FAIL
    )
    unknown = tuple(
        dimension for dimension in expected_dimensions
        if dimension in supplied
        and supplied[dimension].status is Status.UNKNOWN
    )

    if failed:
        result = ReviewResult.BLOCKED
    elif missing or unknown:
        result = ReviewResult.UNRESOLVED
    else:
        result = ReviewResult.INPUTS_PRESENT_NO_AUTHORITY

    return RequirementReview(result, missing, failed, unknown)


@dataclass(frozen=True)
class PairedAssessment:
    schema_version: str
    native_outcomes: tuple[NetInterval, ...]
    legal_review_inputs: RequirementReview
    operational_prerequisites: RequirementReview


def paired_assessment(
    outcomes: tuple[NetInterval, ...],
    legal_review: RequirementReview,
    operation_review: RequirementReview,
) -> PairedAssessment:
    if type(outcomes) is not tuple:
        raise ValueError("outcomes must be a tuple")
    if any(type(outcome) is not NetInterval for outcome in outcomes):
        raise ValueError("typed net outcomes required")
    if type(legal_review) is not RequirementReview:
        raise ValueError("typed legal review required")
    if type(operation_review) is not RequirementReview:
        raise ValueError("typed operation review required")
    return PairedAssessment(
        VERSION, outcomes, legal_review, operation_review
    )


class DualAccountabilityTests(unittest.TestCase):
    def boundary(self):
        return Boundary(
            "Recipient time saved",
            "Participating restoration group",
            "Prespecified follow-up window",
            "Reviewed comparison workflow",
            "Adoption, coordination, and maintenance included",
        )

    def quantity(self, lower, upper, unit=Unit.PERSON_HOUR):
        return QuantityInterval(
            Fraction(lower), Fraction(upper), unit, self.boundary()
        )

    def test_interval_subtraction(self):
        result = net_interval(self.quantity(12, 18), self.quantity(3, 5))
        self.assertEqual((result.lower, result.upper), (Fraction(7), Fraction(15)))

    def test_unlike_units_rejected(self):
        with self.assertRaises(ValueError):
            net_interval(
                self.quantity(12, 18),
                self.quantity(3, 5, Unit.KILOWATT_HOUR),
            )

    def test_missing_requirement_is_unknown_not_pass(self):
        result = review_requirements(("jurisdiction", "fund_flow"), ())
        self.assertEqual(result.result, ReviewResult.UNRESOLVED)
        self.assertEqual(result.missing_dimensions, ("jurisdiction", "fund_flow"))

    def test_failure_dominates_unknown(self):
        result = review_requirements(
            ("jurisdiction", "fund_flow"),
            (
                Requirement("jurisdiction", Status.FAIL, "Synthetic failure"),
                Requirement("fund_flow", Status.UNKNOWN, "Synthetic unknown"),
            ),
        )
        self.assertEqual(result.result, ReviewResult.BLOCKED)

    def test_positive_benefit_cannot_clear_legal_block(self):
        outcome = net_interval(self.quantity(12, 18), self.quantity(3, 5))
        blocked = review_requirements(
            ("jurisdiction",),
            (Requirement("jurisdiction", Status.FAIL, "Synthetic failure"),),
        )
        operation = review_requirements(
            ("exact_terms",),
            (Requirement("exact_terms", Status.PASS, "Synthetic fixture"),),
        )
        result = paired_assessment((outcome,), blocked, operation)
        self.assertEqual(
            result.legal_review_inputs.result, ReviewResult.BLOCKED
        )
        self.assertEqual(
            result.operational_prerequisites.result,
            ReviewResult.INPUTS_PRESENT_NO_AUTHORITY,
        )

    def test_empty_expected_inventory_rejected(self):
        with self.assertRaises(ValueError):
            review_requirements((), ())

    def test_not_applicable_requires_basis(self):
        with self.assertRaises(ValueError):
            Requirement("custody", Status.NOT_APPLICABLE, "")


if __name__ == "__main__":
    unittest.main()
