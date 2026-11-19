from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from math import floor
from typing import Iterable, Mapping, Sequence


@dataclass(frozen=True)
class EmergencyResponseRequest:
    life_safety_priority: float
    communication_modes_available: frozenset[str]
    required_communication_modes: frozenset[str]
    relevant_medical_or_assistive_considerations: frozenset[str]
    identity_attributes_present: frozenset[str]


@dataclass(frozen=True)
class EmergencyResponseDecision:
    lifesaving_priority: float
    accessible_communication_ready: bool
    dignity_protocol_active: bool
    identity_based_triage_prohibited: bool
    relevant_considerations_transmitted: frozenset[str]


@dataclass(frozen=True)
class KnowledgeNode:
    node_id: str
    core_information: str
    optional_identity_specific_information: Mapping[str, str]
    alternatives: tuple[str, ...]
    prerequisites: tuple[str, ...]


@dataclass(frozen=True)
class PublicKnowledgeResponse:
    core_information: str
    requested_optional_information: str | None
    alternatives: tuple[str, ...]
    prerequisites: tuple[str, ...]


@dataclass(frozen=True)
class HeatObservation:
    consent_active: bool
    x_meters: float
    y_meters: float
    observed_at_utc: datetime
    temperature_celsius: float | None
    shade_present: bool | None
    thermal_comfort_score: float | None
    infrastructure_condition: str | None
    confidence: float


@dataclass(frozen=True)
class HeatCellAggregate:
    grid_cell: str
    time_bucket_start_utc: datetime
    report_count: int
    weighted_temperature_celsius: float | None
    shade_observation_rate: float | None
    weighted_comfort_score: float | None
    infrastructure_condition_counts: Mapping[str, int]


MINIMUM_HEAT_GRID_METERS = 100
MINIMUM_HEAT_BUCKET_SECONDS = 15 * 60


def _require_unit_interval(value: float, label: str) -> None:
    if not 0.0 <= value <= 1.0:
        raise ValueError(f"{label} must be within [0, 1].")


def emergency_response_decision(
    request: EmergencyResponseRequest,
) -> EmergencyResponseDecision:
    _require_unit_interval(request.life_safety_priority, "Life-safety priority")

    accessible_communication_ready = (
        request.required_communication_modes
        <= request.communication_modes_available
    )

    return EmergencyResponseDecision(
        lifesaving_priority=request.life_safety_priority,
        accessible_communication_ready=accessible_communication_ready,
        dignity_protocol_active=True,
        identity_based_triage_prohibited=True,
        relevant_considerations_transmitted=(
            request.relevant_medical_or_assistive_considerations
        ),
    )


def emergency_request_is_rights_preserving(
    decision: EmergencyResponseDecision,
) -> bool:
    return (
        decision.accessible_communication_ready
        and decision.dignity_protocol_active
        and decision.identity_based_triage_prohibited
    )


def resolve_public_knowledge(
    node: KnowledgeNode,
    optional_identity_topic: str | None,
) -> PublicKnowledgeResponse:
    requested_optional_information = None

    if optional_identity_topic is not None:
        requested_optional_information = (
            node.optional_identity_specific_information.get(
                optional_identity_topic
            )
        )

    return PublicKnowledgeResponse(
        core_information=node.core_information,
        requested_optional_information=requested_optional_information,
        alternatives=node.alternatives,
        prerequisites=node.prerequisites,
    )


def time_bucket_start(
    timestamp: datetime,
    bucket_seconds: int,
) -> datetime:
    if timestamp.tzinfo is None:
        raise ValueError("Timestamp must include timezone information.")

    if bucket_seconds < MINIMUM_HEAT_BUCKET_SECONDS:
        raise ValueError("Heat-report aggregation windows must be at least 15 minutes.")

    timestamp_utc = timestamp.astimezone(timezone.utc)
    bucket_epoch = floor(timestamp_utc.timestamp() / bucket_seconds) * bucket_seconds
    return datetime.fromtimestamp(bucket_epoch, tz=timezone.utc)


def grid_cell(
    x_meters: float,
    y_meters: float,
    cell_size_meters: int,
) -> str:
    if cell_size_meters < MINIMUM_HEAT_GRID_METERS:
        raise ValueError("Heat-report grid cells must be at least 100 meters.")

    return (
        f"{floor(x_meters / cell_size_meters)}:"
        f"{floor(y_meters / cell_size_meters)}:"
        f"{cell_size_meters}m"
    )


def aggregate_heat_observations(
    observations: Iterable[HeatObservation],
    bucket_seconds: int = MINIMUM_HEAT_BUCKET_SECONDS,
    cell_size_meters: int = MINIMUM_HEAT_GRID_METERS,
) -> tuple[HeatCellAggregate, ...]:
    grouped: dict[tuple[str, datetime], list[HeatObservation]] = {}

    for observation in observations:
        if not observation.consent_active:
            continue

        _require_unit_interval(observation.confidence, "Observation confidence")

        key = (
            grid_cell(
                observation.x_meters,
                observation.y_meters,
                cell_size_meters,
            ),
            time_bucket_start(observation.observed_at_utc, bucket_seconds),
        )
        grouped.setdefault(key, []).append(observation)

    results: list[HeatCellAggregate] = []

    for (cell, bucket), entries in sorted(grouped.items()):
        weighted_temperature_numerator = sum(
            entry.temperature_celsius * entry.confidence
            for entry in entries
            if entry.temperature_celsius is not None
        )
        temperature_weight = sum(
            entry.confidence
            for entry in entries
            if entry.temperature_celsius is not None
        )

        weighted_comfort_numerator = sum(
            entry.thermal_comfort_score * entry.confidence
            for entry in entries
            if entry.thermal_comfort_score is not None
        )
        comfort_weight = sum(
            entry.confidence
            for entry in entries
            if entry.thermal_comfort_score is not None
        )

        shade_entries = [
            entry.shade_present
            for entry in entries
            if entry.shade_present is not None
        ]

        condition_counts: dict[str, int] = {}
        for entry in entries:
            if entry.infrastructure_condition is not None:
                condition_counts[entry.infrastructure_condition] = (
                    condition_counts.get(entry.infrastructure_condition, 0) + 1
                )

        results.append(
            HeatCellAggregate(
                grid_cell=cell,
                time_bucket_start_utc=bucket,
                report_count=len(entries),
                weighted_temperature_celsius=(
                    weighted_temperature_numerator / temperature_weight
                    if temperature_weight > 0.0
                    else None
                ),
                shade_observation_rate=(
                    sum(shade_entries) / len(shade_entries)
                    if shade_entries
                    else None
                ),
                weighted_comfort_score=(
                    weighted_comfort_numerator / comfort_weight
                    if comfort_weight > 0.0
                    else None
                ),
                infrastructure_condition_counts=condition_counts,
            )
        )

    return tuple(results)


def heat_report_is_privacy_preserving(
    exact_location_retained: bool,
    individual_contribution_history_retained: bool,
    grid_cell_meters: int,
    time_bucket_seconds: int,
) -> bool:
    return (
        not exact_location_retained
        and not individual_contribution_history_retained
        and grid_cell_meters >= MINIMUM_HEAT_GRID_METERS
        and time_bucket_seconds >= MINIMUM_HEAT_BUCKET_SECONDS
    )
