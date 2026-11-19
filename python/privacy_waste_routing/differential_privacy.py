from __future__ import annotations

from dataclasses import dataclass
from math import log, sqrt
from secrets import SystemRandom
from typing import Iterable


_secure_random = SystemRandom()


@dataclass(frozen=True)
class PrivacyParameters:
    epsilon: float
    delta: float | None = None

    def __post_init__(self) -> None:
        if self.epsilon <= 0.0:
            raise ValueError("epsilon must be positive.")

        if self.delta is not None and not 0.0 < self.delta < 1.0:
            raise ValueError("delta must be within the open interval (0, 1).")


@dataclass(frozen=True)
class AggregationCell:
    cell_name: str
    clipped_fill_values: tuple[float, ...]
    minimum_bin_count: int
    fill_cap: float

    def __post_init__(self) -> None:
        if not self.cell_name.strip():
            raise ValueError("cell_name must not be empty.")

        if self.minimum_bin_count <= 0:
            raise ValueError("minimum_bin_count must be positive.")

        if self.fill_cap <= 0.0:
            raise ValueError("fill_cap must be positive.")

        if len(self.clipped_fill_values) < self.minimum_bin_count:
            raise ValueError(
                "The aggregation cell does not meet the minimum bin count."
            )

        for value in self.clipped_fill_values:
            if not 0.0 <= value <= self.fill_cap:
                raise ValueError(
                    "All clipped fill values must be within 0.0..=fill_cap."
                )


@dataclass(frozen=True)
class NoisyFillEstimate:
    cell_name: str
    released_average_fill: float
    noise_standard_deviation: float
    mechanism: str
    epsilon: float
    delta: float | None
    protected_bin_count: int


def clip_fill_level(fill_level: float, fill_cap: float = 1.0) -> float:
    if fill_cap <= 0.0:
        raise ValueError("fill_cap must be positive.")

    return min(max(fill_level, 0.0), fill_cap)


def average_fill_sensitivity(fill_cap: float, minimum_bin_count: int) -> float:
    if fill_cap <= 0.0:
        raise ValueError("fill_cap must be positive.")

    if minimum_bin_count <= 0:
        raise ValueError("minimum_bin_count must be positive.")

    return fill_cap / minimum_bin_count


def laplace_scale(sensitivity_l1: float, epsilon: float) -> float:
    if sensitivity_l1 <= 0.0:
        raise ValueError("sensitivity_l1 must be positive.")

    if epsilon <= 0.0:
        raise ValueError("epsilon must be positive.")

    return sensitivity_l1 / epsilon


def laplace_standard_deviation(scale: float) -> float:
    if scale <= 0.0:
        raise ValueError("scale must be positive.")

    return sqrt(2.0) * scale


def gaussian_standard_deviation(
    sensitivity_l2: float,
    epsilon: float,
    delta: float,
) -> float:
    if sensitivity_l2 <= 0.0:
        raise ValueError("sensitivity_l2 must be positive.")

    if not 0.0 < epsilon < 1.0:
        raise ValueError("epsilon must be within (0, 1) for this calibration bound.")

    if not 0.0 < delta < 1.0:
        raise ValueError("delta must be within (0, 1).")

    return (
        sensitivity_l2
        * sqrt(2.0 * log(1.25 / delta))
        / epsilon
    )


def sample_laplace(scale: float) -> float:
    if scale <= 0.0:
        raise ValueError("scale must be positive.")

    uniform = _secure_random.random() - 0.5

    if uniform >= 0.0:
        return -scale * log(1.0 - 2.0 * uniform)

    return scale * log(1.0 + 2.0 * uniform)


def release_laplace_average(
    cell: AggregationCell,
    parameters: PrivacyParameters,
) -> NoisyFillEstimate:
    if parameters.delta is not None:
        raise ValueError(
            "Laplace release provides pure epsilon-DP and must not include delta."
        )

    sensitivity = average_fill_sensitivity(
        fill_cap=cell.fill_cap,
        minimum_bin_count=cell.minimum_bin_count,
    )
    scale = laplace_scale(sensitivity, parameters.epsilon)
    average = sum(cell.clipped_fill_values) / len(cell.clipped_fill_values)
    released_average = average + sample_laplace(scale)

    return NoisyFillEstimate(
        cell_name=cell.cell_name,
        released_average_fill=released_average,
        noise_standard_deviation=laplace_standard_deviation(scale),
        mechanism="laplace",
        epsilon=parameters.epsilon,
        delta=None,
        protected_bin_count=len(cell.clipped_fill_values),
    )


def release_gaussian_average(
    cell: AggregationCell,
    parameters: PrivacyParameters,
) -> NoisyFillEstimate:
    if parameters.delta is None:
        raise ValueError("Gaussian release requires an explicit delta.")

    sensitivity = average_fill_sensitivity(
        fill_cap=cell.fill_cap,
        minimum_bin_count=cell.minimum_bin_count,
    )
    sigma = gaussian_standard_deviation(
        sensitivity_l2=sensitivity,
        epsilon=parameters.epsilon,
        delta=parameters.delta,
    )
    average = sum(cell.clipped_fill_values) / len(cell.clipped_fill_values)
    released_average = average + _secure_random.gauss(0.0, sigma)

    return NoisyFillEstimate(
        cell_name=cell.cell_name,
        released_average_fill=released_average,
        noise_standard_deviation=sigma,
        mechanism="gaussian",
        epsilon=parameters.epsilon,
        delta=parameters.delta,
        protected_bin_count=len(cell.clipped_fill_values),
    )


def basic_composition_epsilons(
    releases: Iterable[PrivacyParameters],
) -> float:
    values = list(releases)

    if not values:
        return 0.0

    return sum(value.epsilon for value in values)


def basic_composition_deltas(
    releases: Iterable[PrivacyParameters],
) -> float:
    values = list(releases)

    return sum(
        value.delta
        for value in values
        if value.delta is not None
    )


def should_collect(
    estimate: NoisyFillEstimate,
    collection_threshold: float,
    confidence_multiplier: float,
    overflow_safety_signal: bool,
) -> bool:
    if not 0.0 <= collection_threshold <= 1.0:
        raise ValueError("collection_threshold must be within 0.0..=1.0.")

    if confidence_multiplier < 0.0:
        raise ValueError("confidence_multiplier must be non-negative.")

    lower_bound = (
        estimate.released_average_fill
        - confidence_multiplier * estimate.noise_standard_deviation
    )

    return overflow_safety_signal or lower_bound >= collection_threshold


def overflow_risk(
    estimate: NoisyFillEstimate,
    overflow_threshold: float,
    confidence_multiplier: float,
) -> bool:
    if not 0.0 <= overflow_threshold <= 1.0:
        raise ValueError("overflow_threshold must be within 0.0..=1.0.")

    if confidence_multiplier < 0.0:
        raise ValueError("confidence_multiplier must be non-negative.")

    upper_bound = (
        estimate.released_average_fill
        + confidence_multiplier * estimate.noise_standard_deviation
    )

    return upper_bound >= overflow_threshold
