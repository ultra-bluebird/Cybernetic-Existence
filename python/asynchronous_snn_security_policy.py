from __future__ import annotations

from dataclasses import asdict, dataclass
from enum import StrEnum
from math import exp
from typing import Sequence


class ThresholdDisposition(StrEnum):
    TRANSMIT = "transmit"
    SUPPRESS = "suppress"
    REQUIRE_REVIEW = "require-review"


class ThresholdPolicyDisposition(StrEnum):
    PRESERVES_RESEARCH_TARGET = "preserves-research-target"
    REQUIRES_THRESHOLD_REVIEW = "requires-threshold-review"
    INSUFFICIENT_EVALUATION = "insufficient-evaluation"


class AeadDisposition(StrEnum):
    ACCEPT = "accept"
    REJECT = "reject"
    QUARANTINE = "quarantine"


@dataclass(frozen=True)
class InstitutionalReference:
    reference_id: str
    record_class: str
    permitted_research_use: str
    value_handling: str = "institutionally-controlled"


@dataclass(frozen=True)
class ThresholdContext:
    context_id: str
    baseline_noise_scale: float
    accuracy_floor: float
    telemetry_budget_fraction: float
    minimum_threshold: float
    maximum_threshold: float

    def validate(self) -> None:
        if not self.context_id.strip():
            raise ValueError("context_id is required")
        if self.baseline_noise_scale < 0.0:
            raise ValueError("baseline_noise_scale must be non-negative")
        if not 0.0 <= self.accuracy_floor <= 1.0:
            raise ValueError("accuracy_floor must be within [0, 1]")
        if not 0.0 <= self.telemetry_budget_fraction <= 1.0:
            raise ValueError("telemetry_budget_fraction must be within [0, 1]")
        if self.minimum_threshold < 0.0:
            raise ValueError("minimum_threshold must be non-negative")
        if self.maximum_threshold < self.minimum_threshold:
            raise ValueError("maximum_threshold must be at least minimum_threshold")


@dataclass(frozen=True)
class ThresholdPolicy:
    base_threshold: float
    noise_multiplier: float
    uncertainty_multiplier: float
    novelty_multiplier: float

    def validate(self) -> None:
        values = (
            self.base_threshold,
            self.noise_multiplier,
            self.uncertainty_multiplier,
            self.novelty_multiplier,
        )
        if any(value < 0.0 for value in values):
            raise ValueError("threshold policy values must be non-negative")


@dataclass(frozen=True)
class EventObservation:
    event_id: str
    normalized_amplitude: float
    normalized_uncertainty: float
    normalized_novelty: float

    def validate(self) -> None:
        if not self.event_id.strip():
            raise ValueError("event_id is required")
        if not -1.0 <= self.normalized_amplitude <= 1.0:
            raise ValueError("normalized_amplitude must be within [-1, 1]")
        if not 0.0 <= self.normalized_uncertainty <= 1.0:
            raise ValueError("normalized_uncertainty must be within [0, 1]")
        if not 0.0 <= self.normalized_novelty <= 1.0:
            raise ValueError("normalized_novelty must be within [0, 1]")


@dataclass(frozen=True)
class ThresholdDecision:
    event_id: str
    adaptive_threshold: float
    absolute_amplitude: float
    disposition: ThresholdDisposition


@dataclass(frozen=True)
class ThresholdEvaluation:
    total_events: int
    transmitted_events: int
    suppressed_events: int
    telemetry_fraction: float
    estimated_accuracy: float
    accuracy_floor: float
    disposition: ThresholdPolicyDisposition


