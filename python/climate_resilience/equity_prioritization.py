from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Iterable


class ResiliencePlanningError(ValueError):
    pass


@dataclass(frozen=True)
class CandidateProject:
    label: str
    social_need: float
    ecological_benefit: float
    feasibility: float
    displacement_risk: float
    rights_accessibility_risk: float
    uncertainty: float

    def __post_init__(self) -> None:
        if not self.label.strip():
            raise ResiliencePlanningError("label must be non-empty.")

        for field_name, value in (
            ("social_need", self.social_need),
            ("ecological_benefit", self.ecological_benefit),
            ("feasibility", self.feasibility),
            ("displacement_risk", self.displacement_risk),
            ("rights_accessibility_risk", self.rights_accessibility_risk),
            ("uncertainty", self.uncertainty),
        ):
            if not isfinite(value) or not 0.0 <= value <= 1.0:
                raise ResiliencePlanningError(
                    f"{field_name} must be a finite value in the inclusive range from zero through one."
                )


@dataclass(frozen=True)
class PlanningWeights:
    social_need: float
    ecological_benefit: float
    feasibility: float

    def __post_init__(self) -> None:
        values = (self.social_need, self.ecological_benefit, self.feasibility)
        if any(not isfinite(value) or value < 0.0 for value in values):
            raise ResiliencePlanningError("All planning weights must be finite and non-negative.")
        if self.social_need <= 0.5:
            raise ResiliencePlanningError("social_need weight must be greater than 0.5.")
        if abs(sum(values) - 1.0) > 1e-9:
            raise ResiliencePlanningError("Planning weights must sum to one.")


@dataclass(frozen=True)
class PlanningDecision:
    label: str
    eligible: bool
    base_score: float | None
    uncertainty_adjusted_score: float | None
    reason: str


def prioritize(
    candidates: Iterable[CandidateProject],
    weights: PlanningWeights,
    minimum_social_need: float = 0.4,
    maximum_displacement_risk: float = 0.25,
    maximum_rights_accessibility_risk: float = 0.2,
    maximum_uncertainty: float = 0.5,
) -> list[PlanningDecision]:
    limits = (
        minimum_social_need,
        maximum_displacement_risk,
        maximum_rights_accessibility_risk,
        maximum_uncertainty,
    )
    if any(not isfinite(value) or not 0.0 <= value <= 1.0 for value in limits):
        raise ResiliencePlanningError("All thresholds must be finite values in the range from zero through one.")

    decisions: list[PlanningDecision] = []
    for candidate in candidates:
        if candidate.social_need < minimum_social_need:
            decisions.append(
                PlanningDecision(
                    label=candidate.label,
                    eligible=False,
                    base_score=None,
                    uncertainty_adjusted_score=None,
                    reason="Candidate does not meet the human-needs floor.",
                )
            )
            continue

        if candidate.displacement_risk > maximum_displacement_risk:
            decisions.append(
                PlanningDecision(
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
                PlanningDecision(
                    label=candidate.label,
                    eligible=False,
                    base_score=None,
                    uncertainty_adjusted_score=None,
                    reason="Candidate exceeds the non-compensable rights and accessibility risk limit.",
                )
            )
            continue

        if candidate.uncertainty > maximum_uncertainty:
            decisions.append(
                PlanningDecision(
                    label=candidate.label,
                    eligible=False,
                    base_score=None,
                    uncertainty_adjusted_score=None,
                    reason="Candidate uncertainty exceeds the maximum decision-support threshold.",
                )
            )
            continue

        base_score = (
            weights.social_need * candidate.social_need
            + weights.ecological_benefit * candidate.ecological_benefit
            + weights.feasibility * candidate.feasibility
        )
        adjusted_score = base_score * (1.0 - candidate.uncertainty)

        decisions.append(
            PlanningDecision(
                label=candidate.label,
                eligible=True,
                base_score=base_score,
                uncertainty_adjusted_score=adjusted_score,
                reason="Candidate meets human-needs, rights, displacement, and uncertainty constraints.",
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
