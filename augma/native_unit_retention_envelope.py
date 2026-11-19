# SPDX-License-Identifier: MIT OR Apache-2.0
"""Offline six-dimension capacity ledger inspection and serialization preview.

Python 3.11+. Standard library only. No storage, network, export delivery,
payment, personal ranking, or operational execution.
"""

from collections.abc import Iterable, Iterator
from copy import deepcopy
from datetime import date
import json
import re
from types import MappingProxyType
from typing import Any
import unicodedata
import unittest


VERSION = "1.0.0"
ENGINE_VERSION = "1.1.0"

MAX_ENTRIES = 1_000
MAX_QUANTITY = 1_000_000_000
MAX_TEXT_LENGTH = 512
MAX_PAYLOAD_CHARACTERS = 2_000_000
MAX_JSON_DEPTH = 16
MAX_INTEGER_DIGITS = 32

UNITS = MappingProxyType({
    "time": frozenset({"contributor_minute"}),
    "skill": frozenset({"reviewed_deliverable"}),
    "knowledge": frozenset({"artifact", "maintenance_release"}),
    "attention": frozenset({"focused_minute"}),
    "trust": frozenset({"consented_introduction", "scoped_endorsement"}),
    "access": frozenset({"authorized_session", "resource_minute"}),
})

PURPOSES = frozenset({"ecological", "social", "ecological_and_social"})
SENSITIVITIES = frozenset({"public", "internal", "restricted"})
COMPLETION = frozenset({"offered", "scheduled", "completed", "cancelled"})
ACCEPTANCE = frozenset({
    "not_reviewed", "accepted", "changes_requested", "unknown",
})
EVIDENCE = frozenset({
    "available", "unavailable", "not_collected", "unknown",
})

PROFILE_FIELDS = frozenset({
    "specific_purpose",
    "sensitivity",
    "necessity_basis",
    "access_restrictions",
    "retention_trigger",
    "finite_review_or_deletion_deadline",
    "deletion_or_restriction_method",
    "backup_handling",
    "responsible_role",
})
ENTRY_FIELDS = frozenset({
    "dimension", "unit", "quantity", "scope",
    "completion", "acceptance", "evidence",
})
ROOT_FIELDS = frozenset({
    "schema_version", "purpose", "retention_profile", "entries",
})
DATE_PATTERN = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", re.ASCII)

FieldPath = tuple[str | int, ...]


def exact_fields(
    value: Any,
    expected: Iterable[str],
    name: str,
) -> None:
    expected_fields = frozenset(expected)
    if type(value) is not dict:
        raise ValueError(f"{name}: dictionary required")
    if any(type(key) is not str for key in value):
        raise ValueError(f"{name}: field names must be strings")
    if frozenset(value) != expected_fields:
        raise ValueError(f"{name}: missing or unsupported fields")


def safe_text(
    value: Any,
    name: str,
    maximum: int = MAX_TEXT_LENGTH,
) -> None:
    if type(maximum) is not int or maximum < 1:
        raise ValueError("maximum text length must be a positive integer")
    if type(value) is not str:
        raise ValueError(f"{name}: text required")
    if not 1 <= len(value) <= maximum or value != value.strip():
        raise ValueError(f"{name}: trimmed nonempty text required")
    if unicodedata.normalize("NFC", value) != value:
        raise ValueError(f"{name}: NFC normalization required")
    if any(unicodedata.category(char).startswith("C") for char in value):
        raise ValueError(f"{name}: control or format character rejected")


def choice(value: Any, allowed: Iterable[str], name: str) -> None:
    if type(value) is not str or value not in allowed:
        raise ValueError(f"{name}: unsupported value")


def calendar_date(value: Any) -> date:
    if type(value) is not str or DATE_PATTERN.fullmatch(value) is None:
        raise ValueError("deadline: YYYY-MM-DD required")
    try:
        return date.fromisoformat(value)
    except ValueError as exc:
        raise ValueError("deadline: invalid calendar date") from exc


