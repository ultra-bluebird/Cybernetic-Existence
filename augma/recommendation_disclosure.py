# SPDX-License-Identifier: MIT OR Apache-2.0
"""Local recommendation screening and financial-control explanations."""

from dataclasses import dataclass
from enum import Enum
import unittest


VERSION = "1.0.0"


class Basis(str, Enum):
    SELECTED_CAUSE = "selected_cause"
    DECLARED_MILESTONE = "declared_milestone"
    INFERRED_AFFLUENCE = "inferred_affluence"
    INFERRED_VULNERABILITY = "inferred_vulnerability"
    UNKNOWN = "unknown"


class Objective(str, Enum):
    PREFERENCE_MATCH = "preference_match"
    MAXIMIZE_CONTRIBUTIONS = "maximize_contributions"
    UNKNOWN = "unknown"


class Disposition(str, Enum):
    BLOCKED = "blocked"
    REVIEW_REQUIRED = "review_required"
    TEMPLATE_AVAILABLE = "template_available"


class FinancialStage(str, Enum):
    FUTURE_INSTRUCTION = "future_instruction"
    CONTRIBUTED_TO_SPONSOR = "contributed_to_sponsor"
    GRANT_RECOMMENDATION = "grant_recommendation"


def tri_state(value: object, name: str) -> None:
    if value is not None and type(value) is not bool:
        raise ValueError(f"{name} must be Boolean or None")


@dataclass(frozen=True)
class Recommendation:
    bases: frozenset[Basis]
    objective: Objective
    sponsored_placement: bool | None
    crisis_targeting: bool | None
    deceptive_urgency: bool | None
    raises_rate: bool | None
    adaptive_persuasion: bool | None

    def __post_init__(self):
        if type(self.bases) is not frozenset or not self.bases:
            raise ValueError("bases must be a nonempty frozenset")
        if any(type(value) is not Basis for value in self.bases):
            raise ValueError("unsupported recommendation basis")
        if type(self.objective) is not Objective:
            raise ValueError("unsupported objective")
        for name in (
            "sponsored_placement",
            "crisis_targeting",
            "deceptive_urgency",
            "raises_rate",
            "adaptive_persuasion",
        ):
            tri_state(getattr(self, name), name)


@dataclass(frozen=True)
class Screening:
    schema_version: str
    disposition: Disposition
    reasons: tuple[str, ...]
    donor_text: str | None


def screen(recommendation: Recommendation) -> Screening:
    """Evaluate declarations, not the truth of the declarations.

    TEMPLATE_AVAILABLE is not dispatch permission, legal clearance,
    consent, or publication approval.
    """
    if type(recommendation) is not Recommendation:
        raise ValueError("typed recommendation required")

    blocked = []
    unresolved = []

    prohibited_bases = {
        Basis.INFERRED_AFFLUENCE,
        Basis.INFERRED_VULNERABILITY,
    }
    if recommendation.bases & prohibited_bases:
        blocked.append("project_prohibited_personal_inference")

    for name in ("crisis_targeting", "deceptive_urgency", "raises_rate"):
        value = getattr(recommendation, name)
        if value is True:
            blocked.append(name + "_prohibited")
        elif value is None:
            unresolved.append(name + "_unknown")

    if Basis.UNKNOWN in recommendation.bases:
        unresolved.append("recommendation_basis_unknown")

    if recommendation.objective is not Objective.PREFERENCE_MATCH:
        unresolved.append("optimization_objective_requires_review")

    if recommendation.adaptive_persuasion is not False:
        unresolved.append("adaptive_persuasion_requires_review")

    if recommendation.sponsored_placement is None:
        unresolved.append("sponsorship_unknown")

    if blocked:
        return Screening(
            VERSION, Disposition.BLOCKED,
            tuple(blocked + unresolved), None,
        )
    if unresolved:
        return Screening(
            VERSION, Disposition.REVIEW_REQUIRED,
            tuple(unresolved), None,
        )

    sentences = []
    if Basis.SELECTED_CAUSE in recommendation.bases:
        sentences.append(
            "Recommended because of a cause preference you selected."
        )
    if Basis.DECLARED_MILESTONE in recommendation.bases:
        sentences.append(
            "Shown in connection with a milestone you declared."
        )

    sentences.append(
        "The stated objective is matching your selected preferences."
    )
    if recommendation.sponsored_placement:
        sentences.append(
            "This is a sponsored placement; sponsor funding influenced "
            "its placement. It is not an independent best-option ranking."
        )

    sentences.extend((
        "This recommendation does not change your contribution rate.",
        "It does not authorize a contribution.",
        "You can decline, pause invitations, or correct your preferences.",
    ))
    return Screening(
        VERSION,
        Disposition.TEMPLATE_AVAILABLE,
        ("declared_inputs_pass_bounded_project_screen",),
        " ".join(sentences),
    )


