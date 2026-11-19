from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
import re
from typing import Iterable, Sequence


class DetectionStatus(str, Enum):
    FICTIONALIZATION_NOT_DETECTED = "FICTIONALIZATION_NOT_DETECTED"
    FICTIONALIZATION_REVIEW_REQUIRED = "FICTIONALIZATION_REVIEW_REQUIRED"
    INSUFFICIENT_TEXT_FOR_REVIEW = "INSUFFICIENT_TEXT_FOR_REVIEW"


class Severity(str, Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"


@dataclass(frozen=True)
class Finding:
    rule_id: str
    severity: Severity
    matched_text: str
    start_offset: int
    end_offset: int
    explanation: str
    suggested_revision: str


@dataclass(frozen=True)
class DetectionResult:
    status: DetectionStatus
    findings: tuple[Finding, ...]
    explanation: str


FICTIONALIZING_TERMS = (
    "alleged",
    "purported",
    "fantasy",
    "delusion",
    "delusional",
    "hypothetical",
    "imaginary",
    "fabricated",
    "fictional",
    "made-up",
    "make-believe",
)

DEROGATORY_CUES = (
    "not real",
    "unreal",
    "nonsense",
    "ridiculous",
    "absurd",
    "crazy",
    "irrational",
    "unreliable",
    "untrustworthy",
    "cannot be trusted",
    "not credible",
    "invalid",
    "fake",
    "fraudulent",
)

PROOF_DEMAND_CUES = (
    "prove it",
    "provide proof",
    "show proof",
    "verify your claim",
    "verification is required",
    "must be verified",
    "need evidence before",
    "cannot proceed without proof",
)

ACCESS_CONDITION_CUES = (
    "deny service",
    "not eligible",
    "ineligible",
    "cannot receive",
    "cannot access",
    "will not provide",
    "withhold access",
    "authorization denied",
)

ELIGIBILITY_CONVERSION_CUES = (
    "eligibility category",
    "rank the user",
    "resource priority",
    "enforcement target",
    "public credential",
    "medical diagnosis",
    "technical certification",
)

TOKEN_PATTERN = re.compile(r"[A-Za-z0-9][A-Za-z0-9._~-]*|[^\s]", re.UNICODE)


def _normalize_phrase(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().casefold())


def _token_spans(text: str) -> list[tuple[str, int, int]]:
    return [(match.group(0), match.start(), match.end()) for match in TOKEN_PATTERN.finditer(text)]


def _find_phrase_spans(text: str, phrase: str) -> list[tuple[int, int]]:
    normalized = phrase.strip()
    if not normalized:
        return []

    expression = re.compile(re.escape(normalized), re.IGNORECASE)
    return [(match.start(), match.end()) for match in expression.finditer(text)]


def _contains_any(text: str, phrases: Iterable[str]) -> bool:
    normalized = _normalize_phrase(text)
    return any(_normalize_phrase(phrase) in normalized for phrase in phrases)


def _window_text(
    text: str,
    tokens: Sequence[tuple[str, int, int]],
    start: int,
    end: int,
    radius: int,
) -> str:
    matching_indexes = [
        index
        for index, (_, token_start, token_end) in enumerate(tokens)
        if token_start < end and token_end > start
    ]

    if not matching_indexes:
        return ""

    first = max(0, matching_indexes[0] - radius)
    last = min(len(tokens) - 1, matching_indexes[-1] + radius)
    return text[tokens[first][1]:tokens[last][2]]


def _is_near_anchored_term(
    text: str,
    fictionalizing_start: int,
    fictionalizing_end: int,
    anchored_terms: Sequence[str],
    radius_characters: int,
) -> bool:
    lower_bound = max(0, fictionalizing_start - radius_characters)
    upper_bound = min(len(text), fictionalizing_end + radius_characters)
    window = text[lower_bound:upper_bound].casefold()
    return any(term.casefold() in window for term in anchored_terms)


def _direct_modifier_match(
    text: str,
    anchored_terms: Sequence[str],
) -> list[tuple[int, int, str]]:
    matches: list[tuple[int, int, str]] = []

    for term in anchored_terms:
        escaped = re.escape(term)
        for fictionalizing in FICTIONALIZING_TERMS:
            patterns = (
                rf"\b{re.escape(fictionalizing)}\b\s+{escaped}\b",
                rf"\b{escaped}\b\s+is\s+(?:a|an)\s+\b{re.escape(fictionalizing)}\b",
                rf"\b{escaped}\b\s+is\s+\b{re.escape(fictionalizing)}\b",
            )

            for pattern in patterns:
                for match in re.finditer(pattern, text, flags=re.IGNORECASE):
                    matches.append((match.start(), match.end(), fictionalizing))

    return matches


def detect_fictionalization(
    text: str,
    anchored_private_terms: Sequence[str],
    context_token_radius: int = 24,
    anchored_term_radius_characters: int = 220,
) -> DetectionResult:
    if not isinstance(text, str) or not text.strip():
        return DetectionResult(
            status=DetectionStatus.INSUFFICIENT_TEXT_FOR_REVIEW,
            findings=(),
            explanation="No reviewable output text was supplied.",
        )

    terms = tuple(term.strip() for term in anchored_private_terms if term and term.strip())
    if not terms:
        return DetectionResult(
            status=DetectionStatus.INSUFFICIENT_TEXT_FOR_REVIEW,
            findings=(),
            explanation="At least one anchored private term is required for contextual review.",
        )

    tokens = _token_spans(text)
    findings: list[Finding] = []
    seen: set[tuple[str, int, int]] = set()

    for start, end, fictionalizing in _direct_modifier_match(text, terms):
        key = ("DIRECT_PRIVATE_TERM_MODIFIER", start, end)
        if key in seen:
            continue
        seen.add(key)

        matched = text[start:end]
        findings.append(
            Finding(
                rule_id="DIRECT_PRIVATE_TERM_MODIFIER",
                severity=Severity.HIGH,
                matched_text=matched,
                start_offset=start,
                end_offset=end,
                explanation=(
                    "A potentially fictionalizing term directly modifies an anchored "
                    "private term. Review for respectful, non-pathologizing wording."
                ),
                suggested_revision=(
                    "Treat the term as user-defined private metadata and continue with "
                    "the requested task using minimum necessary information."
                ),
            )
        )

    for fictionalizing in FICTIONALIZING_TERMS:
        for start, end in _find_phrase_spans(text, fictionalizing):
            if not _is_near_anchored_term(
                text,
                start,
                end,
                terms,
                anchored_term_radius_characters,
            ):
                continue

            key = ("CONTEXTUAL_FICTIONALIZATION", start, end)
            if key in seen:
                continue
            seen.add(key)

            context = _window_text(
                text,
                tokens,
                start,
                end,
                context_token_radius,
            )
            high_severity = (
                _contains_any(context, PROOF_DEMAND_CUES)
                or _contains_any(context, ACCESS_CONDITION_CUES)
                or _contains_any(context, ELIGIBILITY_CONVERSION_CUES)
            )
            derogatory = _contains_any(context, DEROGATORY_CUES)

            findings.append(
                Finding(
                    rule_id="CONTEXTUAL_FICTIONALIZATION",
                    severity=(
                        Severity.HIGH
                        if high_severity
                        else Severity.MEDIUM
                        if derogatory
                        else Severity.LOW
                    ),
                    matched_text=text[start:end],
                    start_offset=start,
                    end_offset=end,
                    explanation=(
                        "Potentially fictionalizing language appears near anchored private "
                        "terminology. The surrounding wording requires human review."
                    ),
                    suggested_revision=(
                        "Use neutral task-focused language. Do not demand proof or convert "
                        "private terminology into a diagnosis, credential, rank, eligibility "
                        "category, or access condition."
                    ),
                )
            )

    if not findings:
        return DetectionResult(
            status=DetectionStatus.FICTIONALIZATION_NOT_DETECTED,
            findings=(),
            explanation=(
                "No configured fictionalization pattern was detected. This is a heuristic "
                "result, not a guarantee of respectful or complete language handling."
            ),
        )

    return DetectionResult(
        status=DetectionStatus.FICTIONALIZATION_REVIEW_REQUIRED,
        findings=tuple(sorted(findings, key=lambda finding: (finding.start_offset, finding.rule_id))),
        explanation=(
            "Potentially fictionalizing or derogatory framing was detected near anchored "
            "private terminology. Human review is required before publication or use."
        ),
    )
