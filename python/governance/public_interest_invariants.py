from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Iterable, Mapping


class GovernanceValidationError(ValueError):
    pass


ESSENTIAL_SERVICES = frozenset(
    {
        "emergency_shelter",
        "cooling",
        "warming",
        "drinking_water",
        "sanitation",
        "safety_information",
        "emergency_communications",
        "life_safety_services",
    }
)

PROHIBITED_PERSONAL_DECISION_BASES = frozenset(
    {
        "identity",
        "self_asserted_identity",
        "health",
        "disability",
        "augmentation",
        "cybernetic_host_status",
        "assistive_technology",
        "biometric",
        "device_ownership",
        "financial_rank",
        "social_rank",
        "reputation_score",
        "property_value",
        "payment_history",
        "customer_profitability",
    }
)

PROHIBITED_RELEASE_FIELDS = frozenset(
    {
        "person_name",
        "identity",
        "self_asserted_identity",
        "health",
        "disability",
        "augmentation",
        "cybernetic_host_status",
        "assistive_technology",
        "biometric_data",
        "device_identifier",
        "precise_location",
        "movement_history",
        "household_data",
        "property_value",
        "financial_rank",
        "social_rank",
        "reputation_score",
        "individual_vulnerability_score",
    }
)


@dataclass(frozen=True)
class ServiceAccessRequest:
    service_kind: str
    requires_credential: bool
    requires_network: bool
    requires_personal_device: bool
    requires_identity_verification: bool
    requires_sensitive_disclosure: bool
    human_fallback_available: bool
    non_digital_fallback_available: bool


@dataclass(frozen=True)
class ServiceAccessResult:
    compliant: bool
    decision: str
    reason: str


@dataclass(frozen=True)
class DataReleaseRequest:
    fields: frozenset[str]
    aggregate_only: bool
    small_cell_suppression_applied: bool
    epsilon: float | None
    reidentification_risk_present: bool
    discriminatory_or_ranking_purpose: bool
    human_review_complete: bool


@dataclass(frozen=True)
class DataReleaseResult:
    compliant: bool
    decision: str
    reason: str


@dataclass(frozen=True)
class LoadArea:
    public_zone: str
    total_demand_mw: float
    essential_demand_mw: float
    residual_outage_hours: float
    technical_exception_documented: bool

    def __post_init__(self) -> None:
        if not self.public_zone.strip():
            raise GovernanceValidationError("public_zone must be non-empty.")

        for field_name, value in (
            ("total_demand_mw", self.total_demand_mw),
            ("essential_demand_mw", self.essential_demand_mw),
            ("residual_outage_hours", self.residual_outage_hours),
        ):
            if not isfinite(value) or value < 0.0:
                raise GovernanceValidationError(
                    f"{field_name} must be finite and non-negative."
                )

        if self.essential_demand_mw > self.total_demand_mw:
            raise GovernanceValidationError(
                "essential_demand_mw must not exceed total_demand_mw."
            )


@dataclass(frozen=True)
class LoadSheddingResult:
    compliant: bool
    jain_fairness_index: float
    requires_human_review: bool
    reason: str


def evaluate_essential_service_access(
    request: ServiceAccessRequest,
) -> ServiceAccessResult:
    if not request.service_kind.strip():
        raise GovernanceValidationError("service_kind must be non-empty.")

    is_essential = request.service_kind in ESSENTIAL_SERVICES
    prohibited_requirement_present = any(
        (
            request.requires_credential,
            request.requires_network,
            request.requires_personal_device,
            request.requires_identity_verification,
            request.requires_sensitive_disclosure,
        )
    )

    if is_essential and prohibited_requirement_present:
        return ServiceAccessResult(
            compliant=False,
            decision="ESSENTIAL_SERVICE_GATING_VIOLATION",
            reason=(
                "Essential service access must not require credentials, network access, "
                "a personal device, identity verification, or sensitive disclosure."
            ),
        )

    if not request.human_fallback_available or not request.non_digital_fallback_available:
        return ServiceAccessResult(
            compliant=False,
            decision="FALLBACK_PATH_MISSING",
            reason=(
                "A consequential public-service workflow requires both accessible human "
                "and non-digital fallback paths."
            ),
        )

    return ServiceAccessResult(
        compliant=True,
        decision="ACCESS_PATH_COMPLIANT",
        reason=(
            "The service access path preserves non-digital and human fallback without "
            "using prohibited sensitive requirements."
        ),
    )


