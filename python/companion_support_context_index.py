from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class ContextIndexStatus(str, Enum):
    COMPANION_CONTEXT_AVAILABLE = "COMPANION_CONTEXT_AVAILABLE"
    COMPANION_CONTEXT_REVIEW_REQUIRED = "COMPANION_CONTEXT_REVIEW_REQUIRED"
    INSUFFICIENT_CONTEXT = "INSUFFICIENT_CONTEXT"


@dataclass(frozen=True)
class ContextWeights:
    coherence_weight: float
    energy_reserve_weight: float
    learning_weight: float
    communication_weight: float
    environmental_stress_weight: float


@dataclass(frozen=True)
class CompanionSupportContext:
    coherence: float
    energy_reserve: float
    learning_rate: float
    communication_quality: float
    environmental_stress: float
    uncertainty: float
    host_direction_active: bool
    advisory_only: bool
    human_review_required: bool
    essential_accessibility_passed: bool


@dataclass(frozen=True)
class ContextIndexResult:
    status: ContextIndexStatus
    raw_index: float | None
    explanation: str


def _unit_interval(value: float, field: str) -> None:
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        raise ValueError(f"{field} must be a number in [0, 1].")
    if not 0.0 <= float(value) <= 1.0:
        raise ValueError(f"{field} must be a number in [0, 1].")


def _validate_weights(weights: ContextWeights) -> None:
    values = (
        weights.coherence_weight,
        weights.energy_reserve_weight,
        weights.learning_weight,
        weights.communication_weight,
        weights.environmental_stress_weight,
    )

    for value, field in zip(
        values,
        (
            "coherence_weight",
            "energy_reserve_weight",
            "learning_weight",
            "communication_weight",
            "environmental_stress_weight",
        ),
        strict=True,
    ):
        _unit_interval(value, field)

    if abs(sum(values) - 1.0) > 1e-12:
        raise ValueError("Context-index weights must sum exactly to 1.0.")


def calculate_companion_support_context_index(
    context: CompanionSupportContext,
    weights: ContextWeights,
) -> ContextIndexResult:
    _validate_weights(weights)

    for value, field in (
        (context.coherence, "coherence"),
        (context.energy_reserve, "energy_reserve"),
        (context.learning_rate, "learning_rate"),
        (context.communication_quality, "communication_quality"),
        (context.environmental_stress, "environmental_stress"),
        (context.uncertainty, "uncertainty"),
    ):
        _unit_interval(value, field)

    if not context.host_direction_active:
        return ContextIndexResult(
            status=ContextIndexStatus.COMPANION_CONTEXT_REVIEW_REQUIRED,
            raw_index=None,
            explanation=(
                "Host direction is not active. The model does not compute a context "
                "index without an active host-directed research context."
            ),
        )

    if (
        not context.advisory_only
        or not context.human_review_required
        or not context.essential_accessibility_passed
    ):
        return ContextIndexResult(
            status=ContextIndexStatus.COMPANION_CONTEXT_REVIEW_REQUIRED,
            raw_index=None,
            explanation=(
                "An essential advisory, human-review, or accessibility condition "
                "failed. A composite index cannot compensate for this."
            ),
        )

    if context.uncertainty > 0.5:
        return ContextIndexResult(
            status=ContextIndexStatus.INSUFFICIENT_CONTEXT,
            raw_index=None,
            explanation=(
                "Context uncertainty exceeds the configured review threshold. "
                "No composite result is released."
            ),
        )

    raw_index = (
        weights.coherence_weight * context.coherence
        + weights.energy_reserve_weight * context.energy_reserve
        + weights.learning_weight * context.learning_rate
        + weights.communication_weight * context.communication_quality
        + weights.environmental_stress_weight * (1.0 - context.environmental_stress)
    )

    return ContextIndexResult(
        status=ContextIndexStatus.COMPANION_CONTEXT_AVAILABLE,
        raw_index=max(0.0, min(1.0, raw_index)),
        explanation=(
            "This is an abstract, host-directed support-context index for research "
            "and review. It is not a health, consciousness, medical, identity, "
            "capability, or physical-system assessment."
        ),
    )
