from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import FrozenSet


class VerificationOutcome(str, Enum):
    VERIFICATION_NOT_REQUIRED = "VERIFICATION_NOT_REQUIRED"
    CLARIFICATION_REQUIRED = "CLARIFICATION_REQUIRED"
    MINIMUM_NECESSARY_INPUT_REQUESTED = "MINIMUM_NECESSARY_INPUT_REQUESTED"
    EXCESSIVE_VERIFICATION_REJECTED = "EXCESSIVE_VERIFICATION_REJECTED"
    REVIEW_REQUIRED = "REVIEW_REQUIRED"


PROHIBITED_FIELD_CATEGORIES: FrozenSet[str] = frozenset(
    {
        "identity_proof",
        "government_identifier",
        "account_credential",
        "biometric_data",
        "medical_record",
        "diagnostic_record",
        "neural_data",
        "device_serial_number",
        "raw_device_identifier",
        "technical_inventory",
        "precise_location",
        "street_address",
        "geometry",
        "raw_spatial_index",
        "institutional_affiliation",
        "augmentation_proof",
        "disability_proof",
    }
)


@dataclass(frozen=True)
class VerificationRequest:
    task_requires_verification: bool
    exact_field_category: str | None
    task_specific_purpose: str | None
    stated_use: str | None
    retention_statement: str | None
    accessible_fallback: str | None
    less_sensitive_alternative_considered: bool
    human_review_available: bool
    attempts_identity_inference: bool = False
    attempts_health_inference: bool = False
    attempts_credibility_inference: bool = False
    attempts_eligibility_determination: bool = False
    attempts_ranking_or_allocation: bool = False
    attempts_enforcement_or_targeting: bool = False


@dataclass(frozen=True)
class VerificationDecision:
    outcome: VerificationOutcome
    message: str
    permitted_field_category: str | None


def evaluate_verification_demand(
    request: VerificationRequest,
) -> VerificationDecision:
    prohibited_purpose = (
        request.attempts_identity_inference
        or request.attempts_health_inference
        or request.attempts_credibility_inference
        or request.attempts_eligibility_determination
        or request.attempts_ranking_or_allocation
        or request.attempts_enforcement_or_targeting
    )

    if prohibited_purpose:
        return VerificationDecision(
            outcome=VerificationOutcome.EXCESSIVE_VERIFICATION_REJECTED,
            message=(
                "The request attempts prohibited inference, ranking, allocation, "
                "eligibility, enforcement, or targeting. It must not proceed."
            ),
            permitted_field_category=None,
        )

    if not request.task_requires_verification:
        return VerificationDecision(
            outcome=VerificationOutcome.VERIFICATION_NOT_REQUIRED,
            message=(
                "Verification is not required for this task. Proceed using the "
                "minimum necessary information and preserve user-defined terminology."
            ),
            permitted_field_category=None,
        )

    if request.exact_field_category is None:
        return VerificationDecision(
            outcome=VerificationOutcome.CLARIFICATION_REQUIRED,
            message=(
                "Name the exact field required for the task, its purpose, intended "
                "use, retention treatment, and accessible fallback."
            ),
            permitted_field_category=None,
        )

    if request.exact_field_category in PROHIBITED_FIELD_CATEGORIES:
        return VerificationDecision(
            outcome=VerificationOutcome.EXCESSIVE_VERIFICATION_REJECTED,
            message=(
                "The requested field category is prohibited for this workflow. "
                "Use a privacy-preserving alternative or route the matter for review."
            ),
            permitted_field_category=None,
        )

    required_text = (
        request.task_specific_purpose,
        request.stated_use,
        request.retention_statement,
        request.accessible_fallback,
    )

    if (
        any(not value or not value.strip() for value in required_text)
        or not request.less_sensitive_alternative_considered
        or not request.human_review_available
    ):
        return VerificationDecision(
            outcome=VerificationOutcome.CLARIFICATION_REQUIRED,
            message=(
                "A task-necessary request must state a specific purpose, use, "
                "retention treatment, accessible fallback, less-sensitive "
                "alternative assessment, and human-review option."
            ),
            permitted_field_category=None,
        )

    return VerificationDecision(
        outcome=VerificationOutcome.MINIMUM_NECESSARY_INPUT_REQUESTED,
        message=(
            "Only the named non-sensitive field may be requested for the stated "
            "task. Do not infer or request additional private information."
        ),
        permitted_field_category=request.exact_field_category,
    )
