from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from math import isfinite


class PlanningDecision(str, Enum):
    REVIEWABLE_SCENARIO = "reviewable_scenario"
    INSUFFICIENT_CAPACITY_EVIDENCE = "insufficient_capacity_evidence"
    ACCESSIBILITY_REVIEW_REQUIRED = "accessibility_review_required"
    FAIRNESS_REVIEW_REQUIRED = "fairness_review_required"
    PRIVACY_BOUNDARY_VIOLATION = "privacy_boundary_violation"


@dataclass(frozen=True)
class StationQueueModel:
    station_reference: str
    arrival_rate_per_hour: float
    service_rate_per_hour: float
    accessible_route_alternative_verified: bool
    aggregate_input_only: bool

    def validate(self) -> None:
        if not self.station_reference.strip():
            raise ValueError("station_reference must not be empty")

        if not isfinite(self.arrival_rate_per_hour) or self.arrival_rate_per_hour < 0:
            raise ValueError("arrival_rate_per_hour must be finite and non-negative")

        if not isfinite(self.service_rate_per_hour) or self.service_rate_per_hour <= 0:
            raise ValueError("service_rate_per_hour must be finite and greater than zero")

    @property
    def utilization(self) -> float:
        self.validate()
        return self.arrival_rate_per_hour / self.service_rate_per_hour

    def expected_wait_minutes(self) -> float | None:
        self.validate()

        if self.arrival_rate_per_hour >= self.service_rate_per_hour:
            return None

        wait_hours = self.arrival_rate_per_hour / (
            self.service_rate_per_hour
            * (self.service_rate_per_hour - self.arrival_rate_per_hour)
        )

        return wait_hours * 60.0


@dataclass(frozen=True)
class ServiceEquityMetrics:
    wait_time_disparity_minutes: float
    reliability_disparity_fraction: float
    accessible_route_continuity_fraction: float
    transfer_burden_disparity: float
    appeal_path_available: bool

    def validate(self) -> None:
        values = (
            self.wait_time_disparity_minutes,
            self.reliability_disparity_fraction,
            self.accessible_route_continuity_fraction,
            self.transfer_burden_disparity,
        )

        if not all(isfinite(value) for value in values):
            raise ValueError("service equity metrics must be finite")

        if self.wait_time_disparity_minutes < 0:
            raise ValueError("wait_time_disparity_minutes must not be negative")

        if not 0.0 <= self.reliability_disparity_fraction <= 1.0:
            raise ValueError("reliability_disparity_fraction must be in [0.0, 1.0]")

        if not 0.0 <= self.accessible_route_continuity_fraction <= 1.0:
            raise ValueError(
                "accessible_route_continuity_fraction must be in [0.0, 1.0]"
            )

        if self.transfer_burden_disparity < 0:
            raise ValueError("transfer_burden_disparity must not be negative")


@dataclass(frozen=True)
class PlanningPolicy:
    maximum_utilization: float
    maximum_wait_time_disparity_minutes: float
    maximum_reliability_disparity_fraction: float
    minimum_accessible_route_continuity_fraction: float
    maximum_transfer_burden_disparity: float

    def validate(self) -> None:
        values = (
            self.maximum_utilization,
            self.maximum_wait_time_disparity_minutes,
            self.maximum_reliability_disparity_fraction,
            self.minimum_accessible_route_continuity_fraction,
            self.maximum_transfer_burden_disparity,
        )

        if not all(isfinite(value) for value in values):
            raise ValueError("planning policy values must be finite")

        if not 0.0 < self.maximum_utilization < 1.0:
            raise ValueError("maximum_utilization must be strictly between 0 and 1")

        if self.maximum_wait_time_disparity_minutes < 0:
            raise ValueError("maximum_wait_time_disparity_minutes must not be negative")

        if not 0.0 <= self.maximum_reliability_disparity_fraction <= 1.0:
            raise ValueError(
                "maximum_reliability_disparity_fraction must be in [0.0, 1.0]"
            )

        if not 0.0 <= self.minimum_accessible_route_continuity_fraction <= 1.0:
            raise ValueError(
                "minimum_accessible_route_continuity_fraction must be in [0.0, 1.0]"
            )

        if self.maximum_transfer_burden_disparity < 0:
            raise ValueError("maximum_transfer_burden_disparity must not be negative")


@dataclass(frozen=True)
class TransitPlanningReport:
    decision: PlanningDecision
    bottleneck_station_reference: str | None
    modeled_network_throughput_per_hour: float | None
    station_wait_minutes: dict[str, float | None]
    reasons: tuple[str, ...]
    external_action_authorized: bool


