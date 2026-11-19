import unittest

from planner import (
    ServiceArea,
    evaluate_plan,
    jain_fairness_index,
)


class FairLoadSheddingTests(unittest.TestCase):
    def test_equal_burden_has_perfect_jain_fairness(self) -> None:
        fairness = jain_fairness_index([2.0, 2.0, 2.0, 2.0])

        self.assertEqual(fairness, 1.0)

    def test_plan_meets_target_when_nonessential_outages_are_balanced(self) -> None:
        report = evaluate_plan(
            [
                ServiceArea("area_a", 10.0, 4.0, 2.0),
                ServiceArea("area_b", 12.0, 5.0, 2.0),
                ServiceArea("area_c", 9.0, 3.0, 2.0),
            ]
        )

        self.assertTrue(report.essential_loads_preserved)
        self.assertTrue(report.meets_fairness_target)
        self.assertFalse(report.requires_human_review)

    def test_unequal_plan_requires_human_review(self) -> None:
        report = evaluate_plan(
            [
                ServiceArea("area_a", 10.0, 4.0, 0.5),
                ServiceArea("area_b", 12.0, 5.0, 4.0),
                ServiceArea("area_c", 9.0, 3.0, 4.0),
            ]
        )

        self.assertFalse(report.meets_fairness_target)
        self.assertTrue(report.requires_human_review)

    def test_long_outage_requires_documented_exception(self) -> None:
        report = evaluate_plan(
            [
                ServiceArea("area_a", 10.0, 4.0, 5.0),
                ServiceArea("area_b", 12.0, 5.0, 5.0),
            ]
        )

        self.assertTrue(report.requires_human_review)
        self.assertIn("without a documented technical exception", report.reason)

    def test_documented_exception_still_requires_review(self) -> None:
        report = evaluate_plan(
            [
                ServiceArea(
                    "area_a",
                    10.0,
                    4.0,
                    5.0,
                    technical_exception_documented=True,
                ),
                ServiceArea(
                    "area_b",
                    12.0,
                    5.0,
                    5.0,
                    technical_exception_documented=True,
                ),
            ]
        )

        self.assertTrue(report.meets_fairness_target)
        self.assertTrue(report.requires_human_review)
        self.assertIn("technical exception", report.reason)


if __name__ == "__main__":
    unittest.main()
