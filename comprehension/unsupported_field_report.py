# SPDX-License-Identifier: MIT OR Apache-2.0
"""Value-free unexpected-field reporting at one explicit object boundary."""

import unittest


VERSION = "1.0.0"
CLASSIFICATIONS = frozenset({
    "reviewed_optional",
    "consequential",
    "privacy_excluded",
    "unclassified",
})


def field_name(value):
    if type(value) is not str or not 1 <= len(value) <= 128:
        raise ValueError("bounded plain field name required")
    if any(ord(char) < 32 or ord(char) > 126 for char in value):
        raise ValueError("ASCII field name required")


def report_fields(record, supported_fields, classification_policy, parent=()):
    if type(record) is not dict:
        raise ValueError("plain object required")
    if type(supported_fields) is not frozenset:
        raise ValueError("immutable supported-field set required")
    if type(classification_policy) is not dict or type(parent) is not tuple:
        raise ValueError("explicit policy and path required")

    for name in record:
        field_name(name)
    for name in supported_fields:
        field_name(name)
    for name, classification in classification_policy.items():
        field_name(name)
        if type(classification) is not str or classification not in CLASSIFICATIONS:
            raise ValueError("unsupported field classification")
    for component in parent:
        field_name(component)

    findings = []
    for name in sorted(set(record) - supported_fields):
        classification = classification_policy.get(name, "unclassified")
        findings.append({
            "code": "unsupported_field",
            "path": list(parent + (name,)),
            "classification": classification,
            "value": "not_recorded",
            "conversion": "rejected",
        })

    return {
        "engine_version": VERSION,
        "boundary": list(parent),
        "findings": findings,
        "result": (
            "rejected_unsupported_fields"
            if findings else "no_unexpected_fields_at_this_boundary"
        ),
        "complete_schema_validation": "not_established",
        "external_action_authorized": False,
    }


class FieldReportTests(unittest.TestCase):
    def test_optional_is_reported_not_dropped(self):
        result = report_fields(
            {"tasks": {}, "comment": "private text"},
            frozenset({"tasks"}),
            {"comment": "reviewed_optional"},
        )
        self.assertEqual(result["result"], "rejected_unsupported_fields")
        self.assertEqual(
            result["findings"][0]["classification"], "reviewed_optional"
        )
        self.assertNotIn("private text", str(result))

    def test_unknown_significance_is_not_benign(self):
        result = report_fields(
            {"extra": 1}, frozenset(), {}
        )
        self.assertEqual(
            result["findings"][0]["classification"], "unclassified"
        )

    def test_no_value_export(self):
        result = report_fields(
            {"credentials": {"secret": "never copy"}},
            frozenset(),
            {"credentials": "privacy_excluded"},
        )
        self.assertNotIn("never copy", str(result))

    def test_supported_presence_is_not_value_validation(self):
        result = report_fields(
            {"tasks": "invalid task object"}, frozenset({"tasks"}), {}
        )
        self.assertEqual(
            result["complete_schema_validation"], "not_established"
        )


if __name__ == "__main__":
    unittest.main()
