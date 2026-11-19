# mk-bluebird/Cybercore/research/puf_feed_forward_xor_evaluation.py
from __future__ import annotations

from dataclasses import asdict, dataclass
from enum import StrEnum
from typing import Sequence


class PufTopology(StrEnum):
    LINEAR_ARBITER = "linear-arbiter"
    XOR_ARBITER = "xor-arbiter"
    FEED_FORWARD_ARBITER = "feed-forward-arbiter"
    FEED_FORWARD_XOR_ARBITER = "feed-forward-xor-arbiter"


class AttackFamily(StrEnum):
    LOGISTIC_REGRESSION = "logistic-regression"
    COVARIANCE_MATRIX_ADAPTATION = "covariance-matrix-adaptation"
    DEEP_NEURAL_NETWORK = "deep-neural-network"
    CHOSEN_CHALLENGE = "chosen-challenge"
    RELIABILITY_BASED = "reliability-based"
    SIDE_CHANNEL_ASSISTED = "side-channel-assisted"
    OTHER = "other"


class ResistanceDisposition(StrEnum):
    NO_EVIDENCE_OF_RESISTANCE = "no-evidence-of-resistance"
    LIMITED_RESISTANCE_IN_DECLARED_EXPERIMENT = "limited-resistance-in-declared-experiment"
    REQUIRES_INDEPENDENT_ATTACK_EVALUATION = "requires-independent-attack-evaluation"
    ACCESS_CONTROL_REQUIRED = "access-control-required"


@dataclass(frozen=True)
class InstitutionalReference:
    reference_id: str
    record_class: str
    permitted_research_use: str
    value_handling: str = "institutionally-controlled"


@dataclass(frozen=True)
class FeedForwardLoop:
    tap_stage: int
    override_stage: int

    def validate(self, challenge_dimensions: int) -> None:
        if (
            self.tap_stage <= 0
            or self.override_stage <= 0
            or self.tap_stage >= self.override_stage
            or self.override_stage > challenge_dimensions
        ):
            raise ValueError("feed-forward loop stages must satisfy 0 < tap < override <= n")


@dataclass(frozen=True)
class PufTopologyProfile:
    profile_id: str
    institutional_reference: InstitutionalReference
    topology: PufTopology
    challenge_dimensions: int
    parallel_streams: int
    feed_forward_loops: tuple[FeedForwardLoop, ...]
    response_access_policy_id: str

    def validate(self) -> None:
        if not self.profile_id.strip():
            raise ValueError("profile_id is required")
        if self.challenge_dimensions <= 0 or self.parallel_streams <= 0:
            raise ValueError("challenge dimensions and parallel streams must be positive")
        if not self.response_access_policy_id.strip():
            raise ValueError("response_access_policy_id is required")

        for loop_specification in self.feed_forward_loops:
            loop_specification.validate(self.challenge_dimensions)

        if self.topology == PufTopology.LINEAR_ARBITER:
            if self.parallel_streams != 1 or self.feed_forward_loops:
                raise ValueError("linear arbiter profile requires one stream and no FF loops")
        elif self.topology == PufTopology.XOR_ARBITER:
            if self.parallel_streams < 2 or self.feed_forward_loops:
                raise ValueError("XOR arbiter profile requires two or more streams and no FF loops")
        elif self.topology == PufTopology.FEED_FORWARD_ARBITER:
            if self.parallel_streams != 1 or not self.feed_forward_loops:
                raise ValueError("feed-forward arbiter profile requires one stream and FF loops")
        elif self.topology == PufTopology.FEED_FORWARD_XOR_ARBITER:
            if self.parallel_streams < 2 or not self.feed_forward_loops:
                raise ValueError("FF-XOR profile requires two or more streams and FF loops")


