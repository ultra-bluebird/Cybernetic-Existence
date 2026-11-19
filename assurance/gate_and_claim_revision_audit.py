# SPDX-License-Identifier: MIT OR Apache-2.0
"""Synthetic gate verification and non-authorizing claim revision review."""

from collections import Counter
from itertools import product


ENGINE_VERSION = "1.0.0"
STATES = ("pass", "fail", "unknown")
CLASSIFICATIONS = frozenset({
    "established_finding",
    "supplied_claim",
    "assumption",
    "design_proposal",
    "tested_implementation",
})
REQUIRED_CLAIM_FIELDS = frozenset({
    "claim_text", "classification", "classification_basis", "sources",
    "scope", "evidence", "limitations", "invalidation_conditions",
    "review_triggers", "review_state", "revision",
})


def classify(values):
    if (
        type(values) is not tuple
        or len(values) != 10
        or any(type(value) is not str or value not in STATES for value in values)
    ):
        raise ValueError("exact ten-state tuple required")
    if "fail" in values:
        return "failed_requirements_present"
    if "unknown" in values:
        return "unresolved_requirements_present"
    return "all_required_evidence_passes"


def reference(values):
    ranks = {"pass": 0, "unknown": 1, "fail": 2}
    labels = (
        "all_required_evidence_passes",
        "unresolved_requirements_present",
        "failed_requirements_present",
    )
    return labels[max(ranks[value] for value in values)]


def verify_gate():
    counts = Counter()
    for vector in product(STATES, repeat=10):
        result = classify(vector)
        if result != reference(vector):
            raise RuntimeError("independent reference disagreement")
        counts[result] += 1

    expected = {
        "all_required_evidence_passes": 1,
        "failed_requirements_present": 3**10 - 2**10,
        "unresolved_requirements_present": 2**10 - 1,
    }
    if dict(counts) != expected:
        raise RuntimeError("combinatorial count mismatch")

    return {
        "engine_version": ENGINE_VERSION,
        "vectors_checked": sum(counts.values()),
        "classification_counts": dict(counts),
        "actual_requirement_satisfaction": "not_evaluated",
        "external_action_authorized": False,
    }


def valid_text(value):
    return type(value) is str and bool(value.strip())


def claim_shape_issues(claim):
    issues = []
    if type(claim) is not dict:
        return ["claim_object_required"]
    if not REQUIRED_CLAIM_FIELDS <= set(claim):
        return ["required_claim_fields_missing"]

    for field in (
        "claim_text", "classification_basis", "scope", "review_state"
    ):
        if not valid_text(claim[field]):
            issues.append(field + "_invalid")

    classification = claim["classification"]
    if type(classification) is not str or classification not in CLASSIFICATIONS:
        issues.append("classification_invalid")

    revision = claim["revision"]
    if type(revision) is not int or revision < 0:
        issues.append("revision_invalid")

    for field in (
        "sources", "evidence", "limitations",
        "invalidation_conditions", "review_triggers",
    ):
        if type(claim[field]) is not list:
            issues.append(field + "_must_be_list")

    for field in ("limitations", "invalidation_conditions", "review_triggers"):
        if type(claim[field]) is list:
            if any(not valid_text(value) for value in claim[field]):
                issues.append(field + "_contains_invalid_text")

    return issues


def audit_revision(
    previous,
    proposed,
    *,
    trigger_observed,
    counterevidence_reported,
    review_disposition_recorded,
):
    """Inspect one explicitly paired revision; never infer source authenticity.

    Review-event Booleans are caller declarations requiring external provenance.
    Findings are value-free and intended for restricted local review.
    """
    for flag in (
        trigger_observed,
        counterevidence_reported,
        review_disposition_recorded,
    ):
        if type(flag) is not bool:
            raise ValueError("review-event flags must be Boolean")

    errors = (
        ["previous:" + code for code in claim_shape_issues(previous)]
        + ["proposed:" + code for code in claim_shape_issues(proposed)]
    )
    if errors:
        return {
            "engine_version": ENGINE_VERSION,
            "status": "invalid_audit_input",
            "findings": errors,
            "authority": "none_granted",
        }

    findings = []
    changed = any(
        previous[field] != proposed[field]
        for field in REQUIRED_CLAIM_FIELDS if field != "revision"
    )

    if changed and proposed["revision"] <= previous["revision"]:
        findings.append("changed_claim_without_revision_advance")
    elif proposed["revision"] < previous["revision"]:
        findings.append("revision_rollback")

    classification_changed = (
        previous["classification"] != proposed["classification"]
    )
    if classification_changed:
        findings.append("classification_change_requires_review")
        if previous["classification_basis"] == proposed["classification_basis"]:
            findings.append("classification_changed_without_revised_basis")

    if previous["scope"] != proposed["scope"]:
        findings.append("scope_changed_requires_review")
    if previous["claim_text"] != proposed["claim_text"]:
        findings.append("proposition_changed_requires_review")
    if set(previous["limitations"]) - set(proposed["limitations"]):
        findings.append("limitations_removed_requires_review")

    if proposed["classification"] == "tested_implementation":
        has_execution_record = any(
            type(item) is dict
            and item.get("kind") == "executed_test_record"
            and valid_text(item.get("reference"))
            for item in proposed["evidence"]
        )
        if not has_execution_record:
            findings.append("tested_classification_without_execution_record")

    if proposed["classification"] == "established_finding":
        if not proposed["sources"]:
            findings.append("established_classification_without_source")

    if (
        trigger_observed or counterevidence_reported
    ) and not review_disposition_recorded:
        findings.append("observed_event_without_review_disposition")

    return {
        "engine_version": ENGINE_VERSION,
        "status": (
            "review_required" if findings
            else "no_selected_structural_drift_detected"
        ),
        "findings": findings,
        "source_support": "not_authenticated",
        "freshness": "not_established_by_this_audit",
        "authority": "none_granted",
    }


if __name__ == "__main__":
    import json
    print(json.dumps(verify_gate(), sort_keys=True, indent=2))
