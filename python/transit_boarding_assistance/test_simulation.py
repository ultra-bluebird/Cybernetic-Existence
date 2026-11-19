import unittest

from simulation import (
    BoardingEvent,
    service_reliability_report,
    simulate_boarding,
    within_headway_reliability_corridor,
)


class TransitBoardingAssistanceTests(unittest.TestCase):
    def test_extra_time_adds_ten_seconds_without_identity(self) -> None:
        outcomes = simulate_boarding(
            [
                BoardingEvent(
                    scheduled_arrival_seconds=0.0,
                    baseline_dwell_seconds=20.0,
                    extra_time_requested=True,
                )
            ],
            extra_time_seconds=10.0,
        )

        self.assertEqual(len(outcomes), 1)
        self.assertTrue(outcomes[0].extra_time_active)
        self.assertEqual(outcomes[0].dwell_seconds, 30.0)

    def test_no_request_uses_baseline_dwell_time(self) -> None:
        outcomes = simulate_boarding(
            [
                BoardingEvent(
                    scheduled_arrival_seconds=0.0,
                    baseline_dwell_seconds=20.0,
                    extra_time_requested=False,
                )
            ]
        )

        self.assertEqual(outcomes[0].dwell_seconds, 20.0)

    def test_report_uses_aggregate_boarding_outcomes(self) -> None:
        outcomes = simulate_boarding(
            [
                BoardingEvent(
                    scheduled_arrival_seconds=0.0,
                    baseline_dwell_seconds=20.0,
                    extra_time_requested=True,
                ),
                BoardingEvent(
                    scheduled_arrival_seconds=300.0,
                    baseline_dwell_seconds=20.0,
                    extra_time_requested=False,
                ),
                BoardingEvent(
                    scheduled_arrival_seconds=600.0,
                    baseline_dwell_seconds=20.0,
                    extra_time_requested=True,
                ),
            ],
            recovery_rate=0.50,
        )

        report = service_reliability_report(
            outcomes,
            scheduled_headway_seconds=300.0,
        )

        self.assertGreater(report.mean_dwell_seconds, 20.0)
        self.assertGreaterEqual(report.extra_time_activation_rate, 0.0)
        self.assertLessEqual(report.extra_time_activation_rate, 1.0)

    def test_reliability_corridor_is_explicit(self) -> None:
        outcomes = simulate_boarding(
            [
                BoardingEvent(
                    scheduled_arrival_seconds=0.0,
                    baseline_dwell_seconds=20.0,
                    extra_time_requested=False,
                ),
                BoardingEvent(
                    scheduled_arrival_seconds=300.0,
                    baseline_dwell_seconds=20.0,
                    extra_time_requested=False,
                ),
                BoardingEvent(
                    scheduled_arrival_seconds=600.0,
                    baseline_dwell_seconds=20.0,
                    extra_time_requested=False,
                ),
            ]
        )

        report = service_reliability_report(
            outcomes,
            scheduled_headway_seconds=300.0,
        )

        self.assertTrue(
            within_headway_reliability_corridor(
                report,
                maximum_coefficient_of_variation=0.10,
            )
        )

    def test_invalid_recovery_rate_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            simulate_boarding(
                [
                    BoardingEvent(
                        scheduled_arrival_seconds=0.0,
                        baseline_dwell_seconds=20.0,
                        extra_time_requested=False,
                    )
                ],
                recovery_rate=1.10,
            )


if __name__ == "__main__":
    unittest.main()
