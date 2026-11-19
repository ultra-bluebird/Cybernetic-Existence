import unittest

from shade_placement import (
    ShadeCandidate,
    prioritize_shade_candidates,
    utci_target_met,
)
from wastewater_heat_recovery import (
    DistrictThermalObservation,
    evaluate_district_heat_recovery,
)


class ShadePlacementTests(unittest.TestCase):
    def test_accepts_privacy_safe_shade_candidate(self) -> None:
        decisions = prioritize_shade_candidates(
            [
                ShadeCandidate(
                    label="transit_shade_and_seating",
                    heat_exposure=0.9,
                    access_gap=0.9,
                    aggregate_use_estimate=0.7,
                    comfort_benefit=0.8,
                    ecological_compatibility=0.8,
                    maintenance_feasibility=0.7,
                    displacement_risk=0.1,
                    rights_accessibility_risk=0.1,
                    uncertainty=0.1,
                )
            ]
        )

        self.assertTrue(decisions[0].eligible)
        self.assertGreater(decisions[0].uncertainty_adjusted_score, 0.0)

    def test_rejects_wifi_probe_based_candidate(self) -> None:
        decisions = prioritize_shade_candidates(
            [
                ShadeCandidate(
                    label="radio_tracked_candidate",
                    heat_exposure=0.9,
                    access_gap=0.9,
                    aggregate_use_estimate=0.9,
                    comfort_benefit=0.9,
                    ecological_compatibility=0.9,
                    maintenance_feasibility=0.9,
                    displacement_risk=0.0,
                    rights_accessibility_risk=0.0,
                    uncertainty=0.0,
                    wifi_probe_data_used=True,
                )
            ]
        )

        self.assertFalse(decisions[0].eligible)
        self.assertIn("prohibited", decisions[0].reason)

    def test_utci_target_requires_ninety_percent_below_threshold(self) -> None:
        values = [25.0] * 9 + [28.0]

        self.assertTrue(utci_target_met(values))
        self.assertFalse(utci_target_met([25.0] * 8 + [28.0] * 2))


class WastewaterHeatRecoveryTests(unittest.TestCase):
    def test_accepts_aggregate_district_heat_recovery(self) -> None:
        decision = evaluate_district_heat_recovery(
            DistrictThermalObservation(
                mass_flow_kg_s=10.0,
                influent_temperature_c=20.0,
                effluent_temperature_c=14.0,
                clean_heat_transfer_coefficient_w_m2_c=1000.0,
                current_heat_transfer_coefficient_w_m2_c=900.0,
                clean_pressure_drop_pa=2000.0,
                current_pressure_drop_pa=3000.0,
            )
        )

        self.assertTrue(decision.eligible)
        self.assertEqual(decision.temperature_drop_c, 6.0)
        self.assertEqual(decision.recovered_thermal_power_w, 250800.0)

    def test_requires_review_for_fouling_loss(self) -> None:
        decision = evaluate_district_heat_recovery(
            DistrictThermalObservation(
                mass_flow_kg_s=10.0,
                influent_temperature_c=20.0,
                effluent_temperature_c=14.0,
                clean_heat_transfer_coefficient_w_m2_c=1000.0,
                current_heat_transfer_coefficient_w_m2_c=750.0,
                clean_pressure_drop_pa=2000.0,
                current_pressure_drop_pa=3000.0,
            )
        )

        self.assertFalse(decision.eligible)
        self.assertTrue(decision.fouling_review_required)

    def test_rejects_household_data_use(self) -> None:
        decision = evaluate_district_heat_recovery(
            DistrictThermalObservation(
                mass_flow_kg_s=10.0,
                influent_temperature_c=20.0,
                effluent_temperature_c=14.0,
                clean_heat_transfer_coefficient_w_m2_c=1000.0,
                current_heat_transfer_coefficient_w_m2_c=900.0,
                clean_pressure_drop_pa=2000.0,
                current_pressure_drop_pa=3000.0,
                household_data_used=True,
            )
        )

        self.assertFalse(decision.eligible)
        self.assertIn("household", decision.reason)


if __name__ == "__main__":
    unittest.main()
