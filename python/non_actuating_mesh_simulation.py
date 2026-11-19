from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Iterable, Literal


AdvisoryStatus = Literal[
    "ADVISORY_STABLE",
    "ADVISORY_PARTITION_CANDIDATE",
    "ADVISORY_DEGRADATION_CANDIDATE",
    "INSUFFICIENT_HOST_REPORTED_CONTEXT",
    "REVIEW_REQUIRED",
]


@dataclass(frozen=True)
class ReportedNode:
    node_id: str
    signal_budget: float
    continuity_index: float
    report_confidence: float
    interference_flag: bool
    uncertainty_flag: bool


@dataclass(frozen=True)
class ReportedEdge:
    edge_id: str
    source_node_id: str
    target_node_id: str
    signal_strength: float
    trust_level: float
    energy_budget: float
    report_confidence: float
    interference_flag: bool
    uncertainty_flag: bool


@dataclass(frozen=True)
class TwinSnapshot:
    snapshot_id: str
    observed_at_utc: datetime
    expected_node_count: int
    nodes: tuple[ReportedNode, ...]
    edges: tuple[ReportedEdge, ...]


@dataclass(frozen=True)
class AnalysisConfig:
    signal_weight: float = 0.35
    confidence_weight: float = 0.25
    energy_weight: float = 0.25
    interference_weight: float = 0.15
    edge_health_threshold: float = 0.45
    minimum_coverage: float = 0.50
    minimum_report_confidence: float = 0.50
    degradation_delta: float = 0.15
    required_consecutive_windows: int = 2


@dataclass(frozen=True)
class AdvisoryAnalysis:
    status: AdvisoryStatus
    continuity_index: float | None
    coverage: float | None
    average_edge_health: float | None
    uncertainty_penalty: float | None
    weak_component_count: int | None
    explanation: str


def _unit_interval(value: float, name: str) -> None:
    if not isinstance(value, (int, float)) or isinstance(value, bool) or not 0.0 <= float(value) <= 1.0:
        raise ValueError(f"{name} must be a number in [0, 1]")


def _validate_config(config: AnalysisConfig) -> None:
    weights = (
        config.signal_weight,
        config.confidence_weight,
        config.energy_weight,
        config.interference_weight,
    )
    for value, name in zip(
        weights,
        ("signal_weight", "confidence_weight", "energy_weight", "interference_weight"),
        strict=True,
    ):
        _unit_interval(value, name)

    if abs(sum(weights) - 1.0) > 1e-12:
        raise ValueError("AnalysisConfig weights must sum exactly to 1.0")

    _unit_interval(config.edge_health_threshold, "edge_health_threshold")
    _unit_interval(config.minimum_coverage, "minimum_coverage")
    _unit_interval(config.minimum_report_confidence, "minimum_report_confidence")
    _unit_interval(config.degradation_delta, "degradation_delta")

    if config.required_consecutive_windows < 1:
        raise ValueError("required_consecutive_windows must be at least 1")


def _edge_health(edge: ReportedEdge, config: AnalysisConfig) -> float:
    for value, name in (
        (edge.signal_strength, "signal_strength"),
        (edge.trust_level, "trust_level"),
        (edge.energy_budget, "energy_budget"),
        (edge.report_confidence, "report_confidence"),
    ):
        _unit_interval(value, name)

    penalty = 1.0 if edge.interference_flag else 0.0
    result = (
        config.signal_weight * edge.signal_strength
        + config.confidence_weight * min(edge.trust_level, edge.report_confidence)
        + config.energy_weight * edge.energy_budget
        - config.interference_weight * penalty
    )
    return max(0.0, min(1.0, result))


def _weak_component_count(
    node_ids: Iterable[str],
    edges: Iterable[ReportedEdge],
    config: AnalysisConfig,
) -> int:
    adjacency: dict[str, set[str]] = {node_id: set() for node_id in node_ids}

    for edge in edges:
        if edge.uncertainty_flag or edge.report_confidence < config.minimum_report_confidence:
            continue
        if _edge_health(edge, config) < config.edge_health_threshold:
            continue
        if edge.source_node_id not in adjacency or edge.target_node_id not in adjacency:
            continue
        adjacency[edge.source_node_id].add(edge.target_node_id)
        adjacency[edge.target_node_id].add(edge.source_node_id)

    remaining = set(adjacency)
    components = 0
    while remaining:
        components += 1
        pending = [remaining.pop()]
        while pending:
            current = pending.pop()
            neighbors = adjacency[current] & remaining
            remaining -= neighbors
            pending.extend(neighbors)

    return components


