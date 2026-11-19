from __future__ import annotations

from collections import defaultdict, deque
from dataclasses import dataclass
from typing import Iterable


@dataclass(frozen=True)
class GraphNode:
    node_id: str
    node_type: str


@dataclass(frozen=True)
class GraphEdge:
    from_node_id: str
    to_node_id: str
    relation: str


class ProvenanceGraphError(ValueError):
    pass


REQUIRED_TYPES = {
    "manifest",
    "research_object",
    "claim",
    "source_record",
    "evidence_manifest",
    "authorization_scope",
    "dataset_version",
    "feature_set",
    "software_asset",
    "sbom",
    "method_configuration",
    "execution_environment",
    "result_artifact",
    "result_record",
    "limitation",
    "review_event",
    "governance_decision",
}


def validate_provenance_graph(
    nodes: Iterable[GraphNode],
    edges: Iterable[GraphEdge],
) -> None:
    node_list = tuple(nodes)
    edge_list = tuple(edges)

    if not node_list:
        raise ProvenanceGraphError("provenance graph must contain at least one node")

    node_ids = [node.node_id for node in node_list]

    if any(not node_id.strip() for node_id in node_ids):
        raise ProvenanceGraphError("node identifiers must not be empty")

    if len(node_ids) != len(set(node_ids)):
        raise ProvenanceGraphError("node identifiers must be unique")

    node_map = {node.node_id: node for node in node_list}
    node_types = {node.node_type for node in node_list}

    missing_types = REQUIRED_TYPES.difference(node_types)
    if missing_types:
        raise ProvenanceGraphError(
            f"graph lacks required node types: {sorted(missing_types)}"
        )

    adjacency: dict[str, list[str]] = defaultdict(list)
    reverse_adjacency: dict[str, list[str]] = defaultdict(list)

    for edge in edge_list:
        if edge.from_node_id not in node_map:
            raise ProvenanceGraphError(
                f"unknown edge source: {edge.from_node_id}"
            )

        if edge.to_node_id not in node_map:
            raise ProvenanceGraphError(
                f"unknown edge target: {edge.to_node_id}"
            )

        if not edge.relation.strip():
            raise ProvenanceGraphError("edge relation must not be empty")

        adjacency[edge.from_node_id].append(edge.to_node_id)
        reverse_adjacency[edge.to_node_id].append(edge.from_node_id)

    claims = [
        node.node_id
        for node in node_list
        if node.node_type == "claim"
    ]

    results = [
        node.node_id
        for node in node_list
        if node.node_type == "result_record"
    ]

    for claim_id in claims:
        reachable = _reachable_from(claim_id, adjacency)

        if not any(
            node_map[node_id].node_type == "evidence_manifest"
            for node_id in reachable
        ):
            raise ProvenanceGraphError(
                f"claim lacks reachable evidence manifest: {claim_id}"
            )

        if not any(
            node_map[node_id].node_type == "result_record"
            for node_id in reachable
        ):
            raise ProvenanceGraphError(
                f"claim lacks reachable result record: {claim_id}"
            )

    for result_id in results:
        predecessors = _reachable_from(result_id, reverse_adjacency)

        required_predecessors = {
            "dataset_version",
            "method_configuration",
            "software_asset",
            "execution_environment",
        }

        observed = {
            node_map[node_id].node_type
            for node_id in predecessors
        }

        if not required_predecessors.issubset(observed):
            missing = required_predecessors.difference(observed)
            raise ProvenanceGraphError(
                f"result lacks required provenance predecessors: {sorted(missing)}"
            )


def _reachable_from(
    start: str,
    adjacency: dict[str, list[str]],
) -> set[str]:
    visited: set[str] = set()
    queue: deque[str] = deque([start])

    while queue:
        current = queue.popleft()

        if current in visited:
            continue

        visited.add(current)
        queue.extend(adjacency[current])

    visited.discard(start)
    return visited
