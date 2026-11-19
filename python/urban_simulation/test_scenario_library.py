import unittest

from queueing import anonymous_mm1_wait_time
from scenario_library import (
    ScenarioValidationError,
    UrbanScenario,
    cooling_center_demand_rate,
    find_scenarios,
    validate_scenario,
)


class UrbanSimulationTests(unittest.TestCase):
    def scenario(self) -> UrbanScenario:
        return UrbanScenario(
            scenario="heatwave_cooling_centers_ble_off",
            domain="cooling_center",
            metric="essential_service_availability",
            value=0.99,
            uncertainty=0.02,
            privacy_class="synthetic_aggregate",
            method_version="1.0.0",
            limitations=(
                "Illustrative scenario based on aggregate input assumptions.",
                "Not a real-time capacity guarantee.",
            ),
            essential_service_availability=0.99,
            jain_fairness_index=0.93,
            privacy_leakage_estimate=0.0,
            ble_identity_used=False,
            essential_service_independent_of_ble=True,
        )

    def test_accepts_ble_independent_aggregate_scenario(self) -> None:
        scenario = validate_scenario(self.scenario())

        self.assertFalse(scenario.ble_identity_used)
        self.assertTrue(scenario.essential_service_independent_of_ble)

    def test_rejects_nonzero_privacy_leakage_estimate(self) -> None:
        invalid = UrbanScenario(
            **{
                **self.scenario().__dict__,
                "privacy_leakage_estimate": 0.01,
            }
        )

        with self.assertRaises(ScenarioValidationError):
            validate_scenario(invalid)

    def test_filters_compact_scenario_catalog(self) -> None:
        result = find_scenarios(
            [self.scenario()],
            domain="cooling_center",
            metric="essential_service_availability",
        )

        self.assertEqual(len(result), 1)
        self.assertEqual(result[0].scenario, "heatwave_cooling_centers_ble_off")

    def test_aggregate_demand_rate_is_bounded_at_zero(self) -> None:
        demand = cooling_center_demand_rate(
            baseline_rate=5.0,
            temperature_c=30.0,
            reference_temperature_c=35.0,
            temperature_coefficient=1.0,
            aggregate_high_risk_share=0.1,
            aggregate_high_risk_coefficient=2.0,
        )

        self.assertEqual(demand, 0.2)

    def test_anonymous_queueing_model_uses_no_identity(self) -> None:
        result = anonymous_mm1_wait_time(
            arrival_rate_per_s=0.1,
            service_rate_per_s=0.5,
        )

        self.assertTrue(result.stable)
        self.assertFalse(result.ble_identity_used)
        self.assertFalse(result.identity_data_retained)

    def test_unstable_queue_is_explicit(self) -> None:
        result = anonymous_mm1_wait_time(
            arrival_rate_per_s=0.5,
            service_rate_per_s=0.5,
        )

        self.assertFalse(result.stable)
        self.assertEqual(result.mean_wait_s, float("inf"))


if __name__ == "__main__":
    unittest.main()
