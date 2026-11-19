import unittest

from research_metrics import (
    CalibrationComparison,
    ImpactFactors,
    cohen_kappa,
    ecological_utility_per_joule,
    evidence_completeness,
    mean_absolute_error,
    repairability_index,
    weighted_geometric_knowledge_factor,
)


class ResearchMetricsTests(unittest.TestCase):
    def test_mean_absolute_error(self) -> None:
        result = mean_absolute_error(
            [
                CalibrationComparison(field_value=10.0, sensor_value=9.0),
                CalibrationComparison(field_value=12.0, sensor_value=14.0),
                CalibrationComparison(field_value=8.0, sensor_value=8.0),
            ]
        )

        self.assertAlmostEqual(result, 1.0)

    def test_cohen_kappa(self) -> None:
        self.assertAlmostEqual(
            cohen_kappa(observed_agreement=0.90, expected_agreement=0.50),
            0.80,
        )

    def test_weighted_geometric_knowledge_factor(self) -> None:
        value = weighted_geometric_knowledge_factor(
            [
                (0.90, 1.0),
                (0.81, 1.0),
            ]
        )

        self.assertAlmostEqual(value, 0.8538149682, places=8)

    def test_evidence_completeness(self) -> None:
        self.assertEqual(evidence_completeness(8, 8), 1.0)
        self.assertEqual(evidence_completeness(6, 8), 0.75)

    def test_ecological_utility_per_joule(self) -> None:
        value = ecological_utility_per_joule(
            ImpactFactors(
                knowledge_factor=0.90,
                ecological_value=0.80,
                residual_risk=0.10,
            ),
            energy_joules=18.0,
        )

        self.assertAlmostEqual(value, 0.036)

    def test_repairability_index(self) -> None:
        value = repairability_index(
            repairable_modules=5,
            total_critical_modules=6,
            diagnosis_minutes=10.0,
            diagnosis_target_minutes=30.0,
            repair_minutes=20.0,
            repair_target_minutes=60.0,
            parts_availability=0.90,
        )

        self.assertAlmostEqual(value, 0.7983333333, places=8)

    def test_repairability_index_rejects_invalid_module_count(self) -> None:
        with self.assertRaises(ValueError):
            repairability_index(
                repairable_modules=7,
                total_critical_modules=6,
                diagnosis_minutes=10.0,
                diagnosis_target_minutes=30.0,
                repair_minutes=20.0,
                repair_target_minutes=60.0,
                parts_availability=0.90,
            )


if __name__ == "__main__":
    unittest.main()
