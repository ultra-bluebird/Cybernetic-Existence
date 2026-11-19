import unittest
from decimal import Decimal

from privacy_budget import (
    PrivacyBudget,
    approve_query,
    contains_prohibited_audit_fields,
)


class PrivacyBudgetTests(unittest.TestCase):
    def budget(self) -> PrivacyBudget:
        return PrivacyBudget(
            project_alias="rotating_project_alias",
            dataset_class="aggregated_environmental_data",
            release_window="2026_q3",
            epsilon_cap=Decimal("0.3"),
            epsilon_used=Decimal("0.1"),
        )

    def test_approves_query_at_per_query_epsilon_limit(self) -> None:
        decision = approve_query(
            self.budget(),
            requested_epsilon="0.1",
            query_has_reidentification_risk=False,
            query_has_discriminatory_or_ranking_purpose=False,
            minimum_group_size_met=True,
        )

        self.assertTrue(decision.approved)
        self.assertEqual(decision.epsilon_remaining_after, Decimal("0.1"))

    def test_rejects_query_above_per_query_limit(self) -> None:
        decision = approve_query(
            self.budget(),
            requested_epsilon="0.1001",
            query_has_reidentification_risk=False,
            query_has_discriminatory_or_ranking_purpose=False,
            minimum_group_size_met=True,
        )

        self.assertFalse(decision.approved)
        self.assertIn("0.1 epsilon", decision.reason)

    def test_rejects_reidentification_risk(self) -> None:
        decision = approve_query(
            self.budget(),
            requested_epsilon="0.05",
            query_has_reidentification_risk=True,
            query_has_discriminatory_or_ranking_purpose=False,
            minimum_group_size_met=True,
        )

        self.assertFalse(decision.approved)
        self.assertIn("re-identification", decision.reason)

    def test_rejects_discriminatory_or_ranking_purpose(self) -> None:
        decision = approve_query(
            self.budget(),
            requested_epsilon="0.05",
            query_has_reidentification_risk=False,
            query_has_discriminatory_or_ranking_purpose=True,
            minimum_group_size_met=True,
        )

        self.assertFalse(decision.approved)
        self.assertIn("ranking", decision.reason)

    def test_audit_record_rejects_sensitive_and_ranking_fields(self) -> None:
        self.assertFalse(
            contains_prohibited_audit_fields(
                {
                    "event_type": "controlled_aggregate_query",
                    "project_pseudonym": "rotating_project_alias",
                }
            )
        )
        self.assertTrue(
            contains_prohibited_audit_fields(
                {
                    "event_type": "controlled_aggregate_query",
                    "researcher_name": "not_permitted",
                }
            )
        )


if __name__ == "__main__":
    unittest.main()
