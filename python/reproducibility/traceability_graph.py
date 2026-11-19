from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Iterable


@dataclass(frozen=True)
class TraceNode:
    node_id: str
    node_type: str


@dataclass(frozen=True)
class TraceEdge:
    source_id: str
    target_id: str
    relation: str


class TraceabilityError(ValueError):
    pass


REQUIRED_NODE_TYPES = {
    "claim",
    "evidence",
    "authorized_data_summary",
    "dataset_version",
    "method_version",
    "result",
    "review_event",
}


def build_traceability_graph(
    manifest: dict[str, Any],
) -> tuple[tuple[TraceNode, ...], tuple[TraceEdge, ...]]:
    _validate_manifest_shape(manifest)

    claim_id = manifest["claim"]["claim_id"]
    data_summary_id = manifest["authorized_data_summary"]["authorization_reference"]
    dataset_id = _versioned_id(
        manifest["dataset_version"]["dataset_id"],
        manifest["dataset_version"]["version"],
    )
    method_id = _versioned_id(
        manifest["method_version"]["method_id"],
        manifest["method_version"]["version"],
    )
    result_id = manifest["result_record"]["result_id"]
    review_id = manifest["review_event"]["review_id"]

    nodes: list[TraceNode] = [
        TraceNode(claim_id, "claim"),
        TraceNode(data_summary_id, "authorized_data_summary"),
        TraceNode(dataset_id, "dataset_version"),
        TraceNode(method_id, "method_version"),
        TraceNode(result_id, "result"),
        TraceNode(review_id, "review_event"),
    ]

    edges: list[TraceEdge] = []

    for evidence in manifest["evidence_references"]:
        evidence_id = evidence["evidence_manifest_id"]
        nodes.append(TraceNode(evidence_id, "evidence"))
        edges.append(
            TraceEdge(
                source_id=claim_id,
                target_id=evidence_id,
                relation="supported_by",
            )
        )
        edges.append(
            TraceEdge(
                source_id=evidence_id,
                target_id=data_summary_id,
                relation="contextualized_by",
            )
        )

    edges.extend(
        [
            TraceEdge(
                source_id=data_summary_id,
                target_id=dataset_id,
                relation="summarizes",
            ),
            TraceEdge(
                source_id=dataset_id,
                target_id=method_id,
                relation="analyzed_by",
            ),
            TraceEdge(
                source_id=method_id,
                target_id=result_id,
                relation="produced",
            ),
            TraceEdge(
                source_id=result_id,
                target_id=review_id,
                relation="reviewed_by",
            ),
        ]
    )

    _validate_graph(nodes, edges)

    return tuple(nodes), tuple(edges)


def render_dot(
    nodes: Iterable[TraceNode],
    edges: Iterable[TraceEdge],
) -> str:
    output = ["digraph reproducibility {", "  rankdir=LR;"]

    for node in nodes:
        output.append(
            f'  "{_escape(node.node_id)}" [label="{_escape(node.node_type)}"];'
        )

    for edge in edges:
        output.append(
            f'  "{_escape(edge.source_id)}" -> "{_escape(edge.target_id)}" '
            f'[label="{_escape(edge.relation)}"];'
        )

    output.append("}")
    return "\n".join(output)


def _validate_manifest_shape(manifest: dict[str, Any]) -> None:
    required = {
        "claim",
        "evidence_references",
        "authorized_data_summary",
        "dataset_version",
        "method_version",
        "result_record",
        "review_event",
    }

    missing = required.difference(manifest)
    if missing:
        raise TraceabilityError(
            f"manifest is missing required sections: {sorted(missing)}"
        )

    if not isinstance(manifest["evidence_references"], list):
        raise TraceabilityError("evidence_references must be a list")

    if not manifest["evidence_references"]:
        raise TraceabilityError("at least one evidence reference is required")


def _validate_graph(
    nodes: Iterable[TraceNode],
    edges: Iterable[TraceEdge],
) -> None:
    node_list = tuple(nodes)
    edge_list = tuple(edges)
    node_ids = [node.node_id for node in node_list]

    if any(not node_id.strip() for node_id in node_ids):
        raise TraceabilityError("traceability node identifiers must not be empty")

    if len(node_ids) != len(set(node_ids)):
        raise TraceabilityError("traceability node identifiers must be unique")

    known = set(node_ids)

    for edge in edge_list:
        if edge.source_id not in known or edge.target_id not in known:
            raise TraceabilityError("traceability edge references an unknown node")

        if not edge.relation.strip():
            raise TraceabilityError("traceability relation must not be empty")

    node_types = {node.node_type for node in node_list}

    if not REQUIRED_NODE_TYPES.issubset(node_types):
        missing = REQUIRED_NODE_TYPES.difference(node_types)
        raise TraceabilityError(
            f"traceability graph lacks required node types: {sorted(missing)}"
        )


def _versioned_id(base: str, version: str) -> str:
    if not base.strip() or not version.strip():
        raise TraceabilityError("versioned identifier fields must not be empty")

    return f"{base}@{version}"


def _escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')
