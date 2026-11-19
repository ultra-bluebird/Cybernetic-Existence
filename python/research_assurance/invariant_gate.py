from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Mapping


class Decision(str, Enum):
    ALLOW_RESEARCH = "allow_research"
    REQUIRE_REVIEW = "require_review"
    ABSTAIN = "abstain"
    REJECT = "reject"


@dataclass(frozen=True)
class ResearchRequest:
    purpose: str
    uses_synthetic_or_public_data: bool
    includes_sensitive_personal_data: bool
    infrastructure_connection_requested: bool
    makes_individual_decision: bool
    requires_augmentation_disclosure_for_service: bool
    automation_interlocks_clear: bool
    automation_command_unexpired: bool
    automation_simulation_passed: bool
    aggregate_minimum_group_size_met: bool
    aggregate_disclosure_risk_acceptable: bool
    aggregate_voluntary_governance_confirmed: bool
    legal_jurisdiction_matched: bool
    legal_source_authoritative: bool
    legal_source_effective: bool
    legal_claim_entailment_confirmed: bool
    legal_outcome_prediction: bool
    accessibility_fallback_available: bool
    uncertainty_declared: bool


@dataclass(frozen=True)
class GateResult:
    decision: Decision
    reasons: tuple[str, ...]
    checks: Mapping[str, bool]


def evaluate_research_request(request: ResearchRequest) -> GateResult:
    reasons: list[str] = []
    checks: dict[str, bool] = {}

    checks["purpose_present"] = bool(request.purpose.strip())
    if not checks["purpose_present"]:
        reasons.append("A specific research purpose is required.")

    checks["synthetic_or_public_data_only"] = request.uses_synthetic_or_public_data
    if not checks["synthetic_or_public_data_only"]:
        reasons.append(
            "Research must use synthetic, public, or independently approved aggregate inputs."
        )

    checks["no_sensitive_personal_data"] = not request.includes_sensitive_personal_data
    if not checks["no_sensitive_personal_data"]:
        reasons.append(
            "Sensitive personal, neural, biometric, health, identity, augmentation, "
            "or precise-location data are prohibited in this research workflow."
        )

    checks["no_infrastructure_connection"] = not request.infrastructure_connection_requested
    if not checks["no_infrastructure_connection"]:
        reasons.append(
            "The research agent may not connect to or control operational infrastructure."
        )

    checks["no_individual_decision"] = not request.makes_individual_decision
    if not checks["no_individual_decision"]:
        reasons.append(
            "The research agent may not make individual eligibility, enforcement, "
            "benefit, or service decisions."
        )

    checks["no_coerced_augmentation_disclosure"] = (
        not request.requires_augmentation_disclosure_for_service
    )
    if not checks["no_coerced_augmentation_disclosure"]:
        reasons.append(
            "Essential services must not depend on augmentation-status disclosure."
        )

    if not all(
        (
            checks["purpose_present"],
            checks["synthetic_or_public_data_only"],
            checks["no_sensitive_personal_data"],
            checks["no_infrastructure_connection"],
            checks["no_individual_decision"],
            checks["no_coerced_augmentation_disclosure"],
        )
    ):
        return GateResult(
            decision=Decision.REJECT,
            reasons=tuple(reasons),
            checks=checks,
        )

    automation_requested = any(
        (
            request.automation_interlocks_clear,
            request.automation_command_unexpired,
            request.automation_simulation_passed,
        )
    )
    if automation_requested:
        checks["automation_interlocks_clear"] = request.automation_interlocks_clear
        checks["automation_command_unexpired"] = request.automation_command_unexpired
        checks["automation_simulation_passed"] = request.automation_simulation_passed

        if not all(
            (
                checks["automation_interlocks_clear"],
                checks["automation_command_unexpired"],
                checks["automation_simulation_passed"],
            )
        ):
            reasons.append(
                "Automation research scenario failed an interlock, expiry, or simulation gate."
            )
            return GateResult(
                decision=Decision.REJECT,
                reasons=tuple(reasons),
                checks=checks,
            )

    aggregate_requested = any(
        (
            request.aggregate_minimum_group_size_met,
            request.aggregate_disclosure_risk_acceptable,
            request.aggregate_voluntary_governance_confirmed,
        )
    )
    if aggregate_requested:
        checks["aggregate_minimum_group_size_met"] = (
            request.aggregate_minimum_group_size_met
        )
        checks["aggregate_disclosure_risk_acceptable"] = (
            request.aggregate_disclosure_risk_acceptable
        )
        checks["aggregate_voluntary_governance_confirmed"] = (
            request.aggregate_voluntary_governance_confirmed
        )

        if not all(
            (
                checks["aggregate_minimum_group_size_met"],
                checks["aggregate_disclosure_risk_acceptable"],
                checks["aggregate_voluntary_governance_confirmed"],
            )
        ):
            reasons.append(
                "Aggregate environmental-justice output requires suppression or "
                "human review because disclosure, group-size, or governance checks failed."
            )
            return GateResult(
                decision=Decision.REQUIRE_REVIEW,
                reasons=tuple(reasons),
                checks=checks,
            )

    legal_requested = any(
        (
            request.legal_jurisdiction_matched,
            request.legal_source_authoritative,
            request.legal_source_effective,
            request.legal_claim_entailment_confirmed,
            request.legal_outcome_prediction,
        )
    )
    if legal_requested:
        checks["legal_jurisdiction_matched"] = request.legal_jurisdiction_matched
        checks["legal_source_authoritative"] = request.legal_source_authoritative
        checks["legal_source_effective"] = request.legal_source_effective
        checks["legal_claim_entailment_confirmed"] = (
            request.legal_claim_entailment_confirmed
        )
        checks["no_legal_outcome_prediction"] = not request.legal_outcome_prediction

        if request.legal_outcome_prediction:
            reasons.append("Legal-outcome predictions are prohibited.")
            return GateResult(
                decision=Decision.REJECT,
                reasons=tuple(reasons),
                checks=checks,
            )

        if not all(
            (
                checks["legal_jurisdiction_matched"],
                checks["legal_source_authoritative"],
                checks["legal_source_effective"],
                checks["legal_claim_entailment_confirmed"],
            )
        ):
            reasons.append(
                "The legal claim is not sufficiently grounded in a current, "
                "jurisdiction-matched, authoritative source passage."
            )
            return GateResult(
                decision=Decision.ABSTAIN,
                reasons=tuple(reasons),
                checks=checks,
            )

    checks["accessibility_fallback_available"] = request.accessibility_fallback_available
    if not checks["accessibility_fallback_available"]:
        reasons.append(
            "An essential function lacks an independent accessible fallback."
        )
        return GateResult(
            decision=Decision.REJECT,
            reasons=tuple(reasons),
            checks=checks,
        )

    checks["uncertainty_declared"] = request.uncertainty_declared
    if not checks["uncertainty_declared"]:
        reasons.append(
            "The research output requires an explicit uncertainty and limitation statement."
        )
        return GateResult(
            decision=Decision.REQUIRE_REVIEW,
            reasons=tuple(reasons),
            checks=checks,
        )

    return GateResult(
        decision=Decision.ALLOW_RESEARCH,
        reasons=("All applicable rights, safety, accessibility, and evidence gates passed.",),
        checks=checks,
    )
