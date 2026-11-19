import unittest

from door_sensor_simulation import (
    DoorDecision,
    SensorObservation,
    decide,
    door_zone_coverage,
    false_rejection_rate,
)


def valid_observation() -> SensorObservation:
    return SensorObservation(
        manual_activation=False,
        emergency_egress=False,
        approach_detected=False,
        occupancy_detected=False,
        obstruction_detected=False,
        activation_sensor_healthy=True,
        presence_sensor_healthy=True,
        operator_feedback_healthy=True,
        minimum_open_time_elapsed=False,
    )


class DoorSensorSimulationTests(unittest.TestCase):
    def test_manual_activation_opens_door(self) -> None:
        observation = valid_observation()
        observation = SensorObservation(
            **{
                **observation.__dict__,
                "manual_activation": True,
            }
        )
        self.assertEqual(decide(observation, door_is_open=False), DoorDecision.OPEN)

    def test_presence_prevents_closing(self) -> None:
        observation = valid_observation()
        observation = SensorObservation(
            **{
                **observation.__dict__,
                "occupancy_detected": True,
                "minimum_open_time_elapsed": True,
            }
        )
        self.assertEqual(
            decide(observation, door_is_open=True),
            DoorDecision.REVERSE_TO_OPEN,
        )

    def test_presence_sensor_fault_enters_safe_state(self) -> None:
        observation = valid_observation()
        observation = SensorObservation(
            **{
                **observation.__dict__,
                "presence_sensor_healthy": False,
            }
        )
        self.assertEqual(
            decide(observation, door_is_open=True),
            DoorDecision.FAULT_SAFE,
        )

    def test_activation_sensor_fault_preserves_manual_access(self) -> None:
        observation = valid_observation()
        observation = SensorObservation(
            **{
                **observation.__dict__,
                "activation_sensor_healthy": False,
                "manual_activation": True,
            }
        )
        self.assertEqual(decide(observation, door_is_open=False), DoorDecision.OPEN)

    def test_false_rejection_rate(self) -> None:
        self.assertEqual(false_rejection_rate(1000, 999), 0.001)

    def test_full_safety_zone_coverage(self) -> None:
        self.assertEqual(door_zone_coverage(6.0, 6.0), 1.0)


if __name__ == "__main__":
    unittest.main()
