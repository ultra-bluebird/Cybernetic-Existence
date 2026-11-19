# SPDX-License-Identifier: MIT OR Apache-2.0
"""Informational tax notices for ecological and social capacity contributions."""

from dataclasses import dataclass
from datetime import date
from enum import Enum
import json
import re
import unicodedata
import unittest


ENGINE_VERSION = "1.0.0"
WIRE_VERSION = "1.0.0"
CODE_PATTERN = re.compile(r"[A-Z]{2}(?:-[A-Z0-9]{1,8}){0,2}", re.ASCII)


class Treatment(Enum):
    SERVICE_VALUE_NOT_DEDUCTIBLE = "service_value_not_deductible"
    NOT_ASSESSED = "not_assessed"
    PARTIAL_TREATMENT_REPORTED = "partial_treatment_reported"
    REVIEW_REQUIRED = "review_required"
    OUT_OF_SCOPE = "out_of_scope"


class Benefits(Enum):
    NONE_REPORTED = "none_reported"
    PROVIDED_REPORTED = "provided_reported"
    UNKNOWN = "unknown"


class Substantiation(Enum):
    NOT_REVIEWED = "not_reviewed"
    REVIEW_REQUIRED = "review_required"
    SOURCE_REQUIREMENTS_REPORTED = "source_requirements_reported"


def checked_text(value: object, name: str, limit: int = 512) -> str:
    if not isinstance(value, str):
        raise ValueError(f"{name} must be text")
    normalized = unicodedata.normalize("NFC", value)
    if not 1 <= len(normalized) <= limit:
        raise ValueError(f"{name} length is invalid")
    if normalized != normalized.strip():
        raise ValueError(f"{name} must be trimmed")
    if any(unicodedata.category(char).startswith("C") for char in normalized):
        raise ValueError(f"{name} contains forbidden control or format characters")
    if any(
        unicodedata.bidirectional(char)
        in {"LRE", "RLE", "LRO", "RLO", "PDF", "LRI", "RLI", "FSI", "PDI"}
        for char in normalized
    ):
        raise ValueError(f"{name} contains bidirectional formatting")
    return normalized


@dataclass(frozen=True)
class Jurisdiction:
    country: str
    subdivision: str | None = None
    local: str | None = None

    def __post_init__(self):
        if type(self.country) is not str or not re.fullmatch(
            r"[A-Z]{2}", self.country, re.ASCII
        ):
            raise ValueError("country must be a canonical two-letter code")
        if self.local is not None and self.subdivision is None:
            raise ValueError("local scope requires subdivision scope")
        for name in ("subdivision", "local"):
            value = getattr(self, name)
            if value is not None:
                if type(value) is not str or not CODE_PATTERN.fullmatch(value):
                    raise ValueError(f"{name} must be a canonical registry code")

    def wire(self) -> dict:
        return {
            "country": self.country,
            "subdivision": self.subdivision,
            "local": self.local,
        }


@dataclass(frozen=True)
class JurisdictionRegistry:
    version: str
    entries: frozenset[Jurisdiction]

    def __post_init__(self):
        checked_text(self.version, "registry version")
        if type(self.entries) is not frozenset:
            raise ValueError("registry entries must be immutable")
        if any(type(entry) is not Jurisdiction for entry in self.entries):
            raise ValueError("invalid registry entry")

    def require_registered(self, value: Jurisdiction) -> None:
        if type(value) is not Jurisdiction or value not in self.entries:
            raise ValueError("unregistered jurisdiction")


DEFAULT_REGISTRY = JurisdictionRegistry(
    "1.0.0", frozenset({Jurisdiction("US")})
)


def enum_value(enum_type, raw):
    if type(raw) is not str:
        raise ValueError("enum wire value must be text")
    try:
        return enum_type(raw)
    except ValueError as exc:
        raise ValueError("unsupported enum value") from exc


