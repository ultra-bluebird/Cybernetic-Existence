from __future__ import annotations

from dataclasses import asdict, dataclass
from enum import StrEnum
from math import exp, log
from typing import Sequence


class GraphEdgeMode(StrEnum):
    SPATIAL_CORRELATION = "spatial-correlation"
    FEATURE_SIMILARITY = "feature-similarity"
    HYBRID = "hybrid"


class TopologyDisposition(StrEnum):
    STABLE = "stable"
    MONITOR = "monitor"
    INVESTIGATE = "investigate"
    INSUFFICIENT_EVIDENCE = "insufficient-evidence"


class LatentDisposition(StrEnum):
    ACCEPTED_FOR_RESEARCH = "accepted-for-research"
    RETAIN_WITH_LIMITATIONS = "retain-with-limitations"
    REQUIRES_MODEL_REVIEW = "requires-model-review"


@dataclass(frozen=True)
class InstitutionalReference:
    reference_id: str
    record_class: str
    permitted_research_use: str
    value_handling: str = "institutionally-controlled"


@dataclass(frozen=True)
class ChannelSummary:
    channel_id: str
    normalized_feature: float
    spatial_x: float | None = None
    spatial_y: float | None = None
    spatial_z: float | None = None

    def validate(self) -> None:
        if not 0.0 <= self.normalized_feature <= 1.0:
            raise ValueError("normalized_feature must be within [0, 1]")
        coordinates = (self.spatial_x, self.spatial_y, self.spatial_z)
        if any(value is not None and not isinstance(value, (int, float)) for value in coordinates):
            raise ValueError("spatial coordinates must be numeric or None")


@dataclass(frozen=True)
class GraphSnapshot:
    snapshot_id: str
    elapsed_window: int
    institutional_reference: InstitutionalReference
    channels: tuple[ChannelSummary, ...]
    edge_mode: GraphEdgeMode
    adjacency: tuple[tuple[float, ...], ...]

    def validate(self) -> None:
        if self.elapsed_window < 0:
            raise ValueError("elapsed_window must be non-negative")
        if len(self.channels) == 0:
            raise ValueError("at least one channel summary is required")
        if len(self.adjacency) != len(self.channels):
            raise ValueError("adjacency rows must equal channel count")
        for channel in self.channels:
            channel.validate()
        for row in self.adjacency:
            if len(row) != len(self.channels):
                raise ValueError("adjacency matrix must be square")
            for weight in row:
                if not 0.0 <= weight <= 1.0:
                    raise ValueError("adjacency weights must be within [0, 1]")


@dataclass(frozen=True)
class TopologyThresholds:
    edge_change_attention: float = 0.10
    edge_change_investigate: float = 0.25
    node_feature_attention: float = 0.10
    node_feature_investigate: float = 0.25


@dataclass(frozen=True)
class TopologyChangeAssessment:
    baseline_snapshot_id: str
    current_snapshot_id: str
    edge_change_fraction: float
    mean_feature_shift: float
    disposition: TopologyDisposition


@dataclass(frozen=True)
class FluxReconstructionSpec:
    model_id: str
    forward_operator_reference: InstitutionalReference
    measurement_reference: InstitutionalReference
    regularization_strength: float
    non_negative_constraint: bool
    uncertainty_method: str

    def validate(self) -> None:
        if self.regularization_strength < 0.0:
            raise ValueError("regularization_strength must be non-negative")
        if not self.uncertainty_method.strip():
            raise ValueError("uncertainty_method is required")


@dataclass(frozen=True)
class LatentSequenceObservation:
    sequence_id: str
    elapsed_step: int
    observed_feature_vector: tuple[float, ...]
    context_vector: tuple[float, ...]

    def validate(self) -> None:
        if self.elapsed_step < 0:
            raise ValueError("elapsed_step must be non-negative")
        if len(self.observed_feature_vector) == 0:
            raise ValueError("observed feature vector must not be empty")
        if any(not 0.0 <= value <= 1.0 for value in self.observed_feature_vector):
            raise ValueError("observed features must be normalized to [0, 1]")
        if any(not -1.0 <= value <= 1.0 for value in self.context_vector):
            raise ValueError("context values must be normalized to [-1, 1]")


