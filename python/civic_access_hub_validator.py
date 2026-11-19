from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable


@dataclass(frozen=True)
class HubMetrics:
    accessibility: float
    cooling_benefit: float
    social_inclusion: float
    privacy_protection: float
    shade_available: bool
    identity_check_required: bool
    quiet_recovery_space_available: bool
    rights_information_available: bool


@dataclass(frozen=True)
class TransitStopMetrics:
    stop_name: str
    accessibility: float
    dignity: float
    shade_or_climate_refuge: bool
    accessible_information: bool
    safe_waiting_area: bool


@dataclass(frozen=True)
class PanelSessionPolicy:
    local_processing: bool
    identity_required: bool
    query_retained: bool
    raw_audio_retained: bool
    neural_data_retained: bool
    human_handoff_available: bool
    offline_core_knowledge_available: bool


def within_unit_interval(value: float) -> bool:
    return 0.0 <= value <= 1.0


def hub_design_score(
    metrics: HubMetrics,
    accessibility_weight: float,
    cooling_weight: float,
    inclusion_weight: float,
    privacy_weight: float,
) -> float:
    weights = (
        accessibility_weight,
        cooling_weight,
        inclusion_weight,
        privacy_weight,
    )

    if not all(within_unit_interval(weight) for weight in weights):
        raise ValueError("All hub-design weights must be within [0, 1].")

    if sum(weights) == 0:
        raise ValueError("At least one hub-design weight must be positive.")

    values = (
        metrics.accessibility,
        metrics.cooling_benefit,
        metrics.social_inclusion,
        metrics.privacy_protection,
    )

    if not all(within_unit_interval(value) for value in values):
        raise ValueError("All hub metrics must be within [0, 1].")

    return sum(weight * value for weight, value in zip(weights, values)) / sum(weights)


def hub_meets_rights_baseline(metrics: HubMetrics) -> bool:
    return (
        not metrics.identity_check_required
        and metrics.shade_available
        and metrics.quiet_recovery_space_available
        and metrics.rights_information_available
    )


def transit_network_meets_rights_baseline(
    stops: Iterable[TransitStopMetrics],
    accessibility_threshold: float,
    dignity_threshold: float,
    non_discrimination_verified: bool,
    identity_based_fare_difference: bool,
) -> bool:
    if not within_unit_interval(accessibility_threshold):
        raise ValueError("Accessibility threshold must be within [0, 1].")

    if not within_unit_interval(dignity_threshold):
        raise ValueError("Dignity threshold must be within [0, 1].")

    evaluated_stops = tuple(stops)

    if not evaluated_stops:
        return False

    all_stops_meet_thresholds = all(
        stop.accessibility >= accessibility_threshold
        and stop.dignity >= dignity_threshold
        and stop.shade_or_climate_refuge
        and stop.accessible_information
        and stop.safe_waiting_area
        for stop in evaluated_stops
    )

    return (
        all_stops_meet_thresholds
        and non_discrimination_verified
        and not identity_based_fare_difference
    )


def panel_session_preserves_privacy_and_access(
    session: PanelSessionPolicy,
) -> bool:
    return (
        session.local_processing
        and not session.identity_required
        and not session.query_retained
        and not session.raw_audio_retained
        and not session.neural_data_retained
        and session.human_handoff_available
        and session.offline_core_knowledge_available
    )