def inspect(document: Any, as_of: date) -> dict[str, Any]:
    """Inspect supplied structure without authorizing collection or action.

    Acceptance describes review of completed work. Retention deadlines
    trigger disposition review; they do not invalidate historical structure.
    """
    if type(as_of) is not date:
        raise ValueError("as_of: date required; datetime is unsupported")

    exact_fields(document, ROOT_FIELDS, "ledger")
    if type(document["schema_version"]) is not str:
        raise ValueError("schema version must be text")
    if document["schema_version"] != VERSION:
        raise ValueError("unsupported schema version")
    choice(document["purpose"], PURPOSES, "purpose")

    profile = document["retention_profile"]
    exact_fields(profile, PROFILE_FIELDS, "retention profile")
    for field in sorted(PROFILE_FIELDS):
        safe_text(profile[field], field)
    choice(profile["sensitivity"], SENSITIVITIES, "sensitivity")
    deadline = calendar_date(profile["finite_review_or_deletion_deadline"])

    entries = document["entries"]
    if type(entries) is not list or len(entries) > MAX_ENTRIES:
        raise ValueError(
            f"entries: list of at most {MAX_ENTRIES} records required"
        )

    for entry in entries:
        exact_fields(entry, ENTRY_FIELDS, "entry")
        choice(entry["dimension"], UNITS, "dimension")
        choice(entry["unit"], UNITS[entry["dimension"]], "native unit")

        quantity = entry["quantity"]
        if type(quantity) is not int or not 0 <= quantity <= MAX_QUANTITY:
            raise ValueError("quantity: bounded nonnegative integer required")

        safe_text(entry["scope"], "scope")
        choice(entry["completion"], COMPLETION, "completion")
        choice(entry["acceptance"], ACCEPTANCE, "acceptance")
        choice(entry["evidence"], EVIDENCE, "evidence")

        if entry["completion"] == "completed" and quantity == 0:
            raise ValueError("completed contribution requires positive quantity")
        if entry["acceptance"] in {"accepted", "changes_requested"}:
            if entry["completion"] != "completed":
                raise ValueError(
                    "acceptance concerns completed work, not an offer"
                )

    review_due = as_of >= deadline
    return {
        "schema_version": VERSION,
        "engine_version": ENGINE_VERSION,
        "result": "structurally_valid_no_authority_granted",
        "structure": "valid_under_supported_profile",
        "retention_review": "due" if review_due else "deadline_not_reached",
        "retention_deadline": deadline.isoformat(),
        "retention_adequacy": "not_established",
        "retention_coverage": "all_leaf_values_inherit_root_profile",
        "actual_deletion": "not_verified",
        "collection_authority": "not_established",
        "export_authority": "not_granted",
        "operational_authority": "not_granted",
        "ordinary_support": "not_conditioned_on_record_status",
        "warnings": (
            ["retention_review_due_not_proof_of_deletion"]
            if review_due else []
        ),
    }


def validate(document: Any, as_of: date) -> dict[str, Any]:
    """Compatibility entry point using the same inspection semantics."""
    return inspect(document, as_of)


def leaf_paths(value: Any, path: FieldPath = ()) -> Iterator[FieldPath]:
    """Yield local field paths with cycle and nesting protection."""
    if type(path) is not tuple:
        raise ValueError("path must be a tuple")
    if any(type(part) not in {str, int} for part in path):
        raise ValueError("path components must be strings or integers")

    active_containers: set[int] = set()

    def walk(
        current: Any,
        current_path: FieldPath,
        depth: int,
    ) -> Iterator[FieldPath]:
        if depth > MAX_JSON_DEPTH:
            raise ValueError("structure exceeds supported nesting depth")
        if type(current) not in {dict, list}:
            yield current_path
            return

        marker = id(current)
        if marker in active_containers:
            raise ValueError("cyclic structures are unsupported")
        active_containers.add(marker)
        try:
            if type(current) is dict:
                if any(type(key) is not str for key in current):
                    raise ValueError("field names must be strings")
                for key in sorted(current):
                    yield from walk(
                        current[key], current_path + (key,), depth + 1
                    )
            else:
                for position, item in enumerate(current):
                    yield from walk(
                        item, current_path + (position,), depth + 1
                    )
        finally:
            active_containers.remove(marker)

    yield from walk(value, path, 0)


def coverage_map(
    document: Any,
    as_of: date,
) -> dict[FieldPath, str]:
    inspect(document, as_of)
    return {
        path: "root_retention_profile"
        for path in leaf_paths(document)
    }


def dimension_view(
    document: Any,
    as_of: date,
) -> dict[str, tuple[dict[str, Any], ...]]:
    """Return independent copies without totals, scores, or conversions."""
    inspect(document, as_of)
    return {
        dimension: tuple(
            deepcopy(entry)
            for entry in document["entries"]
            if entry["dimension"] == dimension
        )
        for dimension in UNITS
    }


