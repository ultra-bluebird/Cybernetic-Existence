import unittest

from pedestrian_envelope import (
    PedestrianInteraction,
    ShuttleState,
    evaluate_interaction,
)


class PedestrianEnvelopeTests(unittest.TestCase):
    def shuttle(self) -> ShuttleState:
        return ShuttleState(
            speed_m_s=5.0,
            sensor_delay_s=0.15,
            planning_delay_s=0.10,
            braking_delay_s=0.25,
            safe_deceleration_m_s2=3.0,
            uncertainty_margin_m=1.5,
            sensor_health_valid=True,
            operating_domain_valid=True,
        )

    def test_requires_controlled_stop_for_short_ttc(self) -> None:
        decision = evaluate_interaction(
            self.shuttle(),
            PedestrianInteraction(
                distance_m=8.0,
                relative_closing_speed_m_s=3.0,
                occupancy_uncertain=False,
                path_intersection_predicted=True,
            ),
        )

        self.assertEqual(decision.state, "CONTROLLED_DECELERATION_OR_STOP")
        self.assertFalse(decision.safe_for_continuation)
        self.assertLessEqual(decision.time_to_collision_s, decision.required_ttc_s)

    def test_requires_conservative_handling_for_uncertain_occupancy(self) -> None:
        decision = evaluate_interaction(
            self.shuttle(),
            PedestrianInteraction(
                distance_m=30.0,
                relative_closing_speed_m_s=0.5,
                occupancy_uncertain=True,
                path_intersection_predicted=False,
            ),
        )

        self.assertEqual(decision.state, "REDUCED_SPEED_WITH_CONSERVATIVE_CLEARANCE")
        self.assertFalse(decision.safe_for_continuation)

    def test_stops_when_sensor_health_is_invalid(self) -> None:
        shuttle = ShuttleState(
            speed_m_s=2.0,
            sensor_delay_s=0.1,
            planning_delay_s=0.1,
            braking_delay_s=0.1,
            safe_deceleration_m_s2=2.0,
            uncertainty_margin_m=1.0,
            sensor_health_valid=False,
            operating_domain_valid=True,
        )

        decision = evaluate_interaction(
            shuttle,
            PedestrianInteraction(
                distance_m=100.0,
                relative_closing_speed_m_s=0.0,
                occupancy_uncertain=False,
                path_intersection_predicted=False,
            ),
        )

        self.assertEqual(decision.state, "MINIMAL_RISK_STOP")
        self.assertFalse(decision.safe_for_continuation)

    def test_continues_only_with_sufficient_ttc_and_distance(self) -> None:
        decision = evaluate_interaction(
            self.shuttle(),
            PedestrianInteraction(
                distance_m=50.0,
                relative_closing_speed_m_s=1.0,
                occupancy_uncertain=False,
                path_intersection_predicted=True,
            ),
        )

        self.assertEqual(decision.state, "CONTINUE_WITH_MONITORING")
        self.assertTrue(decision.safe_for_continuation)


if __name__ == "__main__":
    unittest.main()
