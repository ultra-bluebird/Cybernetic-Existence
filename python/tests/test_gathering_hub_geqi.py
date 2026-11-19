import unittest

from gathering_hub_geqi import (
    GeqiComponents,
    GeqiDecision,
    GeqiWeights,
    assess_geqi,
)


def weights() -> GeqiWeights:
    return GeqiWeights(
        air_quality=0.30,
        noise_comfort=0.20,
        thermal_comfort=0.25,
        light_quality=0.15,
        spatial_density=0.10,
    )


def components() -> GeqiComponents:
    return GeqiComponents(
        air_quality_score=0.80,
        noise_comfort_score=0.70,
        thermal_comfort_score=0.75,
        light_quality_score=0.85,
        spatial_density_score=0.65,
        calibrated=True,
        temporal_window_seconds=900,
        privacy_preserving_occupancy_method=True,
    )


class GatheringHubGeqiTests(unittest.TestCase):
    def test_complete_calibrated_components_produce_reportable_score(self) -> None:
        report = assess_geqi(weights(), components())

        self.assertEqual(
            report.decision,
            GeqiDecision.REPORTABLE_FOR_HUMAN_REVIEW,
        )
        self.assertIsNotNone(report.geqi_score)
        self.assertGreaterEqual(report.geqi_score, 0.0)
        self.assertLessEqual(report.geqi_score, 1.0)
        self.assertFalse(report.physical_action_authorized)

    def test_missing_component_requires_human_review(self) -> None:
        original = components()
        incomplete = GeqiComponents(
            **{
                **original.__dict__,
                "thermal_comfort_score": None,
            }
        )

        report = assess_geqi(weights(), incomplete)

        self.assertEqual(
            report.decision,
            GeqiDecision.INCOMPLETE_ENVIRONMENTAL_EVIDENCE,
        )
        self.assertIsNone(report.geqi_score)
        self.assertIn("thermal_comfort_score", report.missing_components)

    def test_non_private_occupancy_method_is_not_reportable(self) -> None:
        original = components()
        privacy_unsafe = GeqiComponents(
            **{
                **original.__dict__,
                "privacy_preserving_occupancy_method": False,
            }
        )

        report = assess_geqi(weights(), privacy_unsafe)

        self.assertEqual(
            report.decision,
            GeqiDecision.INCOMPLETE_ENVIRONMENTAL_EVIDENCE,
        )
        self.assertIn(
            "spatial_density_method_is_not_privacy_preserving",
            report.reasons,
        )

    def test_weights_must_sum_to_one(self) -> None:
        invalid_weights = GeqiWeights(
            air_quality=0.30,
            noise_comfort=0.20,
            thermal_comfort=0.25,
            light_quality=0.15,
            spatial_density=0.20,
        )

        with self.assertRaises(ValueError):
            assess_geqi(invalid_weights, components())


if __name__ == "__main__":
    unittest.main()
