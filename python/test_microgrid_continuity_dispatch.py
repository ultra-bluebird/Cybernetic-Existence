import unittest

from microgrid_continuity_dispatch import (
    BuildingInput,
    build_deterministic_dispatch,
)


class MicrogridContinuityDispatchTest(unittest.TestCase):
    def test_trade_preserves_critical_continuity_for_high_priority_building(self) -> None:
        buildings = [
            BuildingInput(
                building_key="solar-surplus",
                available_generation_wh=1_200,
                critical_load_wh=300,
                noncritical_load_wh=100,
                battery_energy_wh=0,
                battery_capacity_wh=0,
                battery_discharge_limit_wh=0,
                willingness_to_pay_microunits_per_wh=10,
                minimum_critical_continuity_basis_points=8_000,
            ),
            BuildingInput(
                building_key="critical-care",
                available_generation_wh=100,
                critical_load_wh=900,
                noncritical_load_wh=100,
                battery_energy_wh=100,
                battery_capacity_wh=500,
                battery_discharge_limit_wh=100,
                willingness_to_pay_microunits_per_wh=100,
                minimum_critical_continuity_basis_points=10_000,
            ),
        ]

        solution = build_deterministic_dispatch(
            buildings=buildings,
            clearing_price_microunits_per_wh=25,
        )

        self.assertEqual(len(solution.trades), 1)
        self.assertEqual(solution.trades[0].seller_key, "solar-surplus")
        self.assertEqual(solution.trades[0].buyer_key, "critical-care")
        self.assertEqual(solution.trades[0].energy_wh, 700)

        dispatches = {
            dispatch.building_key: dispatch
            for dispatch in solution.building_dispatches
        }

        self.assertEqual(
            dispatches["critical-care"].served_critical_load_wh,
            900,
        )
        self.assertEqual(
            dispatches["critical-care"].critical_continuity_ratio_basis_points,
            10_000,
        )
        self.assertEqual(
            solution.block_critical_continuity_ratio_basis_points,
            10_000,
        )

    def test_reports_partial_continuity_when_supply_cannot_cover_critical_load(self) -> None:
        buildings = [
            BuildingInput(
                building_key="limited-supply",
                available_generation_wh=300,
                critical_load_wh=300,
                noncritical_load_wh=0,
                battery_energy_wh=0,
                battery_capacity_wh=0,
                battery_discharge_limit_wh=0,
                willingness_to_pay_microunits_per_wh=10,
                minimum_critical_continuity_basis_points=8_000,
            ),
            BuildingInput(
                building_key="critical-demand",
                available_generation_wh=0,
                critical_load_wh=1_000,
                noncritical_load_wh=0,
                battery_energy_wh=100,
                battery_capacity_wh=100,
                battery_discharge_limit_wh=100,
                willingness_to_pay_microunits_per_wh=100,
                minimum_critical_continuity_basis_points=10_000,
            ),
        ]

        solution = build_deterministic_dispatch(
            buildings=buildings,
            clearing_price_microunits_per_wh=25,
        )

        dispatches = {
            dispatch.building_key: dispatch
            for dispatch in solution.building_dispatches
        }

        self.assertEqual(
            dispatches["critical-demand"].served_critical_load_wh,
            100,
        )
        self.assertEqual(
            dispatches["critical-demand"].critical_continuity_ratio_basis_points,
            1_000,
        )


if __name__ == "__main__":
    unittest.main()
