import unittest

from acceptance_metrics import (
    AcceptanceComponents,
    AggregateInteractionCounts,
    DidAggregate,
    acceptance_index,
    bounded_acceptance_index,
    difference_in_differences,
    evidence_completeness,
    proportion_interval,
    public_acceptance_score,
    small_cell_safe,
)


class AcceptanceMetricTests(unittest.TestCase):
    def test_harm_sensitive_acceptance_index(self) -> None:
        result = acceptance_index(
            AggregateInteractionCounts(
                positive=80,
                negative=10,
                total=100,
            ),
            baseline=0.20,
            harm_sensitivity=1.5,
        )

        self.assertAlmostEqual(result, 0.85)

    def test_bounded_index_is_in_unit_interval(self) -> None:
        value = bounded_acceptance_index(0.85)

        self.assertGreater(value, 0.0)
        self.assertLess(value, 1.0)

    def test_public_acceptance_score_subtracts_harm(self) -> None:
        score = public_acceptance_score(
            AcceptanceComponents(
                respectful_treatment=0.90,
                belonging=0.80,
                accessible_service_use=0.85,
                safety=0.88,
                participation=0.70,
                interoperability=0.75,
                harmful_experience=0.10,
            )
        )

        self.assertAlmostEqual(score, 0.738)

    def test_difference_in_differences(self) -> None:
        estimate = difference_in_differences(
            DidAggregate(
                treated_pre=0.50,
                treated_post=0.75,
                comparison_pre=0.55,
                comparison_post=0.60,
            )
        )

        self.assertAlmostEqual(estimate, 0.20)

    def test_proportion_interval(self) -> None:
        lower, upper = proportion_interval(successes=80, total=100)

        self.assertLess(lower, 0.80)
        self.assertGreater(upper, 0.80)

    def test_small_cell_suppression_rule(self) -> None:
        self.assertFalse(small_cell_safe(count=4, minimum_cell_size=5))
        self.assertTrue(small_cell_safe(count=5, minimum_cell_size=5))

    def test_evidence_completeness(self) -> None:
        completeness = evidence_completeness(
            present_fields={
                "method",
                "privacy",
                "uncertainty",
                "review",
            },
            required_fields={
                "method",
                "privacy",
                "uncertainty",
                "review",
                "limitations",
            },
        )

        self.assertAlmostEqual(completeness, 0.80)


if __name__ == "__main__":
    unittest.main()
