import unittest

from heat_grid_calibration import (
    PlanningCell,
    Point,
    RecursiveLeastSquares,
    SensorCandidate,
    batch_correct,
    priority_coverage,
    quality_flag,
    select_greedy_sensor_grid,
    weighted_coverage,
)


class HeatGridCalibrationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.cells = [
            PlanningCell(Point(0.0, 0.0), area_m2=100.0, priority_weight=1.0),
            PlanningCell(Point(100.0, 0.0), area_m2=100.0, priority_weight=2.0),
            PlanningCell(Point(200.0, 0.0), area_m2=100.0, priority_weight=1.0),
        ]
        self.candidates = [
            SensorCandidate(
                Point(0.0, 0.0),
                installation_cost=10.0,
                annual_energy_wh=20.0,
            ),
            SensorCandidate(
                Point(100.0, 0.0),
                installation_cost=10.0,
                annual_energy_wh=20.0,
            ),
            SensorCandidate(
                Point(200.0, 0.0),
                installation_cost=10.0,
                annual_energy_wh=20.0,
            ),
        ]

    def test_empty_grid_has_zero_coverage(self) -> None:
        coverage = weighted_coverage(
            self.cells,
            (),
            correlation_length_m=100.0,
        )
        self.assertEqual(coverage, 0.0)

    def test_nearby_sensor_increases_coverage(self) -> None:
        coverage = weighted_coverage(
            self.cells,
            [self.candidates[1]],
            correlation_length_m=100.0,
        )
        self.assertGreater(coverage, 0.0)
        self.assertLessEqual(coverage, 1.0)

    def test_priority_coverage_weights_priority_cells(self) -> None:
        center_coverage = priority_coverage(
            self.cells,
            [self.candidates[1]],
            correlation_length_m=25.0,
        )
        edge_coverage = priority_coverage(
            self.cells,
            [self.candidates[0]],
            correlation_length_m=25.0,
        )
        self.assertGreater(center_coverage, edge_coverage)

    def test_greedy_selection_respects_budget(self) -> None:
        result = select_greedy_sensor_grid(
            self.cells,
            self.candidates,
            sensor_budget=2,
            correlation_length_m=100.0,
        )
        self.assertEqual(len(result.selected), 2)
        self.assertGreater(result.priority_coverage, 0.0)
        self.assertLessEqual(result.priority_coverage, 1.0)

    def test_rls_moves_prediction_toward_reference(self) -> None:
        calibrator = RecursiveLeastSquares()
        raw_temperature = 40.0
        reference_temperature = 38.0
        before = abs(calibrator.correct(raw_temperature) - reference_temperature)

        for _ in range(20):
            calibrator.update(raw_temperature, reference_temperature)

        after = abs(calibrator.correct(raw_temperature) - reference_temperature)
        self.assertLess(after, before)

    def test_batch_correction_preserves_count(self) -> None:
        calibrator = RecursiveLeastSquares(alpha=1.0, beta=-1.0)
        corrected = batch_correct([30.0, 31.5, 33.0], calibrator)
        self.assertEqual(corrected, [29.0, 30.5, 32.0])

    def test_quality_flags_invalid_humidity(self) -> None:
        flag = quality_flag(
            temperature_c=35.0,
            relative_humidity_percent=105.0,
            minimum_temperature_c=-20.0,
            maximum_temperature_c=70.0,
        )
        self.assertEqual(flag, "humidity_out_of_range")

    def test_quality_flags_accepted_observation(self) -> None:
        flag = quality_flag(
            temperature_c=42.0,
            relative_humidity_percent=15.0,
            minimum_temperature_c=-20.0,
            maximum_temperature_c=70.0,
        )
        self.assertEqual(flag, "accepted")


if __name__ == "__main__":
    unittest.main()
