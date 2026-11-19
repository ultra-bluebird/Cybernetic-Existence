import unittest

from hyperlocal_air.hybrid_forecast import (
    SensorObservation,
    inverse_distance_residual_forecast,
    mean_absolute_error,
)
from public_lockers.offline_code import (
    code_entropy_bits,
    prepare_offline_record,
    verify_offline_code,
)


class HyperlocalAirTests(unittest.TestCase):
    def test_uses_only_calibrated_privacy_safe_observations(self) -> None:
        forecast = inverse_distance_residual_forecast(
            target_x_m=0.0,
            target_y_m=0.0,
            baseline_prediction=20.0,
            observations=[
                SensorObservation(
                    x_m=0.0,
                    y_m=0.0,
                    measured_value=22.0,
                    baseline_prediction=20.0,
                    calibrated=True,
                    sensor_health_valid=True,
                ),
                SensorObservation(
                    x_m=100.0,
                    y_m=100.0,
                    measured_value=100.0,
                    baseline_prediction=20.0,
                    calibrated=True,
                    sensor_health_valid=True,
                    individual_vehicle_data_used=True,
                ),
            ],
        )

        self.assertTrue(forecast.public_release_allowed)
        self.assertAlmostEqual(forecast.predicted_value, 22.0)

    def test_uses_coarser_fallback_when_no_valid_local_observations_exist(self) -> None:
        forecast = inverse_distance_residual_forecast(
            target_x_m=0.0,
            target_y_m=0.0,
            baseline_prediction=20.0,
            observations=[
                SensorObservation(
                    x_m=0.0,
                    y_m=0.0,
                    measured_value=21.0,
                    baseline_prediction=20.0,
                    calibrated=False,
                    sensor_health_valid=False,
                )
            ],
        )

        self.assertFalse(forecast.public_release_allowed)
        self.assertEqual(forecast.prediction_resolution, "regional_only")

    def test_computes_mean_absolute_error(self) -> None:
        error = mean_absolute_error(
            observed_values=[10.0, 20.0, 30.0],
            predicted_values=[11.0, 18.0, 33.0],
        )

        self.assertEqual(error, 2.0)


class OfflineLockerTests(unittest.TestCase):
    def test_generates_at_least_eighty_bits_of_code_entropy(self) -> None:
        self.assertGreaterEqual(code_entropy_bits(), 80)

    def test_verifies_code_without_network_or_identity_requirement(self) -> None:
        code, record = prepare_offline_record(
            compartment_label="public_compartment",
            expires_at_unix_s=2_000_000_000,
        )

        result = verify_offline_code(
            record=record,
            submitted_code=code,
            now_unix_s=1_900_000_000,
        )

        self.assertTrue(result.accepted)
        self.assertEqual(result.next_state, "ACCESS_OPEN")
        self.assertFalse(result.recipient_identity_required)
        self.assertFalse(result.network_required)

    def test_expired_code_routes_to_human_assistance_path(self) -> None:
        code, record = prepare_offline_record(
            compartment_label="public_compartment",
            expires_at_unix_s=1_000,
        )

        result = verify_offline_code(
            record=record,
            submitted_code=code,
            now_unix_s=1_001,
        )

        self.assertFalse(result.accepted)
        self.assertEqual(result.next_state, "CODE_EXPIRED")
        self.assertIn("human assistance", result.reason)

    def test_invalid_code_does_not_reveal_recipient_identity(self) -> None:
        _, record = prepare_offline_record(
            compartment_label="public_compartment",
            expires_at_unix_s=2_000_000_000,
        )

        result = verify_offline_code(
            record=record,
            submitted_code="23456789ABCDEFGH",
            now_unix_s=1_900_000_000,
        )

        self.assertFalse(result.accepted)
        self.assertFalse(result.recipient_identity_required)
        self.assertFalse(result.network_required)


if __name__ == "__main__":
    unittest.main()
