"""Research-only authority tagging and finding rendering.

Run:
    python research/governance/belief_neutral_authority_findings.py

No legal determination, identity assessment, networking, or external action.
All tests use synthetic material.
"""

from dataclasses import dataclass, replace
from enum import Enum
import unittest


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
ATTRIBUTION_SCOPE = (
    "Document credit and workstream metadata only; not identity, consent, "
    "capability authorization, execution evidence, or legal authority."
)


def require_text(value: str) -> None:
    if (
        not isinstance(value, str)
        or not value.strip()
        or len(value) > 3000
    ):
        raise ValueError("Expected bounded nonempty text.")


class SourceKind(Enum):
    ADVISORY = "advisory"
    ORGANIZATIONAL = "organizational"
    CONTRACTUAL = "contractual"
    STATUTORY = "statutory"
    TREATY = "treaty"


class Posture(Enum):
    SOURCE_BASED_ASSESSMENT = "source_based_assessment"
    RESEARCH_PROPOSAL = "research_proposal"
    ANALOGY = "analogy"


class ApplicationStatus(Enum):
    NOT_ASSESSED = "not_assessed"
    CONTESTED = "contested"
    ASSESSED_FOR_DEFINED_USE = "assessed_for_defined_use"


@dataclass(frozen=True)
class AuthorityTag:
    source_kind: SourceKind
    posture: Posture
    application_status: ApplicationStatus
    source_reference: str
    institution: str
    jurisdiction: str
    subject_scope: str
    personal_scope: str
    effective_period: str
    claimed_effect: str
    review_route: str

    def __post_init__(self) -> None:
        if not isinstance(self.source_kind, SourceKind):
            raise TypeError("Invalid source kind.")
        if not isinstance(self.posture, Posture):
            raise TypeError("Invalid posture.")
        if not isinstance(self.application_status, ApplicationStatus):
            raise TypeError("Invalid application status.")

        for value in (
            self.source_reference,
            self.institution,
            self.jurisdiction,
            self.subject_scope,
            self.personal_scope,
            self.effective_period,
            self.claimed_effect,
            self.review_route,
        ):
            require_text(value)

        if (
            self.posture in (Posture.RESEARCH_PROPOSAL, Posture.ANALOGY)
            and self.application_status
            is ApplicationStatus.ASSESSED_FOR_DEFINED_USE
        ):
            raise ValueError(
                "A proposal or analogy does not itself establish "
                "an adopted authority basis."
            )


@dataclass(frozen=True)
class FindingDraft:
    participant_account: str
    evidence_finding: str
    question_decided: str
    response_description: str
    unresolved_questions: str
    authority: AuthorityTag

    def __post_init__(self) -> None:
        for value in (
            self.participant_account,
            self.evidence_finding,
            self.question_decided,
            self.response_description,
            self.unresolved_questions,
        ):
            require_text(value)
        if not isinstance(self.authority, AuthorityTag):
            raise TypeError("Expected AuthorityTag.")


@dataclass(frozen=True)
class RenderedFinding:
    text: str
    source_kind: str
    posture: str
    application_status: str
    authority_reference: str
    review_route: str
    contract_version: str


def render_finding(draft: FindingDraft) -> RenderedFinding:
    if not isinstance(draft, FindingDraft):
        raise TypeError("Expected FindingDraft.")

    authority = draft.authority
    paragraphs = (
        f"Participant account: {draft.participant_account}",
        f"Evidence finding: {draft.evidence_finding}",
        f"Question addressed: {draft.question_decided}",
        f"Response described: {draft.response_description}",
        f"Unresolved questions: {draft.unresolved_questions}",
        (
            "Authority context: "
            f"{authority.source_kind.value}; "
            f"{authority.posture.value}; "
            f"{authority.application_status.value}."
        ),
        (
            "This record separates the participant's account from the "
            "evidence finding. It does not certify metaphysical claims, "
            "determine personhood, or create execution authority."
        ),
    )
    return RenderedFinding(
        text="\n\n".join(paragraphs),
        source_kind=authority.source_kind.value,
        posture=authority.posture.value,
        application_status=authority.application_status.value,
        authority_reference=authority.source_reference,
        review_route=authority.review_route,
        contract_version="bounded-finding-research-v1",
    )


def synthetic_authority() -> AuthorityTag:
    return AuthorityTag(
        source_kind=SourceKind.ORGANIZATIONAL,
        posture=Posture.SOURCE_BASED_ASSESSMENT,
        application_status=ApplicationStatus.ASSESSED_FOR_DEFINED_USE,
        source_reference="Controlled synthetic accessibility policy.",
        institution="Synthetic service body.",
        jurisdiction="Synthetic organizational service context.",
        subject_scope="Notice accessibility for the stated service.",
        personal_scope="Participants using that service.",
        effective_period="Synthetic assessed period.",
        claimed_effect="Internal accessible-notice procedure only.",
        review_route="Synthetic independent accessible review.",
    )


class FindingTests(unittest.TestCase):
    def draft(self) -> FindingDraft:
        return FindingDraft(
            participant_account=(
                "The participant describes the site as spiritually significant."
            ),
            evidence_finding=(
                "Synthetic records show that an accessible notice was not supplied."
            ),
            question_decided="Whether the notice procedure met its stated duty.",
            response_description="Provide an accessible notice and review opportunity.",
            unresolved_questions="The site's metaphysical nature is not determined.",
            authority=synthetic_authority(),
        )

    def test_account_and_evidence_remain_separate(self) -> None:
        result = render_finding(self.draft())
        self.assertIn("Participant account:", result.text)
        self.assertIn("Evidence finding:", result.text)
        self.assertIn("does not certify metaphysical claims", result.text)

    def test_proposal_cannot_be_its_own_adopted_authority(self) -> None:
        with self.assertRaises(ValueError):
            replace(
                synthetic_authority(),
                posture=Posture.RESEARCH_PROPOSAL,
            )

    def test_analogy_cannot_be_its_own_adopted_authority(self) -> None:
        with self.assertRaises(ValueError):
            replace(
                synthetic_authority(),
                posture=Posture.ANALOGY,
            )

    def test_contested_authority_stays_visible(self) -> None:
        draft = replace(
            self.draft(),
            authority=replace(
                synthetic_authority(),
                application_status=ApplicationStatus.CONTESTED,
            ),
        )
        result = render_finding(draft)
        self.assertEqual(result.application_status, "contested")

    def test_source_reference_is_required(self) -> None:
        with self.assertRaises(ValueError):
            replace(synthetic_authority(), source_reference=" ")

    def test_relabeling_account_does_not_change_authority_tag(self) -> None:
        original = render_finding(self.draft())
        changed = render_finding(replace(
            self.draft(),
            participant_account="The participant describes a nonreligious concern.",
        ))
        self.assertEqual(
            original.authority_reference,
            changed.authority_reference,
        )
        self.assertEqual(original.source_kind, changed.source_kind)


if __name__ == "__main__":
    unittest.main()
