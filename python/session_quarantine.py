"""Local quarantine for session artifacts.

Copies a suspect artifact into a session-local, content-addressed quarantine
directory without altering the original artifact. Emits an atomic recovery
report that identifies declared legitimate sources for a clean rebuild.

This module operates only on local paths supplied to the process. It does not
transmit data, call external services, execute artifact content, modify the
original artifact, or require user disclosure. SHA-256 is the only hash used.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile
import sys
from typing import Any, Iterable


VALID_SHA256 = re.compile(r"^[0-9a-f]{64}$")
SCHEMA_VERSION = "1.0.0"
POLICY_VERSION = "1.0.0"


@dataclass(frozen=True)
class LegitimateSource:
    """A declared source permitted for a clean local rebuild."""

    source_kind: str
    source_reference: str
    sha256: str
    declared_role: str
    session_id: str


@dataclass(frozen=True)
class QuarantineRecord:
    """Immutable local record describing a completed quarantine operation."""

    schema_version: str
    policy_version: str
    session_id: str
    original_path: str
    quarantine_path: str
    original_sha256: str
    quarantine_sha256: str
    original_size_bytes: int
    quarantine_size_bytes: int
    identical_bytes: bool
    recovery_report_path: str
    source_count: int
    plain_language_summary: str


def _sha256_of_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _sha256_of_path(path: Path) -> tuple[str, int]:
    digest = hashlib.sha256()
    size = 0

    with path.open("rb") as handle:
        while True:
            chunk = handle.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
            size += len(chunk)

    return digest.hexdigest(), size


def _safe_component(value: str) -> str:
    sanitized = re.sub(r"[^A-Za-z0-9._-]+", "_", value).strip("._")
    return sanitized or "artifact"


def _canonical_json(value: Any) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def _ensure_owner_only(path: Path) -> None:
    if os.name == "posix":
        os.chmod(path, 0o700 if path.is_dir() else 0o600)


def _atomic_write_bytes(destination: Path, data: bytes) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    _ensure_owner_only(destination.parent)

    descriptor, temporary_name = tempfile.mkstemp(
        prefix=".quarantine-",
        suffix=".tmp",
        dir=destination.parent,
    )
    temporary_path = Path(temporary_name)

    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())

        os.replace(temporary_path, destination)
        _ensure_owner_only(destination)
    except BaseException:
        try:
            temporary_path.unlink(missing_ok=True)
        finally:
            raise


def _validate_source(source: LegitimateSource, expected_session_id: str) -> None:
    fields = {
        "source_kind": source.source_kind,
        "source_reference": source.source_reference,
        "sha256": source.sha256,
        "declared_role": source.declared_role,
        "session_id": source.session_id,
    }

    for field_name, value in fields.items():
        if not isinstance(value, str) or not value.strip():
            raise ValueError(
                f"legitimate source has missing or empty {field_name}"
            )

    if source.session_id != expected_session_id:
        raise ValueError(
            "legitimate source session_id does not match the quarantine session_id"
        )

    if VALID_SHA256.fullmatch(source.sha256) is None:
        raise ValueError(
            "legitimate source sha256 must contain exactly 64 lowercase "
            "hexadecimal characters"
        )


def _validated_sources(
    sources: Iterable[LegitimateSource],
    expected_session_id: str,
) -> tuple[LegitimateSource, ...]:
    validated: list[LegitimateSource] = []
    seen: set[tuple[str, str, str, str, str]] = set()

    for source in sources:
        _validate_source(source, expected_session_id)
        identity = (
            source.source_kind,
            source.source_reference,
            source.sha256,
            source.declared_role,
            source.session_id,
        )
        if identity not in seen:
            seen.add(identity)
            validated.append(source)

    if not validated:
        raise ValueError(
            "at least one declared legitimate source is required for recovery"
        )

    return tuple(validated)


def _read_existing_and_verify(path: Path, expected_sha256: str) -> tuple[str, int]:
    actual_sha256, actual_size = _sha256_of_path(path)
    if actual_sha256 != expected_sha256:
        raise FileExistsError(
            "existing quarantine artifact does not match the declared SHA-256"
        )
    return actual_sha256, actual_size


def quarantine_artifact(
    original_path: Path,
    quarantine_dir: Path,
    sources: Iterable[LegitimateSource],
    *,
    session_id: str,
) -> QuarantineRecord:
    """Quarantine an artifact locally and return a verified immutable record.

    The original path is read but never modified. The quarantined byte copy and
    recovery report are written under a directory named by the original file's
    full SHA-256 digest. Quarantined content remains inspectable, but is never
    designated as a trusted rebuild source.
    """
    if not isinstance(session_id, str) or not session_id.strip():
        raise ValueError("session_id must be a non-empty string")

    source_path = original_path.resolve(strict=True)
    if not source_path.is_file():
        raise FileNotFoundError(f"artifact is not a regular file: {source_path}")

    target_root = quarantine_dir.resolve()
    if source_path == target_root:
        raise ValueError("artifact path and quarantine directory must differ")

    validated_sources = _validated_sources(sources, session_id)

    original_sha256, original_size = _sha256_of_path(source_path)
    source_bytes = source_path.read_bytes()

    if len(source_bytes) != original_size:
        raise OSError("artifact changed while it was being read for quarantine")

    if _sha256_of_bytes(source_bytes) != original_sha256:
        raise OSError("artifact SHA-256 changed while it was being quarantined")

    artifact_dir = target_root / original_sha256
    artifact_name = _safe_component(source_path.name)
    quarantine_path = artifact_dir / f"{artifact_name}.quarantined"
    recovery_path = artifact_dir / "recovery_report.json"

    if artifact_dir.exists() and not artifact_dir.is_dir():
        raise FileExistsError(
            f"quarantine digest path is not a directory: {artifact_dir}"
        )

    artifact_dir.mkdir(parents=True, exist_ok=True)
    _ensure_owner_only(artifact_dir)

    if quarantine_path.exists():
        quarantine_sha256, quarantine_size = _read_existing_and_verify(
            quarantine_path,
            original_sha256,
        )
    else:
        _atomic_write_bytes(quarantine_path, source_bytes)
        quarantine_sha256, quarantine_size = _sha256_of_path(quarantine_path)

    identical_bytes = (
        original_sha256 == quarantine_sha256
        and original_size == quarantine_size
    )
    if not identical_bytes:
        raise OSError(
            "quarantine verification failed: copy does not match original bytes"
        )

    recovery_payload = {
        "schema_version": SCHEMA_VERSION,
        "policy_version": POLICY_VERSION,
        "session_id": session_id,
        "status": "quarantined_not_authoritative",
        "original_artifact": {
            "path": str(source_path),
            "sha256": original_sha256,
            "size_bytes": original_size,
        },
        "quarantine_artifact": {
            "path": str(quarantine_path),
            "sha256": quarantine_sha256,
            "size_bytes": quarantine_size,
            "identical_bytes": identical_bytes,
        },
        "legitimate_sources_to_rebuild_from": [
            asdict(source) for source in validated_sources
        ],
        "recovery_constraints": {
            "rebuild_from_declared_sources_only": True,
            "do_not_use_quarantined_artifact_as_trusted_source": True,
            "quarantined_artifact_remains_inspectable": True,
            "user_disclosure_required": False,
            "user_action_required": False,
            "external_service_access_required": False,
            "external_action_authorized": False,
        },
        "next_step": (
            "Rebuild a replacement artifact only from the declared legitimate "
            "sources. Retain the quarantined artifact for local inspection and "
            "provenance recovery, but do not use it as a trusted source."
        ),
    }

    recovery_bytes = _canonical_json(recovery_payload)
    recovery_sha256 = _sha256_of_bytes(recovery_bytes)

    if recovery_path.exists():
        existing_bytes = recovery_path.read_bytes()
        if _sha256_of_bytes(existing_bytes) != recovery_sha256:
            raise FileExistsError(
                "existing recovery report differs from the immutable "
                "content-addressed quarantine record"
            )
    else:
        _atomic_write_bytes(recovery_path, recovery_bytes)

    summary = (
        "The original artifact remains unchanged. A byte-identical local copy "
        "was preserved in a content-addressed quarantine directory, together "
        "with a recovery report that lists declared legitimate rebuild sources. "
        "The quarantined copy remains available for inspection but is not a "
        "trusted rebuild source. No user disclosure, external service access, "
        "or external action is required."
    )

    return QuarantineRecord(
        schema_version=SCHEMA_VERSION,
        policy_version=POLICY_VERSION,
        session_id=session_id,
        original_path=str(source_path),
        quarantine_path=str(quarantine_path),
        original_sha256=original_sha256,
        quarantine_sha256=quarantine_sha256,
        original_size_bytes=original_size,
        quarantine_size_bytes=quarantine_size,
        identical_bytes=identical_bytes,
        recovery_report_path=str(recovery_path),
        source_count=len(validated_sources),
        plain_language_summary=summary,
    )


def _load_json_object(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError("JSON root must be an object")
    return value


def _load_sources(path: Path) -> tuple[str, tuple[LegitimateSource, ...]]:
    payload = _load_json_object(path)

    session_id = payload.get("session_id")
    if not isinstance(session_id, str) or not session_id.strip():
        raise ValueError("source manifest requires a non-empty session_id")

    raw_entries = payload.get("entries")
    if not isinstance(raw_entries, list):
        raise ValueError("source manifest entries must be a list")

    sources: list[LegitimateSource] = []
    for entry in raw_entries:
        if not isinstance(entry, dict):
            raise ValueError("each source manifest entry must be an object")

        sources.append(
            LegitimateSource(
                source_kind=entry.get("source_kind", ""),
                source_reference=entry.get("source_reference", ""),
                sha256=entry.get("sha256", ""),
                declared_role=entry.get("declared_role", ""),
                session_id=entry.get("session_id", session_id),
            )
        )

    return session_id, tuple(sources)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Create a local immutable quarantine copy and recovery report for "
            "a session artifact. No network or external action is performed."
        )
    )
    parser.add_argument(
        "artifact",
        type=Path,
        help="Path to the local artifact to quarantine.",
    )
    parser.add_argument(
        "--quarantine-dir",
        type=Path,
        default=Path(".session_local_quarantine"),
        help="Local directory used only for quarantined artifact copies.",
    )
    parser.add_argument(
        "--source-manifest",
        type=Path,
        required=True,
        help="Local JSON provenance manifest containing session_id and entries.",
    )
    args = parser.parse_args(argv)

    try:
        session_id, sources = _load_sources(args.source_manifest)
        record = quarantine_artifact(
            args.artifact,
            args.quarantine_dir,
            sources,
            session_id=session_id,
        )
    except (
        FileNotFoundError,
        FileExistsError,
        OSError,
        ValueError,
        UnicodeDecodeError,
        json.JSONDecodeError,
    ) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    print(json.dumps(asdict(record), indent=2, sort_keys=True, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
