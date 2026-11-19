import unittest

from differential_privacy import (
    AggregationCell,
    PrivacyParameters,
    average_fill_sensitivity,
    basic_composition_deltas,
    basic_composition_epsilons,
    clip_fill_level,
    gaussian_standard_deviation,
    laplace_scale,
    laplace_standard_deviation,
    overflow_risk,
    release_laplace_average,
    should_collect,
)


class DifferentialPrivacyTests(unittest.TestCase):
    def test_fill_clipping_bounds_contribution(self) -> None:
        self.assertEqual(clip_fill_level(-0.25), 0.0)
        self.assertEqual(clip_fill_level(0.40), 0.40)
        self.assertEqual(clip_fill_level(1.25), 1.0)

    def test_average_sensitivity_uses_cell_size(self) -> None:
        self.assertAlmostEqual(
            average_fill_sensitivity(fill_cap=1.0, minimum_bin_count=10),
            0.10,
        )

    def test_laplace_calibration(self) -> None:
        scale = laplace_scale(sensitivity_l1=0.10, epsilon=0.50)

        self.assertAlmostEqual(scale, 0.20)
        self.assertAlmostEqual(
            laplace_standard_deviation(scale),
            0.282842712474619,
        )

    def test_gaussian_calibration(self) -> None:
        sigma = gaussian_standard_deviation(
            sensitivity_l2=0.10,
            epsilon=0.50,
            delta=1e-5,
        )

        self.assertGreater(sigma, 0.0)

    def test_small_cell_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            AggregationCell(
                cell_name="cell-a",
                clipped_fill_values=(0.2, 0.4),
                minimum_bin_count=3,
                fill_cap=1.0,
            )

    def test_laplace_release_contains_aggregate_metadata(self) -> None:
        estimate = release_laplace_average(
            AggregationCell(
                cell_name="cell-a",
                clipped_fill_values=(0.2, 0.4, 0.5, 0.9),
                minimum_bin_count=4,
                fill_cap=1.0,
            ),
            PrivacyParameters(epsilon=0.75),
        )

        self.assertEqual(estimate.mechanism, "laplace")
        self.assertEqual(estimate.protected_bin_count, 4)
        self.assertGreater(estimate.noise_standard_deviation, 0.0)

    def test_basic_composition(self) -> None:
        parameters = [
            PrivacyParameters(epsilon=0.2),
            PrivacyParameters(epsilon=0.3, delta=1e-6),
            PrivacyParameters(epsilon=0.1, delta=2e-6),
        ]

        self.assertAlmostEqual(basic_composition_epsilons(parameters), 0.6)
        self.assertAlmostEqual(basic_composition_deltas(parameters), 3e-6)

    def test_overflow_signal_overrides_uncertain_estimate(self) -> None:
        estimate = release_laplace_average(
            AggregationCell(
                cell_name="cell-a",
                clipped_fill_values=(0.1, 0.2, 0.3, 0.4),
                minimum_bin_count=4,
                fill_cap=1.0,
            ),
            PrivacyParameters(epsilon=0.75),
        )

        self.assertTrue(
            should_collect(
                estimate=estimate,
                collection_threshold=0.90,
                confidence_multiplier=2.0,
                overflow_safety_signal=True,
            )
        )

    def test_overflow_risk_uses_upper_uncertainty_bound(self) -> None:
        estimate = release_laplace_average(
            AggregationCell(
                cell_name="cell-a",
                clipped_fill_values=(0.7, 0.8, 0.9, 0.9),
                minimum_bin_count=4,
                fill_cap=1.0,
            ),
            PrivacyParameters(epsilon=0.75),
        )

        self.assertIsInstance(
            overflow_risk(
                estimate=estimate,
                overflow_threshold=0.85,
                confidence_multiplier=2.0,
            ),
            bool,
        )


if __name__ == "__main__":
    unittest.main()
