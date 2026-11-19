import unittest

from power_conversion_efficiency import (
    ConverterParameters,
    evaluate_efficiency,
    select_best_modeled_candidate,
)


def candidate(
    switching_frequency_hz: float = 100_000.0,
    estimated_junction_temperature_c: float = 80.0,
) -> ConverterParameters:
    return ConverterParameters(
        output_power_w=500.0,
        switching_frequency_hz=switching_frequency_hz,
        input_capacitance_f=2.0e-9,
        gate_drive_voltage_v=10.0,
        rms_current_a=20.0,
        rds_on_ohm=0.01,
        dead_time_loss_w=1.0,
        reverse_recovery_loss_w=0.5,
        core_loss_w=1.0,
        leakage_loss_w=0.2,
        gate_drive_loss_w=0.3,
        estimated_junction_temperature_c=estimated_junction_temperature_c,
        maximum_junction_temperature_c=100.0,
    )


class PowerConversionEfficiencyTests(unittest.TestCase):
    def test_loss_model_is_positive_and_efficiency_is_bounded(self) -> None:
        result = evaluate_efficiency(candidate())

        self.assertGreater(result.switching_loss_w, 0.0)
        self.assertGreater(result.conduction_loss_w, 0.0)
        self.assertGreater(result.total_loss_w, 0.0)
        self.assertGreater(result.efficiency_fraction, 0.0)
        self.assertLess(result.efficiency_fraction, 1.0)
        self.assertTrue(result.thermal_constraint_satisfied)

    def test_thermal_limit_excludes_candidate(self) -> None:
        overheated = candidate(estimated_junction_temperature_c=101.0)
        acceptable = candidate(estimated_junction_temperature_c=95.0)

        selected, result = select_best_modeled_candidate([overheated, acceptable])

        self.assertEqual(selected, acceptable)
        self.assertTrue(result.thermal_constraint_satisfied)

    def test_no_thermally_valid_candidate_is_refused(self) -> None:
        overheated = candidate(estimated_junction_temperature_c=110.0)

        with self.assertRaises(ValueError):
            select_best_modeled_candidate([overheated])

    def test_higher_switching_frequency_increases_base_switching_loss(self) -> None:
        low_frequency = evaluate_efficiency(candidate(switching_frequency_hz=50_000.0))
        high_frequency = evaluate_efficiency(candidate(switching_frequency_hz=200_000.0))

        self.assertGreater(
            high_frequency.switching_loss_w,
            low_frequency.switching_loss_w,
        )


if __name__ == "__main__":
    unittest.main()
