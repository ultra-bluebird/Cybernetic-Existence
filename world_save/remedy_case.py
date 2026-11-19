"""Separate case lifecycle from correction-verification status.

Python 3.10 or newer; standard library only.

No authentication, persistence, publication, network access, or actuation.
Accepted-event origin and evidence adequacy are outside this module.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

from dataclasses import dataclass
from itertools import product


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

KINDS = frozenset({
    "case_opened",
    "acknowledged",
    "mitigation_recorded",
    "verification_accepted",
    "administratively_closed",
    "reopened",
    "recurrence_observed",
    "verification_disputed",
})

TARGETED = frozenset({
    "mitigation_recorded",
    "verification_accepted",
    "verification_disputed",
    "recurrence_observed",
})


@dataclass(frozen=True)
class CaseEvent:
    sequence: int
    kind: str
    expected_revision: int
    reason: str
    target_issue_revision: int | None = None
    schema_version: str = "1.0.0"


def replay_case(events):
    if type(events) is not tuple or len(events) > 256:
        raise ValueError("bounded_event_tuple_required")

    lifecycle = "not_recorded"
    remedy = "unverified"
    issue_revision = 0
    ever_verified = False
    verification_event = None

    for position, event in enumerate(events, 1):
        if (
            type(event) is not CaseEvent
            or event.schema_version != "1.0.0"
        ):
            raise ValueError("event_schema")

        if (
            type(event.sequence) is not int
            or type(event.expected_revision) is not int
            or event.sequence != position
            or event.expected_revision != position - 1
        ):
            raise ValueError("event_revision")

        if (
            type(event.kind) is not str
            or event.kind not in KINDS
            or type(event.reason) is not str
            or not event.reason.strip()
            or len(event.reason) > 4096
        ):
            raise ValueError("event_content")

        if event.kind in TARGETED:
            if (
                type(event.target_issue_revision) is not int
                or event.target_issue_revision != issue_revision
            ):
                raise ValueError("issue_target")
        elif event.target_issue_revision is not None:
            raise ValueError("unexpected_target")

        if event.kind == "case_opened":
            if position != 1:
                raise ValueError("opening_position")
            lifecycle = "open"
            issue_revision = 1

        elif issue_revision == 0:
            raise ValueError("case_opening_required")

        elif event.kind == "acknowledged":
            if lifecycle == "administratively_closed":
                raise ValueError("reopen_before_acknowledgment")
            lifecycle = "acknowledged"

        elif event.kind == "mitigation_recorded":
            if remedy != "verified":
                remedy = "mitigated"

        elif event.kind == "verification_accepted":
            remedy = "verified"
            ever_verified = True
            verification_event = position

        elif event.kind == "administratively_closed":
            lifecycle = "administratively_closed"

        elif event.kind == "reopened":
            lifecycle = "open"

        elif event.kind == "recurrence_observed":
            if not ever_verified:
                raise ValueError(
                    "prior_verification_required_for_recurrence"
                )
            issue_revision += 1
            remedy = "recurred"
            lifecycle = "open"
            verification_event = None

        elif event.kind == "verification_disputed":
            if remedy != "verified":
                raise ValueError("active_verification_required")
            issue_revision += 1
            remedy = "verification_disputed"
            lifecycle = "open"
            verification_event = None

    return {
        "schema_version": "1.0.0",
        "sovereign_attribution": ATTRIBUTION,
        "attribution_use": "document_credit_only",
        "revision": len(events),
        "case_lifecycle": lifecycle,
        "remedy_status": remedy,
        "issue_revision": issue_revision,
        "ever_verification_recorded": ever_verified,
        "current_verification_event": verification_event,
        "current_verified_correction_recorded":
            remedy == "verified",
        "evidence_basis":
            "supplied_accepted_history_not_authenticated",
        "durability": "not_evaluated",
    }


def append_fixture(history, kind, target=None):
    return history + (
        CaseEvent(
            sequence=len(history) + 1,
            kind=kind,
            expected_revision=len(history),
            reason="Synthetic accepted-review fixture.",
            target_issue_revision=target,
        ),
    )


def verify_reference():
    opening = CaseEvent(
        1, "case_opened", 0, "Synthetic case intake."
    )

    closed = append_fixture(
        (opening,), "administratively_closed"
    )
    if replay_case(closed)["current_verified_correction_recorded"]:
        raise RuntimeError("closure_created_verification")

    verified = append_fixture(
        (opening,), "verification_accepted", 1
    )
    closed_verified = append_fixture(
        verified, "administratively_closed"
    )
    if not replay_case(closed_verified)[
        "current_verified_correction_recorded"
    ]:
        raise RuntimeError("closure_erased_verification")

    recurred = append_fixture(
        closed_verified, "recurrence_observed", 1
    )
    if replay_case(recurred)["current_verified_correction_recorded"]:
        raise RuntimeError("recurrence_retained_current_verification")

    try:
        replay_case(
            append_fixture(recurred, "verification_accepted", 1)
        )
    except ValueError as error:
        if str(error) != "issue_target":
            raise
    else:
        raise RuntimeError("stale_verification_accepted")

    suffix = (
        "acknowledged",
        "mitigation_recorded",
        "verification_accepted",
        "administratively_closed",
        "reopened",
        "recurrence_observed",
        "verification_disputed",
    )

    valid = rejected = closure_checks = 0

    for length in range(5):
        for pattern in product(suffix, repeat=length):
            history = (opening,)

            try:
                for kind in pattern:
                    before = replay_case(history)
                    target = (
                        before["issue_revision"]
                        if kind in TARGETED else None
                    )
                    candidate = append_fixture(history, kind, target)
                    after = replay_case(candidate)

                    if (
                        before["ever_verification_recorded"]
                        and not after["ever_verification_recorded"]
                    ):
                        raise RuntimeError("historical_verification_lost")

                    if kind == "administratively_closed":
                        if (
                            before["current_verified_correction_recorded"]
                            != after["current_verified_correction_recorded"]
                        ):
                            raise RuntimeError(
                                "closure_changed_verification"
                            )
                        closure_checks += 1

                    history = candidate

                valid += 1

            except ValueError:
                rejected += 1

    return {
        "schema_version": "1.0.0",
        "sovereign_attribution": ATTRIBUTION,
        "suffix_patterns": valid + rejected,
        "valid_constructed_histories": valid,
        "rejected_patterns": rejected,
        "closure_comparisons_in_pattern_walks": closure_checks,
        "scope": "synthetic replay checks, not remedy validation",
    }
