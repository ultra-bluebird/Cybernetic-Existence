# mk-bluebird/Cybercore/research/masking_and_wddl_evidence.py
from __future__ import annotations

from dataclasses import asdict, dataclass
from enum import StrEnum
from math import sqrt
from typing import Sequence


class MaskingDisposition(StrEnum):
    STRUCTURALLY_NON_COMPLETE = "structurally-non-complete"
    REQUIRES_SHARE_SEPARATION_REVIEW = "requires-share-separation-review"
    REQUIRES_RANDOMNESS_REVIEW = "requires-randomness-review"


class DualRailDisposition(StrEnum):
    STRUCTURALLY_BALANCED = "structurally-balanced"
    REQUIRES_TRANSITION_BALANCE_REVIEW = "requires-transition-balance-review"
    REQUIRES_PHYSICAL_IMPLEMENTATION_REVIEW = "requires-physical-implementation-review"


class LeakageDisposition(StrEnum):
    NO_STATISTICAL_LEAKAGE_DETECTED = "no-statistical-leakage-detected"
    LEAKAGE_DETECTED = "leakage-detected"
    MEASUREMENT_COVERAGE_INSUFFICIENT = "measurement-coverage-insufficient"


@dataclass(frozen=True)
class InstitutionalReference:
    reference_id: str
    record_class: str
    permitted_research_use: str
    value_handling: str = "institutionally-controlled"


@dataclass(frozen=True)
class MaskedSignal:
    signal_id: str
    share_ids: tuple[str, str, str, str]
    reconstruction_relation: str
    randomness_reference: InstitutionalReference

    def validate(self) -> None:
        if not self.signal_id.strip():
            raise ValueError("signal_id is required")
        if len(set(self.share_ids)) != 4 or any(not share_id.strip() for share_id in self.share_ids):
            raise ValueError("four distinct non-empty shares are required")
        if self.reconstruction_relation != "x0 XOR x1 XOR x2 XOR x3":
            raise ValueError("the required reconstruction relation is x0 XOR x1 XOR x2 XOR x3")


@dataclass(frozen=True)
class GateShareDeclaration:
    gate_id: str
    input_share_ids: tuple[str, ...]
    output_share_id: str
    randomness_input_ids: tuple[str, ...]
    operation_class: str

    def validate(self) -> None:
        if (
            not self.gate_id.strip()
            or not self.input_share_ids
            or any(not share_id.strip() for share_id in self.input_share_ids)
            or not self.output_share_id.strip()
            or not self.operation_class.strip()
        ):
            raise ValueError("gate declaration contains a required empty field")


@dataclass(frozen=True)
class MaskingNetlistProfile:
    profile_id: str
    institutional_reference: InstitutionalReference
    masked_signal: MaskedSignal
    gate_declarations: tuple[GateShareDeclaration, ...]
    declared_probe_order: int
    physical_separation_review_reference: str
    randomness_quality_review_reference: str


@dataclass(frozen=True)
class MaskingAssessment:
    profile_id: str
    highest_share_count_seen_by_one_gate: int
    declared_probe_order: int
    non_complete: bool
    all_required_randomness_declared: bool
    disposition: MaskingDisposition


@dataclass(frozen=True)
class DualRailGateDeclaration:
    gate_id: str
    true_rail_id: str
    complementary_rail_id: str
    nominal_true_transitions: int
    nominal_complementary_transitions: int
    placement_region_reference: str
    routing_region_reference: str

    def validate(self) -> None:
        if (
            not self.gate_id.strip()
            or not self.true_rail_id.strip()
            or not self.complementary_rail_id.strip()
            or self.true_rail_id == self.complementary_rail_id
            or self.nominal_true_transitions < 0
            or self.nominal_complementary_transitions < 0
            or not self.placement_region_reference.strip()
            or not self.routing_region_reference.strip()
        ):
            raise ValueError("invalid dual-rail gate declaration")

    @property
    def transition_delta(self) -> int:
        self.validate()
        return abs(self.nominal_true_transitions - self.nominal_complementary_transitions)


@dataclass(frozen=True)
class DualRailProfile:
    profile_id: str
    institutional_reference: InstitutionalReference
    gates: tuple[DualRailGateDeclaration, ...]
    maximum_allowed_transition_delta: int
    physical_implementation_review_reference: str


@dataclass(frozen=True)
class DualRailAssessment:
    profile_id: str
    maximum_observed_transition_delta: int
    total_nominal_true_transitions: int
    total_nominal_complementary_transitions: int
    structurally_balanced: bool
    disposition: DualRailDisposition


@dataclass(frozen=True)
class LeakageTestResult:
    fixed_trace_count: int
    random_trace_count: int
    fixed_mean: float
    random_mean: float
    fixed_variance: float
    random_variance: float
    absolute_t_threshold: float = 4.5


@dataclass(frozen=True)
class LeakageAssessment:
    absolute_t_value: float
    threshold: float
    disposition: LeakageDisposition


