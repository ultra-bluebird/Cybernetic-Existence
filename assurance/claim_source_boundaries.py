"""Research-only claim/source role checking.

Run:
    python research/assurance/claim_source_boundaries.py

No fetching, signing, networking, or external action.
Source classifications and evidence scope require independent review.
"""

from dataclasses import dataclass
from enum import Enum
import unittest


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
ATTRIBUTION_SCOPE = (
    "Document credit and workstream metadata only; not identity, consent, "
    "capability authorization, execution evidence, or legal authority."
)


def require_text(value: str) -> None:
    if not isinstance(value, str) or not value.strip():
        raise ValueError("Expected nonempty text.")


class ClaimPurpose(Enum):
    FRAMEWORK_PROPOSAL = "framework_proposal"
    EXTERNAL_COMPARISON = "external_comparison"
    LEGAL_APPLICABILITY = "legal_applicability"
    IMPLEMENTATION_RESULT = "implementation_result"


class SourceRole(Enum):
    FRAMEWORK_ARTIFACT = "framework_artifact"
    COMPARATIVE_MATERIAL = "comparative_material"
    APPLICABLE_LEGAL_ANALYSIS = "applicable_legal_analysis"
    EXECUTED_EVALUATION = "executed_evaluation"


@dataclass(frozen=True)
class Claim:
    proposition: str
    purpose: ClaimPurpose
    declared_scope: str

    def __post_init__(self) -> None:
        require_text(self.proposition)
        require_text(self.declared_scope)
        if not isinstance(self.purpose, ClaimPurpose):
            raise TypeError("Invalid claim purpose.")


@dataclass(frozen=True)
class SourceAssessment:
    source_description: str
    role: SourceRole
    assessed_passage: str
    scope_matches_claim: bool
    assessment_record: str

    def __post_init__(self) -> None:
        for value in (
            self.source_description,
            self.assessed_passage,
            self.assessment_record,
        ):
            require_text(value)
        if not isinstance(self.role, SourceRole):
            raise TypeError("Invalid source role.")
        if type(self.scope_matches_claim) is not bool:
            raise TypeError("Scope assessment must be Boolean.")


REQUIRED_ROLE = {
    ClaimPurpose.FRAMEWORK_PROPOSAL: SourceRole.FRAMEWORK_ARTIFACT,
    ClaimPurpose.EXTERNAL_COMPARISON: SourceRole.COMPARATIVE_MATERIAL,
    ClaimPurpose.LEGAL_APPLICABILITY: SourceRole.APPLICABLE_LEGAL_ANALYSIS,
    ClaimPurpose.IMPLEMENTATION_RESULT: SourceRole.EXECUTED_EVALUATION,
}


@dataclass(frozen=True)
class SourceCheck:
    declared_role_matches: bool
    declared_scope_matches: bool
    unresolved_checks: tuple[str, ...]


def check_source(claim: Claim, source: SourceAssessment) -> SourceCheck:
    if not isinstance(claim, Claim) or not isinstance(source, SourceAssessment):
        raise TypeError("Expected typed claim and source assessment.")

    return SourceCheck(
        declared_role_matches=source.role is REQUIRED_ROLE[claim.purpose],
        declared_scope_matches=source.scope_matches_claim,
        unresolved_checks=(
            "Verify the source and assessed passage.",
            "Check that the passage supports this exact proposition.",
            "Preserve jurisdiction, version, and implementation limitations.",
            "Check contrary material and prevent analogy-as-validation.",
        ),
    )


class SourceBoundaryTests(unittest.TestCase):
    def comparison(self) -> SourceAssessment:
        return SourceAssessment(
            source_description="Synthetic external contract specification.",
            role=SourceRole.COMPARATIVE_MATERIAL,
            assessed_passage="Synthetic description of structural validation.",
            scope_matches_claim=True,
            assessment_record="Controlled synthetic source assessment.",
        )

    def test_external_comparison_is_not_framework_origin(self) -> None:
        claim = Claim(
            "CyberLaw proposes standing before unnecessary classification.",
            ClaimPurpose.FRAMEWORK_PROPOSAL,
            "This conversation's CyberLaw proposal.",
        )
        self.assertFalse(
            check_source(claim, self.comparison()).declared_role_matches
        )

    def test_specification_is_not_executed_evaluation(self) -> None:
        claim = Claim(
            "The mechanism prevented a failure in an executed test.",
            ClaimPurpose.IMPLEMENTATION_RESULT,
            "Synthetic test setting.",
        )
        self.assertFalse(
            check_source(claim, self.comparison()).declared_role_matches
        )

    def test_comparison_remains_a_valid_declared_role(self) -> None:
        claim = Claim(
            "The external specification offers a comparison for record structure.",
            ClaimPurpose.EXTERNAL_COMPARISON,
            "Structural comparison only.",
        )
        result = check_source(claim, self.comparison())
        self.assertTrue(result.declared_role_matches)
        self.assertTrue(result.unresolved_checks)


if __name__ == "__main__":
    unittest.main()
