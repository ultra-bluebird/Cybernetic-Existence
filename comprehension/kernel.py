"""Five-task aggregate comprehension reporting.

Python 3.10+; dependency: jsonschema with Draft 2020-12 support.
Use the trusted local schema, never a profile-supplied schema.
No collection, storage, network access, publication, or system control.
SPDX-License-Identifier: MIT OR Apache-2.0
"""
from copy import deepcopy
from jsonschema import Draft202012Validator, ValidationError

ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
TASKS = ("meaning", "derived", "inference", "consent", "correction")
COUNTS = ("assigned", "correct", "incorrect", "explicit_uncertainty", "missing")
MAX_COUNT = 2**53 - 1

class CountError(ValueError):
    pass

def snapshot(value, depth=0):
    if depth > 16:
        raise CountError("record_depth_limit")
    if type(value) is dict:
        if len(value) > 32 or any(type(k) is not str for k in value):
            raise CountError("plain_object_required")
        return {k: snapshot(v, depth + 1) for k, v in value.items()}
    if type(value) in (str, int, bool, type(None)):
        if type(value) is str and len(value) > 4096:
            raise CountError("record_string_limit")
        return value
    raise CountError("unsupported_record_type")

def local_references_only(value):
    if type(value) is dict:
        for key, item in value.items():
            if key in ("$ref", "$dynamicRef") and (
                type(item) is not str or not item.startswith("#/")
            ):
                raise CountError("nonlocal_schema_reference")
            local_references_only(item)
    elif type(value) is list:
        for item in value:
            local_references_only(item)

class ComprehensionKernel:
    def __init__(self, trusted_schema):
        local_references_only(trusted_schema)
        Draft202012Validator.check_schema(trusted_schema)
        self.validator = Draft202012Validator(deepcopy(trusted_schema))

    def summarize(self, record):
        data = snapshot(record)
        try:
            self.validator.validate(data)
        except ValidationError:
            raise CountError("record_schema_mismatch") from None

        rows = {}
        vector = {}
        for task in TASKS:
            cell = data["tasks"][task]
            if any(type(cell[name]) is not int for name in COUNTS):
                raise CountError("plain_integer_counts_required")
            if any(not 0 <= cell[name] <= MAX_COUNT for name in COUNTS):
                raise CountError("count_outside_supported_range")

            partition = sum(cell[name] for name in COUNTS if name != "assigned")
            if partition > MAX_COUNT or partition != cell["assigned"]:
                raise CountError("response_partition_mismatch")

            scorable = cell["correct"] + cell["incorrect"]
            rate = None if scorable == 0 else cell["correct"] / scorable
            coverage = None if cell["assigned"] == 0 else scorable / cell["assigned"]
            rows[task] = {
                "rubric_revision": cell["rubric_revision"],
                "counts": {name: cell[name] for name in COUNTS},
                "correct_numerator": cell["correct"],
                "scorable_denominator": scorable,
                "correct_rate": rate,
                "rate_status": "undefined_no_scorable_responses" if scorable == 0 else "defined",
                "scorable_coverage": coverage,
            }
            vector[task] = rate

        return {
            "schema_version": "1.0.0",
            "record_kind": "task_comprehension_summary",
            "provenance": data["provenance"],
            "scope": data["scope"],
            "task_order": list(TASKS),
            "comprehension_vector": vector,
            "tasks": rows,
            "composite": "not_calculated",
            "adequacy": "not_evaluated",
            "world_save_acceptance": "not_evaluated",
            "execution_authorization": "not_evaluated",
        }
