# SPDX-License-Identifier: MIT OR Apache-2.0
"""Local eco/social contribution notices and scoped review prerequisites."""

from dataclasses import dataclass
from datetime import date
from enum import Enum
import unittest


VERSION = "1.0.0"


class Purpose(str, Enum):
    ECOLOGICAL = "ecological"
    SOCIAL = "social"
    ECOLOGICAL_AND_SOCIAL = "ecological_and_social"


class Contribution(str, Enum):
    CASH = "cash"
    SERVICES = "services"
    VOLUNTEER_EXPENSE = "volunteer_expense"
    KNOWLEDGE_ARTIFACT = "knowledge_artifact"
    ACCESS = "access"


class Activity(str, Enum):
    SOLICITATION = "solicitation"
    SOLICITATION_DRAFTING = "solicitation_drafting"
    PERSONALIZED_RECOMMENDATION = "personalized_recommendation"
    POOLING = "pooling"
    RECEIPTING = "receipting"
    MONEY_MANAGEMENT = "money_management"


class ReviewStatus(str, Enum):
    REQUIREMENTS_UNRESOLVED = "requirements_unresolved"
    CONDITIONS_REVIEWED = "conditions_reviewed"
    EXEMPTION_REVIEWED = "exemption_reviewed"
    NOT_PERMITTED = "not_permitted"


class Gate(str, Enum):
    BLOCKED = "blocked"
    UNRESOLVED = "unresolved"
    REVIEW_PREREQUISITE_MET = "review_prerequisite_met"


def text(value: object, name: str) -> str:
    if not isinstance(value, str):
        raise ValueError(f"{name} must be text")
    if not 1 <= len(value) <= 512 or value != value.strip():
        raise ValueError(f"{name} must be trimmed nonempty text")
    if any(ord(char) < 32 or ord(char) == 127 for char in value):
        raise ValueError(f"{name} contains control characters")
    return value


def tax_notice(kind: Contribution, tax_year: int, jurisdiction: str) -> dict:
    """Only the cited 2025 U.S. federal notice profile is implemented."""
    if type(kind) is not Contribution:
        raise ValueError("typed contribution required")
    if type(tax_year) is not int:
        raise ValueError("tax_year must be an integer")
    text(jurisdiction, "jurisdiction")

    if tax_year != 2025 or jurisdiction != "US-federal":
        return {
            "schema_version": VERSION,
            "status": "jurisdiction_or_year_review_required",
            "deductible_amount": None,
            "message": "No applicable tax determination is implemented.",
        }

    messages = {
        Contribution.CASH:
            "Potential charitable contribution. Recipient eligibility, "
            "substantiation, benefits received, limits, and taxpayer "
            "circumstances require review.",
        Contribution.SERVICES:
            "The value of donated time, services, or expertise is not "
            "deductible under the cited U.S. federal guidance.",
        Contribution.VOLUNTEER_EXPENSE:
            "Certain qualifying unreimbursed expenses may be deductible. "
            "Do not include the value of time or services.",
        Contribution.KNOWLEDGE_ARTIFACT:
            "Creation, sharing, licensing, and property transfer are different "
            "transactions. No deductible property value is determined.",
        Contribution.ACCESS:
            "Do not automatically claim estimated rental, service, or access "
            "value. Transaction-specific review is required.",
    }
    return {
        "schema_version": VERSION,
        "status": "general_notice_only",
        "source_edition": "IRS Publication 526 (2025)",
        "deductible_amount": None,
        "message": messages[kind],
    }


@dataclass(frozen=True)
class Scope:
    jurisdiction: str
    actor_role: str
    activity: Activity
    conduct_description: str

    def __post_init__(self):
        text(self.jurisdiction, "jurisdiction")
        text(self.actor_role, "actor_role")
        text(self.conduct_description, "conduct_description")
        if type(self.activity) is not Activity:
            raise ValueError("typed activity required")


