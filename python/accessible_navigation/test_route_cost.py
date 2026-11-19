import unittest

from route_cost import (
    RoutePreferences,
    Segment,
    evaluate_route,
    privacy_safe_route_session_record,
)


class RouteCostTests(unittest.TestCase):
    def preferences(self) -> RoutePreferences:
        return RoutePreferences(
            accessibility_weight=100.0,
            heat_weight=10.0,
            reliability_weight=25.0,
            avoid_stairs=True,
            require_curb_ramps=True,
            require_operational_elevators=True,
            maximum_slope_percent=5.0,
        )

    def test_evaluates_accessible_route_locally(self) -> None:
        result = evaluate_route(
            [
                Segment(
                    label="shaded_sidewalk",
                    length_m=250.0,
                    inaccessibility_score=0.0,
                    heat_exposure_score=0.2,
                    reliability_penalty=0.0,
                    has_stairs=False,
                    curb_ramp_present=True,
                    elevator_required=False,
                    elevator_available=True,
                    slope_percent=3.0,
                )
            ],
            self.preferences(),
        )

        self.assertTrue(result.eligible)
        self.assertEqual(result.cost, 252.0)

    def test_rejects_route_with_stairs_when_requested(self) -> None:
        result = evaluate_route(
            [
                Segment(
                    label="stairway",
                    length_m=50.0,
                    inaccessibility_score=1.0,
                    heat_exposure_score=0.0,
                    reliability_penalty=0.0,
                    has_stairs=True,
                    curb_ramp_present=False,
                    elevator_required=False,
                    elevator_available=True,
                    slope_percent=1.0,
                )
            ],
            self.preferences(),
        )

        self.assertFalse(result.eligible)
        self.assertIn("stairs", result.reason)

    def test_privacy_record_excludes_route_and_identity_history(self) -> None:
        record = privacy_safe_route_session_record()

        self.assertFalse(record["route_history_retained"])
        self.assertFalse(record["current_location_history_retained"])
        self.assertFalse(record["identity_data_retained"])
        self.assertFalse(record["reputation_score_used"])


if __name__ == "__main__":
    unittest.main()
