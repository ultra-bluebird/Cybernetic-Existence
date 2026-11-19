# SPDX-License-Identifier: MIT OR Apache-2.0
"""Local correction propagation; notifications never establish review."""

from collections import deque
from dataclasses import dataclass
from enum import Enum
from pathlib import PurePosixPath
import unittest


ENGINE_VERSION = "1.0.0"


class ReviewState(Enum):
    NONE = "none"
    ACKNOWLEDGED = "acknowledged"
    IN_PROGRESS = "in_progress"
    RELIANCE_RETAINED = "reviewed_reliance_retained"
    RELIANCE_WITHDRAWN = "reliance_withdrawn"


def artifact_path(value):
    if type(value) is not str or not 1 <= len(value) <= 512:
        raise ValueError("bounded plain artifact path required")
    if value != value.strip() or "\\" in value:
        raise ValueError("canonical repository-relative path required")
    if any(ord(char) < 33 or ord(char) > 126 for char in value):
        raise ValueError("ASCII path without whitespace required")
    path = PurePosixPath(value)
    if path.is_absolute() or ".." in path.parts or ":" in value:
        raise ValueError("unsafe artifact path")
    if str(path) != value or value == ".":
        raise ValueError("noncanonical artifact path")


@dataclass(frozen=True)
class Dependency:
    upstream: str
    downstream: str

    def __post_init__(self):
        artifact_path(self.upstream)
        artifact_path(self.downstream)


@dataclass(frozen=True)
class RelianceReview:
    artifact: str
    against_revision: int
    state: ReviewState

    def __post_init__(self):
        artifact_path(self.artifact)
        if type(self.against_revision) is not int or self.against_revision < 0:
            raise ValueError("nonnegative correction revision required")
        if type(self.state) is not ReviewState:
            raise ValueError("typed review state required")


def affected_artifacts(nodes, edges, source):
    if type(nodes) is not tuple or type(edges) is not tuple:
        raise ValueError("immutable node and edge tuples required")
    for node in nodes:
        artifact_path(node)
    artifact_path(source)
    if len(set(nodes)) != len(nodes):
        raise ValueError("duplicate artifact path")
    if source not in nodes:
        raise ValueError("source absent from graph")

    adjacency = {node: set() for node in nodes}
    for edge in edges:
        if type(edge) is not Dependency:
            raise ValueError("typed dependency required")
        if edge.upstream not in adjacency or edge.downstream not in adjacency:
            raise ValueError("dependency endpoint absent")
        adjacency[edge.upstream].add(edge.downstream)

    visited = {source}
    queue = deque([source])
    while queue:
        current = queue.popleft()
        for downstream in sorted(adjacency[current]):
            if downstream not in visited:
                visited.add(downstream)
                queue.append(downstream)

    return tuple(sorted(visited - {source}))


def reliance_disposition(review_state, against_revision, current_revision):
    if (
        review_state == "reliance_withdrawn"
        and against_revision == current_revision
    ):
        return "reliance_withdrawn_reported"
    if (
        review_state == "reviewed_reliance_retained"
        and against_revision == current_revision
    ):
        return "reviewed_reliance_retained_reported"
    return "reliance_review_required"


def propagation_report(nodes, edges, source, correction_revision, reviews):
    if type(correction_revision) is not int or correction_revision < 0:
        raise ValueError("nonnegative correction revision required")
    if type(reviews) is not tuple:
        raise ValueError("immutable review tuple required")

    affected = affected_artifacts(nodes, edges, source)
    by_artifact = {}

    for review in reviews:
        if type(review) is not RelianceReview:
            raise ValueError("typed reliance review required")
        if review.artifact not in affected:
            raise ValueError("review outside this correction's downstream scope")
        if review.artifact in by_artifact:
            raise ValueError("ambiguous multiple review records")
        if review.against_revision > correction_revision:
            raise ValueError("review refers to a future correction revision")
        by_artifact[review.artifact] = review

    rows = []
    for artifact in affected:
        review = by_artifact.get(artifact)
        disposition = (
            "reliance_review_required"
            if review is None
            else reliance_disposition(
                review.state.value,
                review.against_revision,
                correction_revision,
            )
        )
        rows.append({
            "artifact": artifact,
            "disposition": disposition,
            "substantive_review_quality": "not_verified",
        })

    return {
        "engine_version": ENGINE_VERSION,
        "source_artifact": source,
        "correction_revision": correction_revision,
        "downstream": rows,
        "graph_completeness": "not_established",
        "dependent_claims_automatically_false": False,
        "historical_records_rewritten": False,
        "ordinary_support": "unchanged_by_this_assessment",
        "external_action_authorized": False,
    }


class PropagationTests(unittest.TestCase):
    def graph(self):
        nodes = (
            "research/assurance/research_claim_ledger.json",
            "research/assurance/minimum_acceptance_gate.py",
            "research/comprehension/world_save_mapping.json",
            "docs/augma/voluntary-dividend-pilot.md",
        )
        edges = (
            Dependency(nodes[0], nodes[1]),
            Dependency(nodes[1], nodes[2]),
            Dependency(nodes[0], nodes[3]),
            Dependency(nodes[2], nodes[0]),
        )
        return nodes, edges

    def test_transitive_cycle_is_bounded(self):
        nodes, edges = self.graph()
        self.assertEqual(
            affected_artifacts(nodes, edges, nodes[0]),
            tuple(sorted(nodes[1:])),
        )

    def test_acknowledgment_does_not_close_review(self):
        self.assertEqual(
            reliance_disposition("acknowledged", 2, 2),
            "reliance_review_required",
        )

    def test_stale_review_does_not_close_new_correction(self):
        self.assertEqual(
            reliance_disposition("reviewed_reliance_retained", 1, 2),
            "reliance_review_required",
        )

    def test_review_is_reported_not_authenticated(self):
        nodes, edges = self.graph()
        review = RelianceReview(
            nodes[1], 2, ReviewState.RELIANCE_RETAINED
        )
        report = propagation_report(nodes, edges, nodes[0], 2, (review,))
        row = next(
            item for item in report["downstream"]
            if item["artifact"] == nodes[1]
        )
        self.assertEqual(
            row["disposition"], "reviewed_reliance_retained_reported"
        )
        self.assertFalse(report["external_action_authorized"])


if __name__ == "__main__":
    unittest.main()
