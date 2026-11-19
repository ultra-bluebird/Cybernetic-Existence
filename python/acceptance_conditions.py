from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from math import isclose, isfinite, sqrt
from typing import Iterable


LIKERT_MINIMUM = 1
LIKERT_MAXIMUM = 7
DEFAULT_MINIMUM_GROUP_SIZE = 50
NORMAL_CONFIDENCE_Z_95 = 1.96


class ResponseState(str, Enum):
    ANSWERED = "answered"
    PREFER_NOT_TO_ANSWER = "prefer_not_to_answer"
    MISSING = "missing"


@dataclass(frozen=True)
class LikertResponse:
    value: int | None
    state: ResponseState

    def validate(self) -> None:
        if self.state is ResponseState.ANSWERED:
            if self.value is None:
                raise ValueError(
                    "answered Likert responses must include a value."
                )
            if not isinstance(self.value, int) or isinstance(self.value, bool):
                raise ValueError(
                    "answered Likert response values must be integers."
                )
            if not LIKERT_MINIMUM <= self.value <= LIKERT_MAXIMUM:
                raise ValueError(
                    f"answered Likert response values must be within "
                    f"[{LIKERT_MINIMUM}, {LIKERT_MAXIMUM}]."
                )
            return

        if self.value is not None:
            raise ValueError(
                "missing or withheld Likert responses must not include a value."
            )


@dataclass(frozen=True)
class AcceptanceResponses:
    cognitive_understanding: LikertResponse
    emotional_comfort: LikertResponse
    behavioral_integration: LikertResponse
    institutional_trust: LikertResponse


@dataclass(frozen=True)
class AcceptanceWeights:
    cognitive_understanding: float = 0.25
    emotional_comfort: float = 0.30
    behavioral_integration: float = 0.25
    institutional_trust: float = 0.20


@dataclass(frozen=True)
class AcceptanceAssessment:
    reportable: bool
    acceptance_score: float | None
    answered_domain_count: int
    missing_or_withheld_domain_count: int
    reasons: tuple[str, ...]


@dataclass(frozen=True)
class SourceEstimate:
    normalized_value: float
    coverage: float
    provenance: float
    timeliness: float
    method_validity: float
    standard_error: float


@dataclass(frozen=True)
class ChacsWeights:
    public_discourse: float
    news_tone: float
    institutional_response: float
    complaint_burden: float
    uncertainty_penalty: float


@dataclass(frozen=True)
class ChacsResult:
    score: float | None
    lower_bound: float | None
    upper_bound: float | None
    evidence_quality: float
    propagated_standard_error: float
    suppressed: bool
    reason: str


@dataclass(frozen=True)
class AggregateAcceptanceReport:
    reportable: bool
    group_size: int
    mean_normalized_acceptance_score: float | None
    minimum_group_size: int
    reason: str


def normalize_likert(value: int) -> float:
    if not isinstance(value, int) or isinstance(value, bool):
        raise ValueError("Likert values must be integers.")
    if not LIKERT_MINIMUM <= value <= LIKERT_MAXIMUM:
        raise ValueError(
            f"Likert values must be within [{LIKERT_MINIMUM}, {LIKERT_MAXIMUM}]."
        )
    return (value - LIKERT_MINIMUM) / (LIKERT_MAXIMUM - LIKERT_MINIMUM)


def assess_acceptance(
    responses: AcceptanceResponses,
    weights: AcceptanceWeights = AcceptanceWeights(),
) -> AcceptanceAssessment:
    _validate_acceptance_weights(weights)

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

    if withheld_count > 0:
        return AcceptanceAssessment(
            reportable=False,
            acceptance_score=None,
            answered_domain_count=len(answered),
            missing_or_withheld_domain_count=withheld_count,
            reasons=(
                "Composite score withheld because one or more domains were "
                "missing or marked prefer_not_to_answer.",
                "No imputation is performed by this local assessment function.",
            ),
        )

    score = (
        weights.cognitive_understanding
        * normalize_likert(answered["cognitive_understanding"])
        + weights.emotional_comfort
        * normalize_likert(answered["emotional_comfort"])
        + weights.behavioral_integration
        * normalize_likert(answered["behavioral_integration"])
        + weights.institutional_trust
        * normalize_likert(answered["institutional_trust"])
    )

    if not isfinite(score):
        raise ValueError("Computed acceptance score must be finite.")

    return AcceptanceAssessment(
        reportable=True,
        acceptance_score=_clip(score, 0.0, 1.0),
        answered_domain_count=len(answered),
        missing_or_withheld_domain_count=0,
        reasons=(
            "Research-only composite for aggregate inclusion-climate analysis.",
            "Not for identity inference, public status, CyberRank, eligibility, "
            "employment, service access, accommodation decisions, credibility "
            "assessment, enforcement, or individual ranking.",
        ),
    )


