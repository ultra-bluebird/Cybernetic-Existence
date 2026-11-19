"""Deterministic local evidence assessment with explicit time context.

Python 3.10 or newer; standard library only.

No clock acquisition, storage, publication, network access, or actuation.
The JSON serializer is a local deterministic profile, not JCS and
not a cryptographic commitment implementation.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

from dataclasses import asdict, dataclass
import json


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"


@dataclass(frozen=True)
class TimeContext:
    lower: int | None
    upper: int | None
    valid_from: int
    valid_until: int
    policy_revision: str
    clock_profile: str
    evidence_snapshot_revision: int
    history_cut_revision: int


@dataclass(frozen=True)
class Evidence:
    positive_support: str
    positive_revision: int | None
    finding_status: str
    finding_revision: int | None
    failure_evidence_availability: str


def evaluate(context, evidence):
    if type(context) is not TimeContext or type(evidence) is not Evidence:
        raise ValueError("typed_inputs_required")

    for value in (context.valid_from, context.valid_until):
        if type(value) is not int or abs(value) > 2**52 - 1:
            raise ValueError("time_value")

    for value in (context.lower, context.upper):
        if value is not None and (
            type(value) is not int or abs(value) > 2**52 - 1
        ):
            raise ValueError("time_bound")

    if context.valid_from >= context.valid_until:
        raise ValueError("invalid_validity_window")

    if (
        context.lower is not None
        and context.upper is not None
        and context.lower > context.upper
    ):
        raise ValueError("reversed_time_interval")

    for value in (context.policy_revision, context.clock_profile):
        if (
            type(value) is not str
            or not value.strip()
            or len(value) > 128
        ):
            raise ValueError("profile_label")

    for value in (
        context.evidence_snapshot_revision,
        context.history_cut_revision,
    ):
        if type(value) is not int or not 0 <= value <= 2**53 - 1:
            raise ValueError("context_revision")

    if context.evidence_snapshot_revision > context.history_cut_revision:
        raise ValueError("snapshot_after_history_cut")

    vocabularies = (
        (
            evidence.positive_support,
            {"current", "withdrawn", "unresolved"},
        ),
        (
            evidence.finding_status,
            {
                "none",
                "open_accepted",
                "disputed_pending_review",
                "invalidated_pending_reassessment",
                "corrected_error",
            },
        ),
        (
            evidence.failure_evidence_availability,
            {"available", "deleted", "unavailable", "not_applicable"},
        ),
    )

    for value, allowed in vocabularies:
        if type(value) is not str or value not in allowed:
            raise ValueError("evidence_state")

    for value in (
        evidence.positive_revision,
        evidence.finding_revision,
    ):
        if value is not None and (
            type(value) is not int
            or not 0 <= value <= context.evidence_snapshot_revision
        ):
            raise ValueError("evidence_revision")

    if (
        evidence.positive_support == "current"
        and evidence.positive_revision is None
    ):
        raise ValueError("positive_revision_required")

    if (
        (evidence.finding_status == "none")
        != (evidence.finding_revision is None)
    ):
        raise ValueError("finding_revision")

    lower = context.lower
    upper = context.upper

    if (
        upper is not None and upper < context.valid_from
    ) or (
        lower is not None and lower >= context.valid_until
    ):
        time_state = "F"
    elif (
        lower is not None
        and upper is not None
        and lower >= context.valid_from
        and upper < context.valid_until
    ):
        time_state = "P"
    else:
        time_state = "U"

    if evidence.finding_status in {
        "open_accepted", "disputed_pending_review"
    }:
        decision = "F"
        reason = "accepted_applicable_finding_unresolved"

    elif evidence.finding_status == "invalidated_pending_reassessment":
        decision = "U"
        reason = "finding_basis_invalidated_review_pending"

    elif evidence.positive_support != "current":
        decision = "U"
        reason = "positive_support_not_current"

    elif (
        evidence.finding_status == "corrected_error"
        and evidence.positive_revision <= evidence.finding_revision
    ):
        decision = "U"
        reason = "fresh_positive_review_required_after_correction"

    elif time_state != "P":
        decision = "U"
        reason = "positive_review_time_validity_not_established"

    else:
        decision = "P"
        reason = "supplied_current_positive_review_supported"

    return {
        "schema_version": "1.0.0",
        "serialization_profile": "sorted-compact-json-utf8-local-1",
        "sovereign_attribution": ATTRIBUTION,
        "attribution_use": "document_credit_only",
        "context": asdict(context),
        "evidence": asdict(evidence),
        "time_state": time_state,
        "decision": decision,
        "reason": reason,
        "scope": "local supplied review model",
    }


def decision_bytes(context, evidence):
    return json.dumps(
        evaluate(context, evidence),
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")
