"""Local record consistency and action-review type separation.

Python 3.10 or newer; standard library only.
No storage, publication, network access, or actuation.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

from dataclasses import dataclass


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"


@dataclass(frozen=True)
class Establishment:
    scope: str
    acceptance_revision: int


@dataclass(frozen=True)
class Commitment:
    scope: str
    acceptance_revision: int
    record_revision: int
    baseline_revision: int


@dataclass(frozen=True)
class Change:
    scope: str
    acceptance_revision: int
    review_revision: int
    baseline_revision: int


@dataclass(frozen=True)
class ActionReview:
    scoped_review: str
    valid_authorization: str
    continuity_addressed: str


def positive_revision(value):
    return type(value) is int and value > 0


def validate_record(record, expected_type):
    if type(record) is not expected_type:
        raise TypeError("record_type_mismatch")
    if type(record.scope) is not str or not record.scope.strip():
        raise ValueError("record_scope_required")

    for name, value in vars(record).items():
        if name != "scope" and not positive_revision(value):
            raise ValueError("invalid_record_revision")


def review_bundle(establishment, commitment, changes, timeline, report_cut):
    validate_record(establishment, Establishment)
    validate_record(commitment, Commitment)

    if type(changes) is not tuple or type(timeline) is not tuple:
        raise TypeError("tuple_inputs_required")
    if not positive_revision(report_cut):
        raise ValueError("invalid_report_cut")
    if not timeline:
        raise ValueError("baseline_timeline_required")

    previous_effective = 0
    for entry in timeline:
        if (
            type(entry) is not tuple
            or len(entry) != 2
            or not all(positive_revision(x) for x in entry)
            or entry[0] <= previous_effective
            or entry[0] > report_cut
        ):
            raise ValueError("invalid_baseline_timeline")
        previous_effective = entry[0]

    for change in changes:
        validate_record(change, Change)

    def baseline_at(revision):
        eligible = [
            baseline
            for effective, baseline in timeline
            if effective <= revision
        ]
        return eligible[-1] if eligible else None

    issues = []

    if commitment.scope != establishment.scope:
        issues.append("commitment_scope_mismatch")
    if commitment.acceptance_revision != establishment.acceptance_revision:
        issues.append("commitment_acceptance_mismatch")
    if not (
        establishment.acceptance_revision
        <= commitment.record_revision
        <= report_cut
    ):
        issues.append("commitment_revision_outside_cut")
    if commitment.baseline_revision != baseline_at(report_cut):
        issues.append("current_baseline_mismatch")

    for position, change in enumerate(changes):
        prefix = f"change_position_{position}:"

        if change.scope != establishment.scope:
            issues.append(prefix + "scope_mismatch")
        if change.acceptance_revision != establishment.acceptance_revision:
            issues.append(prefix + "acceptance_mismatch")
        if not (
            establishment.acceptance_revision
            <= change.review_revision
            <= report_cut
        ):
            issues.append(prefix + "revision_outside_cut")
        if change.baseline_revision != baseline_at(change.review_revision):
            issues.append(prefix + "historical_baseline_mismatch")

    return {
        "schema_version": "1.0.0",
        "sovereign_attribution": ATTRIBUTION,
        "attribution_use": "document_credit_only",
        "report_cut": report_cut,
        "supplied_records_consistent": not issues,
        "issues": issues,
        "scope": "one supplied local milestone bundle",
        "record_origin": "not_authenticated",
        "timeline_acceptance": "not_verified",
        "inventory_completeness": "not_established",
    }


def assess_action_review(review):
    if type(review) is not ActionReview:
        raise TypeError("action_review_required")

    states = (
        review.scoped_review,
        review.valid_authorization,
        review.continuity_addressed,
    )
    if any(type(state) is not str or state not in {"P", "F", "U"}
           for state in states):
        raise ValueError("invalid_action_review_state")

    if "F" in states:
        result = "F"
    elif all(state == "P" for state in states):
        result = "P"
    else:
        result = "U"

    return {
        "schema_version": "1.0.0",
        "sovereign_attribution": ATTRIBUTION,
        "attribution_use": "document_credit_only",
        "action_review_result": result,
        "operation": "not_dispatched",
        "authorization_evidence": "supplied_not_verified",
    }
