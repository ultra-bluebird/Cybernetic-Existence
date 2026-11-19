from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import FrozenSet


class CityServiceInvariantError(ValueError):
    pass


ESSENTIAL_SERVICES: FrozenSet[str] = frozenset(
    {
        "emergency_shelter",
        "cooling",
        "warming",
        "drinking_water",
        "sanitation",
        "safety_information",
        "emergency_communications",
        "transit_access",
        "essential_goods_access",
    }
)

PROHIBITED_DECISION_INPUTS: FrozenSet[str] = frozenset(
    {
        "identity",
        "self_asserted_identity",
        "health",
        "disability",
        "augmentation",
        "cybernetic_host_status",
        "assistive_technology",
        "appearance",
        "biometric_data",
        "device_identifier",
        "wifi_mac_address",
        "ble_identifier",
        "location_history",
        "wealth",
        "property_value",
        "payment_history",
        "customer_profitability",
        "financial_rank",
        "social_rank",
        "reputation_score",
        "participation_frequency",
    }
)


@dataclass(frozen=True)
class CityServiceRequest:
    service_kind: str
    credential_required: bool
    network_required: bool
    personal_device_required: bool
    identity_verification_required: bool
    sensitive_disclosure_required: bool
    human_fallback_available: bool
    non_digital_fallback_available: bool
    decision_inputs: FrozenSet[str]
    data_quality_state: str
    automated_actuation_requested: bool


@dataclass(frozen=True)
class CityServiceDecision:
    decision: str
    reason: str
    human_review_required: bool
    non_digital_fallback_available: bool
    identity_or_sensitive_data_used: bool
    ranking_or_reputation_used: bool
    automated_actuation_performed: bool


def evaluate_city_service_request(
    request: CityServiceRequest,
) -> CityServiceDecision:
    if not request.service_kind.strip():
        raise CityServiceInvariantError("service_kind must be non-empty.")

    if request.data_quality_state not in {
        "VALID",
        "STALE",
        "INVALID",
        "UNCALIBRATED",
        "UNAVAILABLE",
    }:
        raise CityServiceInvariantError("data_quality_state is not supported.")

    prohibited_inputs = PROHIBITED_DECISION_INPUTS.intersection(
        request.decision_inputs
    )
    if prohibited_inputs:
        return CityServiceDecision(
            decision="PROHIBITED_INPUT_REJECTED",
            reason="Decision inputs include prohibited identity, device, ranking, or wealth data.",
            human_review_required=True,
            non_digital_fallback_available=request.non_digital_fallback_available,
            identity_or_sensitive_data_used=True,
            ranking_or_reputation_used=bool(
                {
                    "financial_rank",
                    "social_rank",
                    "reputation_score",
                    "participation_frequency",
                }.intersection(prohibited_inputs)
            ),
            automated_actuation_performed=False,
        )

    if request.automated_actuation_requested:
        return CityServiceDecision(
            decision="NON_ACTUATION_GUARD",
            reason="The decision-support layer cannot authorize automated physical action.",
            human_review_required=True,
            non_digital_fallback_available=request.non_digital_fallback_available,
            identity_or_sensitive_data_used=False,
            ranking_or_reputation_used=False,
            automated_actuation_performed=False,
        )

    if (
        not request.human_fallback_available
        or not request.non_digital_fallback_available
    ):
        return CityServiceDecision(
            decision="FALLBACK_PATH_MISSING",
            reason="Accessible human and non-digital fallback paths are required.",
            human_review_required=True,
            non_digital_fallback_available=request.non_digital_fallback_available,
            identity_or_sensitive_data_used=False,
            ranking_or_reputation_used=False,
            automated_actuation_performed=False,
        )

    if request.service_kind in ESSENTIAL_SERVICES and any(
        (
            request.credential_required,
            request.network_required,
            request.personal_device_required,
            request.identity_verification_required,
            request.sensitive_disclosure_required,
        )
    ):
        return CityServiceDecision(
            decision="ESSENTIAL_SERVICE_GATING_VIOLATION",
            reason=(
                "Essential service access must not require credentials, network, "
                "personal devices, identity verification, or sensitive disclosure."
            ),
            human_review_required=True,
            non_digital_fallback_available=True,
            identity_or_sensitive_data_used=False,
            ranking_or_reputation_used=False,
            automated_actuation_performed=False,
        )

    if request.data_quality_state != "VALID":
        return CityServiceDecision(
            decision="DATA_QUALITY_REVIEW_REQUIRED",
            reason=(
                "Stale, invalid, uncalibrated, or unavailable data cannot support "
                "automated reliance."
            ),
            human_review_required=True,
            non_digital_fallback_available=True,
            identity_or_sensitive_data_used=False,
            ranking_or_reputation_used=False,
            automated_actuation_performed=False,
        )

    return CityServiceDecision(
        decision="CONFORMANT_ACCESS_OR_ADVISORY_RESULT",
        reason=(
            "The request preserves privacy, accessibility, human fallback, "
            "non-digital access, and non-actuating decision support."
        ),
        human_review_required=False,
        non_digital_fallback_available=True,
        identity_or_sensitive_data_used=False,
        ranking_or_reputation_used=False,
        automated_actuation_performed=False,
    )


def invariant_coverage(
    exercised_invariants: set[str],
    registered_invariants: set[str],
) -> float:
    if not registered_invariants:
        raise CityServiceInvariantError(
            "registered_invariants must contain at least one invariant."
        )

    unknown = exercised_invariants.difference(registered_invariants)
    if unknown:
        raise CityServiceInvariantError(
            "exercised_invariants contains unknown invariant names."
        )

    return len(exercised_invariants) / len(registered_invariants)


def mutation_score(
    killed_mutations: int,
    total_mutations: int,
) -> float:
    if total_mutations <= 0:
        raise CityServiceInvariantError("total_mutations must be positive.")
    if killed_mutations < 0 or killed_mutations > total_mutations:
        raise CityServiceInvariantError(
            "killed_mutations must be within zero through total_mutations."
        )

    result = killed_mutations / total_mutations
    if not isfinite(result):
        raise CityServiceInvariantError("mutation score must be finite.")
    return result
