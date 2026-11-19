import unittest

from vehicle_only_eta import (
    RouteSegment,
    TransitPredictionValidationError,
    VehicleTelemetry,
    predict_arrival_seconds,
    prediction_quality,
)


class VehicleOnlyEtaTests(unittest.TestCase):
    def telemetry(self, **changes) -> VehicleTelemetry:
        values = {
            "route_id": "public_route",
            "trip_id": "current_trip",
            "telemetry_age_s": 20.0,
            "schedule_deviation_s": 10.0,
            "estimated_dwell_adjustment_s": 5.0,
            "disruption_adjustment_s": 0.0,
            "passenger_device_data_used": False,
            "wifi_or_bluetooth_tracking_used": False,
        }
        values.update(changes)
        return VehicleTelemetry(**values)

    def test_predicts_from_vehicle_and_route_data_only(self) -> None:
        prediction = predict_arrival_seconds(
            [
                RouteSegment(distance_m=500.0, expected_speed_m_s=10.0),
                RouteSegment(distance_m=250.0, expected_speed_m_s=5.0),
            ],
            self.telemetry(),
        )

        self.assertEqual(prediction.predicted_arrival_seconds, 115.0)
        self.assertEqual(prediction.prediction_mode, "LIVE_VEHICLE_PREDICTION")
        self.assertFalse(prediction.passenger_tracking_used)

    def test_stale_vehicle_data_uses_schedule_estimate_state(self) -> None:
        prediction = predict_arrival_seconds(
            [RouteSegment(distance_m=500.0, expected_speed_m_s=10.0)],
            self.telemetry(telemetry_age_s=91.0),
        )

        self.assertEqual(prediction.prediction_mode, "SCHEDULE_BASED_ESTIMATE")

    def test_rejects_passenger_device_tracking(self) -> None:
        with self.assertRaises(TransitPredictionValidationError):
            predict_arrival_seconds(
                [RouteSegment(distance_m=500.0, expected_speed_m_s=10.0)],
                self.telemetry(passenger_device_data_used=True),
            )

    def test_measures_prediction_accuracy(self) -> None:
        mae, within_one_minute = prediction_quality(
            actual_arrival_seconds=[100.0, 200.0, 300.0, 400.0],
            predicted_arrival_seconds=[110.0, 250.0, 350.0, 420.0],
        )

        self.assertEqual(mae, 32.5)
        self.assertEqual(within_one_minute, 1.0)
        self.assertLess(mae, 60.0)


if __name__ == "__main__":
    unittest.main()
