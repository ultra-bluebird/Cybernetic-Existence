"""Research-only preregistration planning checks.

Run:
    python research/protocols/preregistration_completeness.py

No ethics approval, scientific certification, networking, or external action.
Presence of a planning statement does not establish its adequacy.
"""

from dataclasses import dataclass
from enum import Enum
import unittest


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
ATTRIBUTION_SCOPE = (
    "Document credit and workstream metadata only; not identity, consent, "
    "capability authorization, execution evidence, or legal authority."
)


class StudyType(Enum):
    SYNTHETIC = "synthetic"
    PARTICIPANT_USABILITY = "participant_usability"
    FIELD_EVALUATION = "field_evaluation"


class ClaimTarget(Enum):
    MODELED_BEHAVIOR = "modeled_behavior"
    PARTICIPANT_EXPERIENCE = "participant_experience"
    PRACTICAL_EFFECT = "practical_effect"


REQUIRED_COMPONENTS = frozenset({
    "estimand",
    "sampling",
    "unit_and_dependence",
    "intervention",
    "comparator",
    "outcomes",
    "independent_assessment",
    "allocation",
    "sample_size_or_precision",
    "missingness",
    "multiplicity",
    "analysis",
    "effect_margins",
    "stopping_and_protection",
    "disconfirmation",
    "interpretation_limits",
    "artifact_and_correction_plan",
})


@dataclass(frozen=True)
class Protocol:
    study_type: StudyType
    claim_target: ClaimTarget
    revision: str
    components: tuple[tuple[str, str], ...]

    def __post_init__(self) -> None:
        if not isinstance(self.study_type, StudyType):
            raise TypeError("Invalid study type.")
        if not isinstance(self.claim_target, ClaimTarget):
            raise TypeError("Invalid claim target.")
        if not isinstance(self.revision, str) or not self.revision.strip():
            raise ValueError("A protocol revision is required.")
        if not isinstance(self.components, tuple):
            raise TypeError("Components must be an immutable tuple.")

        seen = set()
        for item in self.components:
            if not isinstance(item, tuple) or len(item) != 2:
                raise TypeError("Each component must be a name/text pair.")
            name, statement = item
            if not isinstance(name, str) or not name.strip():
                raise ValueError("Invalid component name.")
            if not isinstance(statement, str) or not statement.strip():
                raise ValueError("Planning statements must be nonempty.")
            if name in seen:
                raise ValueError("Duplicate planning component.")
            seen.add(name)


@dataclass(frozen=True)
class PlanningReport:
    missing_components: frozenset[str]
    unsupported_components: frozenset[str]
    inference_mismatch: bool
    unresolved_review: tuple[str, ...]


def review_planning(protocol: Protocol) -> PlanningReport:
    if not isinstance(protocol, Protocol):
        raise TypeError("Expected Protocol.")

    supplied = {name for name, _ in protocol.components}
    mismatch = (
        protocol.study_type is StudyType.SYNTHETIC
        and protocol.claim_target is not ClaimTarget.MODELED_BEHAVIOR
    )

    return PlanningReport(
        missing_components=REQUIRED_COMPONENTS - supplied,
        unsupported_components=supplied - REQUIRED_COMPONENTS,
        inference_mismatch=mismatch,
        unresolved_review=(
            "Assess scientific adequacy of every planning statement.",
            "Assess ethics, accessibility, and privacy protections.",
            "Verify that the comparator and outcome rules are credible.",
            "Register the final protocol before inspecting study outcomes.",
        ),
    )


class PlanningTests(unittest.TestCase):
    def complete_components(self):
        return tuple(
            (name, "Synthetic planning declaration for this component.")
            for name in sorted(REQUIRED_COMPONENTS)
        )

    def test_complete_declarations_are_not_validation(self):
        protocol = Protocol(
            StudyType.SYNTHETIC,
            ClaimTarget.MODELED_BEHAVIOR,
            "research-v1",
            self.complete_components(),
        )
        result = review_planning(protocol)
        self.assertEqual(result.missing_components, frozenset())
        self.assertTrue(result.unresolved_review)

    def test_synthetic_experience_claim_is_flagged(self):
        protocol = Protocol(
            StudyType.SYNTHETIC,
            ClaimTarget.PARTICIPANT_EXPERIENCE,
            "research-v1",
            self.complete_components(),
        )
        self.assertTrue(review_planning(protocol).inference_mismatch)

    def test_missing_analysis_is_visible(self):
        components = tuple(
            item
            for item in self.complete_components()
            if item[0] != "analysis"
        )
        protocol = Protocol(
            StudyType.FIELD_EVALUATION,
            ClaimTarget.PRACTICAL_EFFECT,
            "research-v1",
            components,
        )
        self.assertIn(
            "analysis",
            review_planning(protocol).missing_components,
        )

    def test_duplicate_component_rejected(self):
        with self.assertRaises(ValueError):
            Protocol(
                StudyType.SYNTHETIC,
                ClaimTarget.MODELED_BEHAVIOR,
                "research-v1",
                (("analysis", "First."), ("analysis", "Second.")),
            )


if __name__ == "__main__":
    unittest.main()
