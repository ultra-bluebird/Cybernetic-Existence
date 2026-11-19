import unittest

from poe_continuity_allocation import (
    PoePortDevice,
    allocate_poe_budget,
)


class PoeContinuityAllocationTest(unittest.TestCase):
    def test_allocates_budget_to_critical_access_and_safety_devices_first(self) -> None:
        devices = [
            PoePortDevice(
                port_key="door-controller-a",
                device_kind="door_controller",
                required_power_watts=12.0,
                maximum_port_power_watts=25.5,
                minimum_operating_voltage_volts=44.0,
                switch_supply_voltage_volts=52.0,
                cable_length_meters=80.0,
                loop_resistance_ohms_per_meter=0.17,
                continuity_weight=100,
                critical=True,
            ),
            PoePortDevice(
                port_key="camera-a",
                device_kind="camera",
                required_power_watts=20.0,
                maximum_port_power_watts=25.5,
                minimum_operating_voltage_volts=44.0,
                switch_supply_voltage_volts=52.0,
                cable_length_meters=80.0,
                loop_resistance_ohms_per_meter=0.17,
                continuity_weight=70,
                critical=True,
            ),
            PoePortDevice(
                port_key="sensor-a",
                device_kind="sensor",
                required_power_watts=8.0,
                maximum_port_power_watts=12.95,
                minimum_operating_voltage_volts=44.0,
                switch_supply_voltage_volts=52.0,
                cable_length_meters=50.0,
                loop_resistance_ohms_per_meter=0.17,
                continuity_weight=40,
                critical=False,
            ),
        ]

        solution = allocate_poe_budget(
            switch_power_budget_watts=32.0,
            devices=devices,
        )

        dispatches = {
            dispatch.port_key: dispatch
            for dispatch in solution.port_dispatches
        }

        self.assertTrue(dispatches["door-controller-a"].powered)
        self.assertTrue(dispatches["camera-a"].powered)
        self.assertFalse(dispatches["sensor-a"].powered)
        self.assertEqual(solution.allocated_power_watts, 32.0)
        self.assertEqual(solution.continuity_ratio_basis_points, 8_500)

    def test_rejects_device_power_when_cable_voltage_drop_is_too_high(self) -> None:
        device = PoePortDevice(
            port_key="long-cable-camera",
            device_kind="camera",
            required_power_watts=25.0,
            maximum_port_power_watts=25.5,
            minimum_operating_voltage_volts=50.0,
            switch_supply_voltage_volts=52.0,
            cable_length_meters=100.0,
            loop_resistance_ohms_per_meter=0.17,
            continuity_weight=100,
            critical=True,
        )

        solution = allocate_poe_budget(
            switch_power_budget_watts=100.0,
            devices=[device],
        )

        self.assertFalse(solution.port_dispatches[0].powered)
        self.assertEqual(solution.continuity_ratio_basis_points, 0)


if __name__ == "__main__":
    unittest.main()