@dataclass(frozen=True)
class LatentModelSpecification:
    model_id: str
    data_reference: InstitutionalReference
    latent_dimension: int
    observed_dimension: int
    context_dimension: int
    likelihood_family: str
    regularization_policy: str
    drift_controls: tuple[str, ...]
    intent_label_policy: str

    def validate(self) -> None:
        if self.latent_dimension <= 0:
            raise ValueError("latent_dimension must be positive")
        if self.observed_dimension <= 0:
            raise ValueError("observed_dimension must be positive")
        if self.context_dimension < 0:
            raise ValueError("context_dimension must be non-negative")
        if not self.likelihood_family.strip():
            raise ValueError("likelihood_family is required")
        if not self.regularization_policy.strip():
            raise ValueError("regularization_policy is required")
        if not self.intent_label_policy.strip():
            raise ValueError("intent_label_policy is required")


@dataclass(frozen=True)
class LatentEvaluation:
    reconstruction_quality: float
    held_out_prediction_quality: float
    intent_task_quality: float
    drift_sensitivity: float
    uncertainty_coverage: float

    def validate(self) -> None:
        values = (
            self.reconstruction_quality,
            self.held_out_prediction_quality,
            self.intent_task_quality,
            self.drift_sensitivity,
            self.uncertainty_coverage,
        )
        if any(not 0.0 <= value <= 1.0 for value in values):
            raise ValueError("latent evaluation metrics must be normalized to [0, 1]")


@dataclass(frozen=True)
class LatentEvaluationResult:
    composite_quality: float
    disposition: LatentDisposition


def mean_absolute_feature_shift(
    baseline: GraphSnapshot,
    current: GraphSnapshot,
) -> float:
    baseline.validate()
    current.validate()

    baseline_features = {channel.channel_id: channel.normalized_feature for channel in baseline.channels}
    current_features = {channel.channel_id: channel.normalized_feature for channel in current.channels}
    shared_ids = sorted(set(baseline_features).intersection(current_features))

    if not shared_ids:
        raise ValueError("snapshots must contain at least one shared channel identifier")

    return sum(
        abs(baseline_features[channel_id] - current_features[channel_id])
        for channel_id in shared_ids
    ) / len(shared_ids)


def edge_change_fraction(
    baseline: GraphSnapshot,
    current: GraphSnapshot,
    change_epsilon: float = 0.10,
) -> float:
    baseline.validate()
    current.validate()

    if len(baseline.channels) != len(current.channels):
        raise ValueError("topology comparison requires equal channel counts")
    if change_epsilon < 0.0:
        raise ValueError("change_epsilon must be non-negative")

    changed = 0
    total = 0
    for baseline_row, current_row in zip(baseline.adjacency, current.adjacency, strict=True):
        for baseline_weight, current_weight in zip(baseline_row, current_row, strict=True):
            if baseline_weight == 0.0 and current_weight == 0.0:
                continue
            total += 1
            if abs(baseline_weight - current_weight) >= change_epsilon:
                changed += 1

    return 0.0 if total == 0 else changed / total


def assess_topology_change(
    baseline: GraphSnapshot,
    current: GraphSnapshot,
    thresholds: TopologyThresholds = TopologyThresholds(),
) -> TopologyChangeAssessment:
    edge_shift = edge_change_fraction(baseline, current)
    feature_shift = mean_absolute_feature_shift(baseline, current)

    if (
        edge_shift >= thresholds.edge_change_investigate
        or feature_shift >= thresholds.node_feature_investigate
    ):
        disposition = TopologyDisposition.INVESTIGATE
    elif (
        edge_shift >= thresholds.edge_change_attention
        or feature_shift >= thresholds.node_feature_attention
    ):
        disposition = TopologyDisposition.MONITOR
    else:
        disposition = TopologyDisposition.STABLE

    return TopologyChangeAssessment(
        baseline_snapshot_id=baseline.snapshot_id,
        current_snapshot_id=current.snapshot_id,
        edge_change_fraction=edge_shift,
        mean_feature_shift=feature_shift,
        disposition=disposition,
    )


