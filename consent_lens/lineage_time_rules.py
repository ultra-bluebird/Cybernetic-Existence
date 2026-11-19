"""Lineage-preserving deadline caps and bounded temporal predicates.

Python 3.10 or newer; standard library only.

Parent positions refer only to earlier rows in this local input.
They are not persistent dataset identities or public registry entries.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

from dataclasses import dataclass


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
SAFE_TIME = 2**52 - 1


@dataclass(frozen=True)
class LineageNode:
    label: str
    parents: tuple[int, ...]
    local_limit: str
    deadline_seconds: int | None
    lineage_complete: bool


def checked_time(value):
    if type(value) is not int or abs(value) > SAFE_TIME:
        raise ValueError("supported_integer_time_required")


def checked_interval(value):
    if value is None:
        return None
    if type(value) is not tuple or len(value) != 2:
        raise ValueError("time_interval_required")
    checked_time(value[0])
    checked_time(value[1])
    if value[0] > value[1]:
        raise ValueError("reversed_time_interval")
    return value


def lineage_deadlines(nodes):
    if type(nodes) is not tuple or not 1 <= len(nodes) <= 256:
        raise ValueError("bounded_topological_node_tuple_required")

    results = []

    for position, node in enumerate(nodes):
        if type(node) is not LineageNode:
            raise ValueError("lineage_node_type")
        if type(node.label) is not str or not node.label.strip():
            raise ValueError("node_label_required")
        if type(node.lineage_complete) is not bool:
            raise ValueError("lineage_completeness_type")

        if (
            type(node.parents) is not tuple
            or len(node.parents) > 64
            or any(
                type(parent) is not int or not 0 <= parent < position
                for parent in node.parents
            )
            or len(set(node.parents)) != len(node.parents)
        ):
            raise ValueError("parents_must_precede_derivative")

        if node.local_limit not in {
            "bounded", "no_additional_limit", "unknown"
        }:
            raise ValueError("local_limit_state")

        if node.local_limit == "bounded":
            checked_time(node.deadline_seconds)
        elif node.deadline_seconds is not None:
            raise ValueError("unexpected_local_deadline")

        candidates = []
        if node.local_limit == "bounded":
            candidates.append(node.deadline_seconds)

        for parent in node.parents:
            inherited = results[parent]["latest_known_deadline_cap"]
            if inherited is not None:
                candidates.append(inherited)

        cap = min(candidates) if candidates else None

        exact = (
            cap is not None
            and node.lineage_complete
            and node.local_limit != "unknown"
            and all(
                results[parent]["exact_deadline_established"]
                for parent in node.parents
            )
        )

        results.append({
            "label": node.label,
            "latest_known_deadline_cap": cap,
            "exact_deadline_established": exact,
            "lineage_complete": node.lineage_complete,
        })

    return {
        "schema_version": "1.0.0",
        "sovereign_attribution": ATTRIBUTION,
        "attribution_use": "document_credit_only",
        "nodes": results,
        "policy_applicability": "supplied_not_verified",
        "deletion_or_archival_action": "not_performed",
    }


def window_state(now_bounds, start, expiry):
    now = checked_interval(now_bounds)
    checked_time(start)
    checked_time(expiry)

    if start >= expiry:
        raise ValueError("nonempty_validity_window_required")
    if now is None:
        return {"state": "U", "reason": "clock_bounds_unavailable"}

    lower, upper = now

    if lower >= start and upper < expiry:
        return {"state": "P", "reason": "within_declared_window"}
    if upper < start:
        return {"state": "F", "reason": "not_yet_effective"}
    if lower >= expiry:
        return {"state": "F", "reason": "expired"}

    return {"state": "U", "reason": "clock_interval_crosses_boundary"}


def reading_age_state(now_bounds, measurement_bounds, maximum_age):
    now = checked_interval(now_bounds)
    measured = checked_interval(measurement_bounds)
    checked_time(maximum_age)

    if maximum_age < 0:
        raise ValueError("nonnegative_maximum_age_required")
    if now is None or measured is None:
        return {"state": "U", "reason": "time_bounds_unavailable"}

    age_lower = now[0] - measured[1]
    age_upper = now[1] - measured[0]

    if age_lower >= 0 and age_upper <= maximum_age:
        state, reason = "P", "all_modeled_ages_within_limit"
    elif age_upper < 0:
        state, reason = "F", "definitely_future_dated"
    elif age_lower > maximum_age:
        state, reason = "F", "definitely_too_old"
    else:
        state, reason = "U", "age_interval_crosses_boundary"

    return {
        "state": state,
        "reason": reason,
        "age_bounds_seconds": (age_lower, age_upper),
    }