def evaluate_data_release(request: DataReleaseRequest) -> DataReleaseResult:
    prohibited_fields = sorted(PROHIBITED_RELEASE_FIELDS.intersection(request.fields))

    if prohibited_fields:
        return DataReleaseResult(
            compliant=False,
            decision="PROHIBITED_FIELD_RELEASE",
            reason="The release includes prohibited personal, household, property, or ranking fields.",
        )

    if not request.aggregate_only:
        return DataReleaseResult(
            compliant=False,
            decision="NON_AGGREGATE_RELEASE",
            reason="Public-interest release must be aggregate-only.",
        )

    if not request.small_cell_suppression_applied:
        return DataReleaseResult(
            compliant=False,
            decision="SMALL_CELL_PROTECTION_MISSING",
            reason="Small-cell suppression is required for aggregate release.",
        )

    if request.reidentification_risk_present:
        return DataReleaseResult(
            compliant=False,
            decision="REIDENTIFICATION_RISK",
            reason="The release is blocked because re-identification risk is present.",
        )

    if request.discriminatory_or_ranking_purpose:
        return DataReleaseResult(
            compliant=False,
            decision="PROHIBITED_PURPOSE",
            reason="Discriminatory, financial-ranking, and social-ranking purposes are prohibited.",
        )

    if request.epsilon is not None:
        if not isfinite(request.epsilon) or request.epsilon <= 0.0 or request.epsilon > 0.1:
            return DataReleaseResult(
                compliant=False,
                decision="PRIVACY_BUDGET_VIOLATION",
                reason="Differential privacy epsilon must be greater than zero and at most 0.1.",
            )

    if not request.human_review_complete:
        return DataReleaseResult(
            compliant=False,
            decision="REVIEW_REQUIRED",
            reason="Privacy and public-interest human review must complete before release.",
        )

    return DataReleaseResult(
        compliant=True,
        decision="RELEASE_COMPLIANT",
        reason="The release is aggregate-only, small-cell protected, purpose-limited, and reviewed.",
    )


def jain_fairness_index(values: Iterable[float]) -> float:
    burdens = list(values)
    if not burdens:
        raise GovernanceValidationError("At least one outage burden is required.")
    if any(not isfinite(value) or value < 0.0 for value in burdens):
        raise GovernanceValidationError(
            "Outage burden values must be finite and non-negative."
        )

    total = sum(burdens)
    squared_total = sum(value * value for value in burdens)

    if squared_total == 0.0:
        return 1.0

    return (total * total) / (len(burdens) * squared_total)


def evaluate_fair_load_shedding(
    areas: Iterable[LoadArea],
    fairness_target: float = 0.9,
    maximum_outage_hours: float = 4.0,
) -> LoadSheddingResult:
    planned_areas = list(areas)

    if not planned_areas:
        raise GovernanceValidationError("At least one public service area is required.")
    if not isfinite(fairness_target) or not 0.0 < fairness_target <= 1.0:
        raise GovernanceValidationError("fairness_target must be in the interval (0, 1].")
    if not isfinite(maximum_outage_hours) or maximum_outage_hours <= 0.0:
        raise GovernanceValidationError("maximum_outage_hours must be positive.")

    essential_preserved = all(
        area.essential_demand_mw <= area.total_demand_mw for area in planned_areas
    )
    fairness = jain_fairness_index(
        area.residual_outage_hours for area in planned_areas
    )

    undocumented_excess = any(
        area.residual_outage_hours > maximum_outage_hours
        and not area.technical_exception_documented
        for area in planned_areas
    )

    has_exception = any(
        area.technical_exception_documented for area in planned_areas
    )

    if not essential_preserved:
        return LoadSheddingResult(
            compliant=False,
            jain_fairness_index=fairness,
            requires_human_review=True,
            reason="Essential demand preservation failed.",
        )

    if undocumented_excess:
        return LoadSheddingResult(
            compliant=False,
            jain_fairness_index=fairness,
            requires_human_review=True,
            reason="A residual outage exceeds the maximum without a technical exception record.",
        )

    if fairness <= fairness_target:
        return LoadSheddingResult(
            compliant=False,
            jain_fairness_index=fairness,
            requires_human_review=True,
            reason="Residual outage burden does not exceed the required Jain fairness target.",
        )

    return LoadSheddingResult(
        compliant=True,
        jain_fairness_index=fairness,
        requires_human_review=has_exception,
        reason=(
            "Essential demand is preserved and residual outage burden exceeds the Jain "
            "fairness target. Documented technical exceptions still require human review."
        ),
    )


def safe_audit_record(record: Mapping[str, object]) -> bool:
    prohibited = {
        "person_name",
        "identity",
        "health",
        "augmentation_status",
        "cybernetic_host_status",
        "biometric_data",
        "device_identifier",
        "precise_location",
        "household_data",
        "property_value",
        "financial_rank",
        "social_rank",
        "reputation_score",
    }
    return not bool(prohibited.intersection(record.keys()))