def financial_explanation(stage: FinancialStage) -> str:
    """Generic template requiring sponsor-specific legal and UX review."""
    if type(stage) is not FinancialStage:
        raise ValueError("typed financial stage required")

    if stage is FinancialStage.FUTURE_INSTRUCTION:
        return (
            "You can stop future instructions where they remain cancellable. "
            "Cancellation does not recover a contribution already completed."
        )
    if stage is FinancialStage.CONTRIBUTED_TO_SPONSOR:
        return (
            "The sponsoring charity owns and controls contributed assets. "
            "They are not a balance available for personal withdrawal. "
            "You may have advisory privileges under the sponsor's terms."
        )
    return (
        "This is a grant recommendation, not a withdrawal instruction. "
        "The sponsoring charity makes the final decision under its terms."
    )


class DisclosureTests(unittest.TestCase):
    def ordinary(self, **changes) -> Recommendation:
        values = {
            "bases": frozenset({Basis.SELECTED_CAUSE}),
            "objective": Objective.PREFERENCE_MATCH,
            "sponsored_placement": False,
            "crisis_targeting": False,
            "deceptive_urgency": False,
            "raises_rate": False,
            "adaptive_persuasion": False,
        }
        values.update(changes)
        return Recommendation(**values)

    def test_declared_preference_gets_bounded_template(self):
        result = screen(self.ordinary())
        self.assertEqual(
            result.disposition, Disposition.TEMPLATE_AVAILABLE
        )
        self.assertIn("does not authorize", result.donor_text)

    def test_inferred_affluence_is_not_cured_by_disclosure(self):
        result = screen(self.ordinary(
            bases=frozenset({
                Basis.SELECTED_CAUSE, Basis.INFERRED_AFFLUENCE
            })
        ))
        self.assertEqual(result.disposition, Disposition.BLOCKED)
        self.assertIsNone(result.donor_text)

    def test_unknown_is_not_clearance(self):
        result = screen(self.ordinary(sponsored_placement=None))
        self.assertEqual(
            result.disposition, Disposition.REVIEW_REQUIRED
        )
        self.assertIsNone(result.donor_text)

    def test_sponsor_influence_is_visible(self):
        result = screen(self.ordinary(sponsored_placement=True))
        self.assertIn("sponsor funding influenced", result.donor_text)

    def test_adaptive_persuasion_needs_review(self):
        result = screen(self.ordinary(adaptive_persuasion=True))
        self.assertEqual(
            result.disposition, Disposition.REVIEW_REQUIRED
        )

    def test_known_block_dominates_unknown(self):
        result = screen(self.ordinary(
            deceptive_urgency=True, sponsored_placement=None
        ))
        self.assertEqual(result.disposition, Disposition.BLOCKED)
        self.assertIn("sponsorship_unknown", result.reasons)

    def test_boolean_fields_reject_integer(self):
        with self.assertRaises(ValueError):
            self.ordinary(raises_rate=1)

    def test_financial_stages_remain_distinct(self):
        texts = {financial_explanation(stage) for stage in FinancialStage}
        self.assertEqual(len(texts), len(FinancialStage))
        self.assertIn(
            "not a withdrawal",
            financial_explanation(FinancialStage.GRANT_RECOMMENDATION),
        )

    def test_no_legal_clearance_result(self):
        self.assertNotIn(
            "legally_compliant", {item.value for item in Disposition}
        )


if __name__ == "__main__":
    unittest.main()
