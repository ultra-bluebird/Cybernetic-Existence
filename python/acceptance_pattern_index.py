from __future__ import annotations

from dataclasses import dataclass
from math import exp, log
from typing import Iterable


@dataclass(frozen=True)
class DiscourseDocument:
    representation_cell: str
    source_category: str
    sentiment_polarity: float
    rights_framing_score: float
    stigmatizing_language_present: bool
    topic_relevance_confidence: float
    source_weight: float = 1.0


@dataclass(frozen=True)
class AcceptancePatternResult:
    index: float
    sentiment_rights_score: float
    volume_confidence: float
    source_diversity: float
    coverage_completeness: float
    representation_bias_penalty: float
    data_quality_confidence: float


def clamp_unit(value: float) -> float:
    return max(0.0, min(1.0, float(value)))


def document_acceptance_score(document: DiscourseDocument) -> float:
    polarity = max(-1.0, min(1.0, float(document.sentiment_polarity)))
    normalized_polarity = (polarity + 1.0) / 2.0
    stigma_penalty = 1.0 if document.stigmatizing_language_present else 0.0

    return clamp_unit(
        0.55 * normalized_polarity
        + 0.35 * clamp_unit(document.rights_framing_score)
        - 0.25 * stigma_penalty
    )


def weighted_mean(values_and_weights: Iterable[tuple[float, float]]) -> float:
    numerator = 0.0
    denominator = 0.0

    for value, weight in values_and_weights:
        bounded_weight = max(0.0, float(weight))
        numerator += clamp_unit(value) * bounded_weight
        denominator += bounded_weight

    return numerator / denominator if denominator > 0.0 else 0.0


def calculate_acceptance_pattern_index(
    documents: list[DiscourseDocument],
    representation_targets: dict[str, int],
    reference_document_count: int,
    minimum_documents_per_cell: int,
    data_quality_confidence: float,
    maximum_representation_weight: float = 4.0,
) -> AcceptancePatternResult:
    if reference_document_count <= 0:
        raise ValueError("reference_document_count must be positive")
    if minimum_documents_per_cell <= 0:
        raise ValueError("minimum_documents_per_cell must be positive")
    if maximum_representation_weight < 1.0:
        raise ValueError("maximum_representation_weight must be at least one")

    cells = set(representation_targets)
    counts = {cell: 0 for cell in cells}
    by_cell: dict[str, list[DiscourseDocument]] = {cell: [] for cell in cells}

    for document in documents:
        if document.representation_cell not in cells:
            continue
        counts[document.representation_cell] += 1
        by_cell[document.representation_cell].append(document)

    representation_weights = {
        cell: min(
            maximum_representation_weight,
            representation_targets[cell] / max(counts[cell], 1),
        )
        for cell in cells
    }

    weighted_documents = []
    for document in documents:
        if document.representation_cell not in cells:
            continue
        weight = (
            max(0.0, document.source_weight)
            * representation_weights[document.representation_cell]
            * clamp_unit(document.topic_relevance_confidence)
        )
        weighted_documents.append((document_acceptance_score(document), weight))

    sentiment_rights_score = weighted_mean(weighted_documents)
    volume_confidence = 1.0 - exp(-len(documents) / reference_document_count)

    category_counts: dict[str, int] = {}
    for document in documents:
        category_counts[document.source_category] = (
            category_counts.get(document.source_category, 0) + 1
        )

    total_documents = sum(category_counts.values())
    if total_documents <= 1 or len(category_counts) <= 1:
        source_diversity = 0.0
    else:
        entropy = -sum(
            (count / total_documents) * log(count / total_documents)
            for count in category_counts.values()
            if count > 0
        )
        source_diversity = entropy / log(len(category_counts))

    cell_scores: dict[str, float] = {}
    for cell in cells:
        cell_scores[cell] = weighted_mean(
            (
                document_acceptance_score(document),
                max(0.0, document.source_weight)
                * clamp_unit(document.topic_relevance_confidence),
            )
            for document in by_cell[cell]
        )

    representation_bias_penalty = (
        max(abs(cell_scores[cell] - sentiment_rights_score) for cell in cells)
        if cells
        else 0.0
    )

    coverage_completeness = (
        sum(counts[cell] >= minimum_documents_per_cell for cell in cells) / len(cells)
        if cells
        else 0.0
    )

    index = clamp_unit(data_quality_confidence) * clamp_unit(
        0.55 * sentiment_rights_score
        + 0.15 * volume_confidence
        + 0.20 * source_diversity
        + 0.10 * coverage_completeness
        - 0.20 * representation_bias_penalty
    )

    return AcceptancePatternResult(
        index=round(index, 6),
        sentiment_rights_score=round(sentiment_rights_score, 6),
        volume_confidence=round(volume_confidence, 6),
        source_diversity=round(source_diversity, 6),
        coverage_completeness=round(coverage_completeness, 6),
        representation_bias_penalty=round(representation_bias_penalty, 6),
        data_quality_confidence=round(clamp_unit(data_quality_confidence), 6),
    )
