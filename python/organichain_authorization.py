from __future__ import annotations

from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from hashlib import sha256
from hmac import digest as hmac_digest
from uuid import uuid4
import json

HASH_BYTES = 32

@dataclass(frozen=True)
class AuthorizationRecord:
    record_version: int
    record_commitment: str
    parent_commitments: tuple[str, ...]
    event_time: str
    session_pseudonym: str
    generation: int
    capability_commitment: str
    decision: str
    reason_code: str
    policy_version: str
    policy_commitment: str
    retention_class: str
    metadata_commitment: str
    integrity_proof: dict[str, str]

def canonical_json(value: dict[str, object]) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")

def sha256_hex(value: dict[str, object]) -> str:
    return sha256(canonical_json(value)).hexdigest()

def canonical_commitment_set(commitments: list[str]) -> tuple[str, ...]:
    result = tuple(sorted(set(commitments)))

    if len(result) != len(commitments):
        raise ValueError("parent commitments must not contain duplicates")

    if len(result) > 16:
        raise ValueError("too many parent commitments")

    for item in result:
        if len(item) != HASH_BYTES * 2:
            raise ValueError("commitment must be a SHA-256 hexadecimal digest")

    return result

def pairwise_pseudonym(
    pseudonym_secret: bytes,
    verifier_context: str,
    purpose: str,
    epoch: int,
) -> str:
    if len(pseudonym_secret) < HASH_BYTES:
        raise ValueError("pseudonym_secret must contain at least 32 bytes")

    if not verifier_context or not purpose or epoch < 0:
        raise ValueError("invalid pseudonym context")

    material = (
        b"organichain/pseudonym/v1\x00"
        + sha256(verifier_context.encode("utf-8")).digest()
        + b"\x00"
        + purpose.encode("utf-8")
        + b"\x00"
        + epoch.to_bytes(8, "big")
    )

    return hmac_digest(pseudonym_secret, material, "sha256").hex()

def create_authorization_record(
    *,
    parent_commitments: list[str],
    session_pseudonym: str,
    generation: int,
    capability_commitment: str,
    decision: str,
    reason_code: str,
    policy_version: str,
    policy_commitment: str,
    retention_class: str,
    metadata_commitment: str,
    integrity_proof: dict[str, str],
    now: datetime | None = None,
) -> AuthorizationRecord:
    if not session_pseudonym or len(session_pseudonym) > 128:
        raise ValueError("invalid session pseudonym")

    if generation < 1:
        raise ValueError("generation must be positive")

    if decision not in {"ALLOW", "DENY", "REVOKE", "EXPIRE", "ERROR"}:
        raise ValueError("invalid decision")

    if retention_class not in {
        "LOCAL_EPHEMERAL",
        "LOCAL_RETAINED",
        "HOLDER_EXPORTED",
    }:
        raise ValueError("invalid retention class")

    parents = canonical_commitment_set(parent_commitments)

    draft: dict[str, object] = {
        "record_version": 1,
        "parent_commitments": parents,
        "event_time": (now or datetime.now(timezone.utc)).isoformat(),
        "session_pseudonym": session_pseudonym,
        "generation": generation,
        "capability_commitment": capability_commitment,
        "decision": decision,
        "reason_code": reason_code,
        "policy_version": policy_version,
        "policy_commitment": policy_commitment,
        "retention_class": retention_class,
        "metadata_commitment": metadata_commitment,
        "integrity_proof": integrity_proof,
    }

    return AuthorizationRecord(
        record_commitment=sha256_hex(draft),
        **draft,
    )

def verify_record_commitment(record: AuthorizationRecord) -> bool:
    value = asdict(record)
    supplied = value.pop("record_commitment")
    return supplied == sha256_hex(value)

def public_audit_summary(record: AuthorizationRecord) -> dict[str, object]:
    return {
        "record_version": record.record_version,
        "record_commitment": record.record_commitment,
        "parent_commitments": record.parent_commitments,
        "event_time": record.event_time,
        "session_pseudonym": record.session_pseudonym,
        "generation": record.generation,
        "decision": record.decision,
        "reason_code": record.reason_code,
        "policy_version": record.policy_version,
        "policy_commitment": record.policy_commitment,
        "retention_class": record.retention_class,
    }

def create_export_manifest(records: list[AuthorizationRecord]) -> dict[str, object]:
    summaries = [public_audit_summary(record) for record in records]
    manifest = {
        "manifest_version": 1,
        "export_id": str(uuid4()),
        "record_count": len(summaries),
        "records": summaries,
    }
    manifest["manifest_commitment"] = sha256_hex(manifest)
    return manifest