def evaluate_transit_scenario(
    stations: list[StationQueueModel],
    equity: ServiceEquityMetrics,
    policy: PlanningPolicy,
    private_identity_or_telemetry_used: bool,
) -> TransitPlanningReport:
    if not stations:
        raise ValueError("at least one station is required")

    policy.validate()
    equity.validate()

    reasons: list[str] = []

    if private_identity_or_telemetry_used:
        return TransitPlanningReport(
            decision=PlanningDecision.PRIVACY_BOUNDARY_VIOLATION,
            bottleneck_station_reference=None,
            modeled_network_throughput_per_hour=None,
            station_wait_minutes={},
            reasons=(
                "individual_identity_or_private_telemetry_is_not_allowed_in_this_model",
            ),
            external_action_authorized=False,
        )

    wait_times: dict[str, float | None] = {}
    bottleneck: StationQueueModel | None = None

    for station in stations:
        station.validate()
        wait_times[station.station_reference] = station.expected_wait_minutes()

        if not station.aggregate_input_only:
            reasons.append(
                f"{station.station_reference}: non_aggregate_input_is_not_permitted"
            )

        if not station.accessible_route_alternative_verified:
            reasons.append(
                f"{station.station_reference}: accessible_route_alternative_not_verified"
            )

        if station.utilization > policy.maximum_utilization:
            reasons.append(
                f"{station.station_reference}: utilization_exceeds_planning_limit"
            )

        if bottleneck is None or station.service_rate_per_hour < bottleneck.service_rate_per_hour:
            bottleneck = station

    if any(wait is None for wait in wait_times.values()):
        reasons.append("one_or_more_station_queues_are_unstable")

    if equity.wait_time_disparity_minutes > policy.maximum_wait_time_disparity_minutes:
        reasons.append("wait_time_disparity_exceeds_policy_limit")

    if (
        equity.reliability_disparity_fraction
        > policy.maximum_reliability_disparity_fraction
    ):
        reasons.append("reliability_disparity_exceeds_policy_limit")

    if (
        equity.accessible_route_continuity_fraction
        < policy.minimum_accessible_route_continuity_fraction
    ):
        reasons.append("accessible_route_continuity_below_policy_floor")

    if (
        equity.transfer_burden_disparity
        > policy.maximum_transfer_burden_disparity
    ):
        reasons.append("transfer_burden_disparity_exceeds_policy_limit")

    if not equity.appeal_path_available:
        reasons.append("accessible_appeal_path_is_required")

    if any("accessible_route_alternative_not_verified" in reason for reason in reasons):
        decision = PlanningDecision.ACCESSIBILITY_REVIEW_REQUIRED
    elif any(
        reason
        in {
            "wait_time_disparity_exceeds_policy_limit",
            "reliability_disparity_exceeds_policy_limit",
            "accessible_route_continuity_below_policy_floor",
            "transfer_burden_disparity_exceeds_policy_limit",
            "accessible_appeal_path_is_required",
        }
        for reason in reasons
    ):
        decision = PlanningDecision.FAIRNESS_REVIEW_REQUIRED
    elif reasons:
        decision = PlanningDecision.INSUFFICIENT_CAPACITY_EVIDENCE
    else:
        decision = PlanningDecision.REVIEWABLE_SCENARIO

    return TransitPlanningReport(
        decision=decision,
        bottleneck_station_reference=(
            bottleneck.station_reference if bottleneck is not None else None
        ),
        modeled_network_throughput_per_hour=(
            bottleneck.service_rate_per_hour if bottleneck is not None else None
        ),
        station_wait_minutes=wait_times,
        reasons=tuple(reasons),
        external_action_authorized=False,
    )


if __name__ == "__main__":
    report = evaluate_transit_scenario(
        stations=[
            StationQueueModel(
                station_reference="station-a",
                arrival_rate_per_hour=720.0,
                service_rate_per_hour=900.0,
                accessible_route_alternative_verified=True,
                aggregate_input_only=True,
            ),
            StationQueueModel(
                station_reference="station-b",
                arrival_rate_per_hour=500.0,
                service_rate_per_hour=850.0,
                accessible_route_alternative_verified=True,
                aggregate_input_only=True,
            ),
        ],
        equity=ServiceEquityMetrics(
            wait_time_disparity_minutes=1.5,
            reliability_disparity_fraction=0.02,
            accessible_route_continuity_fraction=1.0,
            transfer_burden_disparity=0.25,
            appeal_path_available=True,
        ),
        policy=PlanningPolicy(
            maximum_utilization=0.90,
            maximum_wait_time_disparity_minutes=3.0,
            maximum_reliability_disparity_fraction=0.05,
            minimum_accessible_route_continuity_fraction=1.0,
            maximum_transfer_burden_disparity=1.0,
        ),
        private_identity_or_telemetry_used=False,
    )

    print(
        {
            "decision": report.decision.value,
            "bottleneck_station_reference": report.bottleneck_station_reference,
            "modeled_network_throughput_per_hour": report.modeled_network_throughput_per_hour,
            "station_wait_minutes": report.station_wait_minutes,
            "external_action_authorized": report.external_action_authorized,
            "reasons": report.reasons,
        }
    )
