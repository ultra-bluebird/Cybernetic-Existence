# SPDX-License-Identifier: MIT OR Apache-2.0
"""Standalone milestone companion; no base-manifest mutation or authority."""

from copy import deepcopy
from itertools import product
import json
import sys


VERSION = "1.0.0"
TARGET_VERSION = "1.0.0"

DIMS = {
    "milestone_acceptance": ("not_established", "accepted", "disputed"),
    "evidence_availability": ("available", "unavailable", "unknown"),
    "correction": ("none_recorded", "open", "resolved"),
    "current_support": ("available", "gap", "unknown"),
    "maintenance": ("current", "unavailable", "unknown"),
    "reuse_permission": ("withheld", "scoped_permission_reported", "unknown"),
    "operation_review": ("absent", "pending", "review_complete"),
}


def closed(properties):
    return {
        "type": "object",
        "additionalProperties": False,
        "required": list(properties),
        "properties": properties,
    }


SCHEMA = {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "title": "Augma Contribution Milestone Companion",
    **closed({
        "schema_version": {"const": VERSION},
        "record_kind": {"const": "standalone_contribution_milestone_companion"},
        "target": closed({
            "specification": {"const": "World-Save"},
            "version": {"const": TARGET_VERSION},
            "attachment": {"const": "separate_document_no_base_mutation"},
            "adapter_status": {"const": "not_implemented"},
        }),
        "purpose": {
            "enum": ["ecological", "social", "ecological_and_social"]
        },
        "milestone_summary": {
            "type": "string", "minLength": 1, "maxLength": 512
        },
        "dimensions": closed({
            name: {"type": "string", "enum": list(values)}
            for name, values in DIMS.items()
        }),
        "limits": {
            "const": {
                "statuses_are": "supplied_not_authenticated",
                "reuse_scope": "requires_separately_reviewed_terms",
                "operational_authority": "not_granted",
                "publication_authority": "not_granted",
                "collection_authority": "not_established",
            }
        },
    }),
}


def exact_fields(value, names):
    if type(value) is not dict or set(value) != set(names):
        raise ValueError("missing or unsupported fields")


def project(record):
    """Preserve supplied dimensions without cross-dimension derivation."""
    exact_fields(record, DIMS)
    for name, allowed in DIMS.items():
        if type(record[name]) is not str or record[name] not in allowed:
            raise ValueError("unsupported dimension state")
    return {
        "dimensions": dict(record),
        "external_action_authorized": False,
    }


def validate(companion):
    expected = SCHEMA["properties"]
    exact_fields(companion, expected)

    for name in ("schema_version", "record_kind"):
        if type(companion[name]) is not str:
            raise ValueError("text constant required")
        if companion[name] != expected[name]["const"]:
            raise ValueError("unsupported version or record kind")

    target = companion["target"]
    target_properties = expected["target"]["properties"]
    exact_fields(target, target_properties)
    for name, rule in target_properties.items():
        if type(target[name]) is not str or target[name] != rule["const"]:
            raise ValueError("unsupported target or attachment")

    purpose = companion["purpose"]
    if type(purpose) is not str or purpose not in expected["purpose"]["enum"]:
        raise ValueError("unsupported purpose")

    summary = companion["milestone_summary"]
    if (
        type(summary) is not str
        or not 1 <= len(summary) <= 512
        or summary != summary.strip()
    ):
        raise ValueError("trimmed bounded milestone summary required")

    project(companion["dimensions"])

    limits = companion["limits"]
    required_limits = expected["limits"]["const"]
    exact_fields(limits, required_limits)
    if any(
        type(limits[name]) is not str or limits[name] != value
        for name, value in required_limits.items()
    ):
        raise ValueError("unsupported authority or evidence declaration")
    return {
        "schema_version": VERSION,
        "structural_result": "valid_under_local_profile",
        "base_manifest_compatibility": "not_tested",
        "external_action_authorized": False,
    }


def unique_members(pairs):
    result = {}
    for name, value in pairs:
        if name in result:
            raise ValueError("duplicate JSON member")
        result[name] = value
    return result


def reject_constant(value):
    raise ValueError("non-finite JSON constant rejected")


def encode(companion):
    """Return an in-memory serialization, not publication permission."""
    validate(companion)
    return json.dumps(
        companion, sort_keys=True, separators=(",", ":"),
        ensure_ascii=False, allow_nan=False,
    )


def decode(payload):
    if type(payload) is not str or len(payload) > 100_000:
        raise ValueError("invalid or oversized payload")
    try:
        companion = json.loads(
            payload,
            object_pairs_hook=unique_members,
            parse_constant=reject_constant,
        )
    except RecursionError as exc:
        raise ValueError("unsupported JSON nesting") from exc
    validate(companion)
    return companion


def exhaustive_projection_check():
    keys = tuple(DIMS)
    vectors = product(*(DIMS[name] for name in keys))
    vector_count = local_checks = higher_checks = 0

    for vector in vectors:
        record = dict(zip(keys, vector))
        before = deepcopy(record)
        output = project(record)

        if record != before or output["external_action_authorized"] is not False:
            raise AssertionError("immutability or authority invariant failed")
        vector_count += 1

        for name in keys:
            for alternative in DIMS[name]:
                if alternative == record[name]:
                    continue
                changed = dict(record, **{name: alternative})
                result = project(changed)
                if any(
                    result["dimensions"][other] != output["dimensions"][other]
                    for other in keys if other != name
                ):
                    raise AssertionError("cross-dimension inference detected")
                local_checks += 1

            changed = {
                other: (
                    value if other == name
                    else DIMS[other][(DIMS[other].index(value) + 1) % 3]
                )
                for other, value in record.items()
            }
            if project(changed)["dimensions"][name] != output["dimensions"][name]:
                raise AssertionError("higher-order inference detected")
            higher_checks += 1

    return {
        "schema_version": VERSION,
        "state_vectors": vector_count,
        "single_dimension_checks": local_checks,
        "simultaneous_other_dimension_checks": higher_checks,
        "external_authority_false": True,
        "scope": "synthetic_projection_not_real_world_validation",
    }


if __name__ == "__main__":
    if sys.argv[1:] == ["--schema"]:
        print(json.dumps(SCHEMA, indent=2, ensure_ascii=False))
    elif not sys.argv[1:]:
        print(json.dumps(exhaustive_projection_check(), indent=2))
    else:
        raise SystemExit("Use no arguments for checks, or --schema.")
