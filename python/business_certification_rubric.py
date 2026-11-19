from __future__ import annotations

from dataclasses import dataclass
from typing import Literal


CertificationTier = Literal[
    "not_certified",
    "bronze",
    "silver",
    "gold",
    "review_required",
]


@dataclass(frozen=True)
class BusinessCertificationEvidence:
    physical_access_points: float
    communication_access_points: float
    sensory_accommodation_points: float
    non_discrimination_privacy_points: float
    staff_training_points: float
    community_accountability_points: float
    non_discrimination_statement_present: bool
    accessible_grievance_path_present: bool
    mandatory_sensitive_disclosure: bool
    adverse_sensitive_data_use: bool
    material_entry_barrier_unaddressed: bool
    independent_audit_permitted: bool
    material_complaint_unresolved: bool
    verified_staff_training: bool
    verified_feedback_loop: bool
    recurring_independent_audit: bool
    corrective_action_effectiveness_verified: bool


@dataclass(frozen=True)
class CertificationResult:
    tier: CertificationTier
    score: float
    gates_passed: bool
    failed_gates: tuple[str, ...]
    reason: str


def bounded_points(value: float, maximum: float) -> float:
    return max(0.0, min(float(value), maximum))


def calculate_business_certification(
    evidence: BusinessCertificationEvidence,
) -> CertificationResult:
    score = (
        bounded_points(evidence.physical_access_points, 30.0)
        + bounded_points(evidence.communication_access_points, 20.0)
        + bounded_points(evidence.sensory_accommodation_points, 15.0)
        + bounded_points(evidence.non_discrimination_privacy_points, 15.0)
        + bounded_points(evidence.staff_training_points, 15.0)
        + bounded_points(evidence.community_accountability_points, 5.0)
    )

    gates = {
        "non_discrimination_statement": evidence.non_discrimination_statement_present,
        "accessible_grievance_path": evidence.accessible_grievance_path_present,
        "no_mandatory_sensitive_disclosure": not evidence.mandatory_sensitive_disclosure,
        "no_adverse_sensitive_data_use": not evidence.adverse_sensitive_data_use,
        "no_unaddressed_material_entry_barrier": not evidence.material_entry_barrier_unaddressed,
        "independent_audit_permitted": evidence.independent_audit_permitted,
        "no_material_unresolved_complaint": not evidence.material_complaint_unresolved,
    }
    failed_gates = tuple(name for name, passed in gates.items() if not passed)

    if failed_gates:
        return CertificationResult(
            tier="review_required",
            score=round(score, 2),
            gates_passed=False,
            failed_gates=failed_gates,
            reason="Mandatory voluntary-certification gates require review or corrective action.",
        )

    if score < 55.0:
        return CertificationResult(
            tier="not_certified",
            score=round(score, 2),
            gates_passed=True,
            failed_gates=(),
            reason="Evidence does not yet meet the voluntary certification threshold.",
        )

    if score >= 85.0:
        if (
            evidence.recurring_independent_audit
            and evidence.corrective_action_effectiveness_verified
        ):
            return CertificationResult(
                tier="gold",
                score=round(score, 2),
                gates_passed=True,
                failed_gates=(),
                reason="Gold threshold, recurring independent audit, and corrective-action effectiveness are verified.",
            )
        return CertificationResult(
            tier="review_required",
            score=round(score, 2),
            gates_passed=True,
            failed_gates=(),
            reason="Gold score reached; independent audit and corrective-action effectiveness evidence remain required.",
        )

    if score >= 70.0:
        if evidence.verified_staff_training and evidence.verified_feedback_loop:
            return CertificationResult(
                tier="silver",
                score=round(score, 2),
                gates_passed=True,
                failed_gates=(),
                reason="Silver threshold and verified staff training and feedback loop are satisfied.",
            )
        return CertificationResult(
            tier="review_required",
            score=round(score, 2),
            gates_passed=True,
            failed_gates=(),
            reason="Silver score reached; verified staff training and feedback-loop evidence remain required.",
        )

    return CertificationResult(
        tier="bronze",
        score=round(score, 2),
        gates_passed=True,
        failed_gates=(),
        reason="Bronze threshold and mandatory certification gates are satisfied.",
    )
