import unittest

from maintenance_fleet_planner import (
    AllocationPolicy,
    CapabilityProfile,
    MaintenanceTask,
    TaskReviewState,
    propose_allocations,
)


def policy() -> AllocationPolicy:
    return AllocationPolicy(
        priority_threshold=0.70,
        same_region_proximity_score=1.0,
        cross_region_proximity_score=0.4,
        travel_cost_same_region=0.05,
        travel_cost_cross_region=0.30,
    )


def profile() -> CapabilityProfile:
    return CapabilityProfile(
        profile_reference="profile-zone-a",
        supported_capabilities=frozenset({"inspection", "surface_review"}),
        region_reference="zone-a",
        task_capacity=2,
        daily_resource_budget=40,
    )


def eligible_task() -> MaintenanceTask:
    return MaintenanceTask(
        task_reference="inspection-task",
        priority=0.90,
        evidence_complete=True,
        accessible_alternative_verified=True,
        required_capability="inspection",
        region_reference="zone-a",
        estimated_resource_units=10,
    )


class MaintenanceFleetPlannerTests(unittest.TestCase):
    def test_eligible_task_receives_non_actuating_proposal(self) -> None:
        proposals = propose_allocations(
            tasks=[eligible_task()],
            profiles=[profile()],
            policy=policy(),
        )

        proposal = proposals[0]

        self.assertEqual(
            proposal.review_state,
            TaskReviewState.ELIGIBLE_FOR_HUMAN_ALLOCATION_REVIEW,
        )
        self.assertEqual(proposal.profile_reference, "profile-zone-a")
        self.assertFalse(proposal.external_action_authorized)

    def test_incomplete_evidence_requires_manual_inspection(self) -> None:
        source = eligible_task()
        task = MaintenanceTask(
            **{
                **source.__dict__,
                "evidence_complete": False,
            }
        )

        proposal = propose_allocations(
            tasks=[task],
            profiles=[profile()],
            policy=policy(),
        )[0]

        self.assertEqual(
            proposal.review_state,
            TaskReviewState.MANUAL_INSPECTION_REQUIRED,
        )
        self.assertIsNone(proposal.profile_reference)
        self.assertFalse(proposal.external_action_authorized)

    def test_missing_accessible_alternative_blocks_allocation(self) -> None:
        source = eligible_task()
        task = MaintenanceTask(
            **{
                **source.__dict__,
                "accessible_alternative_verified": False,
            }
        )

        proposal = propose_allocations(
            tasks=[task],
            profiles=[profile()],
            policy=policy(),
        )[0]

        self.assertEqual(
            proposal.review_state,
            TaskReviewState.ACCESS_IMPACT_REVIEW_REQUIRED,
        )
        self.assertIsNone(proposal.profile_reference)

    def test_resource_budget_prevents_over_allocation(self) -> None:
        source = eligible_task()
        expensive_task = MaintenanceTask(
            **{
                **source.__dict__,
                "task_reference": "expensive-inspection-task",
                "estimated_resource_units": 50,
            }
        )

        proposal = propose_allocations(
            tasks=[expensive_task],
            profiles=[profile()],
            policy=policy(),
        )[0]

        self.assertEqual(
            proposal.review_state,
            TaskReviewState.NO_ELIGIBLE_CAPABILITY_PROFILE,
        )
        self.assertIsNone(proposal.profile_reference)

    def test_unsupported_capability_is_not_assigned(self) -> None:
        source = eligible_task()
        specialized_task = MaintenanceTask(
            **{
                **source.__dict__,
                "required_capability": "specialized_electrical_review",
            }
        )

        proposal = propose_allocations(
            tasks=[specialized_task],
            profiles=[profile()],
            policy=policy(),
        )[0]

        self.assertEqual(
            proposal.review_state,
            TaskReviewState.NO_ELIGIBLE_CAPABILITY_PROFILE,
        )
        self.assertIsNone(proposal.profile_reference)


if __name__ == "__main__":
    unittest.main()
