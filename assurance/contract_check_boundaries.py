"""Research-only assurance-layer reporting.

Run:
    python research/assurance/contract_check_boundaries.py

No legal determination, network access, persistence, or external action.
All assessments are supplied assertions requiring independent evidence.
"""

from dataclasses import dataclass
from enum import Enum
import unittest


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
ATTRIBUTION_SCOPE = (
    "Document credit and workstream metadata only; not identity, consent, "
    "capability authorization, execution evidence, or legal authority."
)


class Layer(Enum):
    STRUCTURE = "structure"
    POLICY_APPLICATION = "policy_application"
    AUTHORITY = "authority"
    CURRENT_STATE = "current_state"
    ENFORCEMENT = "enforcement"
    PRACTICAL_OUTCOME = "practical_outcome"


class Status(Enum):
    SUPPORTED = "supported"
    UNSUPPORTED = "unsupported"
    UNRESOLVED = "unresolved"
    CONTESTED = "contested"


@dataclass(frozen=True)
class LayerAssessment:
    layer: Layer
    status: Status
    evidence_record: str

    def __post_init__(self) -> None:
        if not isinstance(self.layer, Layer):
            raise TypeError("Invalid layer.")
        if not isinstance(self.status, Status):
            raise TypeError("Invalid status.")
        if (
            not isinstance(self.evidence_record, str)
            or not self.evidence_record.strip()
        ):
            raise ValueError("An evidence or uncertainty record is required.")


@dataclass(frozen=True)
class AssuranceReport:
    assessments: tuple[LayerAssessment, ...]
    missing_layers: frozenset[Layer]
    unsupported_layers: frozenset[Layer]
    unresolved_layers: frozenset[Layer]
    contested_layers: frozenset[Layer]
    notice_key: str


def report_assurance(
    assessments: tuple[LayerAssessment, ...],
) -> AssuranceReport:
    if not isinstance(assessments, tuple):
        raise TypeError("Assessments must be an immutable tuple.")
    if any(not isinstance(item, LayerAssessment) for item in assessments):
        raise TypeError("Invalid layer assessment.")

    layers = [item.layer for item in assessments]
    if len(layers) != len(set(layers)):
        raise ValueError("Duplicate layer assessment.")

    def matching(status: Status) -> frozenset[Layer]:
        return frozenset(
            item.layer for item in assessments if item.status is status
        )

    return AssuranceReport(
        assessments=assessments,
        missing_layers=frozenset(set(Layer) - set(layers)),
        unsupported_layers=matching(Status.UNSUPPORTED),
        unresolved_layers=matching(Status.UNRESOLVED),
        contested_layers=matching(Status.CONTESTED),
        notice_key="assurance-report-does-not-create-authority",
    )


class AssuranceBoundaryTests(unittest.TestCase):
    def assessment(self, layer, status):
        return LayerAssessment(
            layer, status, "Controlled synthetic assessment record."
        )

    def test_structure_does_not_establish_authority(self):
        result = report_assurance((
            self.assessment(Layer.STRUCTURE, Status.SUPPORTED),
            self.assessment(Layer.AUTHORITY, Status.CONTESTED),
        ))
        self.assertIn(Layer.AUTHORITY, result.contested_layers)
        self.assertIn(Layer.ENFORCEMENT, result.missing_layers)

    def test_missing_is_not_supported(self):
        result = report_assurance(())
        self.assertEqual(result.missing_layers, frozenset(Layer))

    def test_supported_enforcement_does_not_prove_repair(self):
        result = report_assurance((
            self.assessment(Layer.ENFORCEMENT, Status.SUPPORTED),
            self.assessment(Layer.PRACTICAL_OUTCOME, Status.UNRESOLVED),
        ))
        self.assertIn(Layer.PRACTICAL_OUTCOME, result.unresolved_layers)

    def test_conflicting_duplicate_requires_a_separate_dispute_record(self):
        with self.assertRaises(ValueError):
            report_assurance((
                self.assessment(Layer.AUTHORITY, Status.SUPPORTED),
                self.assessment(Layer.AUTHORITY, Status.CONTESTED),
            ))


if __name__ == "__main__":
    unittest.main()
