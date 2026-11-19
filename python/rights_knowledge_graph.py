from dataclasses import dataclass
from enum import Enum
from typing import Iterable


class NodeType(str, Enum):
    JURISDICTION = "JURISDICTION"
    AUTHORITY = "AUTHORITY"
    LEGAL_SOURCE = "LEGAL_SOURCE"
    SERVICE_CONTEXT = "SERVICE_CONTEXT"
    DUTY = "DUTY"
    PROCEDURE = "PROCEDURE"
    PLAIN_LANGUAGE_EXPLANATION = "PLAIN_LANGUAGE_EXPLANATION"
    PROVENANCE_RECORD = "PROVENANCE_RECORD"
    GOVERNANCE_TERM = "GOVERNANCE_TERM"
    OPEN_RESEARCH_QUESTION = "OPEN_RESEARCH_QUESTION"


@dataclass(frozen=True)
class RightsNode:
    node_ref: str
    node_type: NodeType
    jurisdiction_ref: str
    provenance_ref: str
    review_state: str
    publication_state: str
    plain_language_text: str | None = None
    legal_conclusion_claimed: bool = False
    identity_inference_allowed: bool = False
    individual_eligibility_decision_allowed: bool = False
    external_action_authorized: bool = False


@dataclass(frozen=True)
class RightsEdge:
    source_ref: str
    predicate: str
    target_ref: str


@dataclass(frozen=True)
class GraphValidationResult:
    valid: bool
    violations: tuple[str, ...]


def validate_rights_graph(nodes: Iterable[RightsNode]) -> GraphValidationResult:
    violations: list[str] = []

    for node in nodes:
        if node.legal_conclusion_claimed:
            violations.append(f"{node.node_ref}: legal conclusions are prohibited")

        if node.identity_inference_allowed:
            violations.append(f"{node.node_ref}: identity inference is prohibited")

        if node.individual_eligibility_decision_allowed:
            violations.append(
                f"{node.node_ref}: individual eligibility decisions are prohibited"
            )

        if node.external_action_authorized:
            violations.append(f"{node.node_ref}: external action authority is prohibited")

        if not node.jurisdiction_ref:
            violations.append(f"{node.node_ref}: jurisdiction reference is required")

        if not node.provenance_ref:
            violations.append(f"{node.node_ref}: provenance reference is required")

    return GraphValidationResult(
        valid=not violations,
        violations=tuple(violations),
    )


def find_nodes_for_jurisdiction(
    nodes: Iterable[RightsNode],
    jurisdiction_ref: str,
) -> tuple[RightsNode, ...]:
    return tuple(
        node for node in nodes if node.jurisdiction_ref == jurisdiction_ref
    )
