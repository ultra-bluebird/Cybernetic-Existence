from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class HeatRecoveryStatus(str, Enum):
    HEAT_RECOVERY_AVAILABLE = "HEAT_RECOVERY_AVAILABLE"
    HEAT_RECOVERY_REVIEW_REQUIRED = "HEAT_RECOVERY_REVIEW_REQUIRED"
    INSUFFICIENT_ECOLOGICAL_CONTEXT = "INSUFFICIENT_ECOLOGICAL_CONTEXT"


@dataclass(frozen=True)
class HeatIslandRecoveryInputs:
    tree_canopy_fraction: float
    green_roof_fraction: float
    permeable_surface_fraction: float
    impervious_surface_fraction: float
    tree_canopy_uncertainty: float
    green_roof_uncertainty: float
    permeable_surface_uncertainty: float
    impervious_surface_uncertainty: float
    provenance_available: bool
    method_documented: bool
    source_dates_current: bool
    human_review_required: bool
    advisory_only: bool


@dataclass(frozen=True)
class HeatIslandRecoveryResult:
    status: HeatRecoveryStatus
    raw_hir: float | None
    normalized_hir: float | None
    uncertainty: float | None
    explanation: str


def _unit_interval(value: float, field: str) -> None:
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        raise ValueError(f"{field} must be numeric.")
    if not 0.0 <= float(value) <= 1.0:
        raise ValueError(f"{field} must be in [0, 1].")


def calculate_heat_island_recovery_score(
    inputs: HeatIslandRecoveryInputs,
    maximum_allowed_uncertainty: float,
) -> HeatIslandRecoveryResult:
    for value, name in (
        (inputs.tree_canopy_fraction, "tree_canopy_fraction"),
        (inputs.green_roof_fraction, "green_roof_fraction"),
        (inputs.permeable_surface_fraction, "permeable_surface_fraction"),
        (inputs.impervious_surface_fraction, "impervious_surface_fraction"),
        (inputs.tree_canopy_uncertainty, "tree_canopy_uncertainty"),
        (inputs.green_roof_uncertainty, "green_roof_uncertainty"),
        (inputs.permeable_surface_uncertainty, "permeable_surface_uncertainty"),
        (inputs.impervious_surface_uncertainty, "impervious_surface_uncertainty"),
        (maximum_allowed_uncertainty, "maximum_allowed_uncertainty"),
    ):
        _unit_interval(value, name)

    uncertainty = max(
        inputs.tree_canopy_uncertainty,
        inputs.green_roof_uncertainty,
        inputs.permeable_surface_uncertainty,
        inputs.impervious_surface_uncertainty,
    )

    usable = (
        inputs.provenance_available
        and inputs.method_documented
        and inputs.source_dates_current
        and inputs.human_review_required
        and inputs.advisory_only
        and uncertainty <= maximum_allowed_uncertainty
    )

    if not usable:
        return HeatIslandRecoveryResult(
            status=HeatRecoveryStatus.HEAT_RECOVERY_REVIEW_REQUIRED,
            raw_hir=None,
            normalized_hir=None,
            uncertainty=uncertainty,
            explanation=(
                "Required provenance, method, freshness, uncertainty, human-review, "
                "or advisory-only conditions are not satisfied. No HIR is released."
            ),
        )

    raw_hir = (
        inputs.tree_canopy_fraction
        + 0.5 * inputs.green_roof_fraction
        + inputs.permeable_surface_fraction
    ) / (1.0 + inputs.impervious_surface_fraction)

    normalized_hir = raw_hir / 2.5

    return HeatIslandRecoveryResult(
        status=HeatRecoveryStatus.HEAT_RECOVERY_AVAILABLE,
        raw_hir=raw_hir,
        normalized_hir=max(0.0, min(1.0, normalized_hir)),
        uncertainty=uncertainty,
        explanation=(
            "HIR is a transparent ecological planning-screening indicator based on "
            "supplied land-cover fractions. It is not a resident profile, service "
            "eligibility measure, neighborhood rank, or automatic allocation rule."
        ),
    )
