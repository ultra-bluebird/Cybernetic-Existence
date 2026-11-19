# SPDX-License-Identifier: MIT OR Apache-2.0
"""Scoped reliance review without historical mutation or action authority."""

from dataclasses import dataclass
from enum import Enum
import unittest


ENGINE_VERSION = "1.0.0"


class ReviewState(Enum):
    NOT_REVIEWED = "not_reviewed"
    PENDING = "pending"
    SUPPORTED = "supported_for_declared_scope"
    NOT_SUPPORTED = "not_supported"


def bounded_text(value, name):
    if type(value) is not str:
        raise ValueError(f"{name}: plain text required")
    if not 1 <= len(value) <= 256 or value != value.strip():
        raise ValueError(f"{name}: trimmed bounded text required")
    if any(ord(char) < 32 or ord(char) == 127 for char in value):
        raise ValueError(f"{name}: control characters rejected")


@dataclass(frozen=True)
class Context:
    implementation: str
    implementation_version: str
    input_domain: str
    evaluated_property: str

    def __post_init__(self):
        for name in self.__dataclass_fields__:
            bounded_text(getattr(self, name), name)


@dataclass(frozen=True)
class RelianceEnvelope:
    historical_context: Context
    proposed_context: Context
    applicability_review: ReviewState
    material_change_review: ReviewState
    downstream_review: ReviewState
    correction_trigger_present: bool

    def __post_init__(self):
        if type(self.historical_context) is not Context:
            raise ValueError("typed historical context required")
        if type(self.proposed_context) is not Context:
            raise ValueError("typed proposed context required")
        for name in (
            "applicability_review",
            "material_change_review",
            "downstream_review",
        ):
            if type(getattr(self, name)) is not ReviewState:
                raise ValueError(f"{name}: typed review state required")
        if type(self.correction_trigger_present) is not bool:
            raise ValueError("correction trigger must be Boolean")


def assess(envelope):
    if type(envelope) is not RelianceEnvelope:
        raise ValueError("typed reliance envelope required")

    fields = tuple(Context.__dataclass_fields__)
    differences = tuple(
        name for name in fields
        if getattr(envelope.historical_context, name)
        != getattr(envelope.proposed_context, name)
    )

    required = {
        "applicability": envelope.applicability_review,
        "material_change": envelope.material_change_review,
    }
    if envelope.correction_trigger_present:
        required["downstream_correction"] = envelope.downstream_review

    unsupported = tuple(
        name for name, state in required.items()
        if state is ReviewState.NOT_SUPPORTED
    )
    unresolved = tuple(
        name for name, state in required.items()
        if state in {ReviewState.NOT_REVIEWED, ReviewState.PENDING}
    )

    if unsupported:
        disposition = "proposed_reliance_not_supported"
    elif unresolved:
        disposition = "proposed_reliance_review_incomplete"
    else:
        disposition = "review_dispositions_present_substance_not_authenticated"

    return {
        "engine_version": ENGINE_VERSION,
        "context_differences": differences,
        "unsupported_reviews": unsupported,
        "unresolved_reviews": unresolved,
        "disposition": disposition,
        "historical_result": "not_rewritten_by_this_assessment",
        "downstream_claims": "not_automatically_false",
        "review_authenticity": "not_verified",
        "ordinary_support": "not_conditioned_on_this_result",
        "external_action_authorized": False,
    }


class EnvelopeTests(unittest.TestCase):
    def context(self, version="1.0.0"):
        return Context(
            "Local comprehension component",
            version,
            "Prespecified synthetic response counts",
            "Partition and undefined-rate behavior",
        )

    def envelope(self, **changes):
        values = {
            "historical_context": self.context(),
            "proposed_context": self.context(),
            "applicability_review": ReviewState.SUPPORTED,
            "material_change_review": ReviewState.SUPPORTED,
            "downstream_review": ReviewState.NOT_REVIEWED,
            "correction_trigger_present": False,
        }
        values.update(changes)
        return RelianceEnvelope(**values)

    def test_matching_context_is_not_action_authority(self):
        result = assess(self.envelope())
        self.assertFalse(result["external_action_authorized"])
        self.assertEqual(
            result["review_authenticity"], "not_verified"
        )

    def test_changed_version_is_visible(self):
        result = assess(self.envelope(
            proposed_context=self.context("2.0.0"),
            applicability_review=ReviewState.PENDING,
        ))
        self.assertIn(
            "implementation_version", result["context_differences"]
        )
        self.assertEqual(
            result["disposition"], "proposed_reliance_review_incomplete"
        )

    def test_correction_requires_downstream_review(self):
        result = assess(self.envelope(
            correction_trigger_present=True
        ))
        self.assertIn(
            "downstream_correction", result["unresolved_reviews"]
        )

    def test_unsupported_review_dominates_pending(self):
        result = assess(self.envelope(
            applicability_review=ReviewState.NOT_SUPPORTED,
            material_change_review=ReviewState.PENDING,
        ))
        self.assertEqual(
            result["disposition"], "proposed_reliance_not_supported"
        )

    def test_history_and_support_are_not_rewritten(self):
        result = assess(self.envelope(
            applicability_review=ReviewState.NOT_SUPPORTED
        ))
        self.assertEqual(
            result["historical_result"],
            "not_rewritten_by_this_assessment",
        )
        self.assertEqual(
            result["ordinary_support"],
            "not_conditioned_on_this_result",
        )


if __name__ == "__main__":
    unittest.main()
