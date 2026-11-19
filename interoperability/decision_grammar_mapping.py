"""Research-only non-amplifying decision-grammar mapping.

Run:
    python research/interoperability/decision_grammar_mapping.py

No remote contexts, public entity identifiers, networking, or external action.
Semantic classifications and mapping reviews are supplied assertions.
"""

from dataclasses import dataclass
from enum import Enum
import unittest


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
ATTRIBUTION_SCOPE = (
    "Document credit and workstream metadata only; not identity, consent, "
    "capability authorization, execution evidence, or legal authority."
)


def text(value: str) -> None:
    if not isinstance(value, str) or not value.strip():
        raise ValueError("Expected nonempty text.")


class MeaningClass(Enum):
    ADMINISTRATIVE_PROGRESS = "administrative_progress"
    REVIEW_DISPOSITION = "review_disposition"
    REMEDY_IMPLEMENTATION = "remedy_implementation"
    PRACTICAL_OUTCOME = "practical_outcome"
    AUTHORITY_ASSERTION = "authority_assertion"
    UNCERTAINTY = "uncertainty"


class MappingRelation(Enum):
    EQUIVALENT_FOR_USE = "equivalent_for_use"
    APPROXIMATE = "approximate"
    UNRESOLVED = "unresolved"


class MappingFinding(Enum):
    SOURCE_CONTEXT_MISMATCH = "source_context_mismatch"
    SEMANTIC_CLASS_CHANGED = "semantic_class_changed"
    MAPPING_NOT_ACCEPTED = "mapping_not_accepted"
    APPROXIMATION_REQUIRES_REVIEW = "approximation_requires_review"
    TARGET_TERM_UNREGISTERED = "target_term_unregistered"


@dataclass(frozen=True)
class SourceStatement:
    vocabulary: str
    vocabulary_revision: str
    term: str
    meaning_class: MeaningClass
    original_text: str
    evidence_basis: str

    def __post_init__(self) -> None:
        for value in (
            self.vocabulary,
            self.vocabulary_revision,
            self.term,
            self.original_text,
            self.evidence_basis,
        ):
            text(value)
        if not isinstance(self.meaning_class, MeaningClass):
            raise TypeError("Invalid meaning class.")


@dataclass(frozen=True)
class MappingRule:
    source_vocabulary: str
    source_revision: str
    source_term: str
    target_vocabulary: str
    target_revision: str
    target_term: str
    source_class: MeaningClass
    target_class: MeaningClass
    relation: MappingRelation
    accepted_for_use: bool
    review_record: str

    def __post_init__(self) -> None:
        for value in (
            self.source_vocabulary,
            self.source_revision,
            self.source_term,
            self.target_vocabulary,
            self.target_revision,
            self.target_term,
            self.review_record,
        ):
            text(value)
        if not isinstance(self.source_class, MeaningClass):
            raise TypeError("Invalid source class.")
        if not isinstance(self.target_class, MeaningClass):
            raise TypeError("Invalid target class.")
        if not isinstance(self.relation, MappingRelation):
            raise TypeError("Invalid mapping relation.")
        if type(self.accepted_for_use) is not bool:
            raise TypeError("Acceptance must be Boolean.")


@dataclass(frozen=True)
class MappingAssessment:
    source: SourceStatement
    proposed_target_term: str
    target_vocabulary: str
    target_revision: str
    findings: frozenset[MappingFinding]
    mapping_review_record: str
    notice_key: str


def assess_mapping(
    source: SourceStatement,
    rule: MappingRule,
    registered_target_terms: frozenset[str],
) -> MappingAssessment:
    if not isinstance(source, SourceStatement):
        raise TypeError("Expected SourceStatement.")
    if not isinstance(rule, MappingRule):
        raise TypeError("Expected MappingRule.")
    if not isinstance(registered_target_terms, frozenset):
        raise TypeError("Target vocabulary must be a frozenset.")
    for term in registered_target_terms:
        text(term)

    findings = set()
    if (
        source.vocabulary != rule.source_vocabulary
        or source.vocabulary_revision != rule.source_revision
        or source.term != rule.source_term
        or source.meaning_class is not rule.source_class
    ):
        findings.add(MappingFinding.SOURCE_CONTEXT_MISMATCH)

    if rule.source_class is not rule.target_class:
        findings.add(MappingFinding.SEMANTIC_CLASS_CHANGED)

    if (
        not rule.accepted_for_use
        or rule.relation is MappingRelation.UNRESOLVED
    ):
        findings.add(MappingFinding.MAPPING_NOT_ACCEPTED)

    if rule.relation is MappingRelation.APPROXIMATE:
        findings.add(MappingFinding.APPROXIMATION_REQUIRES_REVIEW)

    if rule.target_term not in registered_target_terms:
        findings.add(MappingFinding.TARGET_TERM_UNREGISTERED)

    return MappingAssessment(
        source=source,
        proposed_target_term=rule.target_term,
        target_vocabulary=rule.target_vocabulary,
        target_revision=rule.target_revision,
        findings=frozenset(findings),
        mapping_review_record=rule.review_record,
        notice_key="mapping-does-not-transfer-authority-or-prove-outcome",
    )


class MappingTests(unittest.TestCase):
    def source(self) -> SourceStatement:
        return SourceStatement(
            "synthetic-office-vocabulary",
            "research-v1",
            "closed",
            MeaningClass.ADMINISTRATIVE_PROGRESS,
            "The office has dispatched the referral.",
            "Controlled synthetic dispatch record.",
        )

    def rule(self, target_class, relation=MappingRelation.EQUIVALENT_FOR_USE):
        return MappingRule(
            source_vocabulary="synthetic-office-vocabulary",
            source_revision="research-v1",
            source_term="closed",
            target_vocabulary="synthetic-review-vocabulary",
            target_revision="research-v1",
            target_term="administrative_step_complete",
            source_class=MeaningClass.ADMINISTRATIVE_PROGRESS,
            target_class=target_class,
            relation=relation,
            accepted_for_use=True,
            review_record="Controlled synthetic mapping review.",
        )

    def test_administrative_progress_cannot_become_practical_outcome(self):
        result = assess_mapping(
            self.source(),
            self.rule(MeaningClass.PRACTICAL_OUTCOME),
            frozenset({"administrative_step_complete"}),
        )
        self.assertIn(
            MappingFinding.SEMANTIC_CLASS_CHANGED,
            result.findings,
        )

    def test_original_statement_is_preserved(self):
        source = self.source()
        result = assess_mapping(
            source,
            self.rule(MeaningClass.ADMINISTRATIVE_PROGRESS),
            frozenset({"administrative_step_complete"}),
        )
        self.assertEqual(result.source, source)
        self.assertEqual(result.findings, frozenset())

    def test_approximate_mapping_remains_reviewable(self):
        result = assess_mapping(
            self.source(),
            self.rule(
                MeaningClass.ADMINISTRATIVE_PROGRESS,
                MappingRelation.APPROXIMATE,
            ),
            frozenset({"administrative_step_complete"}),
        )
        self.assertIn(
            MappingFinding.APPROXIMATION_REQUIRES_REVIEW,
            result.findings,
        )

    def test_unknown_target_term_is_not_silently_accepted(self):
        result = assess_mapping(
            self.source(),
            self.rule(MeaningClass.ADMINISTRATIVE_PROGRESS),
            frozenset(),
        )
        self.assertIn(
            MappingFinding.TARGET_TERM_UNREGISTERED,
            result.findings,
        )


if __name__ == "__main__":
    unittest.main()
