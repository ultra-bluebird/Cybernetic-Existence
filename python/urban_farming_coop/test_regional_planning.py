import unittest

from regional_planning import (
    RegionalContribution,
    summarize_regional_yields,
    validate_non_ranking_incentive,
)


class RegionalPlanningTests(unittest.TestCase):
    def test_releases_aggregate_yield_when_contributor_threshold_is_met(self) -> None:
        summaries = summarize_regional_yields(
            [
                RegionalContribution(
                    zone_id="regional_food_zone",
                    crop_group="leafy_greens",
                    time_window="2026_spring",
                    cultivated_area_m2=100.0,
                    yield_kg=250.0,
                    contributor_count=3,
                )
            ],
            minimum_contributor_count=3,
        )

        summary = summaries[0]
        self.assertTrue(summary.public_release_allowed)
        self.assertEqual(summary.total_area_m2, 100.0)
        self.assertEqual(summary.total_yield_kg, 250.0)
        self.assertEqual(summary.yield_density_kg_m2, 2.5)

    def test_suppresses_small_cell_without_exposing_area_or_yield(self) -> None:
        summaries = summarize_regional_yields(
            [
                RegionalContribution(
                    zone_id="regional_food_zone",
                    crop_group="rare_crop_group",
                    time_window="2026_spring",
                    cultivated_area_m2=20.0,
                    yield_kg=25.0,
                    contributor_count=1,
                )
            ],
            minimum_contributor_count=3,
        )

        summary = summaries[0]
        self.assertFalse(summary.public_release_allowed)
        self.assertEqual(summary.total_area_m2, 0.0)
        self.assertEqual(summary.total_yield_kg, 0.0)
        self.assertIsNone(summary.yield_density_kg_m2)

    def test_accepts_shared_non_ranking_benefit(self) -> None:
        self.assertTrue(
            validate_non_ranking_incentive(
                benefit_type="shared_seed_library_access",
                changes_member_governance_weight=False,
                derived_from_individual_yield=False,
                derived_from_data_volume=False,
            )
        )

    def test_rejects_yield_based_governance_power(self) -> None:
        self.assertFalse(
            validate_non_ranking_incentive(
                benefit_type="cooperative_procurement",
                changes_member_governance_weight=True,
                derived_from_individual_yield=True,
                derived_from_data_volume=False,
            )
        )


if __name__ == "__main__":
    unittest.main()
