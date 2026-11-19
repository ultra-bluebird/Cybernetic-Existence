# mk-bluebird/Cybercore/research/puf_reliability_and_fuzzy_extraction.py
from __future__ import annotations

from dataclasses import asdict, dataclass
from enum import StrEnum
from math import comb, erf, exp, sqrt
from statistics import mean, pstdev
from typing import Sequence


class PufKind(StrEnum):
    ARBITER = "arbiter"
    SRAM = "sram"


class ReliabilityDisposition(StrEnum):
    SUITABLE_FOR_RESEARCH_EVALUATION = "suitable-for-research-evaluation"
    MONITOR_ENVIRONMENTAL_SENSITIVITY = "monitor-environmental-sensitivity"
    INSUFFICIENT_RELIABILITY_EVIDENCE = "insufficient-reliability-evidence"
    INSUFFICIENT_UNIQUENESS_EVIDENCE = "insufficient-uniqueness-evidence"


class ReconstructionDisposition(StrEnum):
    WITHIN_TARGET_BOUND = "within-target-bound"
    EXCEEDS_TARGET_BOUND = "exceeds-target-bound"
    INSUFFICIENT_PARAMETERIZATION = "insufficient-parameterization"


@dataclass(frozen=True)
class InstitutionalReference:
    reference_id: str
    record_class: str
    permitted_research_use: str
    value_handling: str = "institutionally-controlled"


@dataclass(frozen=True)
class ResponsePair:
    left_response: tuple[int, ...]
    right_response: tuple[int, ...]

    def validate(self) -> None:
        if not self.left_response or len(self.left_response) != len(self.right_response):
            raise ValueError("responses must be non-empty and have equal length")
        if any(bit not in (0, 1) for bit in self.left_response + self.right_response):
            raise ValueError("responses must contain only binary values")

    def hamming_distance(self) -> int:
        self.validate()
        return sum(
            left != right
            for left, right in zip(self.left_response, self.right_response, strict=True)
        )

    def normalized_hamming_distance(self) -> float:
        return self.hamming_distance() / len(self.left_response)


@dataclass(frozen=True)
class ReliabilityThresholds:
    maximum_intra_device_mean_hd: float = 0.10
    maximum_intra_device_max_hd: float = 0.20
    minimum_inter_device_mean_hd: float = 0.40
    maximum_inter_device_deviation: float = 0.10


@dataclass(frozen=True)
class ReliabilityAssessment:
    intra_device_mean_normalized_hd: float
    inter_device_mean_normalized_hd: float
    intra_device_max_normalized_hd: float
    inter_device_standard_deviation: float
    reliability_score: float
    uniqueness_score: float
    disposition: ReliabilityDisposition


@dataclass(frozen=True)
class BchParameters:
    codeword_length: int
    message_length: int
    correction_capacity: int

    def validate(self) -> None:
        if (
            self.codeword_length <= 0
            or self.message_length <= 0
            or self.message_length >= self.codeword_length
            or self.correction_capacity <= 0
            or 2 * self.correction_capacity >= self.codeword_length
        ):
            raise ValueError("invalid BCH parameter profile")

    @property
    def helper_data_length_bits(self) -> int:
        self.validate()
        return self.codeword_length - self.message_length


@dataclass(frozen=True)
class ReconstructionAssessment:
    codeword_length: int
    correction_capacity: int
    independent_bit_error_probability: float
    predicted_failure_probability: float
    target_failure_probability: float
    helper_data_length_bits: int
    disposition: ReconstructionDisposition


def arbiter_feature_vector(challenge: Sequence[int]) -> tuple[int, ...]:
    if not challenge or any(bit not in (0, 1) for bit in challenge):
        raise ValueError("challenge must be a non-empty binary sequence")

    features: list[int] = []
    for index in range(len(challenge)):
        parity = 1
        for bit in challenge[index:]:
            parity *= 1 - 2 * bit
        features.append(parity)
    features.append(1)
    return tuple(features)


