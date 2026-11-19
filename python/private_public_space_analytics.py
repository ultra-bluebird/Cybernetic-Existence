from __future__ import annotations

from dataclasses import dataclass
from math import exp, isfinite, log
from random import SystemRandom
from typing import Iterable, Mapping


@dataclass(frozen=True)
class AggregateObservation:
    zone_name: str
    time_bucket_unix_s: int
    occupancy_count: int
    ingress_count: int
    egress_count: int
    dwell_histogram: Mapping[str, int]
    flow_counts: Mapping[str, int]
    sensor_confidence: float


@dataclass(frozen=True)
class PrivacyReleasePolicy:
    minimum_public_count: int = 8
    occupancy_epsilon: float = 0.50
    flow_epsilon: float = 0.35
    maximum_privacy_budget: float = 8.0
    current_privacy_budget_spent: float = 0.0
    minimum_sensor_confidence: float = 0.70
    maximum_count_per_zone_bucket: int = 10000


@dataclass(frozen=True)
class PrivateAggregateRelease:
    zone_name: str
    time_bucket_unix_s: int
    released_occupancy_count: int | None
    released_ingress_count: int | None
    released_egress_count: int | None
    released_flow_counts: Mapping[str, int]
    released_dwell_histogram: Mapping[str, int]
    privacy_budget_consumed: float
    total_privacy_budget_spent: float
    suppressed: bool
    explanation: str


_rng = SystemRandom()


def _require_finite(name: str, value: float) -> None:
    if not isfinite(value):
        raise ValueError(f"{name} must be finite")


def _require_unit_interval(name: str, value: float) -> None:
    _require_finite(name, value)
    if value < 0.0 or value > 1.0:
        raise ValueError(f"{name} must be within [0, 1]")


def _sample_laplace(scale: float) -> float:
    if not isfinite(scale) or scale <= 0.0:
        raise ValueError("Laplace scale must be finite and positive")

    uniform = _rng.random() - 0.5
    sign = 1.0 if uniform >= 0.0 else -1.0
    return -scale * sign * log(1.0 - 2.0 * abs(uniform))


def _noisy_nonnegative_count(count: int, epsilon: float) -> int:
    if count < 0:
        raise ValueError("count must not be negative")
    if epsilon <= 0.0:
        raise ValueError("epsilon must be positive")

    noisy = round(count + _sample_laplace(1.0 / epsilon))
    return max(0, noisy)


def validate_observation(
    observation: AggregateObservation,
    policy: PrivacyReleasePolicy,
) -> None:
    if not observation.zone_name.strip():
        raise ValueError("zone_name must be non-empty")

    if observation.time_bucket_unix_s <= 0:
        raise ValueError("time_bucket_unix_s must be positive")

    for name, value in {
        "occupancy_count": observation.occupancy_count,
        "ingress_count": observation.ingress_count,
        "egress_count": observation.egress_count,
    }.items():
        if value < 0 or value > policy.maximum_count_per_zone_bucket:
            raise ValueError(
                f"{name} must be within [0, {policy.maximum_count_per_zone_bucket}]"
            )

    _require_unit_interval(
        "sensor_confidence",
        observation.sensor_confidence,
    )

    for bin_name, count in observation.dwell_histogram.items():
        if not bin_name.strip():
            raise ValueError("dwell histogram bin names must be non-empty")
        if count < 0 or count > policy.maximum_count_per_zone_bucket:
            raise ValueError("dwell histogram count is outside the accepted range")

    for destination_zone, count in observation.flow_counts.items():
        if not destination_zone.strip():
            raise ValueError("flow destination zone must be non-empty")
        if count < 0 or count > policy.maximum_count_per_zone_bucket:
            raise ValueError("flow count is outside the accepted range")


def validate_policy(policy: PrivacyReleasePolicy) -> None:
    if policy.minimum_public_count < 1:
        raise ValueError("minimum_public_count must be at least 1")

    for name, value in {
        "occupancy_epsilon": policy.occupancy_epsilon,
        "flow_epsilon": policy.flow_epsilon,
        "maximum_privacy_budget": policy.maximum_privacy_budget,
    }.items():
        _require_finite(name, value)
        if value <= 0.0:
            raise ValueError(f"{name} must be positive")

    _require_finite(
        "current_privacy_budget_spent",
        policy.current_privacy_budget_spent,
    )

    if policy.current_privacy_budget_spent < 0.0:
        raise ValueError("current_privacy_budget_spent must not be negative")

    _require_unit_interval(
        "minimum_sensor_confidence",
        policy.minimum_sensor_confidence,
    )

    if policy.maximum_count_per_zone_bucket < policy.minimum_public_count:
        raise ValueError(
            "maximum_count_per_zone_bucket must meet the public-count threshold"
        )


