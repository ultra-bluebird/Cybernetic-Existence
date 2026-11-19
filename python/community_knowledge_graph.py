from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Iterable


class NodeType(str, Enum):
    ISSUE = "issue"
    SOLUTION = "solution"
    RESOURCE = "resource"
    LOCATION = "location"
    COMMUNITY_GROUP = "community_group"
    CLAIM = "claim"
    EVIDENCE = "evidence"
    REVIEW = "review"
    MODERATION_DECISION = "moderation_decision"
    APPEAL = "appeal"
    SUPERSESSION = "supersession"


class EdgeType(str, Enum):
    REPORTS = "reports"
    FIXES = "fixes"
    LOCATED_AT = "located_at"
    ORGANIZES = "organizes"
    HAS_EXPERTISE = "has_expertise"
    ENDORSES = "endorses"
    SUPPORTS = "supports"
    CHALLENGES = "challenges"
    REVIEWED_BY = "reviewed_by"
    MODERATED_BY = "moderated_by"
    APPEALED_BY = "appealed_by"
    SUPERSEDES = "supersedes"
    WITHDRAWS = "withdraws"


class ClaimStatus(str, Enum):
    SUBMITTED = "submitted"
    NEEDS_EVIDENCE = "needs_evidence"
    CORROBORATING = "corroborating"
    REVIEWED_CONTEXTUAL = "reviewed_contextual"
    DISPUTED = "disputed"
    SUPERSEDED = "superseded"
    WITHDRAWN = "withdrawn"
    RESTRICTED = "restricted"


class ClaimClassification(str, Enum):
    CITED = "cited"
    ASSUMPTION_LABELED = "assumption_labeled"
    OPEN_QUESTION_LABELED = "open_question_labeled"
    UNSUPPORTED = "unsupported"


@dataclass(frozen=True)
class GraphNode:
    node_id: str
    node_type: NodeType
    visibility: str
    content_commitment: str

    def validate(self) -> None:
        if not self.node_id.strip():
            raise ValueError("node_id must not be empty")

        if self.visibility not in {"private", "restricted", "community", "public"}:
            raise ValueError("visibility must be private, restricted, community, or public")

        if not self.content_commitment.strip():
            raise ValueError("content_commitment must not be empty")


@dataclass(frozen=True)
class GraphEdge:
    source_node_id: str
    edge_type: EdgeType
    target_node_id: str

    def validate(self) -> None:
        if not self.source_node_id.strip():
            raise ValueError("source_node_id must not be empty")

        if not self.target_node_id.strip():
            raise ValueError("target_node_id must not be empty")


@dataclass(frozen=True)
class ClaimVerificationInput:
    claim_node_id: str
    classification: ClaimClassification
    status: ClaimStatus
    independent_evidence_count: int
    high_impact: bool
    human_review_recorded: bool
    appeal_path_available: bool
    conflict_disclosed: bool
    contains_sensitive_disclosure: bool


@dataclass(frozen=True)
class ClaimVerificationReport:
    claim_node_id: str
    reportable: bool
    publication_scope: str
    reasons: tuple[str, ...]


def validate_graph(
    nodes: Iterable[GraphNode],
    edges: Iterable[GraphEdge],
) -> None:
    node_list = list(nodes)
    edge_list = list(edges)

    node_ids: set[str] = set()

    for node in node_list:
        node.validate()

        if node.node_id in node_ids:
            raise ValueError(f"duplicate_node_id:{node.node_id}")

        node_ids.add(node.node_id)

    for edge in edge_list:
        edge.validate()

        if edge.source_node_id not in node_ids:
            raise ValueError(f"unknown_edge_source:{edge.source_node_id}")

        if edge.target_node_id not in node_ids:
            raise ValueError(f"unknown_edge_target:{edge.target_node_id}")


def assess_claim(input_data: ClaimVerificationInput) -> ClaimVerificationReport:
    if not input_data.claim_node_id.strip():
        raise ValueError("claim_node_id must not be empty")

    if input_data.independent_evidence_count < 0:
        raise ValueError("independent_evidence_count must not be negative")

    reasons: list[str] = []

    if input_data.contains_sensitive_disclosure:
        reasons.append("claim_contains_sensitive_disclosure_and_requires_restriction")

    if input_data.classification is ClaimClassification.UNSUPPORTED:
        reasons.append("claim_is_not_cited_or_labeled_as_assumption_or_open_question")

    if input_data.status in {ClaimStatus.WITHDRAWN, ClaimStatus.RESTRICTED}:
        reasons.append("claim_status_does_not_allow_broad_publication")

    if input_data.high_impact:
        if input_data.independent_evidence_count < 2:
            reasons.append("high_impact_claim_lacks_minimum_independent_corroboration")

        if not input_data.human_review_recorded:
            reasons.append("high_impact_claim_requires_human_review_record")

        if not input_data.appeal_path_available:
            reasons.append("high_impact_claim_requires_accessible_appeal_path")

        if not input_data.conflict_disclosed:
            reasons.append("high_impact_claim_requires_conflict_status_disclosure")

    reportable = not reasons

    if input_data.contains_sensitive_disclosure:
        publication_scope = "restricted"
    elif input_data.status is ClaimStatus.DISPUTED:
        publication_scope = "community_with_dispute_context"
    elif reportable:
        publication_scope = "community_or_public_subject_to_local_review"
    else:
        publication_scope = "not_reportable"

    if reportable:
        reasons.append(
            "claim_evidence_is_reportable_but_does_not_create_a_contributor_credibility_score"
        )

    return ClaimVerificationReport(
        claim_node_id=input_data.claim_node_id,
        reportable=reportable,
        publication_scope=publication_scope,
        reasons=tuple(reasons),
    )
