"""Research-only public-benefit claim discipline.

Run:
    python research/assurance/public_benefit_claims.py

No certification, evidence authentication, networking, or external action.
All tests use synthetic material.
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


class ClaimKind(Enum):
    DESIGN_CONTRIBUTION = "design_contribution"
    BOUNDED_TECHNICAL_RESULT = "bounded_technical_result"
    DOCUMENTED_PRACTICAL_CASE = "documented_practical_case"
    COMPARATIVE_OUTCOME = "comparative_outcome"


class EvidenceKind(Enum):
    DESIGN_ARTIFACT = "design_artifact"
    EXECUTED_TEST_RECORD = "executed_test_record"
    PRACTICAL_OUTCOME_RECORD = "practical_outcome_record"
    COMPARATIVE_ANALYSIS = "comparative_analysis"


REQUIRED_EVIDENCE = {
    ClaimKind.DESIGN_CONTRIBUTION: EvidenceKind.DESIGN_ARTIFACT,
    ClaimKind.BOUNDED_TECHNICAL_RESULT: EvidenceKind.EXECUTED_TEST_RECORD,
    ClaimKind.DOCUMENTED_PRACTICAL_CASE: EvidenceKind.PRACTICAL_OUTCOME_RECORD,
    ClaimKind.COMPARATIVE_OUTCOME: EvidenceKind.COMPARATIVE_ANALYSIS,
}


@dataclass(frozen=True)
class EvidenceRecord:
    kind: EvidenceKind
    controlled_record_path: str
    scope_description: str

    def __post_init__(self) -> None:
        if not isinstance(self.kind, EvidenceKind):
            raise TypeError("Invalid evidence kind.")
        require_text(self.controlled_record_path)
        require_text(self.scope_description)


@dataclass(frozen=True)
class BenefitClaim:
    kind: ClaimKind
    statement: str
    setting: str
    affected_interests: tuple[str, ...]
    evidence: tuple[EvidenceRecord, ...]
    limitations: tuple[str, ...]
    challenge_route: str

    def __post_init__(self) -> None:
        if not isinstance(self.kind, ClaimKind):
            raise TypeError("Invalid claim kind.")
        for value in (self.statement, self.setting, self.challenge_route):
            require_text(value)
        for collection in (self.affected_interests, self.limitations):
            if not isinstance(collection, tuple) or not collection:
                raise ValueError("Interests and limitations must be explicit.")
            for value in collection:
                require_text(value)
        if not isinstance(self.evidence, tuple):
            raise TypeError("Evidence must be a tuple.")
        if any(not isinstance(item, EvidenceRecord) for item in self.evidence):
            raise TypeError("Invalid evidence record.")


@dataclass(frozen=True)
class ClaimReview:
    required_evidence_kind: EvidenceKind
    declared_evidence_present: bool
    unresolved_checks: tuple[str, ...]
    notice_key: str


def review_claim(claim: BenefitClaim) -> ClaimReview:
    if not isinstance(claim, BenefitClaim):
        raise TypeError("Expected BenefitClaim.")

    required = REQUIRED_EVIDENCE[claim.kind]
    present = any(item.kind is required for item in claim.evidence)

    return ClaimReview(
        required_evidence_kind=required,
        declared_evidence_present=present,
        unresolved_checks=(
            "Authenticate and inspect the referenced evidence.",
            "Assess whether the evidence supports this particular statement.",
            "Check setting, population, and affected-interest coverage.",
            "Review limitations, adverse effects, and contrary evidence.",
        ),
        notice_key="evidence-presence-is-not-benefit-certification",
    )


class BenefitClaimTests(unittest.TestCase):
    def claim(self, kind, evidence):
        return BenefitClaim(
            kind=kind,
            statement="Synthetic bounded public-benefit claim.",
            setting="Synthetic research setting.",
            affected_interests=("Accessible participation.",),
            evidence=evidence,
            limitations=("No deployment-wide inference is established.",),
            challenge_route="Synthetic independent review.",
        )

    def design_evidence(self):
        return EvidenceRecord(
            EvidenceKind.DESIGN_ARTIFACT,
            "research/fixtures/synthetic-design.md",
            "A proposed mechanism only.",
        )

    def test_design_does_not_count_as_executed_testing(self):
        result = review_claim(self.claim(
            ClaimKind.BOUNDED_TECHNICAL_RESULT,
            (self.design_evidence(),),
        ))
        self.assertFalse(result.declared_evidence_present)

    def test_design_does_not_count_as_practical_repair(self):
        result = review_claim(self.claim(
            ClaimKind.DOCUMENTED_PRACTICAL_CASE,
            (self.design_evidence(),),
        ))
        self.assertFalse(result.declared_evidence_present)

    def test_documented_case_does_not_count_as_comparative_analysis(self):
        evidence = EvidenceRecord(
            EvidenceKind.PRACTICAL_OUTCOME_RECORD,
            "research/fixtures/synthetic-outcome.md",
            "One synthetic case, not a population comparison.",
        )
        result = review_claim(self.claim(
            ClaimKind.COMPARATIVE_OUTCOME, (evidence,)
        ))
        self.assertFalse(result.declared_evidence_present)

    def test_matching_declaration_still_requires_substantive_review(self):
        result = review_claim(self.claim(
            ClaimKind.DESIGN_CONTRIBUTION,
            (self.design_evidence(),),
        ))
        self.assertTrue(result.declared_evidence_present)
        self.assertTrue(result.unresolved_checks)


if __name__ == "__main__":
    unittest.main()
