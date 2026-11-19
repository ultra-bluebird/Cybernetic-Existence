# SPDX-License-Identifier: MIT OR Apache-2.0
"""Local continuity, maintenance-claim, and succession assessments."""

from dataclasses import dataclass
from datetime import date
from enum import Enum
import unittest


VERSION = "1.0.0"


class Status(Enum):
    PASS = "pass"
    FAIL = "fail"
    UNKNOWN = "unknown"


class ChangeKind(Enum):
    RECORD_CORRECTION = "record_correction"
    RESOURCE_RETIREMENT = "resource_retirement"
    PERSON_DIRECTED_FUTURE_CHANGE = "person_directed_future_change"


def require_statuses(values):
    if any(type(value) is not Status for value in values):
        raise ValueError("typed review statuses required")


@dataclass(frozen=True)
class ChangeReview:
    kind: ChangeKind
    historical_meaning_preserved: Status
    reasons_and_scope_documented: Status
    ordinary_support_preserved: Status
    correction_and_appeal_working: Status
    person_direction_reviewed: Status
    reliance_transition_reviewed: Status

    def __post_init__(self):
        if type(self.kind) is not ChangeKind:
            raise ValueError("typed change kind required")
        require_statuses((
            self.historical_meaning_preserved,
            self.reasons_and_scope_documented,
            self.ordinary_support_preserved,
            self.correction_and_appeal_working,
            self.person_direction_reviewed,
            self.reliance_transition_reviewed,
        ))


def assess_change(review):
    if type(review) is not ChangeReview:
        raise ValueError("typed change review required")

    core = (
        review.historical_meaning_preserved,
        review.reasons_and_scope_documented,
        review.ordinary_support_preserved,
        review.correction_and_appeal_working,
    )
    if Status.FAIL in core:
        disposition = "potential_continuity_violation_human_review"
    elif Status.UNKNOWN in core:
        disposition = "unresolved_core_review"
    elif review.kind is ChangeKind.PERSON_DIRECTED_FUTURE_CHANGE:
        disposition = (
            "person_directed_change_candidate"
            if review.person_direction_reviewed is Status.PASS
            else "person_direction_unresolved_or_not_established"
        )
    elif review.kind is ChangeKind.RESOURCE_RETIREMENT:
        disposition = (
            "retirement_candidate_after_separate_approval"
            if review.reliance_transition_reviewed is Status.PASS
            else "reliance_transition_requires_review"
        )
    else:
        disposition = "documented_correction_candidate"

    return {
        "engine_version": VERSION,
        "disposition": disposition,
        "final_dispute_determination": "not_made",
        "external_action_authorized": False,
    }


@dataclass(frozen=True)
class MaintenanceReview:
    reviewed_on: date
    review_due: date
    responsible_role_accepted: Status
    scope_coverage: Status
    resources_adequate: Status
    correction_route_working: Status
    recent_review_or_rehearsal: Status
    material_change_resolved: Status

    def __post_init__(self):
        if type(self.reviewed_on) is not date or type(self.review_due) is not date:
            raise ValueError("review dates must be dates, not datetimes")
        if self.review_due <= self.reviewed_on:
            raise ValueError("review deadline must follow review date")
        require_statuses((
            self.responsible_role_accepted,
            self.scope_coverage,
            self.resources_adequate,
            self.correction_route_working,
            self.recent_review_or_rehearsal,
            self.material_change_resolved,
        ))


def maintenance_claim(review, as_of):
    if type(review) is not MaintenanceReview or type(as_of) is not date:
        raise ValueError("typed review and date required")

    statuses = (
        review.responsible_role_accepted,
        review.scope_coverage,
        review.resources_adequate,
        review.correction_route_working,
        review.recent_review_or_rehearsal,
        review.material_change_resolved,
    )
    within_window = review.reviewed_on <= as_of < review.review_due

    if Status.FAIL in statuses:
        label = "maintenance_commitment_requirements_not_met"
    elif not within_window:
        label = "maintenance_claim_requires_current_review"
    elif Status.UNKNOWN in statuses:
        label = "maintenance_commitment_unresolved"
    else:
        label = "maintenance_commitment_current_for_reviewed_scope"

    return {
        "engine_version": VERSION,
        "label": label,
        "artifact_correctness": "not_established_by_commitment",
        "indefinite_support": "not_promised",
        "ordinary_support": "not_conditioned_on_label",
        "external_action_authorized": False,
    }


