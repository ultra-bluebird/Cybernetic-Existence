# SPDX-License-Identifier: MIT OR Apache-2.0
"""Offline six-dimension ledger. No delivery, payment, or evidence collection."""

from copy import deepcopy
from datetime import date
import json
import sys
import unittest

from jsonschema import Draft202012Validator, FormatChecker


VERSION = "1.0.0"
UNITS = {
    "time": ("person_minute",),
    "skill": ("reviewed_deliverable",),
    "knowledge": ("artifact", "maintenance_action"),
    "attention": ("focused_person_minute",),
    "trust": ("consented_introduction", "scoped_endorsement"),
    "access": ("authorized_resource_minute",),
}
STATES = ("draft", "offered", "scheduled", "completed", "cancelled")
TRANSITIONS = {
    "draft": {"offered", "cancelled"},
    "offered": {"scheduled", "completed", "cancelled"},
    "scheduled": {"completed", "cancelled"},
    "completed": set(),
    "cancelled": set(),
}
RETENTION_FIELDS = (
    "specific_purpose",
    "sensitivity",
    "necessity_basis",
    "access_restrictions",
    "retention_trigger",
    "finite_review_or_deletion_deadline",
    "deletion_or_restriction_method",
    "backup_handling",
    "responsible_role",
)


def enum(*values):
    return {"type": "string", "enum": list(values)}


def strict_object(properties):
    return {
        "type": "object",
        "additionalProperties": False,
        "required": list(properties),
        "properties": properties,
    }


DATE = {
    "type": "string",
    "pattern": r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$",
    "format": "date",
}
COUNT = {"type": "integer", "minimum": 0, "maximum": 9_007_199_254_740_991}

RETENTION = strict_object({
    "applies_to": {"const": "entire_record_including_retention_metadata"},
    "specific_purpose": enum("private_capacity_recordkeeping"),
    "sensitivity": enum("private"),
    "necessity_basis": enum("participant_requested_bounded_record"),
    "access_restrictions": enum("participant_and_explicitly_authorized_support"),
    "retention_trigger": enum("record_created"),
    "finite_review_or_deletion_deadline": DATE,
    "deletion_or_restriction_method": enum(
        "review_then_delete_unnecessary_data_or_document_restriction"
    ),
    "backup_handling": enum(
        "no_backups",
        "copies_and_backups_require_same_deadline_review",
    ),
    "responsible_role": enum("participant", "authorized_record_holder"),
})

ENTRY = strict_object({
    "dimension": enum(*UNITS),
    "quantity": COUNT,
    "unit": enum(*(unit for units in UNITS.values() for unit in units)),
    "history": {
        "type": "array",
        "minItems": 1,
        "maxItems": 5,
        "items": enum(*STATES),
    },
    "acceptance": enum("not_reviewed", "accepted", "rejected", "disputed"),
    "evidence_availability": enum("available", "unavailable", "not_collected"),
    "authorization": {"const": "not_granted_by_ledger"},
})
ENTRY["allOf"] = [
    {
        "if": {
            "properties": {"dimension": {"const": dimension}},
            "required": ["dimension"],
        },
        "then": {"properties": {"unit": enum(*units)}},
    }
    for dimension, units in UNITS.items()
]

SCHEMA = {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "title": "Augma Six-Dimension Offline Capacity Ledger",
    **strict_object({
        "schema_version": {"const": VERSION},
        "record_kind": {"const": "private_capacity_contribution_record"},
        "purpose": enum("ecological", "social", "ecological_and_social"),
        "created_on": DATE,
        "retention": RETENTION,
        "entries": {
            "type": "array",
            "minItems": 1,
            "maxItems": 1000,
            "items": ENTRY,
        },
        "aggregation_contract": {
            "const": "no_cross_dimension_or_cross_unit_total"
        },
        "support_contract": {
            "const": "ordinary_support_not_conditioned_on_record_status"
        },
        "collection_authority": {
            "const": "not_established_by_schema"
        },
    }),
}
Draft202012Validator.check_schema(SCHEMA)
VALIDATOR = Draft202012Validator(SCHEMA, format_checker=FormatChecker())


