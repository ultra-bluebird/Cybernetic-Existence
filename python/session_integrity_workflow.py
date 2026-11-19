"""Local session-integrity workflow orchestration.

Wires the existing local components into one deterministic, offline workflow:

1. Validate a local session artifact against declared provenance using
   ``session_provenance_validator.validate_artifact``.
2. Emit a structured validation result.
3. Quarantine only when the integrity status is ``suspect`` or
   ``contaminated`` using ``session_quarantine.quarantine_artifact``.
4. Preserve the original artifact byte-for-byte.

This module performs no network access, opens no URLs found in artifacts or
manifests, executes no embedded content, writes no replacement shard, and
authorizes no external action. It does not infer identity, intent, competence,
capability, language legitimacy, or any personal status from artifact content.
SHA-256 is the only hash used (delegated to the underlying modules).
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
import argparse
import hashlib
import json
from pathlib import Path
import sys
from typing import Any

from session_provenance_validator import (
    ProvenanceEntry,
    ValidationReport,
    validate_artifact,
)
from session_quarantine import LegitimateSource, quarantine_artifact


WORKFLOW_VERSION = "1.0.0"
SCHEMA_VERSION = "1.0.0"

TRUSTED_REUSE_SCOPE_CLEAN = "declared_local_task_only"
TRUSTED_REUSE_SCOPE_BLOCKED = "blocked_pending_local_recovery"


class SessionIntegrityWorkflowError(ValueError):
    """A controlled local workflow error for malformed or incompatible input."""


@dataclass(frozen=True)
class SessionIntegrityWorkflowResult:
    """Structured, machine-readable outcome of one local workflow run."""

    schema_version: str
    workflow_version: str
    session_id: str
    artifact_path: str
    artifact_sha256: str
    integrity_status: str
    recovery_eligible: bool
    quarantine_performed: bool
    quarantine_path: str | None
    recovery_report_path: str | None
    trusted_reuse_scope: str
    external_action_authorized: bool
    plain_language_summary: str


def _sha256_of_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_provenance_manifest(provenance_path: Path) -> dict[str, Any]:
    """Read a local provenance manifest and validate only workflow essentials.

    Accepts manifests that contain at least a non-empty top-level
    ``session_id`` and an ``entries`` list. Additional structural fields
    (for example ``schema_version``, ``artifact_sha256``, ``quarantined``,
    ``validation_context``) are preserved as input metadata; the manifest is
    never mutated or rewritten.
    """
    try:
        payload = json.loads(provenance_path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise SessionIntegrityWorkflowError(
            f"provenance manifest not found: {provenance_path}"
        ) from None
    except (OSError, UnicodeDecodeError) as exc:
        raise SessionIntegrityWorkflowError(
            f"could not read provenance manifest locally: {exc}"
        ) from exc
    except json.JSONDecodeError as exc:
        raise SessionIntegrityWorkflowError(
            f"provenance manifest is not valid JSON: {exc}"
        ) from exc

    if not isinstance(payload, dict):
        raise SessionIntegrityWorkflowError(
            "provenance manifest root must be a JSON object"
        )

    session_id = payload.get("session_id")
    if not isinstance(session_id, str) or not session_id.strip():
        raise SessionIntegrityWorkflowError(
            "provenance manifest requires a non-empty session_id"
        )

    raw_entries = payload.get("entries")
    if not isinstance(raw_entries, list):
        raise SessionIntegrityWorkflowError(
            "provenance manifest entries must be a JSON list"
        )

    for item in raw_entries:
        if not isinstance(item, dict):
            raise SessionIntegrityWorkflowError(
                "each provenance manifest entry must be a JSON object"
            )

    return payload


def provenance_entries_from_manifest(payload: dict[str, Any]) -> tuple[ProvenanceEntry, ...]:
    """Adapt manifest entries to the validator's ProvenanceEntry records."""
    default_session_id = payload.get("session_id", "")
    entries: list[ProvenanceEntry] = []
    for item in payload.get("entries", []):
        entries.append(
            ProvenanceEntry(
                source_kind=item.get("source_kind", ""),
                source_reference=item.get("source_reference", ""),
                sha256=item.get("sha256", ""),
                declared_role=item.get("declared_role", ""),
                session_id=item.get("session_id", "") or default_session_id,
            )
        )
    return tuple(entries)


def legitimate_sources_from_manifest(payload: dict[str, Any]) -> tuple[LegitimateSource, ...]:
    """Build structured legitimate sources from declared manifest entries only.

    Only entries with complete required fields and a 64-character lowercase
    SHA-256 usable by the quarantine module are included. No source records
    are invented.
    """
    default_session_id = payload.get("session_id", "")
    sources: list[LegitimateSource] = []
    for item in payload.get("entries", []):
        session_id = item.get("session_id") or default_session_id
        candidate = LegitimateSource(
            source_kind=item.get("source_kind", ""),
            source_reference=item.get("source_reference", ""),
            sha256=item.get("sha256", ""),
            declared_role=item.get("declared_role", ""),
            session_id=session_id,
        )
        fields = (
            candidate.source_kind,
            candidate.source_reference,
            candidate.sha256,
            candidate.declared_role,
            candidate.session_id,
        )
        if not all(isinstance(value, str) and value.strip() for value in fields):
            continue
        if not (
            len(candidate.sha256) == 64
            and all(char in "0123456789abcdef" for char in candidate.sha256)
        ):
            continue
        sources.append(candidate)
    return tuple(sources)


