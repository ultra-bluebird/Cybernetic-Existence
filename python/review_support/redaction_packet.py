from __future__ import annotations

from dataclasses import dataclass
from re import IGNORECASE, compile
from typing import Iterable


class RedactionPacketValidationError(ValueError):
    pass


SENSITIVE_PATTERNS: tuple[tuple[str, object], ...] = (
    (
        "EMAIL_REDACTED",
        compile(r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b", IGNORECASE),
    ),
    (
        "PHONE_REDACTED",
        compile(
            r"\b(?:\+?1[-.\s]?)?(?:\(?\d{3}\)?[-.\s]?)\d{3}[-.\s]?\d{4}\b"
        ),
    ),
    (
        "ACCOUNT_REFERENCE_REDACTED",
        compile(r"\b(?:account|case|reference)[\s:#-]*[A-Z0-9-]{5,}\b", IGNORECASE),
    ),
    (
        "PRECISE_ADDRESS_REDACTED",
        compile(
            r"\b\d{1,6}\s+[A-Z0-9][A-Z0-9.\-\s]{1,64}\s"
            r"(?:STREET|ST|AVENUE|AVE|ROAD|RD|BOULEVARD|BLVD|DRIVE|DR|LANE|LN)\b",
            IGNORECASE,
        ),
    ),
)


@dataclass(frozen=True)
class RedactionCandidate:
    category: str
    start: int
    end: int
    replacement: str


@dataclass(frozen=True)
class ReviewerPacket:
    request_type: str
    issue_summary: str
    requested_remedy: str
    redaction_candidates: tuple[RedactionCandidate, ...]
    direct_identifier_values_in_packet: bool
    health_or_identity_details_in_packet: bool
    augmentation_or_assistive_details_in_packet: bool
    additional_context_request_available: bool
    appeal_path_available: bool


def find_redaction_candidates(text: str) -> tuple[RedactionCandidate, ...]:
    if not isinstance(text, str):
        raise RedactionPacketValidationError("text must be a string.")

    candidates: list[RedactionCandidate] = []
    for category, pattern in SENSITIVE_PATTERNS:
        for match in pattern.finditer(text):
            candidates.append(
                RedactionCandidate(
                    category=category,
                    start=match.start(),
                    end=match.end(),
                    replacement=f"[{category}]",
                )
            )

    candidates.sort(key=lambda item: (item.start, item.end))
    return tuple(candidates)


def apply_non_overlapping_redactions(
    text: str,
    candidates: Iterable[RedactionCandidate],
) -> str:
    ordered = sorted(candidates, key=lambda item: (item.start, item.end))

    previous_end = 0
    parts: list[str] = []
    for candidate in ordered:
        if candidate.start < previous_end:
            raise RedactionPacketValidationError(
                "Overlapping redaction candidates require human resolution."
            )
        if candidate.start < 0 or candidate.end > len(text) or candidate.end <= candidate.start:
            raise RedactionPacketValidationError("Invalid redaction span.")

        parts.append(text[previous_end:candidate.start])
        parts.append(candidate.replacement)
        previous_end = candidate.end

    parts.append(text[previous_end:])
    return "".join(parts)


def build_reviewer_packet(
    request_type: str,
    issue_summary: str,
    requested_remedy: str,
    verified_candidates: Iterable[RedactionCandidate],
) -> ReviewerPacket:
    if not request_type.strip():
        raise RedactionPacketValidationError("request_type must be non-empty.")
    if not issue_summary.strip():
        raise RedactionPacketValidationError("issue_summary must be non-empty.")
    if not requested_remedy.strip():
        raise RedactionPacketValidationError("requested_remedy must be non-empty.")

    redacted_summary = apply_non_overlapping_redactions(
        issue_summary,
        verified_candidates,
    )

    return ReviewerPacket(
        request_type=request_type,
        issue_summary=redacted_summary,
        requested_remedy=requested_remedy,
        redaction_candidates=tuple(verified_candidates),
        direct_identifier_values_in_packet=False,
        health_or_identity_details_in_packet=False,
        augmentation_or_assistive_details_in_packet=False,
        additional_context_request_available=True,
        appeal_path_available=True,
    )


def redaction_quality(
    sensitive_tokens_found: int,
    sensitive_tokens_removed: int,
    necessary_context_tokens: int,
    necessary_context_tokens_lost: int,
) -> tuple[float, float]:
    values = (
        sensitive_tokens_found,
        sensitive_tokens_removed,
        necessary_context_tokens,
        necessary_context_tokens_lost,
    )
    if any(not isinstance(value, int) or value < 0 for value in values):
        raise RedactionPacketValidationError(
            "Quality metrics must be non-negative integers."
        )
    if sensitive_tokens_found == 0:
        raise RedactionPacketValidationError(
            "sensitive_tokens_found must be positive for recall calculation."
        )
    if necessary_context_tokens == 0:
        raise RedactionPacketValidationError(
            "necessary_context_tokens must be positive for context-loss calculation."
        )
    if sensitive_tokens_removed > sensitive_tokens_found:
        raise RedactionPacketValidationError(
            "sensitive_tokens_removed cannot exceed sensitive_tokens_found."
        )
    if necessary_context_tokens_lost > necessary_context_tokens:
        raise RedactionPacketValidationError(
            "necessary_context_tokens_lost cannot exceed necessary_context_tokens."
        )

    removal_recall = sensitive_tokens_removed / sensitive_tokens_found
    context_loss_rate = necessary_context_tokens_lost / necessary_context_tokens
    return removal_recall, context_loss_rate


def meets_redaction_targets(
    removal_recall: float,
    context_loss_rate: float,
) -> bool:
    return removal_recall > 0.99 and context_loss_rate < 0.05