@dataclass(frozen=True)
class SuccessionReview:
    purpose_and_transfer_basis: Status
    materials_minimized: Status
    successor_context_reviewed: Status
    linkage_and_inference_reviewed: Status
    access_and_retention_reviewed: Status
    exact_transfer_approved: Status

    def __post_init__(self):
        require_statuses((
            self.purpose_and_transfer_basis,
            self.materials_minimized,
            self.successor_context_reviewed,
            self.linkage_and_inference_reviewed,
            self.access_and_retention_reviewed,
            self.exact_transfer_approved,
        ))


def assess_succession(review):
    if type(review) is not SuccessionReview:
        raise ValueError("typed succession review required")
    statuses = (
        review.purpose_and_transfer_basis,
        review.materials_minimized,
        review.successor_context_reviewed,
        review.linkage_and_inference_reviewed,
        review.access_and_retention_reviewed,
        review.exact_transfer_approved,
    )
    if Status.FAIL in statuses:
        disposition = "transfer_review_blocked"
    elif Status.UNKNOWN in statuses:
        disposition = "transfer_review_unresolved"
    else:
        disposition = "review_inputs_present_recheck_at_execution_boundary"

    return {
        "engine_version": VERSION,
        "disposition": disposition,
        "anonymity": "not_certified",
        "automatic_successor_transfer": False,
        "external_action_authorized": False,
    }


class GovernanceTests(unittest.TestCase):
    def test_retirement_requires_reliance_review(self):
        review = ChangeReview(
            ChangeKind.RESOURCE_RETIREMENT,
            Status.PASS, Status.PASS, Status.PASS, Status.PASS,
            Status.UNKNOWN, Status.UNKNOWN,
        )
        self.assertEqual(
            assess_change(review)["disposition"],
            "reliance_transition_requires_review",
        )

    def test_good_reasons_do_not_compensate_for_support_loss(self):
        review = ChangeReview(
            ChangeKind.RECORD_CORRECTION,
            Status.PASS, Status.PASS, Status.FAIL, Status.PASS,
            Status.UNKNOWN, Status.UNKNOWN,
        )
        self.assertEqual(
            assess_change(review)["disposition"],
            "potential_continuity_violation_human_review",
        )

    def maintenance(self):
        return MaintenanceReview(
            date(2026, 11, 1), date(2026, 12, 1),
            Status.PASS, Status.PASS, Status.PASS,
            Status.PASS, Status.PASS, Status.PASS,
        )

    def test_expired_commitment_is_not_current(self):
        result = maintenance_claim(self.maintenance(), date(2026, 12, 1))
        self.assertEqual(
            result["label"], "maintenance_claim_requires_current_review"
        )

    def test_current_commitment_is_not_correctness(self):
        result = maintenance_claim(self.maintenance(), date(2026, 11, 9))
        self.assertEqual(
            result["label"],
            "maintenance_commitment_current_for_reviewed_scope",
        )
        self.assertEqual(
            result["artifact_correctness"],
            "not_established_by_commitment",
        )

    def test_all_reviews_do_not_execute_a_transfer(self):
        review = SuccessionReview(
            Status.PASS, Status.PASS, Status.PASS,
            Status.PASS, Status.PASS, Status.PASS,
        )
        result = assess_succession(review)
        self.assertFalse(result["external_action_authorized"])
        self.assertFalse(result["automatic_successor_transfer"])

    def test_unknown_linkage_is_not_anonymity(self):
        review = SuccessionReview(
            Status.PASS, Status.PASS, Status.PASS,
            Status.UNKNOWN, Status.PASS, Status.PASS,
        )
        self.assertEqual(
            assess_succession(review)["disposition"],
            "transfer_review_unresolved",
        )


if __name__ == "__main__":
    unittest.main()