def topology_regularization_loss(
    adjacency_t: Sequence[Sequence[float]],
    adjacency_previous: Sequence[Sequence[float]],
) -> float:
    if len(adjacency_t) != len(adjacency_previous):
        raise ValueError("adjacency matrices must have equal dimensions")

    total = 0.0
    count = 0
    for current_row, previous_row in zip(adjacency_t, adjacency_previous, strict=True):
        if len(current_row) != len(previous_row):
            raise ValueError("adjacency matrices must have equal dimensions")
        for current_value, previous_value in zip(current_row, previous_row, strict=True):
            total += (current_value - previous_value) ** 2
            count += 1

    return 0.0 if count == 0 else total / count


def ridge_inverse_reconstruction(
    forward_operator: Sequence[Sequence[float]],
    measurements: Sequence[float],
    regularization_strength: float,
) -> tuple[float, ...]:
    if regularization_strength < 0.0:
        raise ValueError("regularization_strength must be non-negative")
    if len(forward_operator) == 0 or len(measurements) == 0:
        raise ValueError("forward operator and measurement vector are required")
    if len(forward_operator) != len(measurements):
        raise ValueError("measurement count must equal forward operator row count")

    source_dimension = len(forward_operator[0])
    if source_dimension == 0 or any(len(row) != source_dimension for row in forward_operator):
        raise ValueError("forward operator must be a non-empty rectangular matrix")

    gram = [[0.0 for _ in range(source_dimension)] for _ in range(source_dimension)]
    rhs = [0.0 for _ in range(source_dimension)]

    for row, measurement in zip(forward_operator, measurements, strict=True):
        for i in range(source_dimension):
            rhs[i] += row[i] * measurement
            for j in range(source_dimension):
                gram[i][j] += row[i] * row[j]

    for i in range(source_dimension):
        gram[i][i] += regularization_strength

    return tuple(_solve_linear_system(gram, rhs))


def evaluate_latent_model(
    evaluation: LatentEvaluation,
    minimum_reconstruction: float = 0.57,
    minimum_held_out: float = 0.57,
    minimum_intent: float = 0.57,
    maximum_drift_sensitivity: float = 0.43,
    minimum_uncertainty_coverage: float = 0.57,
) -> LatentEvaluationResult:
    evaluation.validate()
    thresholds = (
        minimum_reconstruction,
        minimum_held_out,
        minimum_intent,
        maximum_drift_sensitivity,
        minimum_uncertainty_coverage,
    )
    if any(not 0.0 <= value <= 1.0 for value in thresholds):
        raise ValueError("evaluation thresholds must be normalized to [0, 1]")

    composite_quality = (
        0.20 * evaluation.reconstruction_quality
        + 0.25 * evaluation.held_out_prediction_quality
        + 0.30 * evaluation.intent_task_quality
        + 0.15 * (1.0 - evaluation.drift_sensitivity)
        + 0.10 * evaluation.uncertainty_coverage
    )

    accepted = (
        evaluation.reconstruction_quality >= minimum_reconstruction
        and evaluation.held_out_prediction_quality >= minimum_held_out
        and evaluation.intent_task_quality >= minimum_intent
        and evaluation.drift_sensitivity <= maximum_drift_sensitivity
        and evaluation.uncertainty_coverage >= minimum_uncertainty_coverage
    )

    if accepted:
        disposition = LatentDisposition.ACCEPTED_FOR_RESEARCH
    elif composite_quality >= 0.50:
        disposition = LatentDisposition.RETAIN_WITH_LIMITATIONS
    else:
        disposition = LatentDisposition.REQUIRES_MODEL_REVIEW

    return LatentEvaluationResult(
        composite_quality=composite_quality,
        disposition=disposition,
    )


