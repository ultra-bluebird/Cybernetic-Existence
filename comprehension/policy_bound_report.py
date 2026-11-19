"""Policy-bound companion for the existing comprehension kernel.

Python 3.10 or newer.
Dependency: jsonschema with Draft 2020-12 support.

Use trusted local schemas and a reviewed local policy record.
No collection, storage, network access, publication, or system control.

SPDX-License-Identifier: MIT OR Apache-2.0
"""

from copy import deepcopy

from jsonschema import (
    Draft202012Validator,
    SchemaError,
    ValidationError,
)

from research.comprehension.kernel import (
    ComprehensionKernel,
    CountError,
    local_references_only,
)


class ProfileError(ValueError):
    pass


class PolicyBoundComprehensionReport:
    def __init__(
        self,
        counts_schema,
        policy_record,
        policy_definition,
    ):
        try:
            local_references_only(policy_definition)
            Draft202012Validator.check_schema(policy_definition)
            Draft202012Validator(policy_definition).validate(
                policy_record
            )
        except (CountError, ValidationError, SchemaError):
            raise ProfileError(
                "invalid_or_nonlocal_policy_profile"
            ) from None

        if policy_record["policy_version"] != "1.0.0":
            raise ProfileError("unsupported_policy_version")

        self._kernel = ComprehensionKernel(counts_schema)

        # Copy the policy-derived values used by this instance.
        # Later mutation of the caller's policy does not change them.
        self._order = tuple(policy_record["task_order"])
        self._version = policy_record["policy_version"]
        self._composite = policy_record["composite"]
        self._publication = policy_record["publication"]

    def summarize(self, record):
        summary = self._kernel.summarize(record)

        if (
            summary["schema_version"] != "1.0.0"
            or summary["record_kind"]
            != "task_comprehension_summary"
            or tuple(summary["task_order"]) != self._order
            or summary["composite"] != self._composite
        ):
            raise ProfileError("kernel_profile_mismatch")

        unevaluated_fields = (
            "adequacy",
            "world_save_acceptance",
            "execution_authorization",
        )

        if any(
            summary.get(name) != "not_evaluated"
            for name in unevaluated_fields
        ):
            raise ProfileError("kernel_claim_boundary_mismatch")

        coverage = {}

        for task in self._order:
            row = summary["tasks"][task]
            numerator = row["scorable_denominator"]
            denominator = row["counts"]["assigned"]

            expected = (
                None
                if denominator == 0
                else numerator / denominator
            )

            if row["scorable_coverage"] != expected:
                raise ProfileError("coverage_arithmetic_mismatch")

            coverage[task] = {
                "numerator": numerator,
                "denominator": denominator,
                "value": expected,
                "status": (
                    "undefined_no_assigned_responses"
                    if denominator == 0
                    else "defined"
                ),
            }

        return {
            "schema_version": "1.0.0",
            "record_kind": "policy_bound_comprehension_report",
            "policy_version": self._version,
            "provenance": deepcopy(summary["provenance"]),
            "summary": summary,
            "coverage_details": coverage,
            "publication_rule": self._publication,
            "manifest_adapter_compatibility": "not_established",
            "authority_and_counts_authenticity": "not_evaluated",
        }
