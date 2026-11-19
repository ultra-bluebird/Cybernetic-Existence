from __future__ import annotations

from dataclasses import dataclass
from hashlib import sha256
from math import isfinite
from pathlib import Path
from typing import Iterable, Mapping


class DocumentIntegrityError(ValueError):
    pass


HIGH_IMPACT_FIELDS = frozenset(
    {
        "request_type",
        "decision_or_service",
        "requested_remedy",
        "deadline",
        "account_reference",
        "contact_preference",
        "free_text_statement",
        "signature_present",
        "page_count",
    }
)


@dataclass(frozen=True)
class DigitizedField:
    name: str
    source_visible: bool
    ocr_value: str | None
    verified_value: str | None
    reviewer_confirmed: bool
    source_match: bool

    def __post_init__(self) -> None:
        if not self.name.strip():
            raise DocumentIntegrityError("A digitized field requires a non-empty name.")
        if self.ocr_value is not None and not isinstance(self.ocr_value, str):
            raise DocumentIntegrityError("ocr_value must be text or null.")
        if self.verified_value is not None and not isinstance(self.verified_value, str):
            raise DocumentIntegrityError("verified_value must be text or null.")
        if self.reviewer_confirmed and not self.source_visible:
            raise DocumentIntegrityError(
                "A reviewer cannot confirm a field without the source image being visible."
            )


@dataclass(frozen=True)
class ConversionReport:
    accepted_for_routing: bool
    verified_field_count: int
    correct_field_count: int
    conversion_accuracy_percent: float
    reason: str


def sha256_file(path: str | Path) -> str:
    source = Path(path)
    if not source.is_file():
        raise DocumentIntegrityError("The source document must exist and be a regular file.")

    digest = sha256()
    with source.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def conversion_accuracy(fields: Iterable[DigitizedField]) -> tuple[int, int, float]:
    checked = list(fields)
    verified = [field for field in checked if field.reviewer_confirmed]

    if not verified:
        raise DocumentIntegrityError("At least one reviewer-confirmed field is required.")

    correct_count = sum(field.source_match for field in verified)
    accuracy = (correct_count / len(verified)) * 100.0
    return len(verified), correct_count, accuracy


def evaluate_conversion(
    fields: Iterable[DigitizedField],
    page_count_from_source: int,
    page_count_from_scan: int,
) -> ConversionReport:
    if page_count_from_source <= 0 or page_count_from_scan <= 0:
        raise DocumentIntegrityError("Page counts must be positive.")
    if page_count_from_source != page_count_from_scan:
        return ConversionReport(
            accepted_for_routing=False,
            verified_field_count=0,
            correct_field_count=0,
            conversion_accuracy_percent=0.0,
            reason="Page-count mismatch requires source-document review.",
        )

    listed_fields = list(fields)
    missing_high_impact_reviews = [
        field_name
        for field_name in HIGH_IMPACT_FIELDS
        if any(field.name == field_name for field in listed_fields)
        and not any(
            field.name == field_name and field.reviewer_confirmed and field.source_match
            for field in listed_fields
        )
    ]

    if missing_high_impact_reviews:
        return ConversionReport(
            accepted_for_routing=False,
            verified_field_count=0,
            correct_field_count=0,
            conversion_accuracy_percent=0.0,
            reason=(
                "High-impact fields require source-visible review: "
                + ", ".join(sorted(missing_high_impact_reviews))
                + "."
            ),
        )

    verified_count, correct_count, accuracy = conversion_accuracy(listed_fields)
    if not isfinite(accuracy) or accuracy <= 99.0:
        return ConversionReport(
            accepted_for_routing=False,
            verified_field_count=verified_count,
            correct_field_count=correct_count,
            conversion_accuracy_percent=accuracy,
            reason="Conversion accuracy does not exceed the required 99 percent threshold.",
        )

    return ConversionReport(
        accepted_for_routing=True,
        verified_field_count=verified_count,
        correct_field_count=correct_count,
        conversion_accuracy_percent=accuracy,
        reason="Source-linked conversion passed verification for routing.",
    )


def minimal_intake_record(
    request_type: str,
    received_at: str,
    submission_channel: str,
    accessibility_format_requested: str,
) -> Mapping[str, object]:
    if not all(
        isinstance(value, str) and value.strip()
        for value in (
            request_type,
            received_at,
            submission_channel,
            accessibility_format_requested,
        )
    ):
        raise DocumentIntegrityError("Minimal intake fields must be non-empty strings.")

    return {
        "request_type": request_type,
        "received_at": received_at,
        "submission_channel": submission_channel,
        "accessibility_format_requested": accessibility_format_requested,
        "identity_or_health_data_required": False,
        "device_tracking_enabled": False,
        "ocr_is_authoritative": False,
    }