def reject_duplicate_members(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON member")
        result[key] = value
    return result


def load_local_json(payload):
    if type(payload) is not str or len(payload) > 2_000_000:
        raise ValueError("invalid or oversized JSON payload")
    return json.loads(
        payload,
        object_pairs_hook=reject_duplicate_members,
        parse_constant=lambda value: (_ for _ in ()).throw(
            ValueError("non-finite JSON value")
        ),
    )


def validate_ledger(record, as_of):
    """Return structural validity and deadline warnings, not authority."""
    if type(as_of) is not date:
        raise ValueError("as_of must be a date, not a datetime")
    errors = sorted(
        VALIDATOR.iter_errors(record),
        key=lambda error: tuple(str(part) for part in error.absolute_path),
    )
    if errors:
        raise ValueError("ledger schema violation: " + errors[0].message)

    created = date.fromisoformat(record["created_on"])
    deadline = date.fromisoformat(
        record["retention"]["finite_review_or_deletion_deadline"]
    )
    if created > as_of:
        raise ValueError("record creation cannot be in the future")
    if deadline <= created:
        raise ValueError("retention deadline must follow creation")

    for entry in record["entries"]:
        if type(entry["quantity"]) is not int:
            raise ValueError("quantity must be an integer, not Boolean or float")
        history = entry["history"]
        if history[0] != "draft":
            raise ValueError("history must begin at draft")
        for previous, following in zip(history, history[1:]):
            if following not in TRANSITIONS[previous]:
                raise ValueError("unsupported workflow transition")
        if history[-1] == "completed" and entry["quantity"] == 0:
            raise ValueError("completed contribution requires positive quantity")
        if entry["acceptance"] in {"accepted", "rejected"}:
            if history[-1] != "completed":
                raise ValueError("acceptance review requires completed work")

    warnings = []
    if as_of >= deadline:
        warnings.append("retention_review_due_not_proof_of_deletion")
    return {
        "schema_version": VERSION,
        "structurally_valid": True,
        "warnings": warnings,
        "operational_authority": "not_granted",
        "ordinary_support": "not_conditioned_on_this_result",
        "actual_deletion_verified": False,
    }


def synthetic_fixture():
    return {
        "schema_version": VERSION,
        "record_kind": "private_capacity_contribution_record",
        "purpose": "ecological_and_social",
        "created_on": "2026-11-09",
        "retention": {
            "applies_to": "entire_record_including_retention_metadata",
            "specific_purpose": "private_capacity_recordkeeping",
            "sensitivity": "private",
            "necessity_basis": "participant_requested_bounded_record",
            "access_restrictions":
                "participant_and_explicitly_authorized_support",
            "retention_trigger": "record_created",
            "finite_review_or_deletion_deadline": "2026-12-09",
            "deletion_or_restriction_method":
                "review_then_delete_unnecessary_data_or_document_restriction",
            "backup_handling": "no_backups",
            "responsible_role": "participant",
        },
        "entries": [
            {
                "dimension": dimension,
                "quantity": 1,
                "unit": units[0],
                "history": ["draft", "offered", "completed"],
                "acceptance": "not_reviewed",
                "evidence_availability": "not_collected",
                "authorization": "not_granted_by_ledger",
            }
            for dimension, units in UNITS.items()
        ],
        "aggregation_contract": "no_cross_dimension_or_cross_unit_total",
        "support_contract": "ordinary_support_not_conditioned_on_record_status",
        "collection_authority": "not_established_by_schema",
    }


class LedgerTests(unittest.TestCase):
    def test_all_six_dimensions_and_no_mutation(self):
        record = synthetic_fixture()
        before = deepcopy(record)
        result = validate_ledger(record, date(2026, 11, 9))
        self.assertTrue(result["structurally_valid"])
        self.assertEqual(record, before)

    def test_every_cross_dimension_unit_mismatch(self):
        for dimension, units in UNITS.items():
            for other, other_units in UNITS.items():
                if dimension == other:
                    continue
                record = synthetic_fixture()
                record["entries"] = [deepcopy(record["entries"][0])]
                record["entries"][0]["dimension"] = dimension
                record["entries"][0]["unit"] = other_units[0]
                with self.assertRaises(ValueError):
                    validate_ledger(record, date(2026, 11, 9))

    def test_cross_dimension_total_rejected(self):
        record = synthetic_fixture()
        record["total_capacity"] = 6
        with self.assertRaises(ValueError):
            validate_ledger(record, date(2026, 11, 9))

    def test_rollback_and_false_completion_rejected(self):
        for history in (
            ["draft", "completed"],
            ["draft", "offered", "completed", "offered"],
        ):
            record = synthetic_fixture()
            record["entries"][0]["history"] = history
            with self.assertRaises(ValueError):
                validate_ledger(record, date(2026, 11, 9))

    def test_retention_due_preserves_support_contract(self):
        result = validate_ledger(synthetic_fixture(), date(2026, 12, 9))
        self.assertIn(
            "retention_review_due_not_proof_of_deletion", result["warnings"]
        )
        self.assertEqual(
            result["ordinary_support"], "not_conditioned_on_this_result"
        )

    def test_missing_retention_classification_rejected(self):
        for field in RETENTION_FIELDS:
            record = synthetic_fixture()
            del record["retention"][field]
            with self.assertRaises(ValueError):
                validate_ledger(record, date(2026, 11, 9))

    def test_json_round_trip(self):
        record = synthetic_fixture()
        restored = load_local_json(json.dumps(record, allow_nan=False))
        self.assertEqual(restored, record)

    def test_boolean_quantity_rejected(self):
        record = synthetic_fixture()
        record["entries"][0]["quantity"] = True
        with self.assertRaises(ValueError):
            validate_ledger(record, date(2026, 11, 9))


if __name__ == "__main__":
    if sys.argv[1:] == ["--schema"]:
        print(json.dumps(SCHEMA, indent=2, ensure_ascii=False, allow_nan=False))
    else:
        unittest.main()
