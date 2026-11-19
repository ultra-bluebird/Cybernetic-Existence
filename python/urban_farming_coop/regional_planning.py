from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Iterable, Mapping


class CooperativePlanningError(ValueError):
    pass


@dataclass(frozen=True)
class RegionalContribution:
    zone_id: str
    crop_group: str
    time_window: str
    cultivated_area_m2: float
    yield_kg: float
    contributor_count: int

    def __post_init__(self) -> None:
        if not self.zone_id.strip() or not self.crop_group.strip() or not self.time_window.strip():
            raise CooperativePlanningError(
                "zone_id, crop_group, and time_window must be non-empty."
            )

        for field_name, value in (
            ("cultivated_area_m2", self.cultivated_area_m2),
            ("yield_kg", self.yield_kg),
        ):
            if not isfinite(value) or value < 0.0:
                raise CooperativePlanningError(
                    f"{field_name} must be finite and non-negative."
                )

        if self.contributor_count < 0:
            raise CooperativePlanningError(
                "contributor_count must be non-negative."
            )


@dataclass(frozen=True)
class RegionalYieldSummary:
    zone_id: str
    crop_group: str
    time_window: str
    total_area_m2: float
    total_yield_kg: float
    contributor_count: int
    yield_density_kg_m2: float | None
    public_release_allowed: bool
    reason: str


def summarize_regional_yields(
    contributions: Iterable[RegionalContribution],
    minimum_contributor_count: int,
) -> list[RegionalYieldSummary]:
    if minimum_contributor_count < 2:
        raise CooperativePlanningError(
            "minimum_contributor_count must be at least two for a privacy-protective release."
        )

    grouped: dict[tuple[str, str, str], list[RegionalContribution]] = {}
    for contribution in contributions:
        key = (
            contribution.zone_id,
            contribution.crop_group,
            contribution.time_window,
        )
        grouped.setdefault(key, []).append(contribution)

    summaries: list[RegionalYieldSummary] = []
    for (zone_id, crop_group, time_window), members in sorted(grouped.items()):
        total_area = sum(member.cultivated_area_m2 for member in members)
        total_yield = sum(member.yield_kg for member in members)
        contributor_count = sum(member.contributor_count for member in members)

        if contributor_count < minimum_contributor_count:
            summaries.append(
                RegionalYieldSummary(
                    zone_id=zone_id,
                    crop_group=crop_group,
                    time_window=time_window,
                    total_area_m2=0.0,
                    total_yield_kg=0.0,
                    contributor_count=contributor_count,
                    yield_density_kg_m2=None,
                    public_release_allowed=False,
                    reason=(
                        "Small-cell suppression applies because the minimum contributor "
                        "threshold is not met."
                    ),
                )
            )
            continue

        if total_area <= 0.0:
            raise CooperativePlanningError(
                "A releasable regional summary requires positive total cultivated area."
            )

        summaries.append(
            RegionalYieldSummary(
                zone_id=zone_id,
                crop_group=crop_group,
                time_window=time_window,
                total_area_m2=total_area,
                total_yield_kg=total_yield,
                contributor_count=contributor_count,
                yield_density_kg_m2=total_yield / total_area,
                public_release_allowed=True,
                reason=(
                    "The summary is coarsened to a regional crop group and satisfies "
                    "the contributor threshold."
                ),
            )
        )

    return summaries


def validate_non_ranking_incentive(
    benefit_type: str,
    changes_member_governance_weight: bool,
    derived_from_individual_yield: bool,
    derived_from_data_volume: bool,
) -> bool:
    permitted_benefits = {
        "shared_seed_library_access",
        "shared_tool_lending",
        "community_training",
        "cooperative_procurement",
        "shared_regional_planning_summary",
        "opt_in_collective_recognition",
    }

    return (
        benefit_type in permitted_benefits
        and not changes_member_governance_weight
        and not derived_from_individual_yield
        and not derived_from_data_volume
    )
