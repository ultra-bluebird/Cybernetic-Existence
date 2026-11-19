import unittest

from metrics import (
    BinaryOutcomes,
    MetricsValidationError,
    equalized_odds_report,
    reprojection_report,
)


class ReprojectionReportTests(unittest.TestCase):
    def test_accepts_subpixel_calibration(self) -> None:
        report = reprojection_report(
            observed_points=[(10.0, 10.0), (20.0, 20.0), (30.0, 30.0)],
            projected_points=[(10.1, 10.0), (19.9, 20.0), (30.0, 30.2)],
        )

        self.assertTrue(report.passes_target)
        self.assertLess(report.rms_reprojection_error_px, 1.0)
        self.assertEqual(report.correspondence_count, 3)

    def test_rejects_mismatched_point_sets(self) -> None:
        with self.assertRaises(MetricsValidationError):
            reprojection_report(
                observed_points=[(10.0, 10.0)],
                projected_points=[],
            )


class EqualizedOddsTests(unittest.TestCase):
    def test_accepts_small_gap_across_scenarios(self) -> None:
        report = equalized_odds_report(
            {
                "wheelchair_associated_space": BinaryOutcomes(96, 4, 95, 4),
                "pedestrian_associated_space": BinaryOutcomes(97, 3, 96, 3),
            }
        )

        self.assertTrue(report.passes_target)
        self.assertLess(report.equalized_odds_gap, 0.05)

    def test_blocks_gap_at_or_above_threshold(self) -> None:
        report = equalized_odds_report(
            {
                "service_animal_associated_space": BinaryOutcomes(90, 5, 95, 10),
                "pedestrian_associated_space": BinaryOutcomes(98, 1, 99, 2),
            }
        )

        self.assertFalse(report.passes_target)
        self.assertGreaterEqual(report.equalized_odds_gap, 0.05)

    def test_requires_multiple_scenario_strata(self) -> None:
        with self.assertRaises(MetricsValidationError):
            equalized_odds_report(
                {
                    "single_scenario": BinaryOutcomes(10, 1, 10, 1),
                }
            )


if __name__ == "__main__":
    unittest.main()
