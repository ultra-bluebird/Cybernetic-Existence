"""Classify supplied review statuses for a fixed requirement inventory.

Python 3.10 or newer; standard library only.

Input is a decoded JSON object containing reviewed status labels.
Evidence authenticity, applicability, freshness, and adequacy are upstream
review obligations. No external action or service decision occurs.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

REQUIREMENTS = (
    "alternative_input_task_access",
    "accessible_change_notice",
    "private_data_exclusion",
    "outbound_processing_scope",
    "non_interference_boundary",
    "settings_upgrade_preservation",
    "support_exit_continuity",
    "refusal_access_equivalence",
    "correction_and_human_fallback",
    "claim_evidence_scope",
)

STATES = ("pass", "fail", "unknown")


def review_gate(statuses):
    if (
        type(statuses) is not dict
        or set(statuses) != set(REQUIREMENTS)
    ):
        raise ValueError("exact_requirement_inventory_required")

    if any(
        type(value) is not str or value not in STATES
        for value in statuses.values()
    ):
        raise ValueError("unsupported_requirement_status")

    failed = tuple(
        name for name in REQUIREMENTS
        if statuses[name] == "fail"
    )
    unknown = tuple(
        name for name in REQUIREMENTS
        if statuses[name] == "unknown"
    )

    if failed:
        state = "failed_requirements_present"
    elif unknown:
        state = "unresolved_requirements_present"
    else:
        state = "all_required_evidence_passes"

    return {
        "schema_version": "1.0.0",
        "record_kind": "minimum_acceptance_evidence_summary",
        "review_profile": "input_release_minimum_review-1.0.0",
        "state": state,
        "failed_requirements": failed,
        "unknown_requirements": unknown,
        "release_authorized": False,
        "external_action_authorized": False,
        "service_denial_authorized": False,
    }