def release_aggregate(
    observation: AggregateObservation,
    policy: PrivacyReleasePolicy = PrivacyReleasePolicy(),
) -> PrivateAggregateRelease:
    validate_policy(policy)
    validate_observation(observation, policy)

    budget_cost = policy.occupancy_epsilon + policy.flow_epsilon
    next_budget = policy.current_privacy_budget_spent + budget_cost

    if next_budget > policy.maximum_privacy_budget:
        return PrivateAggregateRelease(
            zone_name=observation.zone_name,
            time_bucket_unix_s=observation.time_bucket_unix_s,
            released_occupancy_count=None,
            released_ingress_count=None,
            released_egress_count=None,
            released_flow_counts={},
            released_dwell_histogram={},
            privacy_budget_consumed=0.0,
            total_privacy_budget_spent=policy.current_privacy_budget_spent,
            suppressed=True,
            explanation=(
                "The aggregate was not released because the applicable privacy "
                "budget is exhausted. Publish a coarser aggregate only after a "
                "new, documented privacy-budget allocation."
            ),
        )

    if observation.sensor_confidence < policy.minimum_sensor_confidence:
        return PrivateAggregateRelease(
            zone_name=observation.zone_name,
            time_bucket_unix_s=observation.time_bucket_unix_s,
            released_occupancy_count=None,
            released_ingress_count=None,
            released_egress_count=None,
            released_flow_counts={},
            released_dwell_histogram={},
            privacy_budget_consumed=0.0,
            total_privacy_budget_spent=policy.current_privacy_budget_spent,
            suppressed=True,
            explanation=(
                "The aggregate was not released because the sensor-confidence "
                "requirement was not met. The system must not publish uncertain "
                "counts as public-space evidence."
            ),
        )

    if observation.occupancy_count < policy.minimum_public_count:
        return PrivateAggregateRelease(
            zone_name=observation.zone_name,
            time_bucket_unix_s=observation.time_bucket_unix_s,
            released_occupancy_count=None,
            released_ingress_count=None,
            released_egress_count=None,
            released_flow_counts={},
            released_dwell_histogram={},
            privacy_budget_consumed=0.0,
            total_privacy_budget_spent=policy.current_privacy_budget_spent,
            suppressed=True,
            explanation=(
                "The aggregate was suppressed because occupancy is below the "
                "published minimum group threshold for public release."
            ),
        )

    released_flows = {
        destination_zone: _noisy_nonnegative_count(
            count,
            policy.flow_epsilon,
        )
        for destination_zone, count in observation.flow_counts.items()
        if count >= policy.minimum_public_count
    }

    released_dwell = {
        dwell_bin: _noisy_nonnegative_count(
            count,
            policy.occupancy_epsilon,
        )
        for dwell_bin, count in observation.dwell_histogram.items()
        if count >= policy.minimum_public_count
    }

    return PrivateAggregateRelease(
        zone_name=observation.zone_name,
        time_bucket_unix_s=observation.time_bucket_unix_s,
        released_occupancy_count=_noisy_nonnegative_count(
            observation.occupancy_count,
            policy.occupancy_epsilon,
        ),
        released_ingress_count=_noisy_nonnegative_count(
            observation.ingress_count,
            policy.occupancy_epsilon,
        ),
        released_egress_count=_noisy_nonnegative_count(
            observation.egress_count,
            policy.occupancy_epsilon,
        ),
        released_flow_counts=released_flows,
        released_dwell_histogram=released_dwell,
        privacy_budget_consumed=budget_cost,
        total_privacy_budget_spent=next_budget,
        suppressed=False,
        explanation=(
            "This release contains differentially private, group-level occupancy "
            "and flow statistics. It contains no raw thermal frames, point clouds, "
            "audio, visual imagery, individual trajectories, identities, or "
            "cross-space tracking references."
        ),
    )


def laplace_two_sided_95_percent_interval(
    epsilon: float,
    sensitivity: float = 1.0,
) -> float:
    if epsilon <= 0.0:
        raise ValueError("epsilon must be positive")
    if sensitivity <= 0.0:
        raise ValueError("sensitivity must be positive")

    scale = sensitivity / epsilon
    return scale * log(20.0)
