"""Case-level and remedy-episode accounting at a declared cutoff.

Python 3.10 or newer; standard library only.
Input is one already-accepted, ordered case log through the cutoff.
This is a measurement reducer, not an event-acceptance engine.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

from dataclasses import dataclass


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"


@dataclass(frozen=True)
class RemedyEvent:
    kind: str
    time_seconds: int


def remedy_ages(events, cutoff):
    if (
        type(events) is not tuple
        or len(events) > 256
        or type(cutoff) is not int
        or not 0 <= cutoff <= 2**52 - 1
    ):
        raise ValueError("measurement_input")

    received = None
    active_episode_start = None
    durations = []
    verification_events = 0
    closure_events = 0
    previous_time = -1

    kinds = {
        "received",
        "acknowledged",
        "assigned",
        "mitigated",
        "verified",
        "remedy_reopened",
        "administratively_closed",
    }

    for position, event in enumerate(events):
        if (
            type(event) is not RemedyEvent
            or type(event.kind) is not str
            or event.kind not in kinds
            or type(event.time_seconds) is not int
            or not 0 <= event.time_seconds <= cutoff
            or event.time_seconds < previous_time
        ):
            raise ValueError("event_order_or_value")

        previous_time = event.time_seconds

        if position == 0 and event.kind != "received":
            raise ValueError("received_first")

        if event.kind == "received":
            if received is not None:
                raise ValueError("duplicate_received")
            received = event.time_seconds
            active_episode_start = received

        elif event.kind == "verified":
            verification_events += 1
            if active_episode_start is not None:
                durations.append(
                    event.time_seconds - active_episode_start
                )
                active_episode_start = None

        elif event.kind == "remedy_reopened":
            if active_episode_start is not None:
                raise ValueError("unresolved_episode_already_open")
            active_episode_start = event.time_seconds

        elif event.kind == "administratively_closed":
            closure_events += 1

    exists = received is not None

    return {
        "schema_version": "1.0.0",
        "sovereign_attribution": ATTRIBUTION,
        "attribution_use": "document_credit_only",
        "unique_case_count": int(exists),
        "currently_verified_case_count":
            int(exists and active_episode_start is None),
        "currently_unresolved_case_count":
            int(active_episode_start is not None),
        "ever_verified_case_count": int(bool(durations)),
        "completed_episode_count": len(durations),
        "completed_episode_durations_seconds": durations,
        "verification_event_count": verification_events,
        "administrative_closure_event_count": closure_events,
        "current_unresolved_age_seconds": (
            None if active_episode_start is None
            else cutoff - active_episode_start
        ),
        "intake_age_seconds": (
            None if received is None else cutoff - received
        ),
        "evidence_acceptance": "supplied_not_authenticated",
        "durable_remedy": "not_evaluated",
    }
