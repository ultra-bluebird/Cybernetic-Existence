from __future__ import annotations

from dataclasses import dataclass
from math import exp, pi
from typing import Literal


OffloadingStatus = Literal[
    "OFFLOAD_RESEARCH_AVAILABLE",
    "OFFLOAD_RESEARCH_REVIEW_REQUIRED",
    "INSUFFICIENT_MODEL_CONTEXT",
]


@dataclass(frozen=True)
class OffloadingModelConfig:
    radius_m: float
    attenuation_length_m: float
    maximum_device_capacity_w: float
    target_capacity_w: float
    target_availability_probability: float
    reviewed_exposure_within_limit: bool
    consented_resource_model: bool
    advisory_only: bool
    human_review_required: bool


@dataclass(frozen=True)
class OffloadingResult:
    status: OffloadingStatus
    minimum_density_for_expected_capacity_per_m2: float | None
    minimum_density_for_availability_per_m2: float | None
    expected_capacity_at_density_w: float | None
    probability_of_one_or_more_devices: float | None
    explanation: str


def _positive(value: float, field: str) -> None:
    if not isinstance(value, (int, float)) or isinstance(value, bool) or value <= 0:
        raise ValueError(f"{field} must be a positive finite number")


def _probability(value: float, field: str) -> None:
    if not isinstance(value, (int, float)) or isinstance(value, bool) or not 0 < value < 1:
        raise ValueError(f"{field} must be a finite number strictly between 0 and 1")


def radial_capacity_integral(radius_m: float, attenuation_length_m: float) -> float:
    _positive(radius_m, "radius_m")
    _positive(attenuation_length_m, "attenuation_length_m")

    ratio = radius_m / attenuation_length_m
    return attenuation_length_m**2 * (1.0 - exp(-ratio) * (1.0 + ratio))


def expected_aggregate_capacity_w(
    density_per_m2: float,
    radius_m: float,
    attenuation_length_m: float,
    maximum_device_capacity_w: float,
) -> float:
    _positive(density_per_m2, "density_per_m2")
    _positive(maximum_device_capacity_w, "maximum_device_capacity_w")

    integral = radial_capacity_integral(radius_m, attenuation_length_m)
    return 2.0 * pi * density_per_m2 * maximum_device_capacity_w * integral


def minimum_density_for_expected_capacity_per_m2(
    target_capacity_w: float,
    radius_m: float,
    attenuation_length_m: float,
    maximum_device_capacity_w: float,
) -> float:
    _positive(target_capacity_w, "target_capacity_w")
    _positive(maximum_device_capacity_w, "maximum_device_capacity_w")

    integral = radial_capacity_integral(radius_m, attenuation_length_m)
    denominator = 2.0 * pi * maximum_device_capacity_w * integral
    if denominator <= 0:
        raise ValueError("Model denominator must be positive")

    return target_capacity_w / denominator


def probability_of_one_or_more_devices(
    density_per_m2: float,
    radius_m: float,
) -> float:
    _positive(density_per_m2, "density_per_m2")
    _positive(radius_m, "radius_m")

    return 1.0 - exp(-density_per_m2 * pi * radius_m**2)


def minimum_density_for_availability_probability_per_m2(
    target_probability: float,
    radius_m: float,
) -> float:
    _probability(target_probability, "target_probability")
    _positive(radius_m, "radius_m")

    return -__import__("math").log(1.0 - target_probability) / (pi * radius_m**2)


def analyze_offloading_model(
    config: OffloadingModelConfig,
    candidate_density_per_m2: float,
) -> OffloadingResult:
    _positive(candidate_density_per_m2, "candidate_density_per_m2")
    _positive(config.radius_m, "radius_m")
    _positive(config.attenuation_length_m, "attenuation_length_m")
    _positive(config.maximum_device_capacity_w, "maximum_device_capacity_w")
    _positive(config.target_capacity_w, "target_capacity_w")
    _probability(config.target_availability_probability, "target_availability_probability")

    if not config.advisory_only or not config.human_review_required:
        return OffloadingResult(
            status="OFFLOAD_RESEARCH_REVIEW_REQUIRED",
            minimum_density_for_expected_capacity_per_m2=None,
            minimum_density_for_availability_per_m2=None,
            expected_capacity_at_density_w=None,
            probability_of_one_or_more_devices=None,
            explanation=(
                "The model is not configured as advisory-only with human review. "
                "No research result is available."
            ),
        )

    if not config.consented_resource_model:
        return OffloadingResult(
            status="OFFLOAD_RESEARCH_REVIEW_REQUIRED",
            minimum_density_for_expected_capacity_per_m2=None,
            minimum_density_for_availability_per_m2=None,
            expected_capacity_at_density_w=None,
            probability_of_one_or_more_devices=None,
            explanation=(
                "The model lacks an explicit consent boundary for abstract compute resources. "
                "No offload result may be used."
            ),
        )

    if not config.reviewed_exposure_within_limit:
        return OffloadingResult(
            status="OFFLOAD_RESEARCH_REVIEW_REQUIRED",
            minimum_density_for_expected_capacity_per_m2=None,
            minimum_density_for_availability_per_m2=None,
            expected_capacity_at_density_w=None,
            probability_of_one_or_more_devices=None,
            explanation=(
                "No reviewed, applicable electromagnetic-exposure assessment was supplied. "
                "The simulator does not calculate or assert real-world exposure compliance."
            ),
        )

    minimum_capacity_density = minimum_density_for_expected_capacity_per_m2(
        config.target_capacity_w,
        config.radius_m,
        config.attenuation_length_m,
        config.maximum_device_capacity_w,
    )
    minimum_availability_density = minimum_density_for_availability_probability_per_m2(
        config.target_availability_probability,
        config.radius_m,
    )
    expected_capacity = expected_aggregate_capacity_w(
        candidate_density_per_m2,
        config.radius_m,
        config.attenuation_length_m,
        config.maximum_device_capacity_w,
    )
    availability_probability = probability_of_one_or_more_devices(
        candidate_density_per_m2,
        config.radius_m,
    )

    usable = (
        candidate_density_per_m2 >= minimum_capacity_density
        and candidate_density_per_m2 >= minimum_availability_density
    )

    return OffloadingResult(
        status="OFFLOAD_RESEARCH_AVAILABLE" if usable else "OFFLOAD_RESEARCH_REVIEW_REQUIRED",
        minimum_density_for_expected_capacity_per_m2=minimum_capacity_density,
        minimum_density_for_availability_per_m2=minimum_availability_density,
        expected_capacity_at_density_w=expected_capacity,
        probability_of_one_or_more_devices=availability_probability,
        explanation=(
            "This result is a synthetic Poisson-field capacity estimate using abstract, "
            "consented resource assumptions. It is not device discovery, exposure testing, "
            "medical assessment, or authorization to communicate with nearby devices."
        ),
    )
