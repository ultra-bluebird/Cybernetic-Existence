import unittest

from public_ev_charging.max_min_allocator import (
    ChargingAllocationValidationError,
    ChargingSession,
    allocate_max_min_current,
)
from urban_canopy.canopy_metrics import (
    canopy_cover,
    privacy_safe_remote_sensing_record,
    summarize_thermal_area,
)


class CanopyMetricsTests(unittest.TestCase):
    def test_calculates_canopy_fraction_from_valid_pixels(self) -> None:
        summary = canopy_cover([1, 0, 1, None, 0, 1])

        self.assertEqual(summary.valid_pixel_count, 5)
        self.assertEqual(summary.tree_pixel_count, 3)
        self.assertEqual(summary.canopy_cover_percent, 60.0)

    def test_detects_heat_hotspot_candidate(self) -> None:
        summary = summarize_thermal_area(
            surface_temperatures_kelvin=[310.15, 311.15, 312.15],
            reference_median_c=30.0,
            reference_standard_deviation_c=0.5,
            hotspot_threshold=2.0,
        )

        self.assertTrue(summary.hotspot_candidate)
        self.assertGreater(summary.heat_anomaly, 2.0)

    def test_remote_sensing_record_excludes_surveillance_and_identity_data(self) -> None:
        record = privacy_safe_remote_sensing_record()

        self.assertFalse(record["ground_level_surveillance_used"])
        self.assertFalse(record["person_tracking_used"])
        self.assertFalse(record["mobile_device_data_used"])
        self.assertFalse(record["wifi_or_bluetooth_data_used"])
        self.assertFalse(record["identity_data_used"])


class ChargingAllocationTests(unittest.TestCase):
    def test_allocates_available_current_using_max_min_fairness(self) -> None:
        result = allocate_max_min_current(
            [
                ChargingSession("session_a", 32.0, 32.0),
                ChargingSession("session_b", 16.0, 16.0),
                ChargingSession("session_c", 32.0, 32.0),
            ],
            available_site_current_a=60.0,
        )

        allocations = {
            allocation.session_label: allocation.allocated_current_a
            for allocation in result.allocations
        }

        self.assertEqual(allocations["session_b"], 16.0)
        self.assertEqual(allocations["session_a"], 22.0)
        self.assertEqual(allocations["session_c"], 22.0)
        self.assertEqual(result.total_allocated_current_a, 60.0)
        self.assertFalse(result.vin_retained)
        self.assertFalse(result.driver_identity_retained)
        self.assertFalse(result.payment_tier_used)
        self.assertFalse(result.residential_ranking_used)

    def test_rejects_identity_or_payment_tier_input(self) -> None:
        with self.assertRaises(ChargingAllocationValidationError):
            allocate_max_min_current(
                [
                    ChargingSession(
                        "session_a",
                        32.0,
                        32.0,
                        payment_tier_used=True,
                    )
                ],
                available_site_current_a=32.0,
            )


if __name__ == "__main__":
    unittest.main()
