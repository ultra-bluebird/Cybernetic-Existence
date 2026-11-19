from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Iterable


class ShadePlacementValidationError(ValueError):
    pass


@dataclass(frozen=True)
class ShadeCandidate:
    label: str
    heat_exposure: float
    access_gap: float
    aggregate_use_estimate: float
    comfort_benefit: float
    ecological_compatibility: float
    maintenance_feasibility: float
    displacement_risk: float
    rights_accessibility_risk: float
    uncertainty: float
    wifi_probe_data_used: bool = False
    bluetooth_data_used: bool = False
    camera_data_used: bool = False
    identity_data_used: bool = False

    def __post_init__(self) -> None:
        if not self.label.strip():
            raise ShadePlacementValidationError("label must be non-empty.")

        for field_name, value in (
            ("heat_exposure", self.heat_exposure),
            ("access_gap", self.access_gap),
            ("aggregate_use_estimate", self.aggregate_use_estimate),
            ("comfort_benefit", self.comfort_benefit),
            ("ecological_compatibility", self.ecological_compatibility),
            ("maintenance_feasibility", self.maintenance_feasibility),
            ("displacement_risk", self.displacement_risk),
            ("rights_accessibility_risk", self.rights_accessibility_risk),
            ("uncertainty", self.uncertainty),
        ):
            if not isfinite(value) or not 0.0 <= value <= 1.0:
                raise ShadePlacementValidationError(
                    f"{field_name} must be finite and within zero through one."
                )


@dataclass(frozen=True)
class ShadePlacementDecision:
    label: str
    eligible: bool
    base_score: float | None
    uncertainty_adjusted_score: float | None
    reason: str


def prioritize_shade_candidates(
    candidates: Iterable[ShadeCandidate],
    maximum_displacement_risk: float = 0.25,
    maximum_rights_accessibility_risk: float = 0.20,
    maximum_uncertainty: float = 0.50,
) -> list[ShadePlacementDecision]:
    thresholds = (
        maximum_displacement_risk,
        maximum_rights_accessibility_risk,
        maximum_uncertainty,
    )
    if any(not isfinite(value) or not 0.0 <= value <= 1.0 for value in thresholds):
        raise ShadePlacementValidationError(
            "All thresholds must be finite values between zero and one."
        )

    decisions: list[ShadePlacementDecision] = []

    for candidate in candidates:
        uses_prohibited_data = any(
            (
                candidate.wifi_probe_data_used,
                candidate.bluetooth_data_used,
                candidate.camera_data_used,
                candidate.identity_data_used,
            )
        )

        if uses_prohibited_data:
            decisions.append(
                ShadePlacementDecision(
                    label=candidate.label,
                    eligible=False,
                    base_score=None,
                    uncertainty_adjusted_score=None,
                    reason=(
                        "Candidate is ineligible because use evidence includes prohibited "
                        "radio, camera, or identity-derived data."
                    ),
                )
            )
            continue

        if candidate.displacement_risk > maximum_displacement_risk:
            decisions.append(
                ShadePlacementDecision(
                    label=candidate.label,
                    eligible=False,
                    base_score=None,
                    uncertainty_adjusted_score=None,
                    reason="Candidate exceeds the non-compensable displacement-risk limit.",
                )
            )
            continue

        if candidate.rights_accessibility_risk > maximum_rights_accessibility_risk:
            decisions.append(
                ShadePlacementDecision(
                    label=candidate.label,
                    eligible=False,
                    base_score=None,
                    uncertainty_adjusted_score=None,
                    reason=(
                        "Candidate exceeds the non-compensable rights and accessibility "
                        "risk limit."
                    ),
                )
            )
            continue

        if candidate.uncertainty > maximum_uncertainty:
            decisions.append(
                ShadePlacementDecision(
                    label=candidate.label,
                    eligible=False,
                    base_score=None,
                    uncertainty_adjusted_score=None,
                    reason="Candidate uncertainty exceeds the decision-support limit.",
                )
            )
            continue

        base_score = (
            0.40 * candidate.heat_exposure
            + 0.25 * candidate.access_gap
            + 0.15 * candidate.aggregate_use_estimate
            + 0.10 * candidate.comfort_benefit
            + 0.05 * candidate.ecological_compatibility
            + 0.05 * candidate.maintenance_feasibility
        )
        adjusted_score = base_score * (1.0 - candidate.uncertainty)

        decisions.append(
            ShadePlacementDecision(
                label=candidate.label,
                eligible=True,
                base_score=base_score,
                uncertainty_adjusted_score=adjusted_score,
                reason=(
                    "Candidate uses privacy-safe aggregate evidence and meets rights, "
                    "accessibility, displacement, and uncertainty constraints."
                ),
            )
        )

    return sorted(
        decisions,
        key=lambda decision: (
            not decision.eligible,
            -(decision.uncertainty_adjusted_score or 0.0),
            decision.label,
        ),
    )


def utci_target_met(
    shaded_daytime_utci_c: Iterable[float],
    threshold_c: float = 26.0,
    required_fraction: float = 0.90,
) -> bool:
    values = list(shaded_daytime_utci_c)
    if not values:
        raise ShadePlacementValidationError(
            "At least one UTCI daytime value is required."
        )
    if (
        not isfinite(threshold_c)
        or not isfinite(required_fraction)
        or not 0.0 < required_fraction <= 1.0
    ):
        raise ShadePlacementValidationError(
            "UTCI threshold and required fraction must be finite and valid."
        )
    if any(not isfinite(value) for value in values):
        raise ShadePlacementValidationError("UTCI values must be finite.")

    fraction_below_target = sum(value < threshold_c for value in values) / len(values)
    return fraction_below_target >= required_fraction
