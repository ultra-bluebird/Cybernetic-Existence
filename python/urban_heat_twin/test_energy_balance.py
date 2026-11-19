import unittest

from energy_balance import (
    InterventionScenario,
    SurfaceEnergyBalance,
    ThermalResponseCoefficients,
    absorbed_solar_change_w_m2,
    control_volume_temperature_change_c,
    estimate_scenario,
)


class UrbanHeatTwinTests(unittest.TestCase):
    def test_surface_energy_balance_closes(self) -> None:
        balance = SurfaceEnergyBalance(
            net_radiation_w_m2=500.0,
            sensible_heat_w_m2=180.0,
            latent_heat_w_m2=140.0,
            ground_heat_w_m2=90.0,
            storage_change_w_m2=90.0,
        )

        self.assertEqual(balance.residual_w_m2(), 0.0)
        self.assertTrue(balance.closes_within(0.1))

    def test_reflective_roof_reduces_absorbed_shortwave_energy(self) -> None:
        change = absorbed_solar_change_w_m2(
            incoming_shortwave_w_m2=900.0,
            baseline_albedo=0.20,
            intervention_albedo=0.65,
        )

        self.assertAlmostEqual(change, -405.0)

    def test_control_volume_temperature_change(self) -> None:
        change = control_volume_temperature_change_c(
            sensible_heat_change_w_m2=-50.0,
            duration_seconds=3600.0,
            air_density_kg_m3=1.18,
            air_specific_heat_j_kg_k=1005.0,
            mixing_height_m=100.0,
        )

        self.assertLess(change, 0.0)

    def test_promotion_requires_ecology_access_privacy_and_review(self) -> None:
        scenario = InterventionScenario(
            reflective_roof_fraction=0.50,
            canopy_fraction_change=0.20,
            green_wall_fraction=0.10,
            green_roof_fraction=0.10,
            shade_structure_fraction=0.15,
            irrigation_water_m3_day=20.0,
            sustainable_water_limit_m3_day=25.0,
            accessible_route_preserved=True,
            privacy_safe_inputs_only=True,
            community_review_complete=True,
        )

        coefficients = ThermalResponseCoefficients(
            reflective_roof_c_per_fraction=-0.20,
            canopy_c_per_fraction=-0.80,
            green_wall_c_per_fraction=-0.10,
            green_roof_c_per_fraction=-0.15,
            shade_structure_c_per_fraction=-0.30,
            roof_canopy_interaction_c=-0.05,
            canopy_green_roof_interaction_c=-0.02,
        )

        estimate = estimate_scenario(
            scenario=scenario,
            coefficients=coefficients,
            incoming_shortwave_w_m2=850.0,
            baseline_albedo=0.20,
            intervention_albedo=0.60,
        )

        self.assertTrue(estimate.ecological_feasible)
        self.assertTrue(estimate.promotion_eligible)
        self.assertLess(estimate.air_temperature_change_c, 0.0)
        self.assertLess(estimate.absorbed_solar_change_w_m2, 0.0)

    def test_excess_water_requirement_blocks_promotion(self) -> None:
        scenario = InterventionScenario(
            reflective_roof_fraction=0.10,
            canopy_fraction_change=0.40,
            green_wall_fraction=0.20,
            green_roof_fraction=0.20,
            shade_structure_fraction=0.10,
            irrigation_water_m3_day=40.0,
            sustainable_water_limit_m3_day=20.0,
            accessible_route_preserved=True,
            privacy_safe_inputs_only=True,
            community_review_complete=True,
        )

        coefficients = ThermalResponseCoefficients(
            reflective_roof_c_per_fraction=-0.20,
            canopy_c_per_fraction=-0.80,
            green_wall_c_per_fraction=-0.10,
            green_roof_c_per_fraction=-0.15,
            shade_structure_c_per_fraction=-0.30,
        )

        estimate = estimate_scenario(
            scenario=scenario,
            coefficients=coefficients,
            incoming_shortwave_w_m2=850.0,
            baseline_albedo=0.20,
            intervention_albedo=0.60,
        )

        self.assertFalse(estimate.ecological_feasible)
        self.assertFalse(estimate.promotion_eligible)


if __name__ == "__main__":
    unittest.main()
