"""Witness-bearing review of one caller-scoped transfer map.

Python 3.10 or newer; standard library only.

Positions are local coordinates, not persistent party identifiers.
Engineering caps bound this prototype; they are not privacy guarantees.

No storage, publication, network access, or actuation.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

from collections import deque
from dataclasses import dataclass


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

MAX_PARTIES = 128
MAX_TRANSFERS = 1024


@dataclass(frozen=True)
class Transfer:
    source: int
    target: int
    presence: str
    obligation: str


@dataclass(frozen=True)
class RecipientReview:
    allowed: tuple[str, ...]
    inventory: tuple[str, ...]
    transfers: tuple[Transfer, ...]
    source: int = 0
    schema_version: str = "2.0.0"


def review_closure(record):
    if (
        type(record) is not RecipientReview
        or record.schema_version != "2.0.0"
    ):
        raise ValueError("recipient_schema")

    if (
        type(record.allowed) is not tuple
        or type(record.inventory) is not tuple
        or not 1 <= len(record.allowed) <= MAX_PARTIES
        or len(record.inventory) != len(record.allowed)
    ):
        raise ValueError("party_dimensions")

    if any(
        type(state) is not str or state not in {"P", "F", "U"}
        for state in record.allowed
    ):
        raise ValueError("permission_state")

    if any(
        type(state) is not str
        or state not in {"complete", "incomplete", "unresolved"}
        for state in record.inventory
    ):
        raise ValueError("inventory_state")

    n = len(record.allowed)

    if (
        type(record.source) is not int
        or not 0 <= record.source < n
        or type(record.transfers) is not tuple
        or len(record.transfers) > MAX_TRANSFERS
    ):
        raise ValueError("graph_limits")

    adjacency = [[] for _ in range(n)]
    seen_pairs = set()

    for position, edge in enumerate(record.transfers):
        if (
            type(edge) is not Transfer
            or type(edge.source) is not int
            or type(edge.target) is not int
            or not 0 <= edge.source < n
            or not 0 <= edge.target < n
            or type(edge.presence) is not str
            or edge.presence not in {
                "confirmed", "ruled_out", "unresolved"
            }
            or type(edge.obligation) is not str
            or edge.obligation not in {"P", "F", "U"}
        ):
            raise ValueError("transfer_value")

        pair = (edge.source, edge.target)
        if pair in seen_pairs:
            raise ValueError("duplicate_directed_pair")
        seen_pairs.add(pair)
        adjacency[edge.source].append(position)

    def bfs(presence_values):
        predecessors = {record.source: None}
        queue = deque([record.source])

        while queue:
            source = queue.popleft()

            for position in adjacency[source]:
                edge = record.transfers[position]

                if (
                    edge.presence in presence_values
                    and edge.target not in predecessors
                ):
                    predecessors[edge.target] = position
                    queue.append(edge.target)

        return predecessors

    confirmed = bfs({"confirmed"})
    possible = bfs({"confirmed", "unresolved"})

    def witness(target, predecessors, final_edge=None):
        positions = []
        current = target

        while predecessors[current] is not None:
            position = predecessors[current]
            positions.append(position)
            current = record.transfers[position].source

        positions.reverse()

        if final_edge is not None:
            positions.append(final_edge)

        return {
            "party_positions": [
                record.source,
                *[record.transfers[p].target for p in positions],
            ],
            "transfer_positions": positions,
            "presence": [
                record.transfers[p].presence for p in positions
            ],
        }

    failures = []
    unknowns = []

    for party in sorted(possible):
        permission = record.allowed[party]

        if permission != "P":
            confirmed_failure = permission == "F" and party in confirmed
            destination = failures if confirmed_failure else unknowns

            destination.append({
                "reason": (
                    "party_not_permitted"
                    if permission == "F"
                    else "party_permission_unresolved"
                ),
                "witness": witness(
                    party, confirmed if confirmed_failure else possible
                ),
            })

        if record.inventory[party] != "complete":
            unknowns.append({
                "reason": "onward_inventory_" + record.inventory[party],
                "witness": witness(party, possible),
            })

    for position, edge in enumerate(record.transfers):
        if (
            edge.source in possible
            and edge.presence != "ruled_out"
            and edge.obligation != "P"
        ):
            confirmed_failure = (
                edge.source in confirmed
                and edge.presence == "confirmed"
                and edge.obligation == "F"
            )

            destination = failures if confirmed_failure else unknowns
            destination.append({
                "reason": (
                    "transfer_obligation_failure"
                    if edge.obligation == "F"
                    else "transfer_obligation_unresolved"
                ),
                "witness": witness(
                    edge.source,
                    confirmed if confirmed_failure else possible,
                    position,
                ),
            })

    return {
        "schema_version": "2.0.0",
        "outcome_vocabulary_version": "2.0.0",
        "provenance": {
            "sovereign_attribution": ATTRIBUTION,
            "attribution_use": "document_credit_only",
            "portable_commitment": "not_created",
        },
        "result": "F" if failures else "U" if unknowns else "P",
        "confirmed_path_reachable": sorted(confirmed),
        "modeled_possible_path_reachable": sorted(possible),
        "failures": failures,
        "unknowns": unknowns,
        "evidence_status": {
            "origin": "not_authenticated",
            "integrity": "not_verified",
            "inventory": "caller_supplied_review",
            "scope_and_currency": "caller_responsibility",
        },
    }
