import unittest

from public_benefit_metrics import (
    AccessibilityDividendInput,
    BarrierLifecycle,
    InteractionResult,
    accessibility_dividend,
    immediate_mitigation_coverage,
    interaction_completion,
    median_verified_repair_hours,
    no_disclosure_usability,
    parity_gap,
    repair_first_score,
    small_cell_publishable,
    verified_remediation_coverage,
)


class PublicBenefitMetricsTests(unittest.TestCase):
    def test_accessibility_dividend_rewards_system_improvement(self) -> None:
        dividend = accessibility_dividend(
            AccessibilityDividendInput(
                completion_before=0.70,
                completion_after=0.90,
                barrier_rate_before=0.25,
                barrier_rate_after=0.10,
                median_repair_before_days=20.0,
                median_repair_after_days=5.0,
            )
        )

        self.assertAlmostEqual(dividend, 0.32)

    def test_no_disclosure_usability_requires_all_core_tasks(self) -> None:
        self.assertEqual(no_disclosure_usability(10, 10), 1.0)
        self.assertEqual(no_disclosure_usability(8, 10), 0.8)

    def test_interoperability_parity_gap(self) -> None:
        results = [
            InteractionResult(mode="touch", successful=True),
            InteractionResult(mode="touch", successful=True),
            InteractionResult(mode="touch", successful=False),
            InteractionResult(mode="keyboard", successful=True),
            InteractionResult(mode="keyboard", successful=True),
            InteractionResult(mode="keyboard", successful=True),
        ]

        self.assertAlmostEqual(interaction_completion(results, "touch"), 2 / 3)
        self.assertAlmostEqual(interaction_completion(results, "keyboard"), 1.0)
        self.assertAlmostEqual(parity_gap(results, "touch", "keyboard"), 1 / 3)

    def test_small_cell_dignity_threshold(self) -> None:
        self.assertFalse(small_cell_publishable(count=4, threshold=5))
        self.assertTrue(small_cell_publishable(count=5, threshold=5))

    def test_repair_lifecycle_metrics(self) -> None:
        barriers = [
            BarrierLifecycle(
                reported_at_hours=0.0,
                acknowledged_at_hours=4.0,
                mitigated_at_hours=8.0,
                completed_at_hours=24.0,
                verified_at_hours=30.0,
            ),
            BarrierLifecycle(
                reported_at_hours=0.0,
                acknowledged_at_hours=6.0,
                mitigated_at_hours=10.0,
                completed_at_hours=48.0,
                verified_at_hours=54.0,
            ),
        ]

        mitigation = immediate_mitigation_coverage(barriers)
        verified = verified_remediation_coverage(barriers)
        repair_hours = median_verified_repair_hours(barriers)

        self.assertEqual(mitigation, 1.0)
        self.assertEqual(verified, 1.0)
        self.assertEqual(repair_hours, 42.0)

        score = repair_first_score(
            mitigation_coverage=mitigation,
            verified_coverage=verified,
            median_repair_hours=repair_hours,
            target_repair_hours=72.0,
        )

        self.assertAlmostEqual(score, 0.825)

    def test_unverified_repair_is_not_counted_as_verified(self) -> None:
        barriers = [
            BarrierLifecycle(
                reported_at_hours=0.0,
                acknowledged_at_hours=3.0,
                mitigated_at_hours=5.0,
                completed_at_hours=12.0,
                verified_at_hours=None,
            ),
        ]

        self.assertEqual(verified_remediation_coverage(barriers), 0.0)


if __name__ == "__main__":
    unittest.main()
