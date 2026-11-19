import unittest

from crosswalk_timing import (
    CrosswalkConfiguration,
    CrosswalkSensorState,
    determine_crossing_time,
)
from restroom_maintenance import (
    RestroomMaintenanceState,
    RestroomSensorEvent,
)


class RestroomMaintenanceTests(unittest.TestCase):
    def test_usage_above_threshold_requests_maintenance_without_door_lock(self) -> None:
        state = RestroomMaintenanceState(
            maximum_plausible_occupancy=4,
            usage_threshold=50,
        )
        state.observe(
            RestroomSensorEvent(
                timestamp_s=0.0,
                event_type="manual_cleaning_confirmed",
                sensor_health_valid=True,
            )
        )

        result = None
        for count in range(51):
            result = state.observe(
                RestroomSensorEvent(
                    timestamp_s=float(count + 1),
                    event_type="entry",
                    sensor_health_valid=True,
                )
            )
            state.observe(
                RestroomSensorEvent(
                    timestamp_s=float(count + 1) + 0.1,
                    event_type="exit",
                    sensor_health_valid=True,
                )
            )

        self.assertIsNotNone(result)
        self.assertTrue(result.cleaning_review_requested)
        self.assertFalse(result.door_lock_action_permitted)

    def test_sensor_fault_never_authorizes_lockout(self) -> None:
        state = RestroomMaintenanceState(maximum_plausible_occupancy=2)

        result = state.observe(
            RestroomSensorEvent(
                timestamp_s=10.0,
                event_type="sensor_heartbeat",
                sensor_health_valid=False,
                tamper_detected=True,
            )
        )

        self.assertEqual(result.state, "SENSOR_TAMPER_OR_FAULT")
        self.assertTrue(result.cleaning_review_requested)
        self.assertFalse(result.door_lock_action_permitted)


class CrosswalkTimingTests(unittest.TestCase):
    def config(self) -> CrosswalkConfiguration:
        return CrosswalkConfiguration(
            crossing_width_m=12.0,
            slowest_expected_speed_m_s=0.9,
            fixed_buffer_s=4.0,
            minimum_walk_s=7.0,
            maximum_total_crossing_s=30.0,
            extension_increment_s=3.0,
        )

    def test_occupied_crossing_extends_never_shortens_time(self) -> None:
        result = determine_crossing_time(
            self.config(),
            CrosswalkSensorState(
                crossing_zone_state="CROSSING_OCCUPIED",
                sensor_health_valid=True,
            ),
        )

        self.assertEqual(result.state, "CROSSING_OCCUPIED_EXTENSION")
        self.assertTrue(result.universal_minimum_preserved)
        self.assertTrue(result.adaptive_extension_applied)
        self.assertFalse(result.trajectory_retained)
        self.assertFalse(result.identity_or_health_inference_performed)

    def test_sensor_fault_uses_accessible_fixed_time_fallback(self) -> None:
        config = self.config()
        result = determine_crossing_time(
            config,
            CrosswalkSensorState(
                crossing_zone_state="SENSOR_FAULT",
                sensor_health_valid=False,
            ),
        )

        self.assertEqual(result.state, "SENSOR_FAULT_FIXED_TIME_FALLBACK")
        self.assertEqual(
            result.applied_total_crossing_s,
            config.minimum_total_crossing_s,
        )
        self.assertTrue(result.universal_minimum_preserved)

    def test_clear_crossing_retains_universal_minimum(self) -> None:
        config = self.config()
        result = determine_crossing_time(
            config,
            CrosswalkSensorState(
                crossing_zone_state="CROSSING_CLEAR",
                sensor_health_valid=True,
            ),
        )

        self.assertEqual(result.state, "FIXED_TIME_ACCESSIBLE_OPERATION")
        self.assertEqual(
            result.applied_total_crossing_s,
            config.minimum_total_crossing_s,
        )
        self.assertTrue(result.universal_minimum_preserved)


if __name__ == "__main__":
    unittest.main()