def arbiter_delay_difference(
    weights: Sequence[float],
    challenge: Sequence[int],
) -> float:
    feature_vector = arbiter_feature_vector(challenge)
    if len(weights) != len(feature_vector):
        raise ValueError("weight count must equal challenge length plus one")
    return sum(
        weight * feature
        for weight, feature in zip(weights, feature_vector, strict=True)
    )


def arbiter_response(
    weights: Sequence[float],
    challenge: Sequence[int],
) -> int:
    return int(arbiter_delay_difference(weights, challenge) > 0.0)


def normal_cdf(value: float) -> float:
    return 0.5 * (1.0 + erf(value / sqrt(2.0)))


def sram_cell_one_probability(
    threshold_voltage_difference: float,
    random_dopant_fluctuation_sigma: float,
) -> float:
    if random_dopant_fluctuation_sigma <= 0.0:
        raise ValueError("random_dopant_fluctuation_sigma must be positive")
    return normal_cdf(threshold_voltage_difference / random_dopant_fluctuation_sigma)


def assess_reliability_and_uniqueness(
    intra_device_pairs: Sequence[ResponsePair],
    inter_device_pairs: Sequence[ResponsePair],
    thresholds: ReliabilityThresholds = ReliabilityThresholds(),
) -> ReliabilityAssessment:
    if not intra_device_pairs or not inter_device_pairs:
        raise ValueError("intra-device and inter-device evidence are both required")

    threshold_values = (
        thresholds.maximum_intra_device_mean_hd,
        thresholds.maximum_intra_device_max_hd,
        thresholds.minimum_inter_device_mean_hd,
        thresholds.maximum_inter_device_deviation,
    )
    if any(not 0.0 <= value <= 1.0 for value in threshold_values):
        raise ValueError("reliability thresholds must be within [0, 1]")

    intra_distances = [pair.normalized_hamming_distance() for pair in intra_device_pairs]
    inter_distances = [pair.normalized_hamming_distance() for pair in inter_device_pairs]
    intra_mean = mean(intra_distances)
    inter_mean = mean(inter_distances)
    intra_max = max(intra_distances)
    inter_deviation = pstdev(inter_distances)

    reliability_score = max(
        0.0,
        min(1.0, 1.0 - intra_mean / thresholds.maximum_intra_device_mean_hd),
    )
    uniqueness_mean_score = max(0.0, min(1.0, inter_mean / 0.50))
    uniqueness_spread_score = max(
        0.0,
        min(1.0, 1.0 - inter_deviation / thresholds.maximum_inter_device_deviation),
    )
    uniqueness_score = 0.80 * uniqueness_mean_score + 0.20 * uniqueness_spread_score

    if inter_mean < thresholds.minimum_inter_device_mean_hd:
        disposition = ReliabilityDisposition.INSUFFICIENT_UNIQUENESS_EVIDENCE
    elif (
        intra_mean > thresholds.maximum_intra_device_mean_hd
        or intra_max > thresholds.maximum_intra_device_max_hd
    ):
        disposition = ReliabilityDisposition.INSUFFICIENT_RELIABILITY_EVIDENCE
    elif inter_deviation > thresholds.maximum_inter_device_deviation:
        disposition = ReliabilityDisposition.MONITOR_ENVIRONMENTAL_SENSITIVITY
    else:
        disposition = ReliabilityDisposition.SUITABLE_FOR_RESEARCH_EVALUATION

    return ReliabilityAssessment(
        intra_device_mean_normalized_hd=intra_mean,
        inter_device_mean_normalized_hd=inter_mean,
        intra_device_max_normalized_hd=intra_max,
        inter_device_standard_deviation=inter_deviation,
        reliability_score=reliability_score,
        uniqueness_score=uniqueness_score,
        disposition=disposition,
    )


