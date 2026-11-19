from __future__ import annotations

from dataclasses import dataclass
from math import exp
from typing import Sequence

import numpy as np


@dataclass(frozen=True)
class AssociativeMemoryResult:
    recalled_pattern: tuple[int, ...]
    recall_fidelity: float
    iterations: int
    converged: bool
    explanation: str


def validate_binary_pattern(pattern: Sequence[int], name: str) -> np.ndarray:
    values = np.asarray(pattern, dtype=np.int8)

    if values.ndim != 1 or values.size == 0:
        raise ValueError(f"{name} must be a non-empty one-dimensional pattern.")

    if not np.all(np.isin(values, (-1, 1))):
        raise ValueError(f"{name} values must be either -1 or 1.")

    return values


def build_association_weights(
    stored_patterns: Sequence[Sequence[int]],
) -> np.ndarray:
    if not stored_patterns:
        raise ValueError("At least one stored semantic pattern is required.")

    patterns = [
        validate_binary_pattern(pattern, f"stored_patterns[{index}]")
        for index, pattern in enumerate(stored_patterns)
    ]

    width = patterns[0].size
    if any(pattern.size != width for pattern in patterns):
        raise ValueError("All stored semantic patterns must have equal length.")

    weights = np.zeros((width, width), dtype=np.float64)

    for pattern in patterns:
        weights += np.outer(pattern, pattern)

    weights /= width
    np.fill_diagonal(weights, 0.0)
    return weights


def recall_semantic_pattern(
    weights: np.ndarray,
    cue_pattern: Sequence[int],
    maximum_iterations: int = 64,
) -> AssociativeMemoryResult:
    cue = validate_binary_pattern(cue_pattern, "cue_pattern")

    if weights.ndim != 2 or weights.shape[0] != weights.shape[1]:
        raise ValueError("weights must be a square matrix.")

    if weights.shape[0] != cue.size:
        raise ValueError("cue_pattern width must match the weight matrix.")

    if maximum_iterations < 1:
        raise ValueError("maximum_iterations must be positive.")

    state = cue.copy()

    for iteration in range(1, maximum_iterations + 1):
        next_state = np.where(weights @ state >= 0.0, 1, -1).astype(np.int8)

        if np.array_equal(next_state, state):
            return AssociativeMemoryResult(
                recalled_pattern=tuple(int(value) for value in state),
                recall_fidelity=1.0,
                iterations=iteration,
                converged=True,
                explanation=(
                    "The abstract associative-memory simulation reached a stable "
                    "symbolic pattern. This is not a prediction of human memory, "
                    "sleep outcome, neural condition, or cognitive ability."
                ),
            )

        state = next_state

    return AssociativeMemoryResult(
        recalled_pattern=tuple(int(value) for value in state),
        recall_fidelity=0.0,
        iterations=maximum_iterations,
        converged=False,
        explanation=(
            "The abstract associative-memory simulation did not converge within "
            "the configured iteration limit. Human review or a revised concept "
            "representation may be appropriate."
        ),
    )


def fidelity_to_reference(
    recalled_pattern: Sequence[int],
    reference_pattern: Sequence[int],
) -> float:
    recalled = validate_binary_pattern(recalled_pattern, "recalled_pattern")
    reference = validate_binary_pattern(reference_pattern, "reference_pattern")

    if recalled.size != reference.size:
        raise ValueError("Patterns must have equal length.")

    return float(np.mean(recalled == reference))


def update_semantic_retention(
    current_retention: float,
    learning_rate: float,
) -> float:
    if not 0.0 <= current_retention <= 1.0:
        raise ValueError("current_retention must be in [0, 1].")

    if not 0.0 <= learning_rate <= 1.0:
        raise ValueError("learning_rate must be in [0, 1].")

    return min(1.0, current_retention + learning_rate * (1.0 - current_retention))


def decay_semantic_retention(
    current_retention: float,
    elapsed_units: float,
    retention_scale: float,
) -> float:
    if not 0.0 <= current_retention <= 1.0:
        raise ValueError("current_retention must be in [0, 1].")

    if elapsed_units < 0.0:
        raise ValueError("elapsed_units must be non-negative.")

    if retention_scale <= 0.0:
        raise ValueError("retention_scale must be positive.")

    return current_retention * exp(-elapsed_units / retention_scale)
