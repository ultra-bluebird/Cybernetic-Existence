from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from math import isfinite
from typing import Iterable


class TaskReviewState(str, Enum):
    ELIGIBLE_FOR_HUMAN_ALLOCATION_REVIEW = "eligible_for_human_allocation_review"
    MANUAL_INSPECTION_REQUIRED = "manual_inspection_required"
    ACCESS_IMPACT_REVIEW_REQUIRED = "access_impact_review_required"
    BELOW_PRIORITY_THRESHOLD = "below_priority_threshold"
    NO_ELIGIBLE_CAPABILITY_PROFILE = "no_eligible_capability_profile"


@dataclass(frozen=True)
class MaintenanceTask:
    task_reference: str
    priority: float
    evidence_complete: bool
    accessible_alternative_verified: bool
    required_capability: str
    region_reference: str
    estimated_resource_units: int

    def validate(self) -> None:
        if not self.task_reference.strip():
            raise ValueError("task_reference must not be empty")

        if not isfinite(self.priority) or not 0.0 <= self.priority <= 1.0:
            raise ValueError("priority must be finite and in the range [0.0, 1.0]")

        if not self.required_capability.strip():
            raise ValueError("required_capability must not be empty")

        if not self.region_reference.strip():
            raise ValueError("region_reference must not be empty")

        if self.estimated_resource_units < 0:
            raise ValueError("estimated_resource_units must not be negative")


@dataclass(frozen=True)
class CapabilityProfile:
    profile_reference: str
    supported_capabilities: frozenset[str]
    region_reference: str
    task_capacity: int
    daily_resource_budget: int

    def validate(self) -> None:
        if not self.profile_reference.strip():
            raise ValueError("profile_reference must not be empty")

        if not self.supported_capabilities:
            raise ValueError("supported_capabilities must not be empty")

        if not self.region_reference.strip():
            raise ValueError("region_reference must not be empty")

        if self.task_capacity < 0:
            raise ValueError("task_capacity must not be negative")

        if self.daily_resource_budget < 0:
            raise ValueError("daily_resource_budget must not be negative")


@dataclass(frozen=True)
class AllocationPolicy:
    priority_threshold: float
    same_region_proximity_score: float
    cross_region_proximity_score: float
    travel_cost_same_region: float
    travel_cost_cross_region: float

    def validate(self) -> None:
        values = (
            self.priority_threshold,
            self.same_region_proximity_score,
            self.cross_region_proximity_score,
            self.travel_cost_same_region,
            self.travel_cost_cross_region,
        )

        if not all(isfinite(value) for value in values):
            raise ValueError("allocation policy values must be finite")

        if not 0.0 <= self.priority_threshold <= 1.0:
            raise ValueError("priority_threshold must be in the range [0.0, 1.0]")

        if not 0.0 <= self.same_region_proximity_score <= 1.0:
            raise ValueError("same_region_proximity_score must be in [0.0, 1.0]")

        if not 0.0 <= self.cross_region_proximity_score <= 1.0:
            raise ValueError("cross_region_proximity_score must be in [0.0, 1.0]")

        if self.travel_cost_same_region < 0.0:
            raise ValueError("travel_cost_same_region must not be negative")

        if self.travel_cost_cross_region < 0.0:
            raise ValueError("travel_cost_cross_region must not be negative")


@dataclass(frozen=True)
class AllocationProposal:
    task_reference: str
    profile_reference: str | None
    review_state: TaskReviewState
    modeled_utility: float | None
    reasons: tuple[str, ...]
    external_action_authorized: bool


def capability_score(task: MaintenanceTask, profile: CapabilityProfile) -> float:
    return 1.0 if task.required_capability in profile.supported_capabilities else 0.0


def proximity_and_travel(
    task: MaintenanceTask,
    profile: CapabilityProfile,
    policy: AllocationPolicy,
) -> tuple[float, float]:
    if task.region_reference == profile.region_reference:
        return policy.same_region_proximity_score, policy.travel_cost_same_region

    return policy.cross_region_proximity_score, policy.travel_cost_cross_region


def task_review_state(
    task: MaintenanceTask,
    profiles: Iterable[CapabilityProfile],
    policy: AllocationPolicy,
) -> TaskReviewState:
    task.validate()
    policy.validate()

    if not task.evidence_complete:
        return TaskReviewState.MANUAL_INSPECTION_REQUIRED

    if not task.accessible_alternative_verified:
        return TaskReviewState.ACCESS_IMPACT_REVIEW_REQUIRED

    if task.priority < policy.priority_threshold:
        return TaskReviewState.BELOW_PRIORITY_THRESHOLD

    if not any(
        task.required_capability in profile.supported_capabilities
        for profile in profiles
    ):
        return TaskReviewState.NO_ELIGIBLE_CAPABILITY_PROFILE

    return TaskReviewState.ELIGIBLE_FOR_HUMAN_ALLOCATION_REVIEW