def poisson_negative_log_likelihood(
    observed_counts: Sequence[int],
    predicted_rates: Sequence[float],
) -> float:
    if len(observed_counts) == 0 or len(observed_counts) != len(predicted_rates):
        raise ValueError("observed and predicted vectors must be non-empty and same length")

    total = 0.0
    for observed, predicted in zip(observed_counts, predicted_rates, strict=True):
        if observed < 0 or predicted <= 0.0:
            raise ValueError("counts must be non-negative and rates must be positive")
        total += predicted - observed * log(predicted)
    return total / len(observed_counts)


def _solve_linear_system(matrix: list[list[float]], vector: list[float]) -> list[float]:
    size = len(vector)
    augmented = [row[:] + [value] for row, value in zip(matrix, vector, strict=True)]

    for pivot_index in range(size):
        pivot_row = max(
            range(pivot_index, size),
            key=lambda row_index: abs(augmented[row_index][pivot_index]),
        )
        if abs(augmented[pivot_row][pivot_index]) < 1e-12:
            raise ValueError("inverse reconstruction system is singular")
        augmented[pivot_index], augmented[pivot_row] = (
            augmented[pivot_row],
            augmented[pivot_index],
        )

        pivot = augmented[pivot_index][pivot_index]
        augmented[pivot_index] = [value / pivot for value in augmented[pivot_index]]

        for row_index in range(size):
            if row_index == pivot_index:
                continue
            factor = augmented[row_index][pivot_index]
            augmented[row_index] = [
                value - factor * pivot_value
                for value, pivot_value in zip(
                    augmented[row_index],
                    augmented[pivot_index],
                    strict=True,
                )
            ]

    return [row[-1] for row in augmented]


def example_specification() -> dict[str, object]:
    reference = InstitutionalReference(
        reference_id="INT-REF-DEIDENTIFIED-TOPOLOGY-SUMMARY",
        record_class="managed-technical-record",
        permitted_research_use="deidentified-topology-analysis",
    )
    baseline = GraphSnapshot(
        snapshot_id="R-TOPOLOGY-010-BASELINE",
        elapsed_window=0,
        institutional_reference=reference,
        channels=(
            ChannelSummary("channel-a", 0.50),
            ChannelSummary("channel-b", 0.55),
        ),
        edge_mode=GraphEdgeMode.SPATIAL_CORRELATION,
        adjacency=((0.0, 0.80), (0.80, 0.0)),
    )
    current = GraphSnapshot(
        snapshot_id="R-TOPOLOGY-010-SESSION-001",
        elapsed_window=1,
        institutional_reference=reference,
        channels=(
            ChannelSummary("channel-a", 0.48),
            ChannelSummary("channel-b", 0.66),
        ),
        edge_mode=GraphEdgeMode.SPATIAL_CORRELATION,
        adjacency=((0.0, 0.62), (0.62, 0.0)),
    )
    topology = assess_topology_change(baseline, current)
    latent = evaluate_latent_model(
        LatentEvaluation(
            reconstruction_quality=0.76,
            held_out_prediction_quality=0.71,
            intent_task_quality=0.74,
            drift_sensitivity=0.20,
            uncertainty_coverage=0.73,
        )
    )
    reconstruction = ridge_inverse_reconstruction(
        forward_operator=((1.0, 0.2), (0.3, 0.9)),
        measurements=(0.8, 0.6),
        regularization_strength=0.01,
    )

    return {
        "topology_assessment": asdict(topology),
        "latent_assessment": asdict(latent),
        "illustrative_regularized_inverse_solution": reconstruction,
    }