@dataclass(frozen=True)
class ModelingAttackRecord:
    attack_id: str
    topology_profile_id: str
    attack_family: AttackFamily
    challenge_response_pair_budget: int
    chosen_challenge_access: bool
    reliability_side_information: bool
    side_channel_information: bool
    training_accuracy: float
    held_out_accuracy: float
    held_out_confidence_interval_lower: float
    held_out_confidence_interval_upper: float
    evaluation_protocol_reference: str
    source_reference: str

    def validate(self) -> None:
        if (
            not self.attack_id.strip()
            or not self.topology_profile_id.strip()
            or self.challenge_response_pair_budget <= 0
            or not self.evaluation_protocol_reference.strip()
            or not self.source_reference.strip()
        ):
            raise ValueError("attack record contains a required empty field")

        values = (
            self.training_accuracy,
            self.held_out_accuracy,
            self.held_out_confidence_interval_lower,
            self.held_out_confidence_interval_upper,
        )
        if any(not 0.0 <= value <= 1.0 for value in values):
            raise ValueError("attack accuracies must be normalized to [0, 1]")
        if not (
            self.held_out_confidence_interval_lower
            <= self.held_out_accuracy
            <= self.held_out_confidence_interval_upper
        ):
            raise ValueError("held-out accuracy must lie inside its confidence interval")

    @property
    def advantage_over_random(self) -> float:
        self.validate()
        return max(0.0, self.held_out_accuracy - 0.50)


@dataclass(frozen=True)
class AttackEvaluationThresholds:
    maximum_held_out_accuracy: float = 0.55
    maximum_confidence_interval_lower: float = 0.50
    minimum_attack_families: int = 3
    minimum_independent_evaluations: int = 2


@dataclass(frozen=True)
class ResistanceAssessment:
    profile_id: str
    worst_held_out_accuracy: float
    worst_advantage_over_random: float
    attack_family_count: int
    independent_evaluation_count: int
    chosen_challenge_evaluated: bool
    reliability_information_evaluated: bool
    side_channel_evaluated: bool
    disposition: ResistanceDisposition


def xor_response(component_responses: Sequence[int]) -> int:
    if not component_responses or any(bit not in (0, 1) for bit in component_responses):
        raise ValueError("component responses must be a non-empty binary sequence")

    response = 0
    for bit in component_responses:
        response ^= bit
    return response


def arbiter_feature_vector(challenge: Sequence[int]) -> tuple[int, ...]:
    if not challenge or any(bit not in (0, 1) for bit in challenge):
        raise ValueError("challenge must be a non-empty binary sequence")

    features: list[int] = []
    for index in range(len(challenge)):
        product = 1
        for bit in challenge[index:]:
            product *= 1 - 2 * bit
        features.append(product)
    features.append(1)
    return tuple(features)


def feed_forward_override(
    challenge: Sequence[int],
    tap_stage_zero_based: int,
    override_stage_zero_based: int,
    intermediate_response: int,
) -> tuple[int, ...]:
    if (
        not challenge
        or any(bit not in (0, 1) for bit in challenge)
        or intermediate_response not in (0, 1)
        or tap_stage_zero_based < 0
        or override_stage_zero_based < 0
        or tap_stage_zero_based >= override_stage_zero_based
        or override_stage_zero_based >= len(challenge)
    ):
        raise ValueError("invalid feed-forward override parameters")

    modified = list(challenge)
    modified[override_stage_zero_based] = intermediate_response
    return tuple(modified)


def feed_forward_feature_vector(
    challenge: Sequence[int],
    tap_stage_zero_based: int,
    override_stage_zero_based: int,
    intermediate_response: int,
) -> tuple[int, ...]:
    modified = feed_forward_override(
        challenge,
        tap_stage_zero_based,
        override_stage_zero_based,
        intermediate_response,
    )
    return arbiter_feature_vector(modified)


