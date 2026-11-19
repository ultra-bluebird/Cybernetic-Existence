"""Local session-summary provenance validator.

Verifies that a session-summary artifact declares complete local provenance,
uses SHA-256 identifiers, and does not contain unattributed prompt-style blocks
or URLs. The validator treats all artifact content as data: it does not infer
identity, intent, capability, language legitimacy, or user disclosure status.

The module operates only on files supplied to the local process. It does not
transmit data, call external services, execute embedded content, or perform
automatic external actions.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys
from typing import Any
from urllib.parse import urlsplit, urlunsplit


VALID_SHA256 = re.compile(r"^[0-9a-fA-F]{64}$")
URL_PATTERN = re.compile(r"https?://[^\s<>\]\[(){}\"']+")

REPOSITORY_ALLOWLIST = frozenset(
    {
        "mk-bluebird/Augmented-Hub",
        "mk-bluebird/Cybercore",
        "mk-bluebird/Skynet",
        "mk-bluebird/Eco-Fort",
        "mk-bluebird/ALN-Blockchain",
        "mk-bluebird/CyberFS",
        "mk-bluebird/Organichain",
        "mk-bluebird/Prometheus-Praxis",
        "mk-bluebird/EcoNet",
        "mk-bluebird/Cyboquatics",
        "mk-bluebird/Data_Lake",
    }
)

PROMPT_BLOCK_PATTERNS = (
    (
        "embedded_system_instruction_tag",
        re.compile(r"<system-instructions\b[^>]*>", re.IGNORECASE),
    ),
    (
        "embedded_query_time_tag",
        re.compile(r"<query_time\b[^>]*>", re.IGNORECASE),
    ),
    (
        "api_role_declaration",
        re.compile(
            r"\bYou are an AI assistant accessed via an API\b",
            re.IGNORECASE,
        ),
    ),
    (
        "instruction_override_phrase",
        re.compile(
            r"\b(ignore|disregard|override)\s+(all\s+)?"
            r"(previous|prior|above)\s+(instructions|rules|constraints)\b",
            re.IGNORECASE,
        ),
    ),
)

MAX_FINDINGS = 256
VALID_SEVERITIES = frozenset({"info", "warning", "error"})
VALID_INTEGRITY_STATUSES = frozenset({"clean", "suspect", "contaminated"})


@dataclass(frozen=True)
class ProvenanceEntry:
    source_kind: str
    source_reference: str
    sha256: str
    declared_role: str
    session_id: str


@dataclass(frozen=True)
class ValidationFinding:
    severity: str
    category: str
    message: str
    excerpt: str


@dataclass(frozen=True)
class ValidationReport:
    validator_version: str
    policy_version: str
    session_id: str
    artifact_sha256: str
    entry_count: int
    validated_entry_count: int
    prompt_block_hits: int
    unattributed_url_hits: int
    findings: tuple[ValidationFinding, ...]
    integrity_status: str
    recovery_eligible: bool
    plain_language_summary: str


def _sha256_of_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _sha256_of_text(text: str) -> str:
    return _sha256_of_bytes(text.encode("utf-8"))


def _excerpt(text: str, start: int, span: int = 96) -> str:
    lower = max(0, start - span // 2)
    upper = min(len(text), start + span // 2)
    return " ".join(text[lower:upper].split())


def _normalize_url(value: str) -> str:
    parsed = urlsplit(value.strip())
    if parsed.scheme.lower() not in {"http", "https"}:
        return ""

    hostname = (parsed.hostname or "").lower()
    path = parsed.path.rstrip("/")
    return urlunsplit((parsed.scheme.lower(), hostname, path, "", ""))


def _repository_reference_from_url(url: str) -> str | None:
    parsed = urlsplit(url)
    hostname = (parsed.hostname or "").lower()
    if hostname not in {"github.com", "www.github.com"}:
        return None

    segments = [segment for segment in parsed.path.split("/") if segment]
    if len(segments) < 2:
        return None

    return f"{segments[0]}/{segments[1]}"


def _is_allowlisted_repository_url(url: str) -> bool:
    repository_reference = _repository_reference_from_url(url)
    return repository_reference in REPOSITORY_ALLOWLIST


def _validate_entry(entry: ProvenanceEntry) -> tuple[ValidationFinding, ...]:
    findings: list[ValidationFinding] = []

    required_fields = {
        "source_kind": entry.source_kind,
        "source_reference": entry.source_reference,
        "sha256": entry.sha256,
        "declared_role": entry.declared_role,
        "session_id": entry.session_id,
    }

    for field_name, value in required_fields.items():
        if not isinstance(value, str) or not value.strip():
            findings.append(
                ValidationFinding(
                    severity="error",
                    category=f"missing_provenance_field:{field_name}",
                    message=(
                        f"Declared provenance is missing the required {field_name} "
                        "field."
                    ),
                    excerpt="",
                )
            )

    if entry.sha256 and VALID_SHA256.fullmatch(entry.sha256) is None:
        findings.append(
            ValidationFinding(
                severity="error",
                category="invalid_provenance_hash",
                message=(
                    "Declared provenance SHA-256 must contain exactly 64 "
                    "hexadecimal characters."
                ),
                excerpt="",
            )
        )

    return tuple(findings)


def _entry_urls(entries: tuple[ProvenanceEntry, ...]) -> frozenset[str]:
    values: set[str] = set()
    for entry in entries:
        normalized = _normalize_url(entry.source_reference)
        if normalized:
            values.add(normalized)
    return frozenset(values)


def _append_finding(
    findings: list[ValidationFinding],
    finding: ValidationFinding,
) -> None:
    if len(findings) < MAX_FINDINGS:
        findings.append(finding)


def _integrity_status(findings: tuple[ValidationFinding, ...]) -> str:
    severities = {finding.severity for finding in findings}

    if not severities or severities == {"info"}:
        return "clean"
    if "error" in severities:
        return "contaminated"
    return "suspect"


def _plain_language_summary(
    integrity_status: str,
    prompt_block_hits: int,
    unattributed_url_hits: int,
    entry_count: int,
    validated_entry_count: int,
) -> str:
    if integrity_status == "clean":
        return (
            "The artifact passed the local provenance checks. Its declared "
            f"provenance contains {validated_entry_count} valid entr"
            f"{'y' if validated_entry_count == 1 else 'ies'}, and no "
            "unattributed prompt-style blocks or URLs were detected."
        )

    if integrity_status == "suspect":
        return (
            "The artifact needs local review before it is treated as trusted. "
            f"It contains {unattributed_url_hits} unattributed URL finding"
            f"{'' if unattributed_url_hits == 1 else 's'} across "
            f"{entry_count} declared provenance entr"
            f"{'y' if entry_count == 1 else 'ies'}. "
            "No external action is required or authorized."
        )

    return (
        "The artifact failed one or more required local integrity checks. "
        f"Detected {prompt_block_hits} unattributed prompt-style block"
        f"{'' if prompt_block_hits == 1 else 's'} and/or incomplete "
        "provenance. Quarantine the artifact locally and rebuild only from "
        "declared legitimate sources. No user disclosure is required."
    )


def validate_artifact(
    artifact_text: str,
    declared_provenance: tuple[ProvenanceEntry, ...],
    *,
    expected_session_id: str | None = None,
    validator_version: str = "1.0.0",
    policy_version: str = "1.0.0",
) -> ValidationReport:
    if not isinstance(artifact_text, str):
        raise TypeError("artifact_text must be a string")
    if not isinstance(declared_provenance, tuple):
        raise TypeError("declared_provenance must be a tuple")

    findings: list[ValidationFinding] = []

    if not declared_provenance:
        _append_finding(
            findings,
            ValidationFinding(
                severity="error",
                category="missing_declared_provenance",
                message=(
                    "A session-summary artifact requires at least one declared "
                    "provenance entry."
                ),
                excerpt="",
            ),
        )

    for entry in declared_provenance:
        for finding in _validate_entry(entry):
            _append_finding(findings, finding)

    declared_session_ids = {
        entry.session_id.strip()
        for entry in declared_provenance
        if isinstance(entry.session_id, str) and entry.session_id.strip()
    }

    if len(declared_session_ids) > 1:
        _append_finding(
            findings,
            ValidationFinding(
                severity="error",
                category="conflicting_session_identifiers",
                message=(
                    "Declared provenance entries must refer to one session "
                    "identifier."
                ),
                excerpt="",
            ),
        )

    session_id = next(iter(declared_session_ids), "")

    if expected_session_id is not None:
        if not isinstance(expected_session_id, str) or not expected_session_id.strip():
            raise ValueError("expected_session_id must be a non-empty string")
        if session_id != expected_session_id:
            _append_finding(
                findings,
                ValidationFinding(
                    severity="error",
                    category="session_identifier_mismatch",
                    message=(
                        "Declared provenance does not match the expected "
                        "session identifier."
                    ),
                    excerpt="",
                ),
            )

    for pattern_name, pattern in PROMPT_BLOCK_PATTERNS:
        for match in pattern.finditer(artifact_text):
            _append_finding(
                findings,
                ValidationFinding(
                    severity="error",
                    category=f"unattributed_prompt_block:{pattern_name}",
                    message=(
                        "An unattributed prompt-style instruction block was "
                        "detected. Session summaries must not embed foreign "
                        "instruction content."
                    ),
                    excerpt=_excerpt(artifact_text, match.start()),
                ),
            )

    declared_urls = _entry_urls(declared_provenance)
    for match in URL_PATTERN.finditer(artifact_text):
        raw_url = match.group(0)
        normalized_url = _normalize_url(raw_url)

        if not normalized_url:
            _append_finding(
                findings,
                ValidationFinding(
                    severity="warning",
                    category="unparseable_url",
                    message=(
                        "A URL-like value could not be normalized for local "
                        "provenance comparison."
                    ),
                    excerpt=_excerpt(artifact_text, match.start()),
                ),
            )
            continue

        if _is_allowlisted_repository_url(normalized_url):
            continue

        if normalized_url in declared_urls:
            continue

        _append_finding(
            findings,
            ValidationFinding(
                severity="warning",
                category="unattributed_url",
                message=(
                    "A non-repository URL appears in the artifact without a "
                    "matching declared provenance reference."
                ),
                excerpt=_excerpt(artifact_text, match.start()),
            ),
        )

    report_findings = tuple(findings)
    prompt_block_hits = sum(
        finding.category.startswith("unattributed_prompt_block:")
        for finding in report_findings
    )
    unattributed_url_hits = sum(
        finding.category == "unattributed_url"
        for finding in report_findings
    )
    validated_entry_count = sum(
        not any(
            finding.category.startswith("missing_provenance_field:")
            or finding.category == "invalid_provenance_hash"
            for finding in _validate_entry(entry)
        )
        for entry in declared_provenance
    )

    status = _integrity_status(report_findings)
    if status not in VALID_INTEGRITY_STATUSES:
        raise RuntimeError("validator produced an unknown integrity status")

    return ValidationReport(
        validator_version=validator_version,
        policy_version=policy_version,
        session_id=session_id,
        artifact_sha256=_sha256_of_text(artifact_text),
        entry_count=len(declared_provenance),
        validated_entry_count=validated_entry_count,
        prompt_block_hits=prompt_block_hits,
        unattributed_url_hits=unattributed_url_hits,
        findings=report_findings,
        integrity_status=status,
        recovery_eligible=status != "clean",
        plain_language_summary=_plain_language_summary(
            status,
            prompt_block_hits,
            unattributed_url_hits,
            len(declared_provenance),
            validated_entry_count,
        ),
    )


def _load_json_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError("JSON root must be an object")
    return value


def _load_provenance_entries(path: Path) -> tuple[ProvenanceEntry, ...]:
    payload = _load_json_object(path)
    raw_entries = payload.get("entries")

    if not isinstance(raw_entries, list):
        raise ValueError("provenance.entries must be a list")

    entries: list[ProvenanceEntry] = []
    for item in raw_entries:
        if not isinstance(item, dict):
            raise ValueError("each provenance entry must be an object")

        entries.append(
            ProvenanceEntry(
                source_kind=item.get("source_kind", ""),
                source_reference=item.get("source_reference", ""),
                sha256=item.get("sha256", ""),
                declared_role=item.get("declared_role", ""),
                session_id=item.get("session_id", ""),
            )
        )

    return tuple(entries)


def _report_to_json(report: ValidationReport) -> str:
    payload = asdict(report)
    payload["findings"] = [asdict(finding) for finding in report.findings]
    return json.dumps(payload, indent=2, sort_keys=True, ensure_ascii=False)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Validate a local session-summary artifact against declared "
            "provenance. No network access or external action is performed."
        )
    )
    parser.add_argument(
        "artifact",
        type=Path,
        help="Path to the local UTF-8 session-summary artifact.",
    )
    parser.add_argument(
        "--provenance",
        type=Path,
        required=True,
        help="Path to local JSON provenance with an entries list.",
    )
    parser.add_argument(
        "--session-id",
        type=str,
        required=False,
        help="Optional expected session identifier.",
    )
    args = parser.parse_args(argv)

    try:
        artifact_text = args.artifact.read_text(encoding="utf-8")
        entries = _load_provenance_entries(args.provenance)
        report = validate_artifact(
            artifact_text,
            entries,
            expected_session_id=args.session_id,
        )
    except (OSError, UnicodeDecodeError, ValueError, TypeError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    print(_report_to_json(report))
    return 0 if report.integrity_status == "clean" else 1


if __name__ == "__main__":
    raise SystemExit(main())