def propose_allocations(
    tasks: Iterable[MaintenanceTask],
    profiles: Iterable[CapabilityProfile],
    policy: AllocationPolicy,
) -> list[AllocationProposal]:
    policy.validate()

    task_list = list(tasks)
    profile_list = list(profiles)

    for profile in profile_list:
        profile.validate()

    remaining_capacity = {
        profile.profile_reference: profile.task_capacity
        for profile in profile_list
    }

    remaining_budget = {
        profile.profile_reference: profile.daily_resource_budget
        for profile in profile_list
    }

    proposals: list[AllocationProposal] = []

    for task in sorted(task_list, key=lambda item: item.priority, reverse=True):
        state = task_review_state(task, profile_list, policy)

        if state is not TaskReviewState.ELIGIBLE_FOR_HUMAN_ALLOCATION_REVIEW:
            proposals.append(
                AllocationProposal(
                    task_reference=task.task_reference,
                    profile_reference=None,
                    review_state=state,
                    modeled_utility=None,
                    reasons=(
                        "task_is_not_eligible_for_allocation_under_current_rights_and_evidence_constraints",
                    ),
                    external_action_authorized=False,
                )
            )
            continue

        candidates: list[tuple[float, CapabilityProfile]] = []

        for profile in profile_list:
            if remaining_capacity[profile.profile_reference] <= 0:
                continue

            if remaining_budget[profile.profile_reference] < task.estimated_resource_units:
                continue

            score = capability_score(task, profile)
            if score == 0.0:
                continue

            proximity, travel_cost = proximity_and_travel(task, profile, policy)
            utility = (task.priority * score * proximity) - travel_cost
            candidates.append((utility, profile))

        if not candidates:
            proposals.append(
                AllocationProposal(
                    task_reference=task.task_reference,
                    profile_reference=None,
                    review_state=TaskReviewState.NO_ELIGIBLE_CAPABILITY_PROFILE,
                    modeled_utility=None,
                    reasons=(
                        "no_capability_profile_has_remaining_capacity_and_budget_for_this_task",
                    ),
                    external_action_authorized=False,
                )
            )
            continue

        utility, selected = max(candidates, key=lambda candidate: candidate[0])

        remaining_capacity[selected.profile_reference] -= 1
        remaining_budget[selected.profile_reference] -= task.estimated_resource_units

        proposals.append(
            AllocationProposal(
                task_reference=task.task_reference,
                profile_reference=selected.profile_reference,
                review_state=TaskReviewState.ELIGIBLE_FOR_HUMAN_ALLOCATION_REVIEW,
                modeled_utility=utility,
                reasons=(
                    "proposal_is_a_non_actuating_allocation_recommendation",
                    "human_authorization_and_site_safety_review_are_required",
                    "no_robot_dispatch_or_external_action_is_authorized",
                ),
                external_action_authorized=False,
            )
        )

    return proposals


if __name__ == "__main__":
    proposals = propose_allocations(
        tasks=[
            MaintenanceTask(
                task_reference="access-panel-inspection-zone-a",
                priority=0.92,
                evidence_complete=True,
                accessible_alternative_verified=True,
                required_capability="inspection",
                region_reference="zone-a",
                estimated_resource_units=20,
            ),
            MaintenanceTask(
                task_reference="ramp-surface-review-zone-b",
                priority=0.86,
                evidence_complete=True,
                accessible_alternative_verified=False,
                required_capability="surface_review",
                region_reference="zone-b",
                estimated_resource_units=15,
            ),
        ],
        profiles=[
            CapabilityProfile(
                profile_reference="maintenance-profile-a",
                supported_capabilities=frozenset({"inspection", "surface_review"}),
                region_reference="zone-a",
                task_capacity=3,
                daily_resource_budget=60,
            ),
            CapabilityProfile(
                profile_reference="maintenance-profile-b",
                supported_capabilities=frozenset({"inspection"}),
                region_reference="zone-b",
                task_capacity=2,
                daily_resource_budget=30,
            ),
        ],
        policy=AllocationPolicy(
            priority_threshold=0.75,
            same_region_proximity_score=1.0,
            cross_region_proximity_score=0.4,
            travel_cost_same_region=0.05,
            travel_cost_cross_region=0.30,
        ),
    )

    for proposal in proposals:
        print(
            {
                "task_reference": proposal.task_reference,
                "profile_reference": proposal.profile_reference,
                "review_state": proposal.review_state.value,
                "modeled_utility": proposal.modeled_utility,
                "external_action_authorized": proposal.external_action_authorized,
                "reasons": proposal.reasons,
            }
        )