@dataclass(frozen=True)
class Aead128Contract:
    contract_id: str
    sender_reference: InstitutionalReference
    receiver_reference: InstitutionalReference
    data_class: str
    permitted_purpose: str
    key_length_bits: int = 128
    nonce_length_bits: int = 128
    tag_length_bits: int = 128
    rate_bits: int = 128
    capacity_bits: int = 192
    state_bits: int = 320
    outer_rounds: int = 12
    inner_rounds: int = 8
    nonce_reuse_prohibited: bool = True
    associated_data_required: bool = True
    authenticated_provenance_required: bool = True
    retention_class: str = "institutionally-controlled"
    approved_implementation_required: bool = True

    def validate(self) -> None:
        if not self.contract_id.strip():
            raise ValueError("contract_id is required")
        if not self.data_class.strip():
            raise ValueError("data_class is required")
        if not self.permitted_purpose.strip():
            raise ValueError("permitted_purpose is required")
        if self.key_length_bits != 128:
            raise ValueError("Ascon-AEAD128 requires a 128-bit key")
        if self.nonce_length_bits != 128:
            raise ValueError("Ascon-AEAD128 requires a 128-bit nonce")
        if self.tag_length_bits != 128:
            raise ValueError("this research profile requires full 128-bit tags")
        if self.rate_bits != 128 or self.capacity_bits != 192:
            raise ValueError("Ascon-AEAD128 requires rate=128 and capacity=192")
        if self.state_bits != 320:
            raise ValueError("Ascon-AEAD128 state must be 320 bits")
        if self.outer_rounds != 12 or self.inner_rounds != 8:
            raise ValueError("Ascon-AEAD128 requires 12 outer and 8 inner rounds")
        if not self.nonce_reuse_prohibited:
            raise ValueError("nonce reuse must be prohibited")
        if not self.associated_data_required:
            raise ValueError("associated data is required for this contract")
        if not self.authenticated_provenance_required:
            raise ValueError("authenticated provenance is required")
        if not self.approved_implementation_required:
            raise ValueError("approved implementation requirement cannot be disabled")


@dataclass(frozen=True)
class TelemetryEnvelope:
    envelope_id: str
    contract_id: str
    sequence_number: int
    nonce_reference: str
    associated_data_digest: str
    ciphertext_digest: str
    authentication_tag_length_bits: int
    sender_reference_id: str
    receiver_reference_id: str
    provenance_event_id: str
    created_at_utc: str

    def validate_against(self, contract: Aead128Contract) -> AeadDisposition:
        contract.validate()
        if (
            not self.envelope_id.strip()
            or not self.contract_id.strip()
            or not self.nonce_reference.strip()
            or not self.associated_data_digest.strip()
            or not self.ciphertext_digest.strip()
            or not self.sender_reference_id.strip()
            or not self.receiver_reference_id.strip()
            or not self.provenance_event_id.strip()
            or not self.created_at_utc.strip()
        ):
            return AeadDisposition.REJECT
        if self.contract_id != contract.contract_id:
            return AeadDisposition.REJECT
        if self.sequence_number < 0:
            return AeadDisposition.REJECT
        if self.authentication_tag_length_bits != contract.tag_length_bits:
            return AeadDisposition.REJECT
        if self.sender_reference_id != contract.sender_reference.reference_id:
            return AeadDisposition.REJECT
        if self.receiver_reference_id != contract.receiver_reference.reference_id:
            return AeadDisposition.REJECT
        return AeadDisposition.ACCEPT


def adaptive_threshold(
    context: ThresholdContext,
    policy: ThresholdPolicy,
    observation: EventObservation,
) -> float:
    context.validate()
    policy.validate()
    observation.validate()

    candidate = (
        policy.base_threshold
        + policy.noise_multiplier * context.baseline_noise_scale
        + policy.uncertainty_multiplier * observation.normalized_uncertainty
        - policy.novelty_multiplier * observation.normalized_novelty
    )
    return min(max(candidate, context.minimum_threshold), context.maximum_threshold)


def threshold_decision(
    context: ThresholdContext,
    policy: ThresholdPolicy,
    observation: EventObservation,
) -> ThresholdDecision:
    threshold = adaptive_threshold(context, policy, observation)
    amplitude = abs(observation.normalized_amplitude)

    if observation.normalized_uncertainty >= 0.95:
        disposition = ThresholdDisposition.REQUIRE_REVIEW
    elif amplitude > threshold:
        disposition = ThresholdDisposition.TRANSMIT
    else:
        disposition = ThresholdDisposition.SUPPRESS

    return ThresholdDecision(
        event_id=observation.event_id,
        adaptive_threshold=threshold,
        absolute_amplitude=amplitude,
        disposition=disposition,
    )


