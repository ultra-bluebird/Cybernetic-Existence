"""Exit-planning conjunction and refusal-outcome reporting.

Python 3.10 or newer; standard library only.

Evaluates supplied review results and aggregate counts.
No competence assessment, retaliation adjudication, or external action.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

EXIT_ELEMENTS = (
    "information",
    "continuity",
    "alternatives",
    "data_choices",
    "review_route",
)

META = {
    "schema_version": "1.0.0",
    "sovereign_attribution": ATTRIBUTION,
    "attribution_use": "document_credit_only",
}


def exit_plan(results):
    if type(results) is not dict or set(results) != set(EXIT_ELEMENTS):
        raise ValueError("five_exit_elements_required")

    if any(
        type(value) is not str or value not in {"P", "F", "U"}
        for value in results.values()
    ):
        raise ValueError("invalid_review_result")

    values = tuple(results[name] for name in EXIT_ELEMENTS)

    aggregate = (
        "F" if "F" in values
        else "P" if all(value == "P" for value in values)
        else "U"
    )

    return {
        **META,
        "elements": dict(results),
        "planning_result": aggregate,
        "planning_gaps": [
            name for name in EXIT_ELEMENTS if results[name] == "F"
        ],
        "unresolved_elements": [
            name for name in EXIT_ELEMENTS if results[name] == "U"
        ],
        "actual_exit": "not_evaluated",
        "request_or_refusal_permission": "not_decided_by_this_metric",
    }


def refusal_report(retained, lost, unknown):
    values = (retained, lost, unknown)

    if (
        any(
            type(value) is not int or not 0 <= value <= 2**53 - 1
            for value in values
        )
        or sum(values) > 2**53 - 1
    ):
        raise ValueError("nonnegative_supported_counts_required")

    total = sum(values)
    resolved = retained + lost

    return {
        **META,
        "retained": retained,
        "access_loss": lost,
        "unknown": unknown,
        "eligible_refusal_events": total,
        "resolved_outcomes": resolved,
        "retention_among_resolved": (
            None if resolved == 0 else retained / resolved
        ),
        "resolved_outcome_coverage": (
            None if total == 0 else resolved / total
        ),
        "cohort_retention_bounds": (
            None
            if total == 0
            else [
                retained / total,
                (retained + unknown) / total,
            ]
        ),
        "loss_events_requiring_followup": lost,
        "retaliation_causation": "not_determined",
        "statistical_confidence_interval": "not_calculated",
        "case_creation": "not_performed",
    }
