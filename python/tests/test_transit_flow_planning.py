import unittest

from transit_flow_planning import (
    PlanningDecision,
    PlanningPolicy,
    ServiceEquityMetrics,
    StationQueueModel,
    evaluate_transit_scenario,
)


def policy() -> PlanningPolicy:
    return PlanningPolicy(
        maximum_utilization=0.90,
        maximum_wait_time_disparity_minutes=3.0,
        maximum_reliability_disparity_fraction=0.05,
        minimum_accessible_route_continuity_fraction=1.0,
        maximum_transfer_burden_disparity=1.0,
    )


def equity() -> ServiceEquityMetrics:
    return ServiceEquityMetrics(
        wait_time_disparity_minutes=1.0,
        reliability_disparity_fraction=0.02,
        accessible_route_continuity_fraction=1.0,
        transfer_burden_disparity=0.25,
        appeal_path_available=True,
    )


def station(
    reference: str,
    arrival: float,
    service: float,
    accessible_alternative: bool = True,
) -> StationQueueModel:
    return StationQueueModel(
        station_reference=reference,
        arrival_rate_per_hour=arrival,
        service_rate_per_hour=service,
        accessible_route_alternative_verified=accessible_alternative,
        aggregate_input_only=True,
    )


class TransitFlowPlanningTests(unittest.TestCase):
    def test_stable_aggregate_scenario_is_reviewable(self) -> None:
        report = evaluate_transit_scenario(
            stations=[
                station("station-a", 600.0, 900.0),
                station("station-b", 500.0, 850.0),
            ],
            equity=equity(),
            policy=policy(),
            private_identity_or_telemetry_used=False,
        )

        self.assertEqual(report.decision, PlanningDecision.REVIEWABLE_SCENARIO)
        self.assertFalse(report.external_action_authorized)
        self.assertIsNotNone(report.station_wait_minutes["station-a"])

    def test_unstable_queue_requires_capacity_evidence_review(self) -> None:
        report = evaluate_transit_scenario(
            stations=[station("station-a", 900.0, 900.0)],
            equity=equity(),
            policy=policy(),
            private_identity_or_telemetry_used=False,
        )

        self.assertEqual(
            report.decision,
            PlanningDecision.INSUFFICIENT_CAPACITY_EVIDENCE,
        )
        self.assertIsNone(report.station_wait_minutes["station-a"])

    def test_missing_accessible_alternative_requires_review(self) -> None:
        report = evaluate_transit_scenario(
            stations=[
                station(
                    "station-a",
                    600.0,
                    900.0,
                    accessible_alternative=False,
                )
            ],
            equity=equity(),
            policy=policy(),
            private_identity_or_telemetry_used=False,
        )

        self.assertEqual(
            report.decision,
            PlanningDecision.ACCESSIBILITY_REVIEW_REQUIRED,
        )
        self.assertFalse(report.external_action_authorized)

    def test_fairness_constraint_violation_requires_review(self) -> None:
        inequitable = ServiceEquityMetrics(
            wait_time_disparity_minutes=5.0,
            reliability_disparity_fraction=0.02,
            accessible_route_continuity_fraction=1.0,
            transfer_burden_disparity=0.25,
            appeal_path_available=True,
        )

        report = evaluate_transit_scenario(
            stations=[station("station-a", 600.0, 900.0)],
            equity=inequitable,
            policy=policy(),
            private_identity_or_telemetry_used=False,
        )

        self.assertEqual(
            report.decision,
            PlanningDecision.FAIRNESS_REVIEW_REQUIRED,
        )

    def test_private_identity_or_telemetry_is_rejected(self) -> None:
        report = evaluate_transit_scenario(
            stations=[station("station-a", 600.0, 900.0)],
            equity=equity(),
            policy=policy(),
            private_identity_or_telemetry_used=True,
        )

        self.assertEqual(
            report.decision,
            PlanningDecision.PRIVACY_BOUNDARY_VIOLATION,
        )
        self.assertFalse(report.external_action_authorized)


if __name__ == "__main__":
    unittest.main()