def binomial_tail_probability(
    codeword_length: int,
    correction_capacity: int,
    independent_bit_error_probability: float,
) -> float:
    if (
        codeword_length <= 0
        or correction_capacity < 0
        or correction_capacity >= codeword_length
        or not 0.0 <= independent_bit_error_probability <= 1.0
    ):
        raise ValueError("invalid binomial error-model parameters")

    probability = independent_bit_error_probability
    inverse_probability = 1.0 - probability
    return sum(
        comb(codeword_length, error_count)
        * probability**error_count
        * inverse_probability ** (codeword_length - error_count)
        for error_count in range(correction_capacity + 1, codeword_length + 1)
    )


def assess_bch_reconstruction(
    parameters: BchParameters,
    independent_bit_error_probability: float,
    target_failure_probability: float = 1e-9,
) -> ReconstructionAssessment:
    parameters.validate()
    if not 0.0 <= independent_bit_error_probability <= 1.0:
        raise ValueError("independent_bit_error_probability must be within [0, 1]")
    if not 0.0 <= target_failure_probability <= 1.0:
        raise ValueError("target_failure_probability must be within [0, 1]")

    predicted_failure = binomial_tail_probability(
        parameters.codeword_length,
        parameters.correction_capacity,
        independent_bit_error_probability,
    )
    disposition = (
        ReconstructionDisposition.WITHIN_TARGET_BOUND
        if predicted_failure <= target_failure_probability
        else ReconstructionDisposition.EXCEEDS_TARGET_BOUND
    )

    return ReconstructionAssessment(
        codeword_length=parameters.codeword_length,
        correction_capacity=parameters.correction_capacity,
        independent_bit_error_probability=independent_bit_error_probability,
        predicted_failure_probability=predicted_failure,
        target_failure_probability=target_failure_probability,
        helper_data_length_bits=parameters.helper_data_length_bits,
        disposition=disposition,
    )


def minimum_correction_capacity_for_target(
    codeword_length: int,
    independent_bit_error_probability: float,
    target_failure_probability: float = 1e-9,
) -> int:
    if codeword_length <= 0:
        raise ValueError("codeword_length must be positive")
    for correction_capacity in range(codeword_length):
        if (
            binomial_tail_probability(
                codeword_length,
                correction_capacity,
                independent_bit_error_probability,
            )
            <= target_failure_probability
        ):
            return correction_capacity
    raise ValueError("no correction capacity meets the target probability")


def research_example() -> dict[str, object]:
    intra_pairs = (
        ResponsePair(
            left_response=(0, 1, 0, 1, 0, 1, 0, 1, 0, 1),
            right_response=(0, 1, 0, 1, 0, 1, 0, 1, 0, 0),
        ),
        ResponsePair(
            left_response=(1, 0, 1, 0, 1, 0, 1, 0, 1, 0),
            right_response=(1, 0, 1, 0, 1, 0, 1, 0, 0, 0),
        ),
    )
    inter_pairs = (
        ResponsePair(
            left_response=(0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
            right_response=(1, 1, 1, 1, 1, 1, 1, 1, 1, 1),
        ),
        ResponsePair(
            left_response=(0, 1, 0, 1, 0, 1, 0, 1, 0, 1),
            right_response=(1, 0, 1, 0, 1, 0, 1, 0, 1, 0),
        ),
    )
    reliability = assess_reliability_and_uniqueness(intra_pairs, inter_pairs)
    reconstruction = assess_bch_reconstruction(
        BchParameters(
            codeword_length=127,
            message_length=64,
            correction_capacity=20,
        ),
        independent_bit_error_probability=0.05,
    )

    return {
        "arbiter_feature_vector": arbiter_feature_vector((0, 1, 0)),
        "arbiter_delay_difference": arbiter_delay_difference(
            weights=(0.10, -0.20, 0.30, 0.40),
            challenge=(0, 1, 0),
        ),
        "sram_cell_one_probability": sram_cell_one_probability(0.02, 0.01),
        "reliability": asdict(reliability),
        "reconstruction": asdict(reconstruction),
    }