def exact_date(raw: object) -> date:
    if type(raw) is not str or not re.fullmatch(
        r"[0-9]{4}-[0-9]{2}-[0-9]{2}", raw, re.ASCII
    ):
        raise ValueError("date must use YYYY-MM-DD")
    try:
        return date.fromisoformat(raw)
    except ValueError as exc:
        raise ValueError("invalid calendar date") from exc


@dataclass(frozen=True)
class TaxNotice:
    jurisdiction: Jurisdiction
    tax_year: int
    treatment: Treatment
    benefits: Benefits
    substantiation: Substantiation
    source_edition: str
    retrieved_on: date

    def __post_init__(self):
        if type(self.jurisdiction) is not Jurisdiction:
            raise ValueError("typed jurisdiction required")
        if type(self.tax_year) is not int or not 1900 <= self.tax_year <= 9999:
            raise ValueError("invalid tax year")
        for name, expected in (
            ("treatment", Treatment),
            ("benefits", Benefits),
            ("substantiation", Substantiation),
        ):
            if type(getattr(self, name)) is not expected:
                raise ValueError(f"typed {name} required")
        checked_text(self.source_edition, "source edition")
        if type(self.retrieved_on) is not date:
            raise ValueError("retrieved_on must be a date, not a datetime")


def validate_context(
    notice: TaxNotice,
    registry: JurisdictionRegistry,
    as_of: date,
) -> None:
    if type(notice) is not TaxNotice:
        raise ValueError("typed notice required")
    if type(registry) is not JurisdictionRegistry:
        raise ValueError("typed registry required")
    if type(as_of) is not date:
        raise ValueError("as_of must be a date")
    registry.require_registered(notice.jurisdiction)
    if notice.retrieved_on > as_of:
        raise ValueError("retrieval date cannot be in the future")


def encode(
    notice: TaxNotice,
    registry: JurisdictionRegistry,
    as_of: date,
) -> str:
    validate_context(notice, registry, as_of)
    record = {
        "schema_version": WIRE_VERSION,
        "engine_version": ENGINE_VERSION,
        "registry_version": registry.version,
        "document_kind": "informational_tax_notice_not_receipt",
        "jurisdiction": notice.jurisdiction.wire(),
        "tax_year": notice.tax_year,
        "treatment": notice.treatment.value,
        "benefits_received": notice.benefits.value,
        "substantiation": notice.substantiation.value,
        "source_edition": unicodedata.normalize("NFC", notice.source_edition),
        "retrieved_on": notice.retrieved_on.isoformat(),
        "amount_assessment": "not_performed",
    }
    return json.dumps(
        record, sort_keys=True, separators=(",", ":"),
        ensure_ascii=False, allow_nan=False,
    )


def unique_object(pairs):
    output = {}
    for key, value in pairs:
        if key in output:
            raise ValueError("duplicate JSON member")
        output[key] = value
    return output


def decode(
    payload: str,
    registry: JurisdictionRegistry,
    as_of: date,
) -> TaxNotice:
    if type(payload) is not str or len(payload) > 16384:
        raise ValueError("invalid or oversized payload")
    record = json.loads(payload, object_pairs_hook=unique_object)
    expected = {
        "schema_version", "engine_version", "registry_version",
        "document_kind", "jurisdiction", "tax_year", "treatment",
        "benefits_received", "substantiation", "source_edition",
        "retrieved_on", "amount_assessment",
    }
    if type(record) is not dict or set(record) != expected:
        raise ValueError("unsupported notice fields")
    constants = {
        "schema_version": WIRE_VERSION,
        "engine_version": ENGINE_VERSION,
        "registry_version": registry.version,
        "document_kind": "informational_tax_notice_not_receipt",
        "amount_assessment": "not_performed",
    }
    if any(record[name] != value for name, value in constants.items()):
        raise ValueError("unsupported version or document semantics")
    jurisdiction = record["jurisdiction"]
    if type(jurisdiction) is not dict or set(jurisdiction) != {
        "country", "subdivision", "local"
    }:
        raise ValueError("unsupported jurisdiction fields")
    notice = TaxNotice(
        Jurisdiction(**jurisdiction),
        record["tax_year"],
        enum_value(Treatment, record["treatment"]),
        enum_value(Benefits, record["benefits_received"]),
        enum_value(Substantiation, record["substantiation"]),
        checked_text(record["source_edition"], "source edition"),
        exact_date(record["retrieved_on"]),
    )
    validate_context(notice, registry, as_of)
    return notice