def aggregate_reportable_scores(
    assessments: Iterable[AcceptanceAssessment],
    minimum_group_size: int = DEFAULT_MINIMUM_GROUP_SIZE,
) -> AggregateAcceptanceReport:
    if minimum_group_size < 1:
        raise ValueError("minimum_group_size must be at least 1.")

    scores = [
        assessment.acceptance_score
        for assessment in assessments
        if assessment.reportable and assessment.acceptance_score is not None
    ]

    if len(scores) < minimum_group_size:
        return AggregateAcceptanceReport(
            reportable=False,
            group_size=len(scores),
            mean_normalized_acceptance_score=None,
            minimum_group_size=minimum_group_size,
            reason="minimum_group_size_not_met",
        )

    mean_score = sum(scores) / len(scores)

    return AggregateAcceptanceReport(
        reportable=True,
        group_size=len(scores),
        mean_normalized_acceptance_score=_clip(mean_score, 0.0, 1.0),
        minimum_group_size=minimum_group_size,
        reason=(
            "Aggregate research result only; interpretation requires "
            "preregistered methods and accessible human review."
        ),
    )


def calculate_chacs(
    public_discourse: SourceEstimate,
    news_tone: SourceEstimate,
    institutional_response: SourceEstimate,
    complaint_burden: SourceEstimate,
    weights: ChacsWeights,
    minimum_evidence_quality: float,
    maximum_standard_error: float,
) -> ChacsResult:
    _validate_chacs_weights(weights)
    _validate_source_estimate(public_discourse, "public_discourse")
    _validate_source_estimate(news_tone, "news_tone")
    _validate_source_estimate(institutional_response, "institutional_response")
    _validate_source_estimate(complaint_burden, "complaint_burden")

    if not isfinite(minimum_evidence_quality) or not 0.0 <= minimum_evidence_quality <= 1.0:
        raise ValueError(
            "minimum_evidence_quality must be finite and within [0, 1]."
        )

    if not isfinite(maximum_standard_error) or maximum_standard_error < 0.0:
        raise ValueError(
            "maximum_standard_error must be finite and non-negative."
        )

    evidence_quality = min(
        _evidence_quality(public_discourse),
        _evidence_quality(news_tone),
        _evidence_quality(institutional_response),
        _evidence_quality(complaint_burden),
    )

    propagated_standard_error = sqrt(
        (weights.public_discourse * public_discourse.standard_error) ** 2
        + (weights.news_tone * news_tone.standard_error) ** 2
        + (
            weights.institutional_response
            * institutional_response.standard_error
        ) ** 2
        + (weights.complaint_burden * complaint_burden.standard_error) ** 2
    )

    if evidence_quality < minimum_evidence_quality:
        return ChacsResult(
            score=None,
            lower_bound=None,
            upper_bound=None,
            evidence_quality=evidence_quality,
            propagated_standard_error=propagated_standard_error,
            suppressed=True,
            reason=(
                "Aggregate conditions score suppressed because evidence-quality "
                "requirements are not met."
            ),
        )

    if propagated_standard_error > maximum_standard_error:
        return ChacsResult(
            score=None,
            lower_bound=None,
            upper_bound=None,
            evidence_quality=evidence_quality,
            propagated_standard_error=propagated_standard_error,
            suppressed=True,
            reason=(
                "Aggregate conditions score suppressed because propagated "
                "uncertainty exceeds the publication threshold."
            ),
        )

    raw_score = (
        weights.public_discourse * public_discourse.normalized_value
        + weights.news_tone * news_tone.normalized_value
        + weights.institutional_response
        * institutional_response.normalized_value
        - weights.complaint_burden * complaint_burden.normalized_value
        - weights.uncertainty_penalty * propagated_standard_error
    )

    score = 100.0 * _clip(raw_score, 0.0, 1.0) * evidence_quality
    interval_half_width = (
        NORMAL_CONFIDENCE_Z_95 * propagated_standard_error * 100.0
    )

    return ChacsResult(
        score=score,
        lower_bound=max(0.0, score - interval_half_width),
        upper_bound=min(100.0, score + interval_half_width),
        evidence_quality=evidence_quality,
        propagated_standard_error=propagated_standard_error,
        suppressed=False,
        reason=(
            "Aggregate conditions score calculated from declared input quality "
            "and uncertainty. It is not valid for individual classification, "
            "service eligibility, enforcement, neighborhood ranking, or "
            "identity-related decisions."
        ),
    )


