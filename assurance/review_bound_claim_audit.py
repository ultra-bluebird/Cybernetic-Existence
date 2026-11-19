# SPDX-License-Identifier: MIT OR Apache-2.0
"""Review-bound structural revision audit. No source authentication."""

from dataclasses import dataclass
from datetime import datetime


ENGINE_VERSION = "2.0.0"

CLASSES = frozenset({
    "established_finding",
    "supplied_claim",
    "assumption",
    "design_proposal",
    "tested_implementation",
})


@dataclass(frozen=True)
class Claim:
    revision: int
    text: str
    classification: str
    basis: str
    scope: str
    limitations: tuple[str, ...]
    implementation_version: str | None = None


@dataclass(frozen=True)
class Review:
    previous: Claim
    proposed: Claim
    reviewer_role: str
    completed_at: datetime
    disposition: str


@dataclass(frozen=True)
class Execution:
    implementation_version: str
    scope: str
    record_available: bool
    execution_reported: bool


def validate_claim(claim):
    if type(claim) is not Claim:
        raise ValueError("typed claim required")
    if type(claim.revision) is not int or claim.revision < 0:
        raise ValueError("invalid revision")
    if (
        type(claim.classification) is not str
        or claim.classification not in CLASSES
    ):
        raise ValueError("invalid classification")

    for value in (claim.text, claim.basis, claim.scope):
        if type(value) is not str or not value.strip():
            raise ValueError("profile requires nonempty text")

    if type(claim.limitations) is not tuple:
        raise ValueError("immutable limitations required")
    if any(
        type(value) is not str or not value.strip()
        for value in claim.limitations
    ):
        raise ValueError("invalid limitation")


def audit_link(previous, proposed, review, executions):
    """Audit explicitly paired snapshots.

    Review and execution entries are declarations, not authenticated evidence.
    This profile does not validate source content or stable claim lineage.
    """
    validate_claim(previous)
    validate_claim(proposed)

    fields = (
        "text", "classification", "basis", "scope",
        "limitations", "implementation_version",
    )
    changes = [
        name for name in fields
        if getattr(previous, name) != getattr(proposed, name)
    ]
    findings = []

    expected_revision = (
        previous.revision + 1 if changes else previous.revision
    )
    if proposed.revision != expected_revision:
        findings.append("revision_sequence_mismatch")

    review_bound = (
        type(review) is Review
        and review.previous == previous
        and review.proposed == proposed
        and type(review.reviewer_role) is str
        and bool(review.reviewer_role.strip())
        and type(review.completed_at) is datetime
        and review.completed_at.utcoffset() is not None
        and review.disposition == "supported_for_declared_scope"
    )
    if changes and not review_bound:
        findings.append("changed_snapshot_without_bound_review")

    if (
        previous.classification != proposed.classification
        and previous.basis == proposed.basis
    ):
        findings.append("classification_changed_without_new_basis")

    if proposed.classification == "tested_implementation":
        matches = [
            entry for entry in executions
            if (
                type(entry) is Execution
                and entry.implementation_version
                == proposed.implementation_version
                and entry.scope == proposed.scope
                and entry.record_available is True
                and entry.execution_reported is True
            )
        ]
        if not matches:
            findings.append("matching_available_execution_record_absent")

    return {
        "engine_version": ENGINE_VERSION,
        "changes_observed": changes,
        "structural_findings": findings,
        "status": (
            "selected_structural_flags_raised"
            if findings
            else
            "no_selected_structural_flags_raised_substantive_review_not_performed"
        ),
        "evidence_authenticity": "not_verified",
        "authority": "none_granted",
    }


def audit_sequence(claims, reviews, executions):
    """Retain findings across an explicitly supplied ordered chain."""
    if (
        type(claims) is not tuple
        or len(claims) < 2
        or type(reviews) is not tuple
        or len(reviews) != len(claims) - 1
    ):
        raise ValueError(
            "ordered snapshots and one review slot per link required"
        )

    reports = [
        audit_link(previous, proposed, review, executions)
        for previous, proposed, review
        in zip(claims, claims[1:], reviews)
    ]
    return {
        "engine_version": ENGINE_VERSION,
        "links": reports,
        "history_contains_selected_flags": any(
            report["structural_findings"] for report in reports
        ),
        "authority": "none_granted",
    }
