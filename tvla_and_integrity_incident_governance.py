# mk-bluebird/Cybercore/research/tvla_and_integrity_incident_governance.py
from __future__ import annotations

from dataclasses import asdict, dataclass
from enum import StrEnum
from math import sqrt


class TvlaDisposition(StrEnum):
    NO_FIRST_ORDER_LEAKAGE_DETECTED = "no-first-order-leakage-detected"
    LEAKAGE_DETECTED = "leakage-detected"
    MEASUREMENT_COVERAGE_INSUFFICIENT = "measurement-coverage-insufficient"
    INVALID_MEASUREMENT_RECORD = "invalid-measurement-record"


class IncidentState(StrEnum):
    MONITORING = "monitoring"
    ANOMALY_DETECTED = "anomaly-detected"
    SENSITIVE_STATE_PROTECTED = "sensitive-state-protected"
    INTERFACE_ISOLATED = "interface-isolated"
    AWAITING_AUTHORIZED_REVIEW = "awaiting-authorized-review"
    RESOLVED_BY_AUTHORIZED_REVIEW = "resolved-by-authorized-review"


class IncidentDisposition(StrEnum):
    NO_INCIDENT = "no-incident"
    RECORD_AND_REVIEW = "record-and-review"
    PROTECT_AND_ISOLATE = "protect-and-isolate"
    INVALID_EVENT = "invalid-event"


@dataclass(frozen=True)
class InstitutionalReference:
    reference_id: str
    record_class: str
    permitted_research_use: str
    value_handling: str = "institutionally-controlled"


@dataclass(frozen=True)
class WelchTvlaInput:
    fixed_trace_count: int
    random_trace_count: int
    fixed_mean: float
    random_mean: float
    fixed_variance: float
    random_variance: float
    screening_threshold: float
    required_trace_count_per_class: int


@dataclass(frozen=True)
class WelchTvlaAssessment:
    absolute_t_value: float | None
    screening_threshold: float
    fixed_trace_count: int
    random_trace_count: int
    disposition: TvlaDisposition


@dataclass(frozen=True)
class IntegrityMonitorPolicy:
    impedance_delta_threshold: float
    required_consecutive_breaches: int
    maximum_detection_cycles: int

    def validate(self) -> None:
        if (
            self.impedance_delta_threshold < 0.0
            or self.required_consecutive_breaches <= 0
            or self.maximum_detection_cycles <= 0
        ):
            raise ValueError("integrity-monitor policy parameters are invalid")


@dataclass(frozen=True)
class IntegrityObservation:
    observation_id: str
    protected_component_reference: InstitutionalReference
    elapsed_cycles_since_sampling: int
    baseline_impedance_reference: str
    current_impedance_reference: str
    normalized_impedance_delta: float
    measurement_quality: float
    measurement_provenance_reference: str

    def validate(self) -> None:
        if (
            not self.observation_id.strip()
            or self.elapsed_cycles_since_sampling < 0
            or not self.baseline_impedance_reference.strip()
            or not self.current_impedance_reference.strip()
            or self.normalized_impedance_delta < 0.0
            or not 0.0 <= self.measurement_quality <= 1.0
            or not self.measurement_provenance_reference.strip()
        ):
            raise ValueError("integrity observation parameters are invalid")


@dataclass(frozen=True)
class IncidentActionRecord:
    incident_id: str
    state: IncidentState
    action_id: str
    action_class: str
    completed_within_cycles: int | None
    protected_state_reference: str
    audit_event_reference: str
    authorized_review_required: bool


@dataclass(frozen=True)
class IncidentAssessment:
    incident_id: str
    normalized_impedance_delta: float
    breach_detected: bool
    detection_within_policy: bool
    state: IncidentState
    disposition: IncidentDisposition
    required_actions: tuple[IncidentActionRecord, ...]


def assess_welch_tvla(input_value: WelchTvlaInput) -> WelchTvlaAssessment:
    valid = (
        input_value.fixed_trace_count >= 2
        and input_value.random_trace_count >= 2
        and input_value.required_trace_count_per_class >= 2
        and input_value.fixed_variance >= 0.0
        and input_value.random_variance >= 0.0
        and input_value.screening_threshold > 0.0
    )
    if not valid:
        return WelchTvlaAssessment(
            absolute_t_value=None,
            screening_threshold=input_value.screening_threshold,
            fixed_trace_count=input_value.fixed_trace_count,
            random_trace_count=input_value.random_trace_count,
            disposition=TvlaDisposition.INVALID_MEASUREMENT_RECORD,
        )

    if (
        input_value.fixed_trace_count < input_value.required_trace_count_per_class
        or input_value.random_trace_count < input_value.required_trace_count_per_class
    ):
        return WelchTvlaAssessment(
            absolute_t_value=None,
            screening_threshold=input_value.screening_threshold,
            fixed_trace_count=input_value.fixed_trace_count,
            random_trace_count=input_value.random_trace_count,
            disposition=TvlaDisposition.MEASUREMENT_COVERAGE_INSUFFICIENT,
        )

    denominator = sqrt(
        input_value.fixed_variance / input_value.fixed_trace_count
        + input_value.random_variance / input_value.random_trace_count
    )
    if denominator == 0.0:
        return WelchTvlaAssessment(
            absolute_t_value=None,
            screening_threshold=input_value.screening_threshold,
            fixed_trace_count=input_value.fixed_trace_count,
            random_trace_count=input_value.random_trace_count,
            disposition=TvlaDisposition.INVALID_MEASUREMENT_RECORD,
        )

    absolute_t_value = abs((input_value.fixed_mean - input_value.random_mean) / denominator)
    disposition = (
        TvlaDisposition.NO_FIRST_ORDER_LEAKAGE_DETECTED
        if absolute_t_value < input_value.screening_threshold
        else TvlaDisposition.LEAKAGE_DETECTED
    )
    return WelchTvlaAssessment(
        absolute_t_value=absolute_t_value,
        screening_threshold=input_value.screening_threshold,
        fixed_trace_count=input_value.fixed_trace_count,
        random_trace_count=input_value.random_trace_count,
        disposition=disposition,
    )


