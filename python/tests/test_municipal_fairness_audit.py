import unittest

from municipal_fairness_audit import (
    AggregateConfusionMatrix,
    AuditDecision,
    FairnessAuditInput,
    assess_fairness,
    aggregate_qos_failure_rate,
)


def audit_input() -> FairnessAuditInput:
    return FairnessAuditInput(
        purpose="aggregate_service_access_fairness_review",
        group_a=AggregateConfusionMatrix(
            true_positive=40,
            false_positive=10,
            true_negative=30,
            false_negative=20,
        ),
        group_b=AggregateConfusionMatrix(
            true_positive=42,
            false_positive=8,
            true_negative=32,
            false_negative=18,
        ),
        minimum_group_size=50,
        voluntary_audit_cohorts=True,
        accessible_appeal_available=True,
        identity_inference_used=False,
        proxy_feature_used=False,
    )


class MunicipalFairnessAuditTests(unittest.TestCase):
    def test_aggregate_audit_metrics_are_reportable(self) -> None:
        report = assess_fairness(audit_input())

        self.assertEqual(report.decision, AuditDecision.REPORTABLE)
        self.assertIsNotNone(report.demographic_parity_difference)
        self.assertIsNotNone(report.equalized_opportunity_difference)
        self.assertIsNotNone(report.predictive_parity_difference)

    def test_identity_inference_invalidates_the_audit(self) -> None:
        source = audit_input()
        audit = FairnessAuditInput(
            **{
                **source.__dict__,
                "identity_inference_used": True,
            }
        )

        report = assess_fairness(audit)

        self.assertEqual(report.decision, AuditDecision.INSUFFICIENT_EVIDENCE)
        self.assertIn("identity_inference_is_prohibited", report.findings)

    def test_missing_appeal_path_invalidates_the_audit(self) -> None:
        source = audit_input()
        audit = FairnessAuditInput(
            **{
                **source.__dict__,
                "accessible_appeal_available": False,
            }
        )

        report = assess_fairness(audit)

        self.assertEqual(report.decision, AuditDecision.INSUFFICIENT_EVIDENCE)
        self.assertIn(
            "accessible_appeal_and_human_review_are_required",
            report.findings,
        )

    def test_small_group_results_are_suppressed(self) -> None:
        source = audit_input()
        audit = FairnessAuditInput(
            **{
                **source.__dict__,
                "group_a": AggregateConfusionMatrix(
                    true_positive=10,
                    false_positive=5,
                    true_negative=10,
                    false_negative=5,
                ),
            }
        )

        report = assess_fairness(audit)

        self.assertEqual(report.decision, AuditDecision.INSUFFICIENT_EVIDENCE)
        self.assertIn(
            "group_a_does_not_meet_minimum_aggregation_threshold",
            report.findings,
        )

    def test_qos_failure_rate_is_aggregate_only(self) -> None:
        failure_rate = aggregate_qos_failure_rate(
            successful_requests=980,
            failed_requests=20,
        )

        self.assertEqual(failure_rate, 0.02)


if __name__ == "__main__":
    unittest.main()
