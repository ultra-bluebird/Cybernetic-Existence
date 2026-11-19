from __future__ import annotations

from dataclasses import dataclass
from math import exp, sqrt
from typing import Iterable


@dataclass(frozen=True)
class AggregateInteractionCounts:
    positive: int
    negative: int
    total: int

    def __post_init__(self) -> None:
        if self.positive < 0 or self.negative < 0 or self.total < 0:
            raise ValueError("Interaction counts must be non-negative.")

        if self.positive + self.negative > self.total:
            raise ValueError(
                "Positive plus negative interactions cannot exceed total interactions."
            )


@dataclass(frozen=True)
class AcceptanceComponents:
    respectful_treatment: float
    belonging: float
    accessible_service_use: float
    safety: float
    participation: float
    interoperability: float
    harmful_experience: float

    def __post_init__(self) -> None:
        values = (
            self.respectful_treatment,
            self.belonging,
            self.accessible_service_use,
            self.safety,
            self.participation,
            self.interoperability,
            self.harmful_experience,
        )

        if any(value < 0.0 or value > 1.0 for value in values):
            raise ValueError("Acceptance components must be within 0.0..=1.0.")


@dataclass(frozen=True)
class AcceptanceWeights:
    respectful_treatment: float = 0.18
    belonging: float = 0.16
    accessible_service_use: float = 0.18
    safety: float = 0.16
    participation: float = 0.12
    interoperability: float = 0.10
    harmful_experience: float = 0.10

    def __post_init__(self) -> None:
        values = (
            self.respectful_treatment,
            self.belonging,
            self.accessible_service_use,
            self.safety,
            self.participation,
            self.interoperability,
            self.harmful_experience,
        )

        if any(value < 0.0 for value in values):
            raise ValueError("Acceptance weights must be non-negative.")

        if abs(sum(values) - 1.0) > 1e-9:
            raise ValueError("Acceptance weights must sum to 1.0.")


@dataclass(frozen=True)
class DidAggregate:
    treated_pre: float
    treated_post: float
    comparison_pre: float
    comparison_post: float


def acceptance_index(
    counts: AggregateInteractionCounts,
    baseline: float,
    harm_sensitivity: float = 1.5,
) -> float:
    if harm_sensitivity < 1.0:
        raise ValueError("harm_sensitivity must be at least 1.0.")

    return baseline + (
        counts.positive - harm_sensitivity * counts.negative
    ) / max(counts.total, 1)


def bounded_acceptance_index(unbounded_value: float) -> float:
    return 1.0 / (1.0 + exp(-unbounded_value))


def public_acceptance_score(
    components: AcceptanceComponents,
    weights: AcceptanceWeights = AcceptanceWeights(),
) -> float:
    return (
        weights.respectful_treatment * components.respectful_treatment
        + weights.belonging * components.belonging
        + weights.accessible_service_use * components.accessible_service_use
        + weights.safety * components.safety
        + weights.participation * components.participation
        + weights.interoperability * components.interoperability
        - weights.harmful_experience * components.harmful_experience
    )


def difference_in_differences(aggregate: DidAggregate) -> float:
    treated_change = aggregate.treated_post - aggregate.treated_pre
    comparison_change = aggregate.comparison_post - aggregate.comparison_pre
    return treated_change - comparison_change


def proportion_interval(
    successes: int,
    total: int,
    z_score: float = 1.96,
) -> tuple[float, float]:
    if successes < 0 or total <= 0 or successes > total:
        raise ValueError("successes must be within 0..=total and total must be positive.")

    if z_score <= 0.0:
        raise ValueError("z_score must be positive.")

    estimate = successes / total
    standard_error = sqrt(estimate * (1.0 - estimate) / total)
    margin = z_score * standard_error

    return (
        max(0.0, estimate - margin),
        min(1.0, estimate + margin),
    )


def small_cell_safe(count: int, minimum_cell_size: int) -> bool:
    if count < 0:
        raise ValueError("count must be non-negative.")

    if minimum_cell_size <= 0:
        raise ValueError("minimum_cell_size must be positive.")

    return count >= minimum_cell_size


def evidence_completeness(
    present_fields: Iterable[str],
    required_fields: Iterable[str],
) -> float:
    present = set(present_fields)
    required = set(required_fields)

    if not required:
        raise ValueError("At least one required field is needed.")

    return len(present.intersection(required)) / len(required)