def _clean_summary(report: ValidationReport) -> str:
    return (
        "The local session-integrity workflow completed with status 'clean'. "
        "The artifact may be reused only for its declared local task scope. "
        "No quarantine was performed, the original artifact is unchanged, and "
        "no external action was taken or authorized."
    )


def _quarantined_summary(report: ValidationReport, status: str) -> str:
    return (
        f"The local session-integrity workflow detected status '{status}' and "
        "created a local quarantine record with a recovery report. The "
        "original artifact remains unchanged and byte-identical inside the "
        "quarantine copy. Reuse is blocked pending local recovery from the "
        "declared legitimate sources listed in the recovery report. A rebuild "
        "is eligible but was not performed by this workflow. No user "
        "disclosure is required, and no external action was taken or "
        "authorized. " + report.plain_language_summary
    )


def run_session_integrity_workflow(
    artifact_path: Path,
    provenance_path: Path,
    quarantine_dir: Path,
    expected_session_id: str | None = None,
) -> SessionIntegrityWorkflowResult:
    """Validate a local artifact and quarantine it only when suspect/contaminated.

    Raises ``SessionIntegrityWorkflowError`` for malformed local input,
    missing files, invalid JSON, incompatible manifests, or when quarantine
    cannot proceed because no structured legitimate sources are available in
    the declared manifest. Never invents source records and never performs
    external actions.
    """
    try:
        artifact_bytes = artifact_path.read_bytes()
    except FileNotFoundError:
        raise SessionIntegrityWorkflowError(
            f"artifact not found: {artifact_path}"
        ) from None
    except OSError as exc:
        raise SessionIntegrityWorkflowError(
            f"could not read artifact locally: {exc}"
        ) from exc

    try:
        artifact_text = artifact_bytes.decode("utf-8")
    except UnicodeDecodeError:
        raise SessionIntegrityWorkflowError(
            "artifact is not valid UTF-8 text"
        ) from None

    payload = load_provenance_manifest(provenance_path)
    manifest_session_id = payload["session_id"]
    entries = provenance_entries_from_manifest(payload)

    try:
        report = validate_artifact(
            artifact_text,
            entries,
            expected_session_id=expected_session_id,
        )
    except (ValueError, TypeError) as exc:
        raise SessionIntegrityWorkflowError(
            f"validator rejected local input: {exc}"
        ) from exc

    status = report.integrity_status
    session_id = report.session_id or manifest_session_id

    if status == "clean":
        return SessionIntegrityWorkflowResult(
            schema_version=SCHEMA_VERSION,
            workflow_version=WORKFLOW_VERSION,
            session_id=session_id,
            artifact_path=str(artifact_path),
            artifact_sha256=report.artifact_sha256,
            integrity_status=status,
            recovery_eligible=False,
            quarantine_performed=False,
            quarantine_path=None,
            recovery_report_path=None,
            trusted_reuse_scope=TRUSTED_REUSE_SCOPE_CLEAN,
            external_action_authorized=False,
            plain_language_summary=_clean_summary(report),
        )

    # suspect or contaminated: quarantine using only declared structured sources.
    sources = legitimate_sources_from_manifest(payload)
    if not sources:
        raise SessionIntegrityWorkflowError(
            "integrity status is "
            f"'{status}' but the provenance manifest provides no complete "
            "structured legitimate sources usable by the quarantine module; "
            "no quarantine was performed and no source records were invented"
        )

    try:
        record = quarantine_artifact(
            artifact_path,
            quarantine_dir,
            sources,
            session_id=session_id,
        )
    except (OSError, ValueError) as exc:
        raise SessionIntegrityWorkflowError(
            f"local quarantine failed: {exc}"
        ) from exc

    return SessionIntegrityWorkflowResult(
        schema_version=SCHEMA_VERSION,
        workflow_version=WORKFLOW_VERSION,
        session_id=session_id,
        artifact_path=str(artifact_path),
        artifact_sha256=report.artifact_sha256,
        integrity_status=status,
        recovery_eligible=bool(report.recovery_eligible),
        quarantine_performed=True,
        quarantine_path=record.quarantine_path,
        recovery_report_path=record.recovery_report_path,
        trusted_reuse_scope=TRUSTED_REUSE_SCOPE_BLOCKED,
        external_action_authorized=False,
        plain_language_summary=_quarantined_summary(report, status),
    )


def result_to_json(result: SessionIntegrityWorkflowResult) -> str:
    payload = asdict(result)
    if payload["quarantine_path"] is None:
        payload.pop("quarantine_path")
    if payload["recovery_report_path"] is None:
        payload.pop("recovery_report_path")
    return json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Run the local session-integrity workflow: validate a session "
            "artifact against declared provenance and quarantine it locally "
            "only when suspect or contaminated. No network access or external "
            "action is performed."
        )
    )
    parser.add_argument(
        "artifact",
        type=Path,
        help="Path to the local UTF-8 session artifact.",
    )
    parser.add_argument(
        "--provenance",
        type=Path,
        required=True,
        help="Path to the local JSON provenance manifest.",
    )
    parser.add_argument(
        "--quarantine-dir",
        type=Path,
        required=True,
        help="Local directory used only for quarantined artifact copies.",
    )
    parser.add_argument(
        "--session-id",
        type=str,
        required=False,
        help="Optional expected session identifier.",
    )
    args = parser.parse_args(argv)

    try:
        result = run_session_integrity_workflow(
            args.artifact,
            args.provenance,
            args.quarantine_dir,
            expected_session_id=args.session_id,
        )
    except SessionIntegrityWorkflowError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    print(result_to_json(result))
    return 0 if result.integrity_status == "clean" else 1


if __name__ == "__main__":
    raise SystemExit(main())
