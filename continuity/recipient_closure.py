"""Bounded review of recipient paths for one processing scope and period.

Python 3.10 or newer; standard library only.

Positions are local input coordinates, not persistent party identifiers.
P/F/U are supplied review results, not authenticated by this module.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

from dataclasses import dataclass


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"


@dataclass(frozen=True)
class Transfer:
    source: int
    target: int
    presence: str
    obligation: str


def review_recipient_closure(allowed, inventory, edges, source=0):
    if (
        type(allowed) is not tuple
        or type(inventory) is not tuple
        or not 1 <= len(allowed) <= 128
        or len(inventory) != len(allowed)
    ):
        raise ValueError("node_state_dimensions")

    n = len(allowed)
    states = {"P", "F", "U"}

    if any(
        type(value) is not str or value not in states
        for value in allowed + inventory
    ):
        raise ValueError("review_state")

    if (
        type(source) is not int
        or not 0 <= source < n
        or type(edges) is not tuple
        or len(edges) > 1024
    ):
        raise ValueError("graph_shape")

    for edge in edges:
        if (
            type(edge) is not Transfer
            or type(edge.source) is not int
            or type(edge.target) is not int
            or not 0 <= edge.source < n
            or not 0 <= edge.target < n
            or type(edge.presence) is not str
            or type(edge.obligation) is not str
            or edge.presence not in states
            or edge.obligation not in states
        ):
            raise ValueError("edge_value")

    def reachable(permitted_states):
        reached = {source}
        while True:
            following = reached | {
                edge.target
                for edge in edges
                if edge.source in reached
                and edge.presence in permitted_states
            }
            if following == reached:
                return reached
            reached = following

    certain = reachable({"P"})
    possible = reachable({"P", "U"})
    failures = []
    unknowns = []

    for position in sorted(possible):
        if allowed[position] == "F":
            target = failures if position in certain else unknowns
            target.append({
                "position": position,
                "reason": "processing_party_not_permitted",
            })
        elif allowed[position] == "U":
            unknowns.append({
                "position": position,
                "reason": "party_permission_unresolved",
            })

        if inventory[position] != "P":
            unknowns.append({
                "position": position,
                "reason": "onward_inventory_not_established_complete",
            })

    for position, edge in enumerate(edges):
        if (
            edge.source in possible
            and edge.presence != "F"
            and edge.obligation != "P"
        ):
            confirmed_failure = (
                edge.source in certain
                and edge.presence == "P"
                and edge.obligation == "F"
            )
            target = failures if confirmed_failure else unknowns
            target.append({
                "transfer_position": position,
                "reason": (
                    "obligation_failure"
                    if confirmed_failure
                    else "obligation_unresolved_for_possible_transfer"
                ),
            })

    result = "F" if failures else "U" if unknowns else "P"

    return {
        "schema_version": "1.0.0",
        "sovereign_attribution": ATTRIBUTION,
        "attribution_use": "document_credit_only",
        "result": result,
        "certain_reachable_positions": sorted(certain),
        "possible_reachable_positions": sorted(possible),
        "failures": failures,
        "unknowns": unknowns,
        "inventory_truth": "supplied_not_independently_verified",
        "scope": "one declared processing activity and period",
    }