@dataclass(frozen=True)
class LegalReview:
    scope: Scope
    status: ReviewStatus
    reviewed_on: date
    review_due: date
    source_basis: str
    conditions_satisfied: bool | None

    def __post_init__(self):
        if type(self.scope) is not Scope:
            raise ValueError("typed scope required")
        if type(self.status) is not ReviewStatus:
            raise ValueError("typed review status required")
        if type(self.reviewed_on) is not date or type(self.review_due) is not date:
            raise ValueError("review dates must be dates")
        if self.review_due <= self.reviewed_on:
            raise ValueError("review deadline must follow review date")
        text(self.source_basis, "source_basis")
        if (
            self.conditions_satisfied is not None
            and type(self.conditions_satisfied) is not bool
        ):
            raise ValueError("conditions_satisfied must be Boolean or None")


def review_gate(
    requested: Scope,
    review: LegalReview | None,
    as_of: date,
) -> Gate:
    """Check declared review prerequisites, never operational permission.

    Review interval is [reviewed_on, review_due).
    Reviewer authority and source accuracy require external verification.
    """
    if type(requested) is not Scope or type(as_of) is not date:
        raise ValueError("typed scope and date required")
    if review is None:
        return Gate.UNRESOLVED
    if type(review) is not LegalReview:
        raise ValueError("typed legal review required")
    if requested != review.scope:
        return Gate.UNRESOLVED
    if review.status is ReviewStatus.NOT_PERMITTED:
        return Gate.BLOCKED
    if not review.reviewed_on <= as_of < review.review_due:
        return Gate.UNRESOLVED
    if review.status is ReviewStatus.REQUIREMENTS_UNRESOLVED:
        return Gate.UNRESOLVED
    if review.conditions_satisfied is False:
        return Gate.BLOCKED
    if review.conditions_satisfied is None:
        return Gate.UNRESOLVED
    return Gate.REVIEW_PREREQUISITE_MET


def capacity_acknowledgment(purpose: Purpose) -> str:
    if type(purpose) is not Purpose:
        raise ValueError("typed purpose required")
    return (
        f"This record recognizes a contribution to {purpose.value} goods. "
        "It does not determine tax deductibility or assign a deductible "
        "value to time, services, or expertise."
    )


class NoticeTests(unittest.TestCase):
    def scope(self):
        return Scope(
            "Reviewed jurisdiction",
            "Reviewed platform role",
            Activity.SOLICITATION,
            "Exact reviewed outward activity",
        )

    def review(self):
        return LegalReview(
            self.scope(),
            ReviewStatus.CONDITIONS_REVIEWED,
            date(2026, 11, 1),
            date(2027, 2, 1),
            "Counsel-reviewed source basis required by the integration",
            True,
        )

    def test_no_deduction_amount_is_generated(self):
        for kind in Contribution:
            notice = tax_notice(kind, 2025, "US-federal")
            self.assertIsNone(notice["deductible_amount"])

    def test_later_year_is_not_silently_supported(self):
        notice = tax_notice(Contribution.CASH, 2026, "US-federal")
        self.assertEqual(
            notice["status"], "jurisdiction_or_year_review_required"
        )

    def test_review_expiry_is_explicit(self):
        self.assertEqual(
            review_gate(self.scope(), self.review(), date(2027, 2, 1)),
            Gate.UNRESOLVED,
        )

    def test_valid_review_is_not_execution_permission(self):
        self.assertEqual(
            review_gate(self.scope(), self.review(), date(2026, 11, 9)),
            Gate.REVIEW_PREREQUISITE_MET,
        )

    def test_changed_conduct_requires_review(self):
        changed = Scope(
            self.scope().jurisdiction,
            self.scope().actor_role,
            Activity.MONEY_MANAGEMENT,
            "Different activity",
        )
        self.assertEqual(
            review_gate(changed, self.review(), date(2026, 11, 9)),
            Gate.UNRESOLVED,
        )

    def test_missing_review_is_unresolved(self):
        self.assertEqual(
            review_gate(self.scope(), None, date(2026, 11, 9)),
            Gate.UNRESOLVED,
        )

    def test_purpose_does_not_create_tax_value(self):
        for purpose in Purpose:
            self.assertIn(
                "does not determine tax deductibility",
                capacity_acknowledgment(purpose),
            )


if __name__ == "__main__":
    unittest.main()
