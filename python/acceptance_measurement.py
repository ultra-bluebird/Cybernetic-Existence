from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from math import isfinite
from typing import Iterable, Optional


class ResponseState(str, Enum):
    ANSWERED = "answered"
    PREFER_NOT_TO_ANSWER = "prefer_not_to_answer"
    MISSING = "missing"


@dataclass(frozen=True)
class LikertResponse:
    value: Optional[int]
    state: ResponseState

    def validate(self) -> None:
        if self.state is ResponseState.ANSWERED:
            if self.value is None or not 1 <= self.value <= 7:
                raise ValueError("answered Likert responses must have an integer value from 1 to 7")
        elif self.value is not None:
            raise ValueError("non-answered Likert responses must not carry a score")


@dataclass(frozen=True)
class AcceptanceResponses:
    cognitive_understanding: LikertResponse
    emotional_comfort: LikertResponse
    behavioral_integration: LikertResponse
    institutional_trust: LikertResponse


@dataclass(frozen=True)
class AcceptanceAssessment:
    reportable: bool
    acceptance_score: Optional[float]
    answered_domain_count: int
    missing_or_withheld_domain_count: int
    reasons: tuple[str, ...]


WEIGHTS = {
    "cognitive_understanding": 0.25,
    "emotional_comfort": 0.30,
    "behavioral_integration": 0.25,
    "institutional_trust": 0.20,
}


def normalize_likert(value: int) -> float:
    return (value - 1) / 6


def assess_acceptance(responses: AcceptanceResponses) -> AcceptanceAssessment:
    fields = {
        "cognitive_understanding": responses.cognitive_understanding,
        "emotional_comfort": responses.emotional_comfort,
        "behavioral_integration": responses.behavioral_integration,
        "institutional_trust": responses.institutional_trust,
    }

    for response in fields.values():
        response.validate()

    answered = {
        name: response.value
        for name, response in fields.items()
        if response.state is ResponseState.ANSWERED and response.value is not None
    }

    withheld_count = len(fields) - len(answered)

    if len(answered) != len(fields):
        return AcceptanceAssessment(
            reportable=False,
            acceptance_score=None,
            answered_domain_count=len(answered),
            missing_or_withheld_domain_count=withheld_count,
            reasons=(
                "individual composite score withheld because one or more domains "
                "were skipped or marked prefer_not_to_answer",
            ),
        )

    score = sum(
        WEIGHTS[name] * normalize_likert(value)
        for name, value in answered.items()
    )

    if not isfinite(score):
        raise ValueError("computed score must be finite")

    return AcceptanceAssessment(
        reportable=True,
        acceptance_score=score,
        answered_domain_count=len(answered),
        missing_or_withheld_domain_count=0,
        reasons=(
            "research-only composite; not suitable for identity, eligibility, "
            "employment, service, accommodation, credibility, or ranking decisions",
        ),
    )


def aggregate_reportable_scores(
    assessments: Iterable[AcceptanceAssessment],
    minimum_group_size: int = 50,
) -> dict[str, float | int | bool]:
    scores = [
        assessment.acceptance_score
        for assessment in assessments
        if assessment.reportable and assessment.acceptance_score is not None
    ]

    if minimum_group_size < 1:
        raise ValueError("minimum_group_size must be at least one")

    if len(scores) < minimum_group_size:
        return {
            "reportable": False,
            "group_size": len(scores),
            "reason": "minimum_group_size_not_met",
        }

    return {
        "reportable": True,
        "group_size": len(scores),
        "mean_normalized_acceptance_score": sum(scores) / len(scores),
        "minimum_group_size": minimum_group_size,
    }


if __name__ == "__main__":
    answered = LikertResponse(value=6, state=ResponseState.ANSWERED)

    assessment = assess_acceptance(
        AcceptanceResponses(
            cognitive_understanding=answered,
            emotional_comfort=LikertResponse(
                value=5,
                state=ResponseState.ANSWERED,
            ),
            behavioral_integration=LikertResponse(
                value=6,
                state=ResponseState.ANSWERED,
            ),
            institutional_trust=LikertResponse(
                value=4,
                state=ResponseState.ANSWERED,
            ),
        )
    )

    print(
        {
            "reportable": assessment.reportable,
            "acceptance_score": assessment.acceptance_score,
            "interpretation": "research_only_group_aggregation_required",
        }
    )
