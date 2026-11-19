"""CyberLaw intake-semantics research model.

Not an adjudication engine, authorization service, or evidence validator.
Uses synthetic test values and performs no external actions.

Run:
    python research/standing/typed_intake_semantics.py
"""

from dataclasses import dataclass, replace
from datetime import datetime, timezone
from enum import Enum
from itertools import product
import unittest


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
ATTRIBUTION_SCOPE = (
    "Document credit and workstream metadata only; not identity, "
    "consent, capability authorization, or legal authority."
)


def require_text(value: str, name: str, limit: int = 500) -> None:
    if not isinstance(value, str):
        raise TypeError(f"{name} must be text.")
    if not value.strip() or len(value) > limit:
        raise ValueError(f"{name} must contain 1 to {limit} characters.")


class DescriptionState(Enum):
    DESCRIBED = "described"
    CLARIFICATION = "clarification_needed"
    NOT_ARTICULATED = "not_articulated_after_supported_review"


class CompetenceState(Enum):
    WITHIN = "within_mandate"
    UNRESOLVED = "competence_unresolved"
    OUTSIDE = "outside_mandate"


class IntakeStep(Enum):
    ADMIT = "admit_for_substantive_review"
    ASSIST = "offer_supported_clarification"
    REVIEW_ARTICULATION = "independently_review_articulation_finding"
    RESOLVE_COMPETENCE = "review_competence"
    OFFER_REFERRAL = "offer_accessible_referral"


class ReasonCode(Enum):
    DESCRIPTIONS_PRESENT = "descriptions_present"
    CLARIFICATION_NEEDED = "clarification_needed"
    ARTICULATION_REVIEW_NEEDED = "articulation_review_needed"
    COMPETENCE_UNRESOLVED = "competence_unresolved"
    OUTSIDE_THIS_MANDATE = "outside_this_mandate"


@dataclass(frozen=True)
class EvidencePresence:
    supporting_material: bool
    counterevidence: bool

    def __post_init__(self) -> None:
        if any(
            type(value) is not bool
            for value in (self.supporting_material, self.counterevidence)
        ):
            raise TypeError("Evidence-presence values must be Boolean.")

    def information_leq(self, other: "EvidencePresence") -> bool:
        if not isinstance(other, EvidencePresence):
            raise TypeError("Comparison requires EvidencePresence.")
        return (
            self.supporting_material <= other.supporting_material
            and self.counterevidence <= other.counterevidence
        )


@dataclass(frozen=True)
class IntakeDescription:
    state: DescriptionState
    procedural_reason: str
    supporting_material_reference: str | None = None

    def __post_init__(self) -> None:
        if not isinstance(self.state, DescriptionState):
            raise TypeError("Invalid description state.")
        require_text(self.procedural_reason, "procedural_reason")
        if self.supporting_material_reference is not None:
            require_text(
                self.supporting_material_reference,
                "supporting_material_reference",
            )
        if (
            self.state is DescriptionState.NOT_ARTICULATED
            and self.supporting_material_reference is None
        ):
            raise ValueError(
                "A negative articulation finding requires a reference "
                "to its supported-review record."
            )


@dataclass(frozen=True)
class IntakeProvenance:
    policy_version: str
    mandate_basis: str
    assessment_context: str
    reviewer_role: str
    reviewer_record_reference: str
    review_route: str
    assessed_at: datetime

    def __post_init__(self) -> None:
        for name in (
            "policy_version",
            "mandate_basis",
            "assessment_context",
            "reviewer_role",
            "reviewer_record_reference",
            "review_route",
        ):
            require_text(getattr(self, name), name)
        if not isinstance(self.assessed_at, datetime):
            raise TypeError("assessed_at must be a datetime.")
        if (
            self.assessed_at.tzinfo is None
            or self.assessed_at.utcoffset() is None
        ):
            raise ValueError("assessed_at must be timezone-aware.")


