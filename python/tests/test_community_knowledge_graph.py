import unittest

from community_knowledge_graph import (
    ClaimClassification,
    ClaimStatus,
    ClaimVerificationInput,
    EdgeType,
    GraphEdge,
    GraphNode,
    NodeType,
    assess_claim,
    validate_graph,
)


class CommunityKnowledgeGraphTests(unittest.TestCase):
    def test_valid_graph_accepts_known_node_references(self) -> None:
        nodes = [
            GraphNode(
                node_id="issue-001",
                node_type=NodeType.ISSUE,
                visibility="community",
                content_commitment="issue-content-commitment",
            ),
            GraphNode(
                node_id="claim-001",
                node_type=NodeType.CLAIM,
                visibility="community",
                content_commitment="claim-content-commitment",
            ),
        ]

        edges = [
            GraphEdge(
                source_node_id="claim-001",
                edge_type=EdgeType.REPORTS,
                target_node_id="issue-001",
            )
        ]

        validate_graph(nodes, edges)

    def test_unknown_edge_target_is_rejected(self) -> None:
        nodes = [
            GraphNode(
                node_id="claim-001",
                node_type=NodeType.CLAIM,
                visibility="community",
                content_commitment="claim-content-commitment",
            )
        ]

        edges = [
            GraphEdge(
                source_node_id="claim-001",
                edge_type=EdgeType.SUPPORTS,
                target_node_id="missing-evidence",
            )
        ]

        with self.assertRaises(ValueError):
            validate_graph(nodes, edges)

    def test_high_impact_claim_requires_corroboration_review_and_appeal(self) -> None:
        report = assess_claim(
            ClaimVerificationInput(
                claim_node_id="claim-001",
                classification=ClaimClassification.CITED,
                status=ClaimStatus.CORROBORATING,
                independent_evidence_count=1,
                high_impact=True,
                human_review_recorded=False,
                appeal_path_available=False,
                conflict_disclosed=False,
                contains_sensitive_disclosure=False,
            )
        )

        self.assertFalse(report.reportable)
        self.assertIn(
            "high_impact_claim_lacks_minimum_independent_corroboration",
            report.reasons,
        )
        self.assertIn(
            "high_impact_claim_requires_human_review_record",
            report.reasons,
        )
        self.assertIn(
            "high_impact_claim_requires_accessible_appeal_path",
            report.reasons,
        )

    def test_labeled_open_question_can_be_reportable_when_not_high_impact(self) -> None:
        report = assess_claim(
            ClaimVerificationInput(
                claim_node_id="claim-question-001",
                classification=ClaimClassification.OPEN_QUESTION_LABELED,
                status=ClaimStatus.REVIEWED_CONTEXTUAL,
                independent_evidence_count=0,
                high_impact=False,
                human_review_recorded=True,
                appeal_path_available=True,
                conflict_disclosed=True,
                contains_sensitive_disclosure=False,
            )
        )

        self.assertTrue(report.reportable)
        self.assertEqual(
            report.publication_scope,
            "community_or_public_subject_to_local_review",
        )

    def test_sensitive_disclosure_is_restricted(self) -> None:
        report = assess_claim(
            ClaimVerificationInput(
                claim_node_id="claim-sensitive-001",
                classification=ClaimClassification.CITED,
                status=ClaimStatus.REVIEWED_CONTEXTUAL,
                independent_evidence_count=3,
                high_impact=True,
                human_review_recorded=True,
                appeal_path_available=True,
                conflict_disclosed=True,
                contains_sensitive_disclosure=True,
            )
        )

        self.assertFalse(report.reportable)
        self.assertEqual(report.publication_scope, "restricted")


if __name__ == "__main__":
    unittest.main()
