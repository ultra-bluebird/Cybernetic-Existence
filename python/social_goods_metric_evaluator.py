from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
from enum import Enum
from typing import Iterable


class EvidenceClass(str, Enum):
    OBSERVED_MEASUREMENT = "observed_measurement"
    MODELED_ESTIMATE = "modeled_estimate"
    REVIEWED_FINDING = "reviewed_finding"
    VERIFIED_OUTCOME = "verified_outcome"
    INCOMPLETE_OR_UNCERTAIN = "incomplete_or_uncertain"


class SocialGoodsError(ValueError):
    pass


@dataclass(frozen=True)
class RightsGate:
    privacy_protected: bool
    non_discrimination_protected: bool
    accessibility_protected: bool
    no_coercive_use: bool
    community_review_available: bool

    def eligible(self) -> bool:
        return (
            self.privacy_protected
            and self.non_discrimination_protected
            and self.accessibility_protected
            and self.no_coercive_use
            and self.community_review_available
        )


@dataclass(frozen=True)
class BenefitOutcome:
    outcome_id: str
    domain: str
    benefit_value: Decimal
    affected_population_or_area: Decimal
    evidence_quality: Decimal
    evidence_class: EvidenceClass


@dataclass(frozen=True)
class CostOutcome:
    outcome_id: str
    domain: str
    cost_value: Decimal
    affected_population_or_area: Decimal
    uncertainty_or_burden: Decimal
    evidence_class: EvidenceClass


@dataclass(frozen=True)
class SocialGoodsAssessment:
    eligible: bool
    net_community_benefit: Decimal | None
    benefit_total: Decimal | None
    cost_total: Decimal | None
    benefit_outcome_count: int
    cost_outcome_count: int
    evidence_classes: tuple[str, ...]
    reason: str
    person_ranking_authorized: bool
    eligibility_decision_authorized: bool
    external_action_authorized: bool


def assess_social_goods(
    rights_gate: RightsGate,
    benefits: Iterable[BenefitOutcome],
    costs: Iterable[CostOutcome],
) -> SocialGoodsAssessment:
    benefit_entries = tuple(benefits)
    cost_entries = tuple(costs)

    validate_rights_gate(rights_gate)
    validate_benefits(benefit_entries)
    validate_costs(cost_entries)

    evidence_classes = tuple(
        sorted(
            {
                entry.evidence_class.value
                for entry in (*benefit_entries, *cost_entries)
            }
        )
    )

    if not rights_gate.eligible():
        return SocialGoodsAssessment(
            eligible=False,
            net_community_benefit=None,
            benefit_total=None,
            cost_total=None,
            benefit_outcome_count=len(benefit_entries),
            cost_outcome_count=len(cost_entries),
            evidence_classes=evidence_classes,
            reason=(
                "The rights gate is not satisfied. Aggregate benefit must not "
                "compensate for privacy, non-discrimination, accessibility, "
                "non-coercion, or community-review failure."
            ),
            person_ranking_authorized=False,
            eligibility_decision_authorized=False,
            external_action_authorized=False,
        )

    benefit_total = sum(
        (
            entry.benefit_value
            * entry.affected_population_or_area
            * entry.evidence_quality
        )
        for entry in benefit_entries
    )

    cost_total = sum(
        (
            entry.cost_value
            * entry.affected_population_or_area
            * entry.uncertainty_or_burden
        )
        for entry in cost_entries
    )

    return SocialGoodsAssessment(
        eligible=True,
        net_community_benefit=benefit_total - cost_total,
        benefit_total=benefit_total,
        cost_total=cost_total,
        benefit_outcome_count=len(benefit_entries),
        cost_outcome_count=len(cost_entries),
        evidence_classes=evidence_classes,
        reason=(
            "The assessment is eligible as a community-level planning metric. "
            "It is not a person score, contributor ranking, eligibility "
            "decision, enforcement finding, or authorization for external action."
        ),
        person_ranking_authorized=False,
        eligibility_decision_authorized=False,
        external_action_authorized=False,
    )


def validate_rights_gate(rights_gate: RightsGate) -> None:
    if not isinstance(rights_gate, RightsGate):
        raise SocialGoodsError("rights_gate must be a RightsGate instance.")


def validate_benefits(entries: tuple[BenefitOutcome, ...]) -> None:
    for entry in entries:
        validate_identifier(entry.outcome_id, "benefit outcome_id")
        validate_identifier(entry.domain, "benefit domain")
        validate_non_negative(entry.benefit_value, "benefit_value")
        validate_non_negative(
            entry.affected_population_or_area,
            "benefit affected_population_or_area",
        )
        validate_unit_interval(entry.evidence_quality, "benefit evidence_quality")


def validate_costs(entries: tuple[CostOutcome, ...]) -> None:
    for entry in entries:
        validate_identifier(entry.outcome_id, "cost outcome_id")
        validate_identifier(entry.domain, "cost domain")
        validate_non_negative(entry.cost_value, "cost_value")
        validate_non_negative(
            entry.affected_population_or_area,
            "cost affected_population_or_area",
        )
        validate_unit_interval(
            entry.uncertainty_or_burden,
            "cost uncertainty_or_burden",
        )


def validate_identifier(value: str, field_name: str) -> None:
    if not isinstance(value, str) or not value.strip() or len(value.strip()) > 160:
        raise SocialGoodsError(
            f"{field_name} must be a non-empty string with at most 160 characters."
        )


def validate_non_negative(value: Decimal, field_name: str) -> None:
    if not isinstance(value, Decimal) or value < Decimal("0"):
        raise SocialGoodsError(
            f"{field_name} must be a Decimal greater than or equal to zero."
        )


def validate_unit_interval(value: Decimal, field_name: str) -> None:
    if (
        not isinstance(value, Decimal)
        or value < Decimal("0")
        or value > Decimal("1")
    ):
        raise SocialGoodsError(
            f"{field_name} must be a Decimal from 0 to 1."
        )


def decimal_from_text(value: str) -> Decimal:
    try:
        return Decimal(value)
    except (InvalidOperation, TypeError) as error:
        raise SocialGoodsError("Expected a decimal-compatible text value.") from error