def assess_integrity_incident(
    policy: IntegrityMonitorPolicy,
    observation: IntegrityObservation,
    consecutive_breach_count: int,
) -> IncidentAssessment:
    policy.validate()
    observation.validate()
    if consecutive_breach_count < 0:
        raise ValueError("consecutive_breach_count must be non-negative")

    incident_id = f"INCIDENT-{observation.observation_id}"
    measurement_is_usable = observation.measurement_quality >= 0.57
    breach_detected = (
        measurement_is_usable
        and observation.normalized_impedance_delta > policy.impedance_delta_threshold
    )
    detection_within_policy = (
        observation.elapsed_cycles_since_sampling <= policy.maximum_detection_cycles
    )

    if not breach_detected:
        return IncidentAssessment(
            incident_id=incident_id,
            normalized_impedance_delta=observation.normalized_impedance_delta,
            breach_detected=False,
            detection_within_policy=detection_within_policy,
            state=IncidentState.MONITORING,
            disposition=IncidentDisposition.NO_INCIDENT,
            required_actions=(),
        )

    if consecutive_breach_count < policy.required_consecutive_breaches:
        return IncidentAssessment(
            incident_id=incident_id,
            normalized_impedance_delta=observation.normalized_impedance_delta,
            breach_detected=True,
            detection_within_policy=detection_within_policy,
            state=IncidentState.ANOMALY_DETECTED,
            disposition=IncidentDisposition.RECORD_AND_REVIEW,
            required_actions=(
                IncidentActionRecord(
                    incident_id=incident_id,
                    state=IncidentState.ANOMALY_DETECTED,
                    action_id="ACTION-RECORD-ANOMALY",
                    action_class="privacy-minimized-audit-record",
                    completed_within_cycles=observation.elapsed_cycles_since_sampling,
                    protected_state_reference="not-applicable",
                    audit_event_reference=observation.measurement_provenance_reference,
                    authorized_review_required=True,
                ),
            ),
        )

    return IncidentAssessment(
        incident_id=incident_id,
        normalized_impedance_delta=observation.normalized_impedance_delta,
        breach_detected=True,
        detection_within_policy=detection_within_policy,
        state=IncidentState.AWAITING_AUTHORIZED_REVIEW,
        disposition=IncidentDisposition.PROTECT_AND_ISOLATE,
        required_actions=(
            IncidentActionRecord(
                incident_id=incident_id,
                state=IncidentState.SENSITIVE_STATE_PROTECTED,
                action_id="ACTION-PROTECT-VOLATILE-STATE",
                action_class="approved-sensitive-state-protection",
                completed_within_cycles=observation.elapsed_cycles_since_sampling,
                protected_state_reference="managed-volatile-state-reference",
                audit_event_reference=observation.measurement_provenance_reference,
                authorized_review_required=True,
            ),
            IncidentActionRecord(
                incident_id=incident_id,
                state=IncidentState.INTERFACE_ISOLATED,
                action_id="ACTION-ISOLATE-DATA-INTERFACE",
                action_class="logical-interface-isolation",
                completed_within_cycles=observation.elapsed_cycles_since_sampling,
                protected_state_reference="managed-interface-boundary-reference",
                audit_event_reference=observation.measurement_provenance_reference,
                authorized_review_required=True,
            ),
            IncidentActionRecord(
                incident_id=incident_id,
                state=IncidentState.AWAITING_AUTHORIZED_REVIEW,
                action_id="ACTION-OPEN-AUTHORIZED-REVIEW",
                action_class="institutional-incident-review",
                completed_within_cycles=None,
                protected_state_reference="not-applicable",
                audit_event_reference=observation.measurement_provenance_reference,
                authorized_review_required=True,
            ),
        ),
    )


def research_example() -> dict[str, object]:
    tvla = assess_welch_tvla(
        WelchTvlaInput(
            fixed_trace_count=1_000_000_000,
            random_trace_count=1_000_000_000,
            fixed_mean=1.000_000_000,
            random_mean=1.000_000_001,
            fixed_variance=1.0,
            random_variance=1.0,
            screening_threshold=2.3,
            required_trace_count_per_class=1_000_000_000,
        )
    )
    component_reference = InstitutionalReference(
        reference_id="INT-REF-HW-SECURITY-001",
        record_class="managed-hardware-security-record",
        permitted_research_use="deidentified-integrity-governance",
    )
    incident = assess_integrity_incident(
        IntegrityMonitorPolicy(
            impedance_delta_threshold=0.15,
            required_consecutive_breaches=2,
            maximum_detection_cycles=3,
        ),
        IntegrityObservation(
            observation_id="OBS-001",
            protected_component_reference=component_reference,
            elapsed_cycles_since_sampling=3,
            baseline_impedance_reference="BASELINE-REFERENCE",
            current_impedance_reference="CURRENT-REFERENCE",
            normalized_impedance_delta=0.20,
            measurement_quality=0.90,
            measurement_provenance_reference="MEASUREMENT-PROVENANCE-001",
        ),
        consecutive_breach_count=2,
    )
    return {
        "tvla_assessment": asdict(tvla),
        "incident_assessment": asdict(incident),
    }