def serialization_preview(document: Any, as_of: date) -> str:
    """Return JSON text in memory; writing or sharing is a separate action."""
    inspect(document, as_of)
    payload = json.dumps(
        document,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    )
    if len(payload) > MAX_PAYLOAD_CHARACTERS:
        raise ValueError("serialized payload exceeds supported size")
    return payload


def encode(document: Any, as_of: date) -> str:
    """Compatibility alias for an in-memory serialization preview."""
    return serialization_preview(document, as_of)


def unique_members(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON member")
        result[key] = value
    return result


def reject_constant(value: str) -> None:
    raise ValueError("non-finite JSON value rejected")


def bounded_integer(value: str) -> int:
    digits = value.removeprefix("-")
    if len(digits) > MAX_INTEGER_DIGITS:
        raise ValueError("JSON integer exceeds supported digit limit")
    return int(value)


def reject_float(value: str) -> None:
    raise ValueError("floating-point JSON numbers are unsupported")


def check_json_depth(payload: str) -> None:
    depth = 0
    in_string = False
    escaped = False

    for char in payload:
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
        elif char == '"':
            in_string = True
        elif char in "[{":
            depth += 1
            if depth > MAX_JSON_DEPTH:
                raise ValueError("JSON nesting exceeds supported depth")
        elif char in "]}":
            depth -= 1
            if depth < 0:
                raise ValueError("invalid JSON container structure")


def decode(payload: Any, as_of: date) -> dict[str, Any]:
    if type(payload) is not str:
        raise ValueError("payload must be JSON text")
    if not payload or len(payload) > MAX_PAYLOAD_CHARACTERS:
        raise ValueError("invalid or oversized payload")

    check_json_depth(payload)
    try:
        document = json.loads(
            payload,
            object_pairs_hook=unique_members,
            parse_constant=reject_constant,
            parse_int=bounded_integer,
            parse_float=reject_float,
        )
    except (json.JSONDecodeError, RecursionError) as exc:
        raise ValueError("invalid or unsupported JSON document") from exc

    inspect(document, as_of)
    return document


class EnvelopeTests(unittest.TestCase):
    def fixture(self) -> dict[str, Any]:
        return {
            "schema_version": VERSION,
            "purpose": "ecological_and_social",
            "retention_profile": {
                "specific_purpose": "Synthetic local contribution exercise",
                "sensitivity": "restricted",
                "necessity_basis": "Evaluate bounded recording behavior",
                "access_restrictions": "Local test reviewer",
                "retention_trigger": "Synthetic exercise completion",
                "finite_review_or_deletion_deadline": "2027-01-01",
                "deletion_or_restriction_method": "Reviewed local disposition",
                "backup_handling": "No retained backups in this fixture",
                "responsible_role": "Local test maintainer",
            },
            "entries": [{
                "dimension": "knowledge",
                "unit": "artifact",
                "quantity": 1,
                "scope": "Synthetic restoration guide",
                "completion": "completed",
                "acceptance": "not_reviewed",
                "evidence": "not_collected",
            }],
        }

    def test_round_trip_and_no_input_mutation(self):
        document = self.fixture()
        original = deepcopy(document)
        today = date(2026, 11, 9)
        self.assertEqual(decode(encode(document, today), today), original)
        self.assertEqual(document, original)

    def test_public_api_families_are_wired_together(self):
        document = self.fixture()
        today = date(2026, 11, 9)
        self.assertEqual(validate(document, today), inspect(document, today))
        self.assertEqual(
            encode(document, today),
            serialization_preview(document, today),
        )

    def test_due_record_remains_inspectable(self):
        document = self.fixture()
        today = date(2027, 1, 1)
        result = validate(document, today)
        self.assertEqual(result["retention_review"], "due")
        self.assertEqual(result["actual_deletion"], "not_verified")
        self.assertEqual(len(dimension_view(document, today)["knowledge"]), 1)
        self.assertTrue(coverage_map(document, today))
        self.assertEqual(decode(encode(document, today), today), document)

    def test_completed_does_not_imply_accepted(self):
        view = dimension_view(self.fixture(), date(2026, 11, 9))
        self.assertEqual(view["knowledge"][0]["acceptance"], "not_reviewed")

    def test_review_of_uncompleted_work_rejected(self):
        for completion in ("offered", "scheduled", "cancelled"):
            for acceptance in ("accepted", "changes_requested"):
                document = self.fixture()
                document["entries"][0].update(
                    completion=completion,
                    acceptance=acceptance,
                )
                with self.assertRaises(ValueError):
                    inspect(document, date(2026, 11, 9))

    def test_all_dimension_units_are_representable(self):
        for dimension, units in UNITS.items():
            for unit in units:
                document = self.fixture()
                document["entries"][0].update(
                    dimension=dimension, unit=unit
                )
                inspect(document, date(2026, 11, 9))

    def test_all_cross_dimension_units_rejected(self):
        for dimension in UNITS:
            for other_dimension, units in UNITS.items():
                if dimension == other_dimension:
                    continue
                for unit in units:
                    document = self.fixture()
                    document["entries"][0].update(
                        dimension=dimension, unit=unit
                    )
                    with self.assertRaises(ValueError):
                        inspect(document, date(2026, 11, 9))

    def test_cross_dimension_total_rejected(self):
        document = self.fixture()
        document["total_capacity"] = 1
        with self.assertRaises(ValueError):
            validate(document, date(2026, 11, 9))

    def test_profile_metadata_has_coverage(self):
        paths = coverage_map(self.fixture(), date(2026, 11, 9))
        self.assertIn(("retention_profile", "responsible_role"), paths)

    def test_every_retention_field_is_required(self):
        for field in PROFILE_FIELDS:
            document = self.fixture()
            del document["retention_profile"][field]
            with self.assertRaises(ValueError):
                inspect(document, date(2026, 11, 9))

    def test_invalid_quantities_rejected(self):
        for quantity in (True, False, -1, 1.0, MAX_QUANTITY + 1, 0):
            document = self.fixture()
            document["entries"][0]["quantity"] = quantity
            with self.assertRaises(ValueError):
                validate(document, date(2026, 11, 9))

    def test_offered_zero_quantity_is_representable(self):
        document = self.fixture()
        document["entries"][0].update(completion="offered", quantity=0)
        inspect(document, date(2026, 11, 9))

    def test_dimension_view_does_not_mutate_source(self):
        document = self.fixture()
        view = dimension_view(document, date(2026, 11, 9))
        view["knowledge"][0]["scope"] = "Changed local preview"
        self.assertEqual(
            document["entries"][0]["scope"], "Synthetic restoration guide"
        )

    def test_duplicate_members_rejected(self):
        with self.assertRaises(ValueError):
            decode(
                '{"schema_version":"1.0.0","schema_version":"1.0.0"}',
                date(2026, 11, 9),
            )

    def test_nonfinite_float_and_large_integer_rejected(self):
        for payload in (
            '{"value":NaN}',
            '{"value":Infinity}',
            '{"value":1.0}',
            '{"value":' + ("9" * (MAX_INTEGER_DIGITS + 1)) + "}",
        ):
            with self.assertRaises(ValueError):
                decode(payload, date(2026, 11, 9))

    def test_depth_limit_and_string_brackets(self):
        with self.assertRaises(ValueError):
            decode(
                "[" * (MAX_JSON_DEPTH + 1)
                + "0"
                + "]" * (MAX_JSON_DEPTH + 1),
                date(2026, 11, 9),
            )
        document = self.fixture()
        document["entries"][0]["scope"] = 'Guide includes [brackets] and "quotes"'
        payload = encode(document, date(2026, 11, 9))
        self.assertEqual(
            decode(payload, date(2026, 11, 9)), document
        )

    def test_invalid_dates_and_datetime_rejected(self):
        from datetime import datetime

        for deadline in ("2027-02-29", "2027-1-01", "2027-01-01T00:00:00"):
            document = self.fixture()
            document["retention_profile"][
                "finite_review_or_deletion_deadline"
            ] = deadline
            with self.assertRaises(ValueError):
                inspect(document, date(2026, 11, 9))
        with self.assertRaises(ValueError):
            inspect(self.fixture(), datetime(2026, 11, 9))

    def test_unsafe_and_non_normalized_text_rejected(self):
        for scope in ("Hidden\u200btext", "Line\nbreak", "Cafe\u0301", " padded"):
            document = self.fixture()
            document["entries"][0]["scope"] = scope
            with self.assertRaises(ValueError):
                inspect(document, date(2026, 11, 9))

    def test_empty_ledger_is_representable_without_claiming_work(self):
        document = self.fixture()
        document["entries"] = []
        inspect(document, date(2026, 11, 9))
        self.assertTrue(all(
            not entries
            for entries in dimension_view(
                document, date(2026, 11, 9)
            ).values()
        ))

    def test_leaf_paths_reject_cycles(self):
        cyclic = []
        cyclic.append(cyclic)
        with self.assertRaises(ValueError):
            tuple(leaf_paths(cyclic))


if __name__ == "__main__":
    unittest.main()
