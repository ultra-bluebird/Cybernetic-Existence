# SPDX-License-Identifier: MIT OR Apache-2.0
"""Finite structural non-derivation checks with negative controls."""

from copy import deepcopy
from datetime import datetime, timezone
from itertools import product
import json


ENGINE_VERSION = "2.0.0"
DIMS_VERSION = "2.0.0"

DOMAIN = (
    ("contribution_completion", (
        "not_completed", "completed", "completion_unresolved"
    )),
    ("milestone_acceptance", (
        "not_established", "accepted", "disputed"
    )),
    ("evidence_availability", (
        "available", "unavailable", "availability_unresolved"
    )),
    ("correction", (
        "none_recorded", "open", "resolved"
    )),
    ("current_support", (
        "available", "gap", "support_unresolved"
    )),
    ("maintenance", (
        "current", "unavailable", "maintenance_unresolved"
    )),
    ("reuse_permission", (
        "withheld", "terms_review_required", "reuse_unresolved"
    )),
    ("operation_review", (
        "absent", "pending", "review_complete"
    )),
)


def project(record):
    """Baseline only: copy declared states without deriving other states."""
    if type(record) is not dict:
        raise ValueError("plain dictionary required")
    if set(record) != {name for name, _ in DOMAIN}:
        raise ValueError("unsupported dimension fields")

    for name, states in DOMAIN:
        if type(record[name]) is not str or record[name] not in states:
            raise ValueError("unsupported dimension state")
    return dict(record)


def check(candidate):
    """Check a deterministic, stateless candidate over the full finite domain.

    This tests non-derivation and output shape, not truth or authorization.
    Exceptions from candidate are execution failures and are not swallowed.
    """
    fibers = {}
    records = 0
    comparisons = 0

    for vector in product(*(states for _, states in DOMAIN)):
        record = dict(zip((name for name, _ in DOMAIN), vector))
        before = deepcopy(record)
        result = candidate(record)

        if record != before:
            return {
                "passed": False,
                "failure": "input_mutation",
                "vectors_checked": records,
            }
        if type(result) is not dict or set(result) != set(record):
            return {
                "passed": False,
                "failure": "output_contract",
                "vectors_checked": records,
            }

        records += 1

        for name, states in DOMAIN:
            if type(result[name]) is not str or result[name] not in states:
                return {
                    "passed": False,
                    "failure": "output_state",
                    "vectors_checked": records,
                }

            key = (name, record[name])
            if key not in fibers:
                fibers[key] = result[name]
                continue

            comparisons += 1
            if result[name] != fibers[key]:
                return {
                    "passed": False,
                    "failure": "cross_dimension_derivation",
                    "dimension": name,
                    "vectors_checked": records,
                }

    covered_pairs = sum(
        len(states) * (records // len(states)) ** 2
        for _, states in DOMAIN
    )
    return {
        "passed": True,
        "vectors_checked": records,
        "fiber_classes": len(fibers),
        "fiber_representative_comparisons": comparisons,
        "covered_ordered_equal_coordinate_pairs": covered_pairs,
    }


def direct_mutant(record):
    result = project(record)
    if record["milestone_acceptance"] == "accepted":
        result["evidence_availability"] = "available"
    return result


def joint_mutant(record):
    result = project(record)
    if (
        record["milestone_acceptance"] == "accepted"
        and record["correction"] == "resolved"
        and record["current_support"] == "gap"
        and record["maintenance"] == "unavailable"
    ):
        result["evidence_availability"] = "available"
    return result


def authority_mutant(record):
    result = project(record)
    result["publication_authorized"] = True
    return result


def build_report(completed_at):
    if type(completed_at) is not datetime:
        raise ValueError("datetime required")
    if completed_at.utcoffset() is None:
        raise ValueError("timezone-aware completion timestamp required")

    results = {
        "baseline": check(project),
        "direct_mutant": check(direct_mutant),
        "joint_mutant": check(joint_mutant),
        "authority_mutant": check(authority_mutant),
    }

    if not results["baseline"]["passed"]:
        raise RuntimeError("baseline failed")
    if any(
        results[name]["passed"]
        for name in ("direct_mutant", "joint_mutant", "authority_mutant")
    ):
        raise RuntimeError("negative control was not detected")

    return {
        "engine_version": ENGINE_VERSION,
        "dims_version": DIMS_VERSION,
        "completed_at": completed_at.astimezone(timezone.utc).isoformat(),
        "classification": "finite_structural_non_derivation_check",
        "results": results,
        "scope": (
            "Deterministic stateless candidate over the declared Cartesian "
            "domain. Not lifecycle reachability, authenticity, consent, "
            "consumer behavior, or epistemic interpretation."
        ),
        "schema_codec_and_base_adapter_tested": False,
        "persistent_identifiers_created": False,
    }


def encode_report(report):
    """Deterministic JSON layout for the ASCII-keyed generated report."""
    return json.dumps(
        report,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    )


if __name__ == "__main__":
    try:
        print(encode_report(build_report(datetime.now(timezone.utc))))
    except (ValueError, RuntimeError) as error:
        print(str(error))
        raise SystemExit(1)
    raise SystemExit(0)
