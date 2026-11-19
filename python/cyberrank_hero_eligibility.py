from __future__ import annotations

from dataclasses import dataclass
from typing import Literal


TitleState = Literal["candidate", "hero-active", "hero-at-rest"]


@dataclass(frozen=True)
class HeroEligibilityAssessment:
    public_benefit_magnitude: float
    seriousness_of_loss: float
    contribution_connection: float
    durability_stewardship: float
    rights_alignment: float
    accessibility_reviewability: float
    public_benefit_gate: bool
    evidence_gate: bool
    rights_gate: bool
    review_gate: bool
    candidate_activity_state: Literal["active", "at_rest"]


@dataclass(frozen=True)
class HeroEligibilityResult:
    score: float
    recommended_title_state: TitleState
    gates_passed: bool
    failed_gates: tuple[str, ...]
    component_scores: dict[str, float]
    reason: str


def clamp_unit(value: float) -> float:
    return max(0.0, min(1.0, float(value)))


def calculate_hero_eligibility(
    assessment: HeroEligibilityAssessment,
    recognition_recorded: bool = False,
    human_override: TitleState | None = None,
) -> HeroEligibilityResult:
    components = {
        "public_benefit_magnitude": clamp_unit(assessment.public_benefit_magnitude),
        "seriousness_of_loss": clamp_unit(assessment.seriousness_of_loss),
        "contribution_connection": clamp_unit(assessment.contribution_connection),
        "durability_stewardship": clamp_unit(assessment.durability_stewardship),
        "rights_alignment": clamp_unit(assessment.rights_alignment),
        "accessibility_reviewability": clamp_unit(assessment.accessibility_reviewability),
    }

    score = (
        0.24 * components["public_benefit_magnitude"]
        + 0.20 * components["seriousness_of_loss"]
        + 0.18 * components["contribution_connection"]
        + 0.14 * components["durability_stewardship"]
        + 0.12 * components["rights_alignment"]
        + 0.12 * components["accessibility_reviewability"]
    )

    gates = {
        "public_benefit": assessment.public_benefit_gate,
        "evidence": assessment.evidence_gate,
        "rights": assessment.rights_gate,
        "review": assessment.review_gate,
    }
    failed_gates = tuple(name for name, passed in gates.items() if not passed)
    gates_passed = not failed_gates

    if human_override is not None:
        if human_override not in {"candidate", "hero-active", "hero-at-rest"}:
            raise ValueError("human_override must be a supported title state")
        return HeroEligibilityResult(
            score=round(score, 6),
            recommended_title_state=human_override,
            gates_passed=gates_passed,
            failed_gates=failed_gates,
            component_scores=components,
            reason="Human institutional override recorded; audit reason and appeal path are required.",
        )

    if not gates_passed:
        state: TitleState = "candidate"
        reason = "One or more required eligibility gates did not pass."
    elif score < 0.75:
        state = "candidate"
        reason = "Eligibility score is below the institutional hero recommendation threshold."
    elif not recognition_recorded:
        state = "candidate"
        reason = "Eligibility threshold passed; human institutional recognition remains pending."
    elif assessment.candidate_activity_state == "at_rest":
        state = "hero-at-rest"
        reason = "Eligibility threshold and review gates passed; recognized recipient is at rest."
    else:
        state = "hero-active"
        reason = "Eligibility threshold and review gates passed; recognized recipient is active."

    return HeroEligibilityResult(
        score=round(score, 6),
        recommended_title_state=state,
        gates_passed=gates_passed,
        failed_gates=failed_gates,
        component_scores=components,
        reason=reason,
    )
