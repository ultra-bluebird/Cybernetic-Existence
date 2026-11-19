from dataclasses import dataclass
from decimal import Decimal


@dataclass(frozen=True)
class AggregatePeriodOutcome:
    context_ref: str
    period_ref: str
    intervention_group: bool
    post_intervention: bool
    outcome_value: Decimal
    aggregation_threshold_met: bool
    provenance_complete: bool
    identity_inference_used: bool = False
    person_level_data_used: bool = False


@dataclass(frozen=True)
class DifferenceInDifferencesEstimate:
    intervention_before: Decimal | None
    intervention_after: Decimal | None
    comparison_before: Decimal | None
    comparison_after: Decimal | None
    estimate: Decimal | None
    reportable: bool
    reasons: tuple[str, ...]


def average(values: list[Decimal]) -> Decimal | None:
    if not values:
        return None
    return sum(values, Decimal("0")) / Decimal(len(values))


def estimate_difference_in_differences(
    observations: list[AggregatePeriodOutcome],
) -> DifferenceInDifferencesEstimate:
    reasons: list[str] = []

    if any(
        not observation.aggregation_threshold_met
        for observation in observations
    ):
        reasons.append("AGGREGATION_THRESHOLD_NOT_MET")

    if any(
        not observation.provenance_complete
        for observation in observations
    ):
        reasons.append("MISSING_PROVENANCE")

    if any(
        observation.identity_inference_used
        for observation in observations
    ):
        reasons.append("IDENTITY_INFERENCE_PROHIBITED")

    if any(
        observation.person_level_data_used
        for observation in observations
    ):
        reasons.append("PERSON_LEVEL_DATA_PROHIBITED")

    intervention_before = average([
        item.outcome_value
        for item in observations
        if item.intervention_group and not item.post_intervention
    ])

    intervention_after = average([
        item.outcome_value
        for item in observations
        if item.intervention_group and item.post_intervention
    ])

    comparison_before = average([
        item.outcome_value
        for item in observations
        if not item.intervention_group and not item.post_intervention
    ])

    comparison_after = average([
        item.outcome_value
        for item in observations
        if not item.intervention_group and item.post_intervention
    ])

    required_values = (
        intervention_before,
        intervention_after,
        comparison_before,
        comparison_after,
    )

    if any(value is None for value in required_values):
        reasons.append("INCOMPLETE_COMPARISON_PERIODS")

    if reasons:
        return DifferenceInDifferencesEstimate(
            intervention_before=intervention_before,
            intervention_after=intervention_after,
            comparison_before=comparison_before,
            comparison_after=comparison_after,
            estimate=None,
            reportable=False,
            reasons=tuple(reasons),
        )

    estimate = (
        (intervention_after - intervention_before)
        - (comparison_after - comparison_before)
    )

    return DifferenceInDifferencesEstimate(
        intervention_before=intervention_before,
        intervention_after=intervention_after,
        comparison_before=comparison_before,
        comparison_after=comparison_after,
        estimate=estimate.quantize(Decimal("0.001")),
        reportable=True,
        reasons=(),
    )
