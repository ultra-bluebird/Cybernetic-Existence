from __future__ import annotations

from dataclasses import dataclass
import math


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
    suppressed: bool
    reason: str


def calculate_chacs(
    public_discourse: SourceEstimate,
    news_tone: SourceEstimate,
    institutional_response: SourceEstimate,
    complaint_burden: SourceEstimate,
    weights: ChacsWeights,
    minimum_evidence_quality: float,
    maximum_standard_error: float,
) -> ChacsResult:
    _validate_weights(weights)
    _validate_source_estimate(public_discourse, "public_discourse")
    _validate_source_estimate(news_tone, "news_tone")
    _validate_source_estimate(institutional_response, "institutional_response")
    _validate_source_estimate(complaint_burden, "complaint_burden")

    if not 0.0 <= minimum_evidence_quality <= 1.0:
        raise ValueError("minimum_evidence_quality must be within [0, 1].")
    if maximum_standard_error < 0.0 or not math.isfinite(maximum_standard_error):
        raise ValueError("maximum_standard_error must be finite and non-negative.")

    evidence_quality = min(
        _evidence_quality(public_discourse),
        _evidence_quality(news_tone),
        _evidence_quality(institutional_response),
        _evidence_quality(complaint_burden),
    )

    propagated_standard_error = math.sqrt(
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
            suppressed=True,
            reason=(
                "District score suppressed because evidence-quality requirements "
                "for coverage, provenance, timeliness, or method validity are not met."
            ),
        )

    if propagated_standard_error > maximum_standard_error:
        return ChacsResult(
            score=None,
            lower_bound=None,
            upper_bound=None,
            evidence_quality=evidence_quality,
            suppressed=True,
            reason=(
                "District score suppressed because uncertainty exceeds the "
                "configured publication threshold."
            ),
        )

    raw_score = (
        weights.public_discourse * public_discourse.normalized_value
        + weights.news_tone * news_tone.normalized_value
        + weights.institutional_response * institutional_response.normalized_value
        - weights.complaint_burden * complaint_burden.normalized_value
        - weights.uncertainty_penalty * propagated_standard_error
    )

    score = 100.0 * _clip(raw_score, 0.0, 1.0) * evidence_quality
    interval_half_width = 1.96 * propagated_standard_error * 100.0

    return ChacsResult(
        score=score,
        lower_bound=max(0.0, score - interval_half_width),
        upper_bound=min(100.0, score + interval_half_width),
        evidence_quality=evidence_quality,
        suppressed=False,
        reason=(
            "Aggregate acceptance-conditions score calculated with declared "
            "evidence quality and uncertainty. It must not be used for "
            "individual classification, service eligibility, or enforcement."
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
    for field_name, value in {
        "normalized_value": source.normalized_value,
        "coverage": source.coverage,
        "provenance": source.provenance,
        "timeliness": source.timeliness,
        "method_validity": source.method_validity,
        "standard_error": source.standard_error,
    }.items():
        if not math.isfinite(value):
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


def _validate_weights(weights: ChacsWeights) -> None:
    values = (
        weights.public_discourse,
        weights.news_tone,
        weights.institutional_response,
        weights.complaint_burden,
        weights.uncertainty_penalty,
    )

    if any(not math.isfinite(value) or value < 0.0 for value in values):
        raise ValueError("All weights must be finite and non-negative.")

    if not math.isclose(sum(values), 1.0, rel_tol=1e-9, abs_tol=1e-9):
        raise ValueError("CHACS weights must sum to 1.0.")


def _clip(value: float, lower: float, upper: float) -> float:
    return max(lower, min(value, upper))