def render(
    notice: TaxNotice,
    registry: JurisdictionRegistry,
    as_of: date,
) -> str:
    validate_context(notice, registry, as_of)
    messages = {
        Treatment.SERVICE_VALUE_NOT_DEDUCTIBLE:
            "The cited treatment excludes the value of donated services. "
            "Separately qualifying expenses require their own review.",
        Treatment.NOT_ASSESSED:
            "Tax treatment has not been assessed.",
        Treatment.PARTIAL_TREATMENT_REPORTED:
            "Partial tax treatment is reported. This notice neither "
            "determines nor calculates the deductible portion.",
        Treatment.REVIEW_REQUIRED:
            "Tax treatment requires jurisdiction- and transaction-specific review.",
        Treatment.OUT_OF_SCOPE:
            "This contribution falls outside this notice's reviewed scope.",
    }
    return (
        "Informational tax notice — not a tax receipt.\n"
        f"Tax year: {notice.tax_year}.\n"
        f"{messages[notice.treatment]}\n"
        f"Benefits received: {notice.benefits.value}.\n"
        f"Substantiation review: {notice.substantiation.value}.\n"
        f"Source: {notice.source_edition}.\n"
        f"Retrieved: {notice.retrieved_on.isoformat()}.\n"
        "No deductible amount was calculated. Do not interpret an absent "
        "amount as zero, a refund, or an approved deduction."
    )


class ContractTests(unittest.TestCase):
    def notice(self, treatment=Treatment.NOT_ASSESSED):
        return TaxNotice(
            Jurisdiction("US"), 2025, treatment, Benefits.UNKNOWN,
            Substantiation.NOT_REVIEWED, "Synthetic source fixture",
            date(2026, 11, 9),
        )

    def test_round_trip_and_stable_encoding(self):
        today = date(2026, 11, 9)
        payload = encode(self.notice(), DEFAULT_REGISTRY, today)
        restored = decode(payload, DEFAULT_REGISTRY, today)
        self.assertEqual(payload, encode(restored, DEFAULT_REGISTRY, today))

    def test_every_treatment_is_explicit_and_not_a_receipt(self):
        for treatment in Treatment:
            output = render(
                self.notice(treatment), DEFAULT_REGISTRY, date(2026, 11, 9)
            )
            self.assertIn("not a tax receipt", output)
            self.assertIn("No deductible amount was calculated", output)

    def test_unknown_jurisdiction_and_unicode_codes_rejected(self):
        for country in ("us", "UＳ", "U\u200bS", "US\n"):
            with self.assertRaises(ValueError):
                Jurisdiction(country)
        with self.assertRaises(ValueError):
            encode(
                TaxNotice(
                    Jurisdiction("CA"), 2025, Treatment.NOT_ASSESSED,
                    Benefits.UNKNOWN, Substantiation.NOT_REVIEWED,
                    "Synthetic source fixture", date(2026, 11, 9),
                ),
                DEFAULT_REGISTRY, date(2026, 11, 9),
            )

    def test_future_retrieval_rejected(self):
        with self.assertRaises(ValueError):
            encode(self.notice(), DEFAULT_REGISTRY, date(2026, 11, 8))

    def test_raw_enum_string_rejected(self):
        with self.assertRaises(ValueError):
            self.notice("not_assessed")

    def test_unknown_version_rejected(self):
        today = date(2026, 11, 9)
        payload = encode(self.notice(), DEFAULT_REGISTRY, today)
        changed = json.loads(payload)
        changed["schema_version"] = "2.0.0"
        with self.assertRaises(ValueError):
            decode(json.dumps(changed), DEFAULT_REGISTRY, today)


if __name__ == "__main__":
    unittest.main()
