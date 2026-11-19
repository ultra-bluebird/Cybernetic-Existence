from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
from typing import Mapping


class PrivacyBudgetError(ValueError):
    pass


MAX_EPSILON_PER_QUERY = Decimal("0.1")


@dataclass(frozen=True)
class PrivacyBudget:
    project_alias: str
    dataset_class: str
    release_window: str
    epsilon_cap: Decimal
    epsilon_used: Decimal = Decimal("0")

    def __post_init__(self) -> None:
        if not self.project_alias.strip():
            raise PrivacyBudgetError("project_alias must be non-empty.")
        if not self.dataset_class.strip():
            raise PrivacyBudgetError("dataset_class must be non-empty.")
        if not self.release_window.strip():
            raise PrivacyBudgetError("release_window must be non-empty.")
        if self.epsilon_cap <= 0:
            raise PrivacyBudgetError("epsilon_cap must be positive.")
        if self.epsilon_used < 0:
            raise PrivacyBudgetError("epsilon_used must not be negative.")
        if self.epsilon_used > self.epsilon_cap:
            raise PrivacyBudgetError("epsilon_used must not exceed epsilon_cap.")

    @property
    def epsilon_remaining(self) -> Decimal:
        return self.epsilon_cap - self.epsilon_used


@dataclass(frozen=True)
class QueryDecision:
    approved: bool
    requested_epsilon: Decimal
    epsilon_remaining_after: Decimal
    reason: str
    fallback: str | None


def as_epsilon(value: str | Decimal | float) -> Decimal:
    try:
        epsilon = Decimal(str(value))
    except (InvalidOperation, ValueError) as error:
        raise PrivacyBudgetError("epsilon must be decimal-compatible.") from error

    if not epsilon.is_finite() or epsilon <= 0:
        raise PrivacyBudgetError("epsilon must be finite and positive.")

    return epsilon


def approve_query(
    budget: PrivacyBudget,
    requested_epsilon: str | Decimal | float,
    query_has_reidentification_risk: bool,
    query_has_discriminatory_or_ranking_purpose: bool,
    minimum_group_size_met: bool,
) -> QueryDecision:
    epsilon = as_epsilon(requested_epsilon)

    if query_has_reidentification_risk:
        return QueryDecision(
            approved=False,
            requested_epsilon=epsilon,
            epsilon_remaining_after=budget.epsilon_remaining,
            reason="The request is blocked because it presents a re-identification or reconstruction risk.",
            fallback="Use a larger geographic area, longer time window, or public aggregate.",
        )

    if query_has_discriminatory_or_ranking_purpose:
        return QueryDecision(
            approved=False,
            requested_epsilon=epsilon,
            epsilon_remaining_after=budget.epsilon_remaining,
            reason="The request is blocked because discrimination, financial ranking, or social ranking is prohibited.",
            fallback="Reframe the request as a non-personal public-interest aggregate analysis.",
        )

    if not minimum_group_size_met:
        return QueryDecision(
            approved=False,
            requested_epsilon=epsilon,
            epsilon_remaining_after=budget.epsilon_remaining,
            reason="The request is blocked because the aggregation threshold is not met.",
            fallback="Use a coarser geographic or temporal aggregation.",
        )

    if epsilon > MAX_EPSILON_PER_QUERY:
        return QueryDecision(
            approved=False,
            requested_epsilon=epsilon,
            epsilon_remaining_after=budget.epsilon_remaining,
            reason="The requested privacy cost exceeds the 0.1 epsilon per-query limit.",
            fallback="Request a lower-precision aggregate with epsilon at or below 0.1.",
        )

    if budget.epsilon_used + epsilon > budget.epsilon_cap:
        return QueryDecision(
            approved=False,
            requested_epsilon=epsilon,
            epsilon_remaining_after=budget.epsilon_remaining,
            reason="The approved project privacy budget would be exceeded.",
            fallback="Use a coarser result, a later release window, or a synthetic dataset.",
        )

    return QueryDecision(
        approved=True,
        requested_epsilon=epsilon,
        epsilon_remaining_after=budget.epsilon_remaining - epsilon,
        reason="The aggregate query is eligible for privacy-preserving release under the project budget.",
        fallback=None,
    )


def permitted_audit_fields() -> frozenset[str]:
    return frozenset(
        {
            "event_type",
            "project_pseudonym",
            "purpose_category",
            "dataset_class",
            "geographic_resolution",
            "time_resolution",
            "privacy_epsilon",
            "cumulative_project_epsilon",
            "output_mode",
            "review_state",
            "retention_deadline",
        }
    )


def contains_prohibited_audit_fields(record: Mapping[str, object]) -> bool:
    prohibited = {
        "researcher_name",
        "home_address",
        "device_identifier",
        "browser_fingerprint",
        "biometric_data",
        "health_data",
        "augmentation_status",
        "cybernetic_host_status",
        "reputation_score",
        "financial_rank",
        "social_rank",
    }
    return bool(prohibited.intersection(record.keys()))