def _evidence_quality(source: SourceEstimate) -> float:
    return (
        source.coverage
        * source.provenance
        * source.timeliness
        * source.method_validity
    )


def _validate_source_estimate(source: SourceEstimate, name: str) -> None:
    values = {
        "normalized_value": source.normalized_value,
        "coverage": source.coverage,
        "provenance": source.provenance,
        "timeliness": source.timeliness,
        "method_validity": source.method_validity,
        "standard_error": source.standard_error,
    }

    for field_name, value in values.items():
        if not isfinite(value):
            raise ValueError(f"{name}.{field_name} must be finite.")

    if not 0.0 <= source.normalized_value <= 1.0:
        raise ValueError(f"{name}.normalized_value must be within [0, 1].")

    for field_name, value in {
        "coverage": source.coverage,
        "provenance": source.provenance,
        "timeliness": source.timeliness,
        "method_validity": source.method_validity,
    }.items():
        if not 0.0 <= value <= 1.0:
            raise ValueError(f"{name}.{field_name} must be within [0, 1].")

    if source.standard_error < 0.0:
        raise ValueError(f"{name}.standard_error must be non-negative.")


def _validate_acceptance_weights(weights: AcceptanceWeights) -> None:
    values = (
        weights.cognitive_understanding,
        weights.emotional_comfort,
        weights.behavioral_integration,
        weights.institutional_trust,
    )

    if any(not isfinite(value) or value < 0.0 for value in values):
        raise ValueError(
            "AcceptanceScore weights must be finite and non-negative."
        )

    if not isclose(sum(values), 1.0, rel_tol=1e-9, abs_tol=1e-9):
        raise ValueError("AcceptanceScore weights must sum to 1.0.")


def _validate_chacs_weights(weights: ChacsWeights) -> None:
    values = (
        weights.public_discourse,
        weights.news_tone,
        weights.institutional_response,
        weights.complaint_burden,
        weights.uncertainty_penalty,
    )

    if any(not isfinite(value) or value < 0.0 for value in values):
        raise ValueError("CHACS weights must be finite and non-negative.")

    if not isclose(sum(values), 1.0, rel_tol=1e-9, abs_tol=1e-9):
        raise ValueError("CHACS weights must sum to 1.0.")


def _clip(value: float, lower: float, upper: float) -> float:
    return max(lower, min(value, upper))


if __name__ == "__main__":
    acceptance = assess_acceptance(
        AcceptanceResponses(
            cognitive_understanding=LikertResponse(
                value=6,
                state=ResponseState.ANSWERED,
            ),
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

    source = SourceEstimate(
        normalized_value=0.70,
        coverage=0.90,
        provenance=0.90,
        timeliness=0.85,
        method_validity=0.90,
        standard_error=0.02,
    )

    chacs = calculate_chacs(
        public_discourse=source,
        news_tone=source,
        institutional_response=source,
        complaint_burden=SourceEstimate(
            normalized_value=0.20,
            coverage=0.90,
            provenance=0.90,
            timeliness=0.85,
            method_validity=0.90,
            standard_error=0.02,
        ),
        weights=ChacsWeights(
            public_discourse=0.25,
            news_tone=0.20,
            institutional_response=0.25,
            complaint_burden=0.20,
            uncertainty_penalty=0.10,
        ),
        minimum_evidence_quality=0.50,
        maximum_standard_error=0.10,
    )

    print(
        {
            "acceptance_reportable": acceptance.reportable,
            "acceptance_score": acceptance.acceptance_score,
            "chacs_suppressed": chacs.suppressed,
            "chacs_score": chacs.score,
            "chacs_lower_bound": chacs.lower_bound,
            "chacs_upper_bound": chacs.upper_bound,
            "output_scope": "aggregate_research_and_human_review_only",
        }
    )
