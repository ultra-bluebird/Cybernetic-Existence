import unittest

from cusum_drift import (
    CusumDriftDetector,
    ReferenceObservation,
    scheduled_calibration_interval_days,
)


class CusumDriftTests(unittest.TestCase):
    def test_detects_persistent_positive_drift(self) -> None:
        detector = CusumDriftDetector(
            expected_residual_mean=0.0,
            allowance=0.1,
            decision_threshold=1.0,
        )

        observation = ReferenceObservation(
            sensor_value=12.0,
            reference_value=10.0,
            expected_value=10.0,
            tolerance=2.0,
            instrument_health_valid=True,
        )

        first = detector.observe(observation)
        second = detector.observe(observation)

        self.assertEqual(first.state, "SUSPECT_DRIFT")
        self.assertEqual(second.state, "DRIFT_REVIEW_REQUIRED")
        self.assertFalse(second.safe_for_automated_reliance)
        self.assertTrue(second.requires_calibration_review)

    def test_invalid_instrument_health_fails_closed(self) -> None:
        detector = CusumDriftDetector(
            expected_residual_mean=0.0,
            allowance=0.1,
            decision_threshold=1.0,
        )

        decision = detector.observe(
            ReferenceObservation(
                sensor_value=10.0,
                reference_value=10.0,
                expected_value=10.0,
                tolerance=1.0,
                instrument_health_valid=False,
            )
        )

        self.assertEqual(decision.state, "OUT_OF_SERVICE_FOR_AUTOMATED_RELIANCE")
        self.assertTrue(decision.requires_calibration_review)
        self.assertFalse(decision.safe_for_automated_reliance)

    def test_calibration_interval_applies_safety_factor(self) -> None:
        interval = scheduled_calibration_interval_days(
            maximum_allowable_error=1.0,
            conservative_drift_rate_per_day=0.1,
            safety_factor=2.0,
        )

        self.assertEqual(interval, 5.0)


if __name__ == "__main__":
    unittest.main()