def evaluate_threshold_policy(
    context: ThresholdContext,
    policy: ThresholdPolicy,
    events: Sequence[EventObservation],
    estimated_accuracy: float,
) -> ThresholdEvaluation:
    context.validate()
    policy.validate()
    if not events:
        raise ValueError("at least one event is required")
    if not 0.0 <= estimated_accuracy <= 1.0:
        raise ValueError("estimated_accuracy must be within [0, 1]")

    decisions = [threshold_decision(context, policy, event) for event in events]
    transmitted = sum(
        decision.disposition == ThresholdDisposition.TRANSMIT
        for decision in decisions
    )
    suppressed = sum(
        decision.disposition == ThresholdDisposition.SUPPRESS
        for decision in decisions
    )
    telemetry_fraction = transmitted / len(events)

    if estimated_accuracy < context.accuracy_floor:
        disposition = ThresholdPolicyDisposition.REQUIRES_THRESHOLD_REVIEW
    elif telemetry_fraction > context.telemetry_budget_fraction:
        disposition = ThresholdPolicyDisposition.REQUIRES_THRESHOLD_REVIEW
    else:
        disposition = ThresholdPolicyDisposition.PRESERVES_RESEARCH_TARGET

    return ThresholdEvaluation(
        total_events=len(events),
        transmitted_events=transmitted,
        suppressed_events=suppressed,
        telemetry_fraction=telemetry_fraction,
        estimated_accuracy=estimated_accuracy,
        accuracy_floor=context.accuracy_floor,
        disposition=disposition,
    )


def estimated_transmission_rate(
    threshold: float,
    signal_scale: float,
) -> float:
    if threshold < 0.0 or signal_scale <= 0.0:
        raise ValueError("threshold must be non-negative and signal_scale must be positive")
    return exp(-threshold / signal_scale)


def example_specification() -> dict[str, object]:
    sender = InstitutionalReference(
        reference_id="INT-REF-NODE-CLASS",
        record_class="managed-interface-component",
        permitted_research_use="telemetry-contract-reference",
    )
    receiver = InstitutionalReference(
        reference_id="INT-REF-LOCAL-HUB",
        record_class="managed-local-processing-boundary",
        permitted_research_use="telemetry-contract-reference",
    )
    contract = Aead128Contract(
        contract_id="SEC-ASCON-AEAD128-001",
        sender_reference=sender,
        receiver_reference=receiver,
        data_class="deidentified-event-summary",
        permitted_purpose="authorized-assistive-research-analysis",
    )
    context = ThresholdContext(
        context_id="SNN-CONTEXT-RESTING-001",
        baseline_noise_scale=0.08,
        accuracy_floor=0.75,
        telemetry_budget_fraction=0.35,
        minimum_threshold=0.10,
        maximum_threshold=0.90,
    )
    policy = ThresholdPolicy(
        base_threshold=0.25,
        noise_multiplier=1.0,
        uncertainty_multiplier=0.15,
        novelty_multiplier=0.05,
    )
    events = (
        EventObservation("evt-001", 0.50, 0.10, 0.20),
        EventObservation("evt-002", 0.18, 0.15, 0.10),
        EventObservation("evt-003", 0.75, 0.10, 0.30),
        EventObservation("evt-004", 0.25, 0.96, 0.20),
    )
    evaluation = evaluate_threshold_policy(
        context=context,
        policy=policy,
        events=events,
        estimated_accuracy=0.81,
    )
    envelope = TelemetryEnvelope(
        envelope_id="ENV-001",
        contract_id=contract.contract_id,
        sequence_number=1,
        nonce_reference="managed-unique-nonce-reference",
        associated_data_digest="sha256:associated-data-digest-reference",
        ciphertext_digest="sha256:ciphertext-digest-reference",
        authentication_tag_length_bits=128,
        sender_reference_id=sender.reference_id,
        receiver_reference_id=receiver.reference_id,
        provenance_event_id="PROV-001",
        created_at_utc="2026-09-03T22:00:00Z",
    )

    return {
        "threshold_evaluation": asdict(evaluation),
        "aead_envelope_disposition": envelope.validate_against(contract),
        "illustrative_transmission_rate": estimated_transmission_rate(0.33, 0.20),
    }
