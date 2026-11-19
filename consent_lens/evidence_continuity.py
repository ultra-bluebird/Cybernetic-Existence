"""Pure lifecycle kernel for one bounded claim.

Requires Python 3.10 or newer; standard library only.

SOVEREIGN-ATTRIBUTION:
bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7

Attribution is document credit only, not identity, consent, or authority.

Events must already have passed the external review/authorization process.
This module does not authenticate reviewers or evaluate resolution evidence.
It performs no storage, publication, network access, or actuation.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

from dataclasses import dataclass, replace


@dataclass(frozen=True)
class FindingState:
    revision: int = 0
    demonstration: int = 0
    open_finding: bool = False
    applicability: str = "unknown"
    support: bool = False
    conflict: bool = False
    retired: bool = False


@dataclass(frozen=True)
class Event:
    kind: str
    expected_revision: int
    demonstration: int | None = None
    decision: str | None = None
    basis: str = ""


def validate_state(state):
    if not isinstance(state, FindingState):
        raise ValueError("state_type")

    if (
        type(state.revision) is not int
        or type(state.demonstration) is not int
        or not 0 <= state.demonstration <= state.revision
    ):
        raise ValueError("state_revision")

    if state.applicability not in {"yes", "no", "unknown"}:
        raise ValueError("state_applicability")

    flags = (
        state.open_finding,
        state.support,
        state.conflict,
        state.retired,
    )
    if any(type(value) is not bool for value in flags):
        raise ValueError("state_flags")

    if state.open_finding and state.demonstration == 0:
        raise ValueError("state_finding")


def disposition(state):
    """Extract the current claim disposition without altering history."""
    validate_state(state)

    if state.retired:
        return "retired"

    if state.open_finding and state.applicability == "yes":
        return "nonconforming"

    if state.conflict or state.applicability == "unknown":
        return "unknown"

    if state.support:
        return "conforming"

    return "unknown"


def transition(state, event):
    """Apply one already-accepted event; reject stale or malformed input."""
    validate_state(state)

    if (
        not isinstance(event, Event)
        or type(event.expected_revision) is not int
        or event.expected_revision != state.revision
    ):
        raise ValueError("stale_or_invalid_event")

    if (
        not isinstance(event.kind, str)
        or not isinstance(event.basis, str)
        or not event.basis.strip()
    ):
        raise ValueError("event_basis")

    allowed = {
        "demonstrated",
        "support_accepted",
        "support_expired",
        "conflict_recorded",
        "conflict_reviewed",
        "applicability_reviewed",
        "resolution_accepted",
        "configuration_changed",
        "retired",
        "reactivated",
    }
    if event.kind not in allowed:
        raise ValueError("event_kind")

    if event.kind == "resolution_accepted":
        if (
            type(event.demonstration) is not int
            or event.demonstration != state.demonstration
            or not state.open_finding
        ):
            raise ValueError("resolution_target")
        if event.decision not in {
            "verified_correction",
            "finding_error_corrected",
        }:
            raise ValueError("resolution_reason")

    elif event.kind == "applicability_reviewed":
        if (
            event.demonstration is not None
            or event.decision not in {"yes", "no", "unknown"}
        ):
            raise ValueError("applicability_event")

    elif event.demonstration is not None or event.decision is not None:
        raise ValueError("unexpected_event_fields")

    allowed_while_retired = {
        "reactivated",
        "resolution_accepted",
        "applicability_reviewed",
        "conflict_reviewed",
        "conflict_recorded",
    }
    if state.retired and event.kind not in allowed_while_retired:
        raise ValueError("retired_scope")

    updated = replace(state, revision=state.revision + 1)

    if event.kind == "demonstrated":
        updated = replace(
            updated,
            demonstration=state.demonstration + 1,
            open_finding=True,
            applicability="yes",
            conflict=state.conflict or state.support,
        )

    elif event.kind == "support_accepted":
        updated = replace(
            updated,
            support=True,
            conflict=state.conflict
            or (state.open_finding and state.applicability == "yes"),
        )

    elif event.kind == "support_expired":
        updated = replace(updated, support=False)

    elif event.kind == "conflict_recorded":
        updated = replace(updated, conflict=True)

    elif event.kind == "conflict_reviewed":
        updated = replace(updated, conflict=False, support=False)

    elif event.kind == "applicability_reviewed":
        updated = replace(updated, applicability=event.decision)

    elif event.kind == "resolution_accepted":
        updated = replace(updated, open_finding=False, support=False)

    elif event.kind == "configuration_changed":
        updated = replace(
            updated, support=False, applicability="unknown"
        )

    elif event.kind == "retired":
        updated = replace(updated, retired=True, support=False)

    elif event.kind == "reactivated":
        if not state.retired:
            raise ValueError("not_retired")
        updated = replace(
            updated,
            retired=False,
            support=False,
            applicability="unknown",
        )

    validate_state(updated)
    return updated
