from dataclasses import dataclass
from decimal import Decimal
from enum import Enum
from typing import Iterable


class ExecutionTier(str, Enum):
    EDGE = "EDGE"
    FOG = "FOG"
    CLOUD = "CLOUD"


@dataclass(frozen=True)
class TransitWorkload:
    workload_ref: str
    maximum_latency_ms: int
    data_class: str
    requires_manual_fallback: bool
    contains_raw_personal_data: bool
    safety_critical: bool


@dataclass(frozen=True)
class NodeProfile:
    node_ref: str
    tier: ExecutionTier
    estimated_latency_ms: int
    estimated_energy_cost: Decimal
    privacy_risk: Decimal
    resilience_risk: Decimal
    accepts_raw_personal_data: bool
    available: bool
    local_fallback_available: bool


@dataclass(frozen=True)
class PlacementDecision:
    workload_ref: str
    node_ref: str | None
    tier: ExecutionTier | None
    objective_value: Decimal | None
    eligible: bool
    exclusions: tuple[str, ...]


def evaluate_placement(
    workload: TransitWorkload,
    node: NodeProfile,
) -> PlacementDecision:
    exclusions: list[str] = []

    if not node.available:
        exclusions.append("NODE_UNAVAILABLE")

    if node.estimated_latency_ms > workload.maximum_latency_ms:
        exclusions.append("LATENCY_BUDGET_EXCEEDED")

    if workload.contains_raw_personal_data:
        exclusions.append("RAW_PERSONAL_DATA_WORKLOAD_PROHIBITED")

    if workload.safety_critical and node.tier == ExecutionTier.CLOUD:
        exclusions.append("CLOUD_ONLY_SAFETY_CRITICAL_PLACEMENT_PROHIBITED")

    if workload.requires_manual_fallback and not node.local_fallback_available:
        exclusions.append("MANUAL_FALLBACK_UNAVAILABLE")

    if node.accepts_raw_personal_data:
        exclusions.append("NODE_ACCEPTS_RAW_PERSONAL_DATA")

    if exclusions:
        return PlacementDecision(
            workload_ref=workload.workload_ref,
            node_ref=node.node_ref,
            tier=node.tier,
            objective_value=None,
            eligible=False,
            exclusions=tuple(exclusions),
        )

    objective_value = (
        Decimal(node.estimated_latency_ms)
        + node.estimated_energy_cost
        + node.privacy_risk
        + node.resilience_risk
    )

    return PlacementDecision(
        workload_ref=workload.workload_ref,
        node_ref=node.node_ref,
        tier=node.tier,
        objective_value=objective_value,
        eligible=True,
        exclusions=(),
    )


def select_placement(
    workload: TransitWorkload,
    nodes: Iterable[NodeProfile],
) -> PlacementDecision | None:
    candidates = [
        evaluate_placement(workload, node)
        for node in nodes
    ]

    eligible = [
        candidate
        for candidate in candidates
        if candidate.eligible and candidate.objective_value is not None
    ]

    if not eligible:
        return None

    return min(eligible, key=lambda candidate: candidate.objective_value)
