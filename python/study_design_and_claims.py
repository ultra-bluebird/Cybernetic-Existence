from dataclasses import dataclass
from enum import Enum
from math import ceil, isfinite, sqrt
from statistics import NormalDist


def text(value: str, field: str) -> None:
    if not isinstance(value, str) or not value.strip() or len(value) > 4096:
        raise ValueError(f"{field} must be non-empty text within the limit.")


def probability(value: float, field: str) -> None:
    if (
        isinstance(value, bool)
        or not isinstance(value, (int, float))
        or not isfinite(value)
        or not 0 < value < 1
    ):
        raise ValueError(f"{field} must lie strictly between zero and one.")


class Structure(str, Enum):
    SEQUENTIAL = "sequential_within_participant"
    RANDOMIZED = "randomized_comparison"


class Purpose(str, Enum):
    FEASIBILITY = "feasibility"
    CONFIRMATORY = "confirmatory_comparison"


@dataclass(frozen=True)
class Design:
    structure: Structure
    purpose: Purpose
    primary_question: str
    assignment_unit: str
    allocation_description: str
    estimand: str
    analysis_plan: str
    missingness_policy: str
    sample_size_rationale: str
    sensitivity_analysis: str
    progression_or_success_criteria: str
    revision: str

    def __post_init__(self) -> None:
        if not isinstance(self.structure, Structure):
            raise ValueError("Select one supported study structure.")
        if not isinstance(self.purpose, Purpose):
            raise ValueError("Select one supported purpose.")
        for field in (
            "primary_question", "assignment_unit", "allocation_description",
            "estimand", "analysis_plan", "missingness_policy",
            "sample_size_rationale", "sensitivity_analysis",
            "progression_or_success_criteria", "revision",
        ):
            text(getattr(self, field), field)
        if (
            self.structure == Structure.SEQUENTIAL
            and self.purpose == Purpose.CONFIRMATORY
        ):
            raise ValueError(
                "This bounded selector does not authorize sequential "
                "phases as a confirmatory intervention comparison."
            )


def wilson_interval(successes: int, assessed: int, confidence: float) -> dict:
    probability(confidence, "Confidence level")
    if type(assessed) is not int or assessed < 1:
        raise ValueError("Assessed count must be a positive integer.")
    if type(successes) is not int or not 0 <= successes <= assessed:
        raise ValueError("Success count must lie within assessed count.")

    z = NormalDist().inv_cdf((1 + confidence) / 2)
    p = successes / assessed
    denominator = 1 + z * z / assessed
    center = (p + z * z / (2 * assessed)) / denominator
    half = (
        z * sqrt(p * (1 - p) / assessed + z * z / (4 * assessed * assessed))
        / denominator
    )
    return {
        "assessed": assessed,
        "successes": successes,
        "estimate": p,
        "lower": max(0.0, center - half),
        "upper": min(1.0, center + half),
        "width": 2 * half,
        "independent_binomial_assumption_required": True,
    }


def enrollment_target(analyzable: int, unavailable_fraction: float) -> int:
    if type(analyzable) is not int or analyzable < 1:
        raise ValueError("Analyzable target must be positive.")
    if (
        isinstance(unavailable_fraction, bool)
        or not isinstance(unavailable_fraction, (int, float))
        or not isfinite(unavailable_fraction)
        or not 0 <= unavailable_fraction < 1
    ):
        raise ValueError("Unavailable fraction must lie from zero to below one.")
    return ceil(analyzable / (1 - unavailable_fraction))


class ClaimStrategy(str, Enum):
    DESCRIPTIVE = "descriptive_only"
    SINGLE = "single_primary"
    BONFERRONI = "bonferroni_individual_claims"
    JOINT = "joint_all_endpoints_required"


@dataclass(frozen=True)
class Endpoint:
    name: str
    definition: str
    timepoint: str
    contrast: str
    alpha: float | None

    def __post_init__(self) -> None:
        for field in ("name", "definition", "timepoint", "contrast"):
            text(getattr(self, field), field)
        if self.alpha is not None:
            probability(self.alpha, "Endpoint alpha")


def claim_plan(
    strategy: ClaimStrategy,
    endpoints: tuple[Endpoint, ...],
    family_alpha: float | None,
) -> dict:
    if not isinstance(strategy, ClaimStrategy):
        raise ValueError("Select one declared claim strategy.")
    if type(endpoints) is not tuple or not endpoints:
        raise ValueError("Supply a non-empty endpoint tuple.")
    if any(not isinstance(endpoint, Endpoint) for endpoint in endpoints):
        raise ValueError("Use validated endpoints.")
    names = [endpoint.name for endpoint in endpoints]
    if len(names) != len(set(names)):
        raise ValueError("Endpoint names must be unique in this family.")

    if strategy == ClaimStrategy.DESCRIPTIVE:
        if family_alpha is not None or any(e.alpha is not None for e in endpoints):
            raise ValueError("Descriptive plans do not allocate testing alpha.")
    else:
        probability(family_alpha, "Family alpha")
        if any(endpoint.alpha is None for endpoint in endpoints):
            raise ValueError("Every confirmatory endpoint needs explicit alpha.")
        if strategy == ClaimStrategy.SINGLE:
            if len(endpoints) != 1 or endpoints[0].alpha != family_alpha:
                raise ValueError("Single-primary allocation is inconsistent.")
        elif strategy == ClaimStrategy.BONFERRONI:
            if sum(endpoint.alpha for endpoint in endpoints) > family_alpha:
                raise ValueError("Allocated alpha exceeds the family budget.")
        elif strategy == ClaimStrategy.JOINT:
            if len(endpoints) < 2:
                raise ValueError("Joint claims require at least two endpoints.")
            if any(endpoint.alpha != family_alpha for endpoint in endpoints):
                raise ValueError("Joint components use the declared family alpha.")

    return {
        "strategy": strategy.value,
        "family_alpha": family_alpha,
        "endpoint_count": len(endpoints),
        "claim_requires_all_endpoints": strategy == ClaimStrategy.JOINT,
        "confirmatory_claims_planned": strategy != ClaimStrategy.DESCRIPTIVE,
        "preregistration_completed": False,
        "statistical_assumptions_verified": False,
        "study_implementation_authorized": False,
    }
