import unittest

from accessibility_maintenance_advisory import (
    HazardCoefficients,
    MaintenanceCovariates,
    MaintenanceDecision,
    WeibullBaseline,
    assess_maintenance,
)


def baseline() -> WeibullBaseline:
    return WeibullBaseline(shape=1.5, scale_days=1_000.0)


def coefficients() -> HazardCoefficients:
    return HazardCoefficients(
        cycles_per_day=0.0005,
        load_variance=0.10,
        sensor_drift=0.25,
        environmental_stress=0.15,
    )


def covariates() -> MaintenanceCovariates:
    return MaintenanceCovariates(
        cycles_per_day=800.0,
        load_variance=0.4,
        sensor_drift=0.1,
        environmental_stress=0.3,
        evidence_complete=True,
        accessible_alternative_verified=True,
        estimated_disruption_minutes=30,
        low_disruption_window_available=True,
    )


class AccessibilityMaintenanceAdvisoryTests(unittest.TestCase):
    def test_incomplete_evidence_requires_manual_inspection(self) -> None:
        input_data = covariates()
        incomplete = MaintenanceCovariates(
            **{
                **input_data.__dict__,
                "evidence_complete": False,
            }
        )

        result = assess_maintenance(
            baseline(),
            coefficients(),
            incomplete,
            age_days=500.0,
            prioritized_review_threshold=0.01,
        )

        self.assertEqual(
            result.decision,
            MaintenanceDecision.MANUAL_INSPECTION_REQUIRED,
        )
        self.assertIsNone(result.modeled_hazard_per_day)
        self.assertFalse(result.physical_action_authorized)

    def test_missing_accessible_alternative_requires_access_review(self) -> None:
        input_data = covariates()
        no_alternative = MaintenanceCovariates(
            **{
                **input_data.__dict__,
                "accessible_alternative_verified": False,
            }
        )

        result = assess_maintenance(
            baseline(),
            coefficients(),
            no_alternative,
            age_days=500.0,
            prioritized_review_threshold=0.01,
        )

        self.assertEqual(
            result.decision,
            MaintenanceDecision.ACCESS_IMPACT_REVIEW_REQUIRED,
        )
        self.assertFalse(result.physical_action_authorized)

    def test_high_risk_is_advisory_only(self) -> None:
        input_data = covariates()
        high_risk = MaintenanceCovariates(
            **{
                **input_data.__dict__,
                "sensor_drift": 3.0,
            }
        )

        result = assess_maintenance(
            baseline(),
            coefficients(),
            high_risk,
            age_days=900.0,
            prioritized_review_threshold=0.001,
        )

        self.assertEqual(
            result.decision,
            MaintenanceDecision.PRIORITIZED_HUMAN_REVIEW,
        )
        self.assertTrue(result.human_authorization_required)
        self.assertFalse(result.physical_action_authorized)

    def test_non_negative_inputs_are_required(self) -> None:
        invalid = MaintenanceCovariates(
            cycles_per_day=-1.0,
            load_variance=0.2,
            sensor_drift=0.1,
            environmental_stress=0.2,
            evidence_complete=True,
            accessible_alternative_verified=True,
            estimated_disruption_minutes=10,
            low_disruption_window_available=False,
        )

        with self.assertRaises(ValueError):
            assess_maintenance(
                baseline(),
                coefficients(),
                invalid,
                age_days=100.0,
                prioritized_review_threshold=0.01,
            )


if __name__ == "__main__":
    unittest.main()
