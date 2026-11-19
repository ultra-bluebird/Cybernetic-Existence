from dataclasses import dataclass
from decimal import Decimal
from typing import Iterable


ZERO = Decimal("0")
ONE = Decimal("1")


@dataclass(frozen=True)
class DashboardIndicator:
    indicator_ref: str
    value: Decimal
    weight: Decimal
    uncertainty: Decimal
    missingness: Decimal
    definition_present: bool
    unit_present: bool
    provenance_complete: bool
    data_owner_present: bool
    collection_method_present: bool
    reference_period_present: bool
    geographic_scope_present: bool
    last_review_date_present: bool
    person_level_data_used: bool = False
    identity_inference_used: bool = False
    external_action_authorized: bool = False


@dataclass(frozen=True)
class DashboardScenarioAssessment:
    scenario_ref: str
    readiness_score: Decimal | None
    reportable: bool
    reasons: tuple[str, ...]


def require_unit_interval(value: Decimal, field_name: str) -> None:
    if value < ZERO or value > ONE:
        raise ValueError(f"{field_name} must be between 0 and 1")


def assess_scenario(
    scenario_ref: str,
    indicators: Iterable[DashboardIndicator],
) -> DashboardScenarioAssessment:
    indicator_list = tuple(indicators)
    reasons: list[str] = []

    if not indicator_list:
        reasons.append("NO_INDICATORS_PROVIDED")

    weighted_value = ZERO
    total_weight = ZERO
    weighted_uncertainty = ZERO
    weighted_missingness = ZERO

    for indicator in indicator_list:
        require_unit_interval(indicator.value, "value")
        require_unit_interval(indicator.uncertainty, "uncertainty")
        require_unit_interval(indicator.missingness, "missingness")

        if indicator.weight < ZERO:
            raise ValueError("weight must not be negative")

        required_metadata = (
            indicator.definition_present
            and indicator.unit_present
            and indicator.provenance_complete
            and indicator.data_owner_present
            and indicator.collection_method_present
            and indicator.reference_period_present
            and indicator.geographic_scope_present
            and indicator.last_review_date_present
        )

        if not required_metadata:
            reasons.append(f"INCOMPLETE_METADATA:{indicator.indicator_ref}")

        if indicator.person_level_data_used:
            reasons.append(f"PERSON_LEVEL_DATA_PROHIBITED:{indicator.indicator_ref}")

        if indicator.identity_inference_used:
            reasons.append(f"IDENTITY_INFERENCE_PROHIBITED:{indicator.indicator_ref}")

        if indicator.external_action_authorized:
            reasons.append(
                f"EXTERNAL_ACTION_AUTHORIZATION_PROHIBITED:{indicator.indicator_ref}"
            )

        weighted_value += indicator.value * indicator.weight
        weighted_uncertainty += indicator.uncertainty * indicator.weight
        weighted_missingness += indicator.missingness * indicator.weight
        total_weight += indicator.weight

    if total_weight <= ZERO:
        reasons.append("NONPOSITIVE_TOTAL_WEIGHT")

    if reasons:
        return DashboardScenarioAssessment(
            scenario_ref=scenario_ref,
            readiness_score=None,
            reportable=False,
            reasons=tuple(reasons),
        )

    readiness_score = (
        (weighted_value / total_weight)
        - (weighted_uncertainty / total_weight)
        - (weighted_missingness / total_weight)
    )

    return DashboardScenarioAssessment(
        scenario_ref=scenario_ref,
        readiness_score=max(ZERO, readiness_score).quantize(Decimal("0.001")),
        reportable=True,
        reasons=(),
    )
