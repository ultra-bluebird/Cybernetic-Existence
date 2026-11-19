import unittest

from rest_aware_astar import (
    Cell,
    CostCell,
    PlannerWeights,
    RestAwareAStar,
    TaskUrgency,
)


def make_cell(
    *,
    traversable: bool = True,
    rest_zone_weight: float = 0.0,
    quiet_window_weight: float = 1.0,
    density: int = 0,
    hazard_cost: float = 0.0,
) -> CostCell:
    return CostCell(
        traversable=traversable,
        distance_cost=1.0,
        time_cost=1.0,
        energy_cost=1.0,
        rest_zone_weight=rest_zone_weight,
        quiet_window_weight=quiet_window_weight,
        accessibility_protection_cost=0.0,
        hazard_cost=hazard_cost,
        anonymous_density_bucket=density,
    )


class RestAwareAStarTests(unittest.TestCase):
    def test_routine_task_avoids_high_disturbance_rest_cell(self) -> None:
        grid = {
            Cell(0, 0): make_cell(),
            Cell(1, 0): make_cell(
                rest_zone_weight=1.0,
                quiet_window_weight=3.0,
                density=3,
            ),
            Cell(2, 0): make_cell(),
            Cell(0, 1): make_cell(),
            Cell(1, 1): make_cell(),
            Cell(2, 1): make_cell(),
        }

        planner = RestAwareAStar(
            grid=grid,
            weights=PlannerWeights(rest=10.0),
            width=3,
            height=2,
        )

        plan = planner.plan(
            start=Cell(0, 0),
            goal=Cell(2, 0),
            urgency=TaskUrgency.ROUTINE,
        )

        self.assertIsNotNone(plan)
        assert plan is not None
        self.assertNotIn(Cell(1, 0), plan.path)
        self.assertIn(Cell(1, 1), plan.path)

    def test_emergency_task_can_use_rest_zone_when_shortest(self) -> None:
        grid = {
            Cell(0, 0): make_cell(),
            Cell(1, 0): make_cell(
                rest_zone_weight=1.0,
                quiet_window_weight=3.0,
                density=3,
            ),
            Cell(2, 0): make_cell(),
            Cell(0, 1): make_cell(),
            Cell(1, 1): make_cell(),
            Cell(2, 1): make_cell(),
        }

        planner = RestAwareAStar(
            grid=grid,
            weights=PlannerWeights(rest=10.0),
            width=3,
            height=2,
        )

        plan = planner.plan(
            start=Cell(0, 0),
            goal=Cell(2, 0),
            urgency=TaskUrgency.EMERGENCY,
        )

        self.assertIsNotNone(plan)
        assert plan is not None
        self.assertIn(Cell(1, 0), plan.path)
        self.assertEqual(plan.total_rest_cost, 0.0)

    def test_hard_blocked_cell_is_never_used(self) -> None:
        grid = {
            Cell(0, 0): make_cell(),
            Cell(1, 0): make_cell(traversable=False),
            Cell(2, 0): make_cell(),
            Cell(0, 1): make_cell(),
            Cell(1, 1): make_cell(),
            Cell(2, 1): make_cell(),
        }

        planner = RestAwareAStar(
            grid=grid,
            weights=PlannerWeights(),
            width=3,
            height=2,
        )

        plan = planner.plan(
            start=Cell(0, 0),
            goal=Cell(2, 0),
            urgency=TaskUrgency.ESSENTIAL,
        )

        self.assertIsNotNone(plan)
        assert plan is not None
        self.assertNotIn(Cell(1, 0), plan.path)
        self.assertIn(Cell(1, 1), plan.path)

    def test_density_bucket_must_be_coarse_and_bounded(self) -> None:
        with self.assertRaises(ValueError):
            make_cell(density=4)

    def test_essential_task_retains_some_rest_weight(self) -> None:
        grid = {
            Cell(0, 0): make_cell(),
            Cell(1, 0): make_cell(
                rest_zone_weight=1.0,
                quiet_window_weight=2.0,
                density=3,
            ),
        }

        planner = RestAwareAStar(
            grid=grid,
            weights=PlannerWeights(rest=8.0),
            width=2,
            height=1,
        )

        plan = planner.plan(
            start=Cell(0, 0),
            goal=Cell(1, 0),
            urgency=TaskUrgency.ESSENTIAL,
        )

        self.assertIsNotNone(plan)
        assert plan is not None
        self.assertGreater(plan.total_rest_cost, 0.0)


if __name__ == "__main__":
    unittest.main()