def assess_non_completeness(profile: MaskingNetlistProfile) -> MaskingAssessment:
    profile.masked_signal.validate()
    if (
        not profile.profile_id.strip()
        or not profile.gate_declarations
        or profile.declared_probe_order <= 0
        or profile.declared_probe_order >= 4
        or not profile.physical_separation_review_reference.strip()
        or not profile.randomness_quality_review_reference.strip()
    ):
        raise ValueError("invalid masking netlist profile")

    authorized_shares = set(profile.masked_signal.share_ids)
    highest_share_count = 0
    non_complete = True
    all_required_randomness_declared = True

    for gate in profile.gate_declarations:
        gate.validate()
        visible_shares = set(gate.input_share_ids).intersection(authorized_shares)
        highest_share_count = max(highest_share_count, len(visible_shares))
        if len(visible_shares) >= 4:
            non_complete = False
        if gate.operation_class == "nonlinear" and not gate.randomness_input_ids:
            all_required_randomness_declared = False

    if not non_complete:
        disposition = MaskingDisposition.REQUIRES_SHARE_SEPARATION_REVIEW
    elif not all_required_randomness_declared:
        disposition = MaskingDisposition.REQUIRES_RANDOMNESS_REVIEW
    else:
        disposition = MaskingDisposition.STRUCTURALLY_NON_COMPLETE

    return MaskingAssessment(
        profile_id=profile.profile_id,
        highest_share_count_seen_by_one_gate=highest_share_count,
        declared_probe_order=profile.declared_probe_order,
        non_complete=non_complete,
        all_required_randomness_declared=all_required_randomness_declared,
        disposition=disposition,
    )


def assess_dual_rail_balance(profile: DualRailProfile) -> DualRailAssessment:
    if (
        not profile.profile_id.strip()
        or not profile.gates
        or profile.maximum_allowed_transition_delta < 0
        or not profile.physical_implementation_review_reference.strip()
    ):
        raise ValueError("invalid dual-rail profile")

    for gate in profile.gates:
        gate.validate()

    maximum_delta = max(gate.transition_delta for gate in profile.gates)
    total_true = sum(gate.nominal_true_transitions for gate in profile.gates)
    total_complementary = sum(gate.nominal_complementary_transitions for gate in profile.gates)
    structurally_balanced = maximum_delta <= profile.maximum_allowed_transition_delta

    if not structurally_balanced:
        disposition = DualRailDisposition.REQUIRES_TRANSITION_BALANCE_REVIEW
    else:
        disposition = DualRailDisposition.STRUCTURALLY_BALANCED

    return DualRailAssessment(
        profile_id=profile.profile_id,
        maximum_observed_transition_delta=maximum_delta,
        total_nominal_true_transitions=total_true,
        total_nominal_complementary_transitions=total_complementary,
        structurally_balanced=structurally_balanced,
        disposition=disposition,
    )


def welch_t_assessment(result: LeakageTestResult) -> LeakageAssessment:
    if (
        result.fixed_trace_count < 2
        or result.random_trace_count < 2
        or result.fixed_variance < 0.0
        or result.random_variance < 0.0
        or result.absolute_t_threshold <= 0.0
    ):
        raise ValueError("invalid Welch t-test parameters")

    denominator = sqrt(
        result.fixed_variance / result.fixed_trace_count
        + result.random_variance / result.random_trace_count
    )
    if denominator == 0.0:
        raise ValueError("Welch t-test denominator must be positive")

    absolute_t_value = abs((result.fixed_mean - result.random_mean) / denominator)
    disposition = (
        LeakageDisposition.LEAKAGE_DETECTED
        if absolute_t_value >= result.absolute_t_threshold
        else LeakageDisposition.NO_STATISTICAL_LEAKAGE_DETECTED
    )
    return LeakageAssessment(
        absolute_t_value=absolute_t_value,
        threshold=result.absolute_t_threshold,
        disposition=disposition,
    )


def research_example() -> dict[str, object]:
    reference = InstitutionalReference(
        reference_id="INT-REF-SIDECHANNEL-001",
        record_class="managed-hardware-security-record",
        permitted_research_use="deidentified-side-channel-review",
    )
    signal = MaskedSignal(
        signal_id="state-word-0",
        share_ids=("x0", "x1", "x2", "x3"),
        reconstruction_relation="x0 XOR x1 XOR x2 XOR x3",
        randomness_reference=reference,
    )
    masking = assess_non_completeness(
        MaskingNetlistProfile(
            profile_id="MASK-4SHARE-001",
            institutional_reference=reference,
            masked_signal=signal,
            gate_declarations=(
                GateShareDeclaration(
                    gate_id="gate-0",
                    input_share_ids=("x1", "x2", "x3"),
                    output_share_id="y0",
                    randomness_input_ids=("rho-0",),
                    operation_class="nonlinear",
                ),
                GateShareDeclaration(
                    gate_id="gate-1",
                    input_share_ids=("x0", "x2", "x3"),
                    output_share_id="y1",
                    randomness_input_ids=("rho-1",),
                    operation_class="nonlinear",
                ),
            ),
            declared_probe_order=3,
            physical_separation_review_reference="PHYS-REVIEW-001",
            randomness_quality_review_reference="RNG-REVIEW-001",
        )
    )
    dual_rail = assess_dual_rail_balance(
        DualRailProfile(
            profile_id="WDDL-001",
            institutional_reference=reference,
            gates=(
                DualRailGateDeclaration(
                    gate_id="dual-gate-0",
                    true_rail_id="true-0",
                    complementary_rail_id="false-0",
                    nominal_true_transitions=10,
                    nominal_complementary_transitions=10,
                    placement_region_reference="PLACE-0",
                    routing_region_reference="ROUTE-0",
                ),
            ),
            maximum_allowed_transition_delta=0,
            physical_implementation_review_reference="PHYS-REVIEW-002",
        )
    )
    leakage = welch_t_assessment(
        LeakageTestResult(
            fixed_trace_count=1_000,
            random_trace_count=1_000,
            fixed_mean=0.10,
            random_mean=0.11,
            fixed_variance=1.00,
            random_variance=1.00,
        )
    )

    return {
        "masking_assessment": asdict(masking),
        "dual_rail_assessment": asdict(dual_rail),
        "leakage_assessment": asdict(leakage),
    }