def analyze_snapshot(snapshot: TwinSnapshot, config: AnalysisConfig) -> AdvisoryAnalysis:
    _validate_config(config)

    if snapshot.expected_node_count < 1:
        raise ValueError("expected_node_count must be at least 1")

    if snapshot.observed_at_utc.tzinfo is None:
        raise ValueError("observed_at_utc must include timezone information")

    if snapshot.observed_at_utc.utcoffset() != timezone.utc.utcoffset(snapshot.observed_at_utc):
        raise ValueError("observed_at_utc must be normalized to UTC")

    if not snapshot.nodes:
        return AdvisoryAnalysis(
            status="INSUFFICIENT_HOST_REPORTED_CONTEXT",
            continuity_index=None,
            coverage=None,
            average_edge_health=None,
            uncertainty_penalty=None,
            weak_component_count=None,
            explanation="No host-reported nodes were supplied. No continuity conclusion is available.",
        )

    node_ids = {node.node_id for node in snapshot.nodes}
    if len(node_ids) != len(snapshot.nodes):
        raise ValueError("node_id values must be unique within one snapshot")

    for node in snapshot.nodes:
        for value, name in (
            (node.signal_budget, "signal_budget"),
            (node.continuity_index, "continuity_index"),
            (node.report_confidence, "report_confidence"),
        ):
            _unit_interval(value, name)

    coverage = min(1.0, len(snapshot.nodes) / snapshot.expected_node_count)

    usable_edges = tuple(
        edge
        for edge in snapshot.edges
        if edge.source_node_id in node_ids
        and edge.target_node_id in node_ids
        and not edge.uncertainty_flag
        and edge.report_confidence >= config.minimum_report_confidence
    )

    if coverage < config.minimum_coverage:
        return AdvisoryAnalysis(
            status="INSUFFICIENT_HOST_REPORTED_CONTEXT",
            continuity_index=None,
            coverage=coverage,
            average_edge_health=None,
            uncertainty_penalty=None,
            weak_component_count=None,
            explanation=(
                "Reported coverage is below the configured minimum. "
                "The model preserves uncertainty and does not classify continuity."
            ),
        )

    if not usable_edges and len(snapshot.nodes) > 1:
        return AdvisoryAnalysis(
            status="INSUFFICIENT_HOST_REPORTED_CONTEXT",
            continuity_index=None,
            coverage=coverage,
            average_edge_health=None,
            uncertainty_penalty=None,
            weak_component_count=None,
            explanation=(
                "No usable host-reported relationships were supplied for a multi-node snapshot. "
                "No partition or continuity conclusion is available."
            ),
        )

    edge_health_values = tuple(_edge_health(edge, config) for edge in usable_edges)
    average_edge_health = sum(edge_health_values) / len(edge_health_values) if edge_health_values else 1.0

    uncertainty_items = [
        1.0 - node.report_confidence if node.uncertainty_flag else 0.0
        for node in snapshot.nodes
    ] + [
        1.0 - edge.report_confidence if edge.uncertainty_flag else 0.0
        for edge in snapshot.edges
    ]

    uncertainty_penalty = (
        sum(uncertainty_items) / len(uncertainty_items) if uncertainty_items else 0.0
    )

    continuity_index = max(
        0.0,
        min(1.0, coverage * average_edge_health * (1.0 - uncertainty_penalty)),
    )

    component_count = _weak_component_count(node_ids, usable_edges, config)

    if len(snapshot.nodes) >= 2 and component_count > 1:
        return AdvisoryAnalysis(
            status="ADVISORY_PARTITION_CANDIDATE",
            continuity_index=continuity_index,
            coverage=coverage,
            average_edge_health=average_edge_health,
            uncertainty_penalty=uncertainty_penalty,
            weak_component_count=component_count,
            explanation=(
                "The abstract host-reported graph has multiple weak components under the "
                "configured advisory threshold. This is not a verified physical partition "
                "and requires human review if action is considered."
            ),
        )

    return AdvisoryAnalysis(
        status="ADVISORY_STABLE",
        continuity_index=continuity_index,
        coverage=coverage,
        average_edge_health=average_edge_health,
        uncertainty_penalty=uncertainty_penalty,
        weak_component_count=component_count,
        explanation=(
            "The supplied abstract report is connected under the configured advisory model. "
            "This is not a confirmation of real-world continuity or system condition."
        ),
    )


def analyze_degradation(
    previous: AdvisoryAnalysis,
    current: AdvisoryAnalysis,
    config: AnalysisConfig,
    consecutive_candidate_windows: int,
) -> AdvisoryAnalysis:
    _validate_config(config)

    if previous.continuity_index is None or current.continuity_index is None:
        return AdvisoryAnalysis(
            status="INSUFFICIENT_HOST_REPORTED_CONTEXT",
            continuity_index=current.continuity_index,
            coverage=current.coverage,
            average_edge_health=current.average_edge_health,
            uncertainty_penalty=current.uncertainty_penalty,
            weak_component_count=current.weak_component_count,
            explanation=(
                "At least one comparison window lacks sufficient host-reported context. "
                "The model does not calculate a degradation conclusion."
            ),
        )

    delta = current.continuity_index - previous.continuity_index
    if (
        delta <= -config.degradation_delta
        and current.coverage is not None
        and current.coverage >= config.minimum_coverage
        and consecutive_candidate_windows >= config.required_consecutive_windows
    ):
        return AdvisoryAnalysis(
            status="ADVISORY_DEGRADATION_CANDIDATE",
            continuity_index=current.continuity_index,
            coverage=current.coverage,
            average_edge_health=current.average_edge_health,
            uncertainty_penalty=current.uncertainty_penalty,
            weak_component_count=current.weak_component_count,
            explanation=(
                "The advisory continuity index declined beyond the configured threshold "
                "across sufficient consecutive windows. This is a review signal, not a "
                "verified condition or operational command."
            ),
        )

    return AdvisoryAnalysis(
        status="ADVISORY_STABLE",
        continuity_index=current.continuity_index,
        coverage=current.coverage,
        average_edge_health=current.average_edge_health,
        uncertainty_penalty=current.uncertainty_penalty,
        weak_component_count=current.weak_component_count,
        explanation=(
            "No persistent advisory degradation candidate was established under the "
            "configured thresholds."
        ),
    )
