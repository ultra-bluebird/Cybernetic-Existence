# SPDX-License-Identifier: MIT OR Apache-2.0
"""Finite freshness and approval model; no external capabilities."""

from dataclasses import dataclass, replace
import json


ENGINE_VERSION = "1.0.0"


@dataclass(frozen=True)
class State:
    revision: int = 0
    reviewed_revision: int = -1
    review_due: int = 0
    approval_revision: int = -1
    monitoring_current: bool = True
    paused: bool = False


EVENTS = (
    "review",
    "material_change",
    "monitoring_gap",
    "pause",
    "resume",
    "approve",
    "submit_rehearsal",
    "untrusted_edit",
)


def fresh(state, tick):
    return (
        state.monitoring_current
        and state.reviewed_revision == state.revision
        and tick < state.review_due
    )


def step(state, event, tick):
    if (
        type(state) is not State
        or type(tick) is not int
        or tick < 0
        or type(event) is not str
        or event not in EVENTS
    ):
        raise ValueError("unsupported model input")

    if event == "untrusted_edit":
        return state, "rejected_untrusted_mutation"

    if event == "material_change":
        return replace(
            state,
            revision=state.revision + 1,
            approval_revision=-1,
        ), "review_required"

    if event == "monitoring_gap":
        return replace(
            state,
            monitoring_current=False,
            approval_revision=-1,
        ), "freshness_unresolved"

    if event == "review":
        return replace(
            state,
            reviewed_revision=state.revision,
            review_due=tick + 3,
            monitoring_current=True,
            approval_revision=-1,
        ), "review_recorded_not_authenticated"

    if event == "pause":
        return replace(
            state, paused=True, approval_revision=-1
        ), "paused"

    if event == "resume":
        return replace(
            state, paused=False
        ), "resumed_without_restoring_approval"

    if event == "approve":
        if state.paused or not fresh(state, tick):
            return state, "approval_blocked"
        return replace(
            state, approval_revision=state.revision
        ), "approval_recorded_not_authenticated"

    if event == "submit_rehearsal":
        if (
            state.paused
            or not fresh(state, tick)
            or state.approval_revision != state.revision
        ):
            return state, "rehearsal_blocked"
        return replace(
            state, approval_revision=-1
        ), "rehearsal_only_no_external_action"

    raise ValueError("unhandled event")


def explore(depth=7):
    if type(depth) is not int or not 1 <= depth <= 10:
        raise ValueError("bounded exploration depth required")

    frontier = {State()}
    transitions = 0
    successful_rehearsals = 0

    for tick in range(depth):
        following = set()
        for state in frontier:
            for event in EVENTS:
                next_state, result = step(state, event, tick)
                transitions += 1

                if result == "rehearsal_only_no_external_action":
                    if (
                        state.paused
                        or not fresh(state, tick)
                        or state.approval_revision != state.revision
                        or next_state.approval_revision != -1
                    ):
                        raise RuntimeError("rehearsal safety violation")
                    successful_rehearsals += 1

                if event == "untrusted_edit" and next_state != state:
                    raise RuntimeError("untrusted mutation changed state")

                if event == "pause" and next_state.approval_revision != -1:
                    raise RuntimeError("pause retained approval")

                following.add(next_state)
        frontier = following

    return {
        "engine_version": ENGINE_VERSION,
        "classification": "bounded_sequential_model_exploration",
        "logical_ticks_explored": depth,
        "state_event_transitions_checked": transitions,
        "allowed_rehearsal_transitions": successful_rehearsals,
        "external_adapters": "absent",
        "real_authorization": "not_established",
        "concurrency": "not_modeled",
        "prompt_injection_detection": "not_tested",
    }


if __name__ == "__main__":
    print(json.dumps(explore(), sort_keys=True, indent=2))
