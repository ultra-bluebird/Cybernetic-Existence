import unittest

from zone_alerts import (
    ZoneMeasurement,
    create_zone_alert,
    estimated_coverage_percent,
    meets_delivery_target,
)


class ZoneAlertTests(unittest.TestCase):
    def test_validated_measurement_above_threshold_creates_public_alert(self):
        alert = create_zone_alert(
            ZoneMeasurement(
                zone_id="public_alert_zone",
                rolling_24h_pm25_ug_m3=35.1,
                measurement_validated=True,
                measured_at="2026-09-01T00:00:00Z",
            ),
            channels=["public_display", "radio", "accessible_web", "opt_in_sms"],
        )

        self.assertEqual(alert.state, "VALIDATED_ZONE_ALERT")
        self.assertFalse(alert.includes_personal_data)
        self.assertFalse(alert.includes_health_records)
        self.assertFalse(alert.includes_precise_location_tracking)

    def test_exact_threshold_does_not_trigger_strict_greater_than_rule(self):
        alert = create_zone_alert(
            ZoneMeasurement(
                zone_id="public_alert_zone",
                rolling_24h_pm25_ug_m3=35.0,
                measurement_validated=True,
                measured_at="2026-09-01T00:00:00Z",
            ),
            channels=["public_display"],
        )

        self.assertEqual(alert.state, "NO_ALERT")

    def test_unvalidated_measurement_remains_preliminary(self):
        alert = create_zone_alert(
            ZoneMeasurement(
                zone_id="public_alert_zone",
                rolling_24h_pm25_ug_m3=70.0,
                measurement_validated=False,
                measured_at="2026-09-01T00:00:00Z",
            ),
            channels=["radio"],
        )

        self.assertEqual(alert.state, "PRELIMINARY_ELEVATED_READING")

    def test_coverage_target_is_ninety_five_percent(self):
        self.assertEqual(estimated_coverage_percent(1000, 950), 95.0)
        self.assertTrue(meets_delivery_target(1000, 950))
        self.assertFalse(meets_delivery_target(1000, 949))


if __name__ == "__main__":
    unittest.main()
