"""Reference-inventory aggregation for world-save prerequisite reviews.

Python 3.10 or newer; standard library only.
No acceptance, authentication, storage, publication, or actuation.

Enrichments over the prior revision:
- Validation bug fixed: non-string applicability/result/exclusion values
  now raise a named ValueError instead of an unhashable-type TypeError.
- Aggregate and per-requirement reason codes are stable named constants,
  so downstream consumers can distinguish missing records, unresolved
  applicability, missing or rejected exclusions, and failed dependencies.
- Optional non-identifying ReviewContext (reviewer role, reviewed-at,
  revision, evidence reference) for audit without collecting personal data.
- Optional dependency edges (Review.depends_on) with closure computation
  and cycle detection. A positive state whose transitive dependency is
  failed or unknown becomes unknown, never positive.
- passed_count added; sum of passed+excluded+unknown+failed == reference_count.
- Deterministic SHA-256 over a canonical JSON serialization, so two runs
  over the same inputs are directly comparable.
- Helpers: prerequisites_met, validate_result, inventory_diff, and the
  factories make_applicable / make_inapplicable / make_unknown.
- validate_result enforces internal consistency; it does not attest that
  any review decision is correct.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass, field
from typing import Mapping

ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
SCHEMA_VERSION = "1.1.0"

APPLICABILITY_VALUES = frozenset({"applicable", "inapplicable", "unknown"})
RESULT_VALUES = frozenset({"P", "F", "U"})
EXCLUSION_REVIEW_VALUES = frozenset({"pending", "accepted", "rejected"})

AGGREGATE_FAILURE = "applicable_failure"
AGGREGATE_EMPTY = "no_established_applicable_requirement"
AGGREGATE_PASS = "applicable_passes_and_reviewed_exclusions"
AGGREGATE_UNRESOLVED = "reference_inventory_unresolved"

REASON_APPLICABLE = "applicable"
REASON_MISSING_RECORD = "missing_record"
REASON_APPLICABILITY_UNKNOWN = "applicability_unknown"
REASON_EXCLUSION_REASON_MISSING = "exclusion_reason_missing"
REASON_EXCLUSION_REASON_NOT_PERMITTED = "exclusion_reason_not_permitted"
REASON_EXCLUSION_REVIEW_PENDING = "exclusion_review_pending"
REASON_EXCLUSION_REVIEW_REJECTED = "exclusion_review_rejected"
REASON_DEPENDENCY_FAILED = "dependency_failed"
REASON_DEPENDENCY_UNRESOLVED = "dependency_unresolved"


@dataclass(frozen=True)
class ReviewContext:
    """Optional, non-identifying context attached to a review."""

    reviewer_role: str = ""
    reviewed_at: str = ""
    revision: int = 0
    evidence_ref: str = ""


@dataclass(frozen=True)
class Review:
    applicability: str
    result: str | None = None
    exclusion_reason: str = ""
    exclusion_review: str = "pending"
    depends_on: frozenset[str] = field(default_factory=frozenset)
    context: ReviewContext = field(default_factory=ReviewContext)


def _require_str(value, name, allow_empty=True):
    if type(value) is not str:
        raise ValueError(f"{name}_type")
    if not allow_empty and not value.strip():
        raise ValueError(f"{name}_empty")


def _require_member(value, allowed, name):
    if type(value) is not str:
        raise ValueError(f"{name}_type")
    if value not in allowed:
        raise ValueError(f"{name}_value")


def validate_context(context):
    if type(context) is not ReviewContext:
        raise ValueError("context_type")
    _require_str(context.reviewer_role, "reviewer_role")
    _require_str(context.reviewed_at, "reviewed_at")
    _require_str(context.evidence_ref, "evidence_ref")
    if type(context.revision) is not int:
        raise ValueError("revision_type")
    if context.revision < 0:
        raise ValueError("revision_value")


def validate_review(review):
    if type(review) is not Review:
        raise ValueError("review_type")

    _require_member(review.applicability, APPLICABILITY_VALUES, "applicability")
    _require_str(review.exclusion_reason, "exclusion_reason")
    _require_member(
        review.exclusion_review,
        EXCLUSION_REVIEW_VALUES,
        "exclusion_review",
    )

    if type(review.depends_on) is not frozenset:
        raise ValueError("depends_on_type")
    for dep in review.depends_on:
        if type(dep) is not str or not dep.strip():
            raise ValueError("depends_on_value")

    validate_context(review.context)

    if review.applicability == "applicable":
        if type(review.result) is not str or review.result not in RESULT_VALUES:
            raise ValueError("applicable_result_required")
        if review.exclusion_reason or review.exclusion_review != "pending":
            raise ValueError("unexpected_exclusion_fields")
    elif review.applicability == "inapplicable":
        if review.result is not None:
            raise ValueError("result_requires_applicability")
    else:  # unknown applicability; result optional but must be well-typed
        if review.result is not None and (
            type(review.result) is not str or review.result not in RESULT_VALUES
        ):
            raise ValueError("result_requires_applicability")


def _dependency_closure(reference, records):
    declared = set(reference)
    forward = {}
    for req in reference:
        record = records.get(req)
        if record is None:
            forward[req] = frozenset()
            continue
        validate_review(record)
        extra = record.depends_on - declared
        if extra:
            raise ValueError("undeclared_dependency")
        forward[req] = record.depends_on

    color = {}

    def visit(node):
        if color.get(node) == 1:
            raise ValueError("dependency_cycle")
        if color.get(node) == 2:
            return frozenset()
        color[node] = 1
        result = set()
        for parent in forward.get(node, frozenset()):
            result.add(parent)
            result |= visit(parent)
        color[node] = 2
        return frozenset(result)

    return {req: visit(req) for req in reference}


def _evaluate_record(record, permitted):
    if record is None:
        return "U", REASON_MISSING_RECORD, ""

    if record.applicability == "applicable":
        return record.result, REASON_APPLICABLE, ""

    if record.applicability == "unknown":
        return "U", REASON_APPLICABILITY_UNKNOWN, ""

    if not record.exclusion_reason:
        return "U", REASON_EXCLUSION_REASON_MISSING, ""
    if record.exclusion_reason not in permitted:
        return "U", REASON_EXCLUSION_REASON_NOT_PERMITTED, record.exclusion_reason
    if record.exclusion_review == "pending":
        return "U", REASON_EXCLUSION_REVIEW_PENDING, record.exclusion_reason
    if record.exclusion_review == "rejected":
        return "U", REASON_EXCLUSION_REVIEW_REJECTED, record.exclusion_reason
    return "excluded", record.exclusion_reason, record.exclusion_reason


def _canonical_hash(obj):
    payload = json.dumps(
        obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def review_inventory(reference, records, permitted_exclusions,
                     require_applicable=True):
    if (
        type(reference) is not tuple
        or not reference
        or any(type(x) is not str or not x.strip() for x in reference)
        or len(set(reference)) != len(reference)
    ):
        raise ValueError("nonempty_unique_reference_required")

    if not isinstance(records, Mapping):
        raise ValueError("mapping_inputs_required")
    if not isinstance(permitted_exclusions, Mapping):
        raise ValueError("mapping_inputs_required")

    if set(records) - set(reference):
        raise ValueError("undeclared_requirement")
    if set(permitted_exclusions) - set(reference):
        raise ValueError("undeclared_exclusion_policy")

    for reasons in permitted_exclusions.values():
        if type(reasons) is not frozenset:
            raise ValueError("invalid_exclusion_policy")
        for reason in reasons:
            if type(reason) is not str or not reason.strip():
                raise ValueError("invalid_exclusion_policy")

    if type(require_applicable) is not bool:
        raise ValueError("require_applicable_type")

    closure = _dependency_closure(reference, records)

    base_states = {}
    for requirement in reference:
        record = records.get(requirement)
        state, reason, exclusion = _evaluate_record(
            record,
            permitted_exclusions.get(requirement, frozenset()),
        )
        base_states[requirement] = (state, reason, exclusion)

    outcomes = []
    for requirement in reference:
        state, reason, exclusion = base_states[requirement]
        if state == "P":
            dep_states = {base_states[d][0] for d in closure[requirement]}
            if "F" in dep_states:
                state = "U"
                reason = REASON_DEPENDENCY_FAILED
            elif "U" in dep_states:
                state = "U"
                reason = REASON_DEPENDENCY_UNRESOLVED
        outcomes.append({
            "requirement": requirement,
            "state": state,
            "reason": reason,
            "exclusion_reason": exclusion,
            "depends_on": sorted(closure[requirement]),
        })

    states = [item["state"] for item in outcomes]
    applicable_count = sum(
        1 for req in reference
        if records.get(req) is not None
        and records[req].applicability == "applicable"
    )

    if "F" in states:
        aggregate = "F"
        aggregate_reason = AGGREGATE_FAILURE
    elif require_applicable and applicable_count == 0:
        aggregate = "U"
        aggregate_reason = AGGREGATE_EMPTY
    elif all(s in {"P", "excluded"} for s in states):
        aggregate = "P"
        aggregate_reason = AGGREGATE_PASS
    else:
        aggregate = "U"
        aggregate_reason = AGGREGATE_UNRESOLVED

    summary = {
        "schema_version": SCHEMA_VERSION,
        "sovereign_attribution": ATTRIBUTION,
        "attribution_use": "document_credit_only",
        "reference_count": len(reference),
        "applicable_count": applicable_count,
        "passed_count": states.count("P"),
        "excluded_count": states.count("excluded"),
        "unknown_count": states.count("U"),
        "failed_count": states.count("F"),
        "aggregate": aggregate,
        "aggregate_reason": aggregate_reason,
        "requirements": outcomes,
        "require_applicable": require_applicable,
        "acceptance_evaluated": False,
        "review_authority_verified": False,
        "world_save_established_by_calculation": False,
    }
    summary["deterministic_hash"] = _canonical_hash(summary)
    return summary


def prerequisites_met(result):
    """True only when the aggregate is a positive claim within scope.

    A positive aggregate is a prerequisite for a person-directed
    acceptance; it is not itself a world-save. The returned boolean
    reflects the calculation, not acceptance or execution authority.
    """
    if not isinstance(result, dict):
        raise ValueError("result_type")
    if result.get("schema_version") != SCHEMA_VERSION:
        raise ValueError("result_schema_mismatch")
    return (
        result.get("aggregate") == "P"
        and result.get("aggregate_reason") == AGGREGATE_PASS
        and result.get("acceptance_evaluated") is False
        and result.get("world_save_established_by_calculation") is False
    )


def validate_result(result):
    """Verify the summary is well-formed and internally consistent.

    Does not attest that the review decisions are correct; only that
    the returned data satisfies its own declared invariants.
    """
    if not isinstance(result, dict):
        raise ValueError("result_type")

    required = {
        "schema_version", "sovereign_attribution", "attribution_use",
        "reference_count", "applicable_count", "passed_count",
        "excluded_count", "unknown_count", "failed_count",
        "aggregate", "aggregate_reason", "requirements",
        "require_applicable", "acceptance_evaluated",
        "review_authority_verified",
        "world_save_established_by_calculation",
        "deterministic_hash",
    }
    missing = required - set(result)
    if missing:
        raise ValueError(f"missing_fields:{sorted(missing)}")

    if result["schema_version"] != SCHEMA_VERSION:
        raise ValueError("schema_version_mismatch")
    if result["sovereign_attribution"] != ATTRIBUTION:
        raise ValueError("attribution_mismatch")
    if result["attribution_use"] != "document_credit_only":
        raise ValueError("attribution_use_value")

    for name in (
        "acceptance_evaluated",
        "review_authority_verified",
        "world_save_established_by_calculation",
    ):
        if result[name] is not False:
            raise ValueError(f"{name}_must_be_false")

    if type(result["require_applicable"]) is not bool:
        raise ValueError("require_applicable_type")

    for name in (
        "reference_count", "applicable_count", "passed_count",
        "excluded_count", "unknown_count", "failed_count",
    ):
        value = result[name]
        if type(value) is not int or value < 0:
            raise ValueError(f"{name}_value")

    state_sum = (
        result["passed_count"]
        + result["excluded_count"]
        + result["unknown_count"]
        + result["failed_count"]
    )
    if state_sum != result["reference_count"]:
        raise ValueError("state_sum_mismatch")

    if result["applicable_count"] > result["reference_count"]:
        raise ValueError("applicable_count_exceeds_reference")

    if len(result["requirements"]) != result["reference_count"]:
        raise ValueError("requirement_count_mismatch")

    if result["aggregate"] not in {"P", "F", "U"}:
        raise ValueError("aggregate_value")

    valid_reasons = {
        "P": {AGGREGATE_PASS},
        "F": {AGGREGATE_FAILURE},
        "U": {AGGREGATE_EMPTY, AGGREGATE_UNRESOLVED},
    }
    if result["aggregate_reason"] not in valid_reasons[result["aggregate"]]:
        raise ValueError("aggregate_reason_mismatch")

    if result["aggregate"] == "F" and result["failed_count"] == 0:
        raise ValueError("aggregate_failure_without_failure")
    if result["aggregate"] == "P" and result["failed_count"]:
        raise ValueError("aggregate_pass_with_failure")
    if result["aggregate"] == "P" and result["unknown_count"]:
        raise ValueError("aggregate_pass_with_unknown")

    expected = _canonical_hash(
        {k: v for k, v in result.items() if k != "deterministic_hash"}
    )
    if result["deterministic_hash"] != expected:
        raise ValueError("deterministic_hash_mismatch")


def inventory_diff(old_result, new_result):
    """Compare two summaries produced by this schema version."""
    validate_result(old_result)
    validate_result(new_result)

    old_req = {r["requirement"]: r for r in old_result["requirements"]}
    new_req = {r["requirement"]: r for r in new_result["requirements"]}

    transitions = []
    for name in sorted(set(old_req) | set(new_req)):
        before = old_req.get(name, {}).get("state", "absent")
        after = new_req.get(name, {}).get("state", "absent")
        if before != after:
            transitions.append({
                "requirement": name,
                "before": before,
                "after": after,
            })

    return {
        "from_hash": old_result["deterministic_hash"],
        "to_hash": new_result["deterministic_hash"],
        "aggregate_change": (
            old_result["aggregate"],
            new_result["aggregate"],
        ),
        "transitions": transitions,
    }


def make_applicable(result, **context_kwargs):
    return Review(
        applicability="applicable",
        result=result,
        context=ReviewContext(**context_kwargs),
    )


def make_inapplicable(reason, review="pending", **context_kwargs):
    return Review(
        applicability="inapplicable",
        exclusion_reason=reason,
        exclusion_review=review,
        context=ReviewContext(**context_kwargs),
    )


def make_unknown(**context_kwargs):
    return Review(
        applicability="unknown",
        context=ReviewContext(**context_kwargs),
    )
