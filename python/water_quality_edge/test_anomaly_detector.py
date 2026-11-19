import unittest

from anomaly_detector import (
    BaselineModel,
    EdgeAnomalyState,
    WaterQualityValidationError,
    WaterReading,
)


class EdgeAnomalyDetectorTests(unittest.TestCase):
    def baseline_readings(self):
        return [
            WaterReading(
                temperature_c=20.0 + (index % 3) * 0.1,
                turbidity_ntu=0.2 + (index % 2) * 0.01,
                ph=7.2 + (index % 4) * 0.01,
                conductivity_us_cm=280.0 + (index % 5),
                battery_v=3.8,
            )
            for index in range(20)
        ]

    def test_persistent_deviation_requests_maintenance_review(self):
        model = BaselineModel.fit(
            self.baseline_readings(),
            threshold=16.0,
            required_consecutive_exceedances=3,
        )
        state = EdgeAnomalyState()
        shifted_reading = WaterReading(
            temperature_c=32.0,
            turbidity_ntu=10.0,
            ph=8.8,
            conductivity_us_cm=900.0,
            battery_v=3.8,
        )

        first = state.evaluate(model, shifted_reading)
        second = state.evaluate(model, shifted_reading)
        third = state.evaluate(model, shifted_reading)

        self.assertEqual(first["state"], "NORMAL")
        self.assertEqual(second["state"], "NORMAL")
        self.assertEqual(third["state"], "MAINTENANCE_REVIEW_REQUESTED")
        self.assertFalse(third["raw_reading_exported"])

    def test_maintenance_mode_never_requests_alert(self):
        model = BaselineModel.fit(self.baseline_readings(), threshold=16.0)
        state = EdgeAnomalyState()
        reading = WaterReading(
            temperature_c=40.0,
            turbidity_ntu=100.0,
            ph=12.0,
            conductivity_us_cm=10000.0,
            battery_v=3.8,
            sensor_maintenance_mode=True,
        )

        result = state.evaluate(model, reading)

        self.assertEqual(result["state"], "RECHECK_REQUIRED")
        self.assertIsNone(result["score"])

    def test_invalid_ph_is_rejected(self):
        with self.assertRaises(WaterQualityValidationError):
            WaterReading(
                temperature_c=20.0,
                turbidity_ntu=0.2,
                ph=15.0,
                conductivity_us_cm=280.0,
                battery_v=3.8,
            ).feature_vector()


if __name__ == "__main__":
    unittest.main()