def assess_modeling_resistance(
    profile: PufTopologyProfile,
    records: Sequence[ModelingAttackRecord],
    thresholds: AttackEvaluationThresholds = AttackEvaluationThresholds(),
) -> ResistanceAssessment:
    profile.validate()
    if (
        not 0.0 <= thresholds.maximum_held_out_accuracy <= 1.0
        or not 0.0 <= thresholds.maximum_confidence_interval_lower <= 1.0
        or thresholds.minimum_attack_families <= 0
        or thresholds.minimum_independent_evaluations <= 0
    ):
        raise ValueError("invalid attack-evaluation thresholds")

    matched = [
        record
        for record in records
        if record.topology_profile_id == profile.profile_id
    ]
    if not matched:
        raise ValueError("no attack-evaluation records match this profile")
    for record in matched:
        record.validate()

    worst = max(matched, key=lambda record: record.held_out_accuracy)
    attack_family_count = len({record.attack_family for record in matched})
    independent_evaluation_count = len({record.source_reference for record in matched})
    chosen_challenge_evaluated = any(record.chosen_challenge_access for record in matched)
    reliability_information_evaluated = any(
        record.reliability_side_information for record in matched
    )
    side_channel_evaluated = any(record.side_channel_information for record in matched)

    sufficient_coverage = (
        attack_family_count >= thresholds.minimum_attack_families
        and independent_evaluation_count >= thresholds.minimum_independent_evaluations
    )

    if worst.held_out_accuracy > thresholds.maximum_held_out_accuracy:
        disposition = ResistanceDisposition.NO_EVIDENCE_OF_RESISTANCE
    elif (
        not sufficient_coverage
        or not chosen_challenge_evaluated
        or not reliability_information_evaluated
    ):
        disposition = ResistanceDisposition.REQUIRES_INDEPENDENT_ATTACK_EVALUATION
    elif not side_channel_evaluated:
        disposition = ResistanceDisposition.ACCESS_CONTROL_REQUIRED
    else:
        disposition = ResistanceDisposition.LIMITED_RESISTANCE_IN_DECLARED_EXPERIMENT

    return ResistanceAssessment(
        profile_id=profile.profile_id,
        worst_held_out_accuracy=worst.held_out_accuracy,
        worst_advantage_over_random=worst.advantage_over_random,
        attack_family_count=attack_family_count,
        independent_evaluation_count=independent_evaluation_count,
        chosen_challenge_evaluated=chosen_challenge_evaluated,
        reliability_information_evaluated=reliability_information_evaluated,
        side_channel_evaluated=side_channel_evaluated,
        disposition=disposition,
    )


def research_example() -> dict[str, object]:
    reference = InstitutionalReference(
        reference_id="INT-REF-PUF-TOPOLOGY",
        record_class="managed-hardware-security-record",
        permitted_research_use="deidentified-security-evaluation",
    )
    profile = PufTopologyProfile(
        profile_id="PUF-FF-XOR-128-08",
        institutional_reference=reference,
        topology=PufTopology.FEED_FORWARD_XOR_ARBITER,
        challenge_dimensions=128,
        parallel_streams=8,
        feed_forward_loops=(FeedForwardLoop(tap_stage=33, override_stage=69),),
        response_access_policy_id="ACCESS-POLICY-CRP-001",
    )
    records = (
        ModelingAttackRecord(
            attack_id="ATTACK-DNN-001",
            topology_profile_id=profile.profile_id,
            attack_family=AttackFamily.DEEP_NEURAL_NETWORK,
            challenge_response_pair_budget=1_000_000,
            chosen_challenge_access=False,
            reliability_side_information=False,
            side_channel_information=False,
            training_accuracy=0.53,
            held_out_accuracy=0.51,
            held_out_confidence_interval_lower=0.49,
            held_out_confidence_interval_upper=0.53,
            evaluation_protocol_reference="EVAL-PROTOCOL-001",
            source_reference="SOURCE-EVAL-001",
        ),
    )
    assessment = assess_modeling_resistance(profile, records)

    return {
        "linear_feature_vector": arbiter_feature_vector((0, 1, 0, 1)),
        "feed_forward_feature_vector": feed_forward_feature_vector(
            challenge=(0, 1, 0, 1),
            tap_stage_zero_based=1,
            override_stage_zero_based=3,
            intermediate_response=0,
        ),
        "xor_response": xor_response((1, 0, 1, 1)),
        "resistance_assessment": asdict(assessment),
    }