@dataclass(frozen=True)
class IntakeAssessment:
    interest: IntakeDescription
    harm: IntakeDescription
    competence: CompetenceState
    harm_evidence: EvidencePresence

    def __post_init__(self) -> None:
        if not isinstance(self.interest, IntakeDescription):
            raise TypeError("Invalid interest description.")
        if not isinstance(self.harm, IntakeDescription):
            raise TypeError("Invalid harm description.")
        if not isinstance(self.competence, CompetenceState):
            raise TypeError("Invalid competence state.")
        if not isinstance(self.harm_evidence, EvidencePresence):
            raise TypeError("Invalid evidence representation.")


@dataclass(frozen=True)
class IntakeReceipt:
    assessment: IntakeAssessment
    provenance: IntakeProvenance
    recommended_steps: tuple[IntakeStep, ...]
    reason_codes: tuple[ReasonCode, ...]
    unresolved_questions: tuple[str, ...]
    correction_duties: tuple[str, ...]
    authority_notice: str


def evaluate_intake(
    assessment: IntakeAssessment,
    provenance: IntakeProvenance,
) -> IntakeReceipt:
    if not isinstance(assessment, IntakeAssessment):
        raise TypeError("assessment must be IntakeAssessment.")
    if not isinstance(provenance, IntakeProvenance):
        raise TypeError("provenance must be IntakeProvenance.")

    steps: list[IntakeStep] = []
    reasons: list[ReasonCode] = []
    questions: list[str] = []

    descriptions = (assessment.interest, assessment.harm)
    if any(
        item.state is DescriptionState.CLARIFICATION
        for item in descriptions
    ):
        steps.append(IntakeStep.ASSIST)
        reasons.append(ReasonCode.CLARIFICATION_NEEDED)

    if any(
        item.state is DescriptionState.NOT_ARTICULATED
        for item in descriptions
    ):
        steps.append(IntakeStep.REVIEW_ARTICULATION)
        reasons.append(ReasonCode.ARTICULATION_REVIEW_NEEDED)

    descriptions_present = all(
        item.state is DescriptionState.DESCRIBED
        for item in descriptions
    )
    if descriptions_present:
        reasons.append(ReasonCode.DESCRIPTIONS_PRESENT)

    if assessment.competence is CompetenceState.OUTSIDE:
        steps.append(IntakeStep.OFFER_REFERRAL)
        reasons.append(ReasonCode.OUTSIDE_THIS_MANDATE)
    elif assessment.competence is CompetenceState.UNRESOLVED:
        steps.append(IntakeStep.RESOLVE_COMPETENCE)
        reasons.append(ReasonCode.COMPETENCE_UNRESOLVED)
        questions.append("Determine the applicable institutional mandate.")
    elif descriptions_present:
        steps.append(IntakeStep.ADMIT)

    if assessment.interest.state is not DescriptionState.DESCRIBED:
        questions.append("Clarify or review what interest is described.")
    if assessment.harm.state is not DescriptionState.DESCRIBED:
        questions.append("Clarify or review the alleged interference.")

    if not assessment.harm_evidence.supporting_material:
        questions.append("Assess supporting material during merits review.")
    if assessment.harm_evidence.counterevidence:
        questions.append("Examine counterevidence without erasing the account.")

    return IntakeReceipt(
        assessment=assessment,
        provenance=provenance,
        recommended_steps=tuple(steps),
        reason_codes=tuple(reasons),
        unresolved_questions=tuple(questions),
        correction_duties=(
            "Provide an accessible explanation.",
            "Permit correction and independent procedural challenge.",
            "Do not infer absence of interests from a routing outcome.",
            "Do not forward confidential content without a separate basis.",
        ),
        authority_notice=(
            "Research-only procedural receipt. No legal or technical "
            "execution authority is granted."
        ),
    )


class TypedIntakeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.provenance = IntakeProvenance(
            policy_version="research-proposal",
            mandate_basis="synthetic local intake charter",
            assessment_context="hypothetical research evaluation",
            reviewer_role="research reviewer",
            reviewer_record_reference="controlled synthetic reviewer record",
            review_route="accessible independent research review",
            assessed_at=datetime(2026, 11, 1, tzinfo=timezone.utc),
        )

    def description(self, state: DescriptionState) -> IntakeDescription:
        reference = (
            "controlled synthetic supported-review record"
            if state is DescriptionState.NOT_ARTICULATED
            else None
        )
        return IntakeDescription(
            state=state,
            procedural_reason="Synthetic procedural assessment.",
            supporting_material_reference=reference,
        )

    def test_route_table_exhaustively(self) -> None:
        for interest, harm, competence, support, counter in product(
            DescriptionState,
            DescriptionState,
            CompetenceState,
            (False, True),
            (False, True),
        ):
            assessment = IntakeAssessment(
                self.description(interest),
                self.description(harm),
                competence,
                EvidencePresence(support, counter),
            )
            receipt = evaluate_intake(assessment, self.provenance)
            expected_admission = (
                interest is DescriptionState.DESCRIBED
                and harm is DescriptionState.DESCRIBED
                and competence is CompetenceState.WITHIN
            )
            self.assertEqual(
                IntakeStep.ADMIT in receipt.recommended_steps,
                expected_admission,
            )
            self.assertEqual(
                IntakeStep.OFFER_REFERRAL in receipt.recommended_steps,
                competence is CompetenceState.OUTSIDE,
            )

    def test_evidence_cannot_veto_description(self) -> None:
        described = self.description(DescriptionState.DESCRIBED)
        base = IntakeAssessment(
            described,
            described,
            CompetenceState.WITHIN,
            EvidencePresence(False, False),
        )
        for support, counter in product((False, True), repeat=2):
            varied = replace(
                base,
                harm_evidence=EvidencePresence(support, counter),
            )
            receipt = evaluate_intake(varied, self.provenance)
            self.assertIn(IntakeStep.ADMIT, receipt.recommended_steps)

    def test_referral_preserves_assistance(self) -> None:
        assessment = IntakeAssessment(
            self.description(DescriptionState.DESCRIBED),
            self.description(DescriptionState.CLARIFICATION),
            CompetenceState.OUTSIDE,
            EvidencePresence(False, False),
        )
        receipt = evaluate_intake(assessment, self.provenance)
        self.assertIn(IntakeStep.ASSIST, receipt.recommended_steps)
        self.assertIn(IntakeStep.OFFER_REFERRAL, receipt.recommended_steps)
        self.assertIs(
            receipt.assessment.interest.state,
            DescriptionState.DESCRIBED,
        )

    def test_information_order(self) -> None:
        states = [
            EvidencePresence(support, counter)
            for support, counter in product((False, True), repeat=2)
        ]
        for state in states:
            self.assertTrue(state.information_leq(state))
        for left, right in product(states, repeat=2):
            if left.information_leq(right) and right.information_leq(left):
                self.assertEqual(left, right)
        for left, middle, right in product(states, repeat=3):
            if left.information_leq(middle) and middle.information_leq(right):
                self.assertTrue(left.information_leq(right))
        self.assertFalse(states[1].information_leq(states[2]))
        self.assertFalse(states[2].information_leq(states[1]))

    def test_negative_articulation_requires_review_reference(self) -> None:
        with self.assertRaises(ValueError):
            IntakeDescription(
                DescriptionState.NOT_ARTICULATED,
                "Synthetic negative finding.",
            )

    def test_naive_timestamp_rejected(self) -> None:
        with self.assertRaises(ValueError):
            replace(
                self.provenance,
                assessed_at=datetime(2026, 11, 1),
            )

    def test_invalid_evidence_type_rejected(self) -> None:
        with self.assertRaises(TypeError):
            EvidencePresence(1, False)


if __name__ == "__main__":
    unittest.main()
