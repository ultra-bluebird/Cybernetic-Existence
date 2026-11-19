"""Policy-leaf inventory and value-bound mapping coverage.

Python 3.10 or newer; standard library only.
No file access, network access, publication, or actuation.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

import json
import math


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"

MODES = {
    "declaration_check",
    "behavior_test",
    "expert_review",
    "hybrid",
    "context_only",
}


def reject_duplicates(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate_json_key")
        result[key] = value
    return result


def parse_policy(text):
    if type(text) is not str:
        raise TypeError("policy_text_required")
    if len(text.encode("utf-8")) > 2_000_000:
        raise ValueError("policy_text_limit")

    def reject_constant(value):
        raise ValueError("nonfinite_json_constant")

    policy = json.loads(
        text,
        object_pairs_hook=reject_duplicates,
        parse_constant=reject_constant,
    )
    if type(policy) is not dict:
        raise ValueError("policy_object_required")
    return policy


def leaf_inventory(policy):
    output = {}
    visited = 0

    def walk(value, path, depth):
        nonlocal visited
        visited += 1

        if depth > 32 or visited > 10_000:
            raise ValueError("policy_complexity_limit")

        if type(value) is dict and value:
            for key, item in value.items():
                if type(key) is not str:
                    raise ValueError("json_key_type")
                escaped = key.replace("~", "~0").replace("/", "~1")
                walk(item, path + "/" + escaped, depth + 1)

        elif type(value) is list and value:
            for position, item in enumerate(value):
                walk(item, path + "/" + str(position), depth + 1)

        elif type(value) in (
            dict, list, str, int, float, bool, type(None)
        ):
            if type(value) is float and not math.isfinite(value):
                raise ValueError("nonfinite_value")
            output[path] = value

        else:
            raise ValueError("non_json_value")

    walk(policy, "", 0)
    return output


def same_value(left, right):
    # Prevent Python's True == 1 from hiding a policy-type change.
    return type(left) is type(right) and left == right


def mapping_report(policy, mappings):
    leaves = leaf_inventory(policy)

    if type(mappings) is not list:
        raise TypeError("mapping_list_required")

    by_path = {}
    duplicates = []

    for item in mappings:
        if type(item) is not dict or set(item) != {
            "path", "expected_value", "mode", "verification_note"
        }:
            raise ValueError("mapping_shape")

        if (
            type(item["path"]) is not str
            or type(item["mode"]) is not str
            or item["mode"] not in MODES
            or type(item["verification_note"]) is not str
            or not item["verification_note"].strip()
        ):
            raise ValueError("mapping_value")

        if item["path"] in by_path:
            duplicates.append(item["path"])
        by_path[item["path"]] = item

    common = set(leaves) & set(by_path)
    missing = sorted(set(leaves) - set(by_path))
    extra = sorted(set(by_path) - set(leaves))
    stale = sorted(
        path for path in common
        if not same_value(
            leaves[path], by_path[path]["expected_value"]
        )
    )
    matched = common - set(stale)

    return {
        "schema_version": "1.0.0",
        "sovereign_attribution": ATTRIBUTION,
        "attribution_use": "document_credit_only",
        "leaf_count": len(leaves),
        "value_matched_mapping_count": len(matched),
        "mapping_coverage": len(matched) / len(leaves),
        "missing_paths": missing,
        "extra_paths": extra,
        "stale_value_paths": stale,
        "duplicate_paths": sorted(set(duplicates)),
        "structurally_complete_mapping": not (
            missing or extra or stale or duplicates
        ),
        "runtime_enforcement": "not_evaluated",
        "semantic_classification": "not_reviewed",
    }
