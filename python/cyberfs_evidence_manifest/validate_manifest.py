from __future__ import annotations

import hashlib
import json
import re
from datetime import datetime
from typing import Any

SHA256_HEX = re.compile(r"^[0-9a-fA-F]{64}$")
EVIDENCE_LEVELS = {
    "unreviewed_observation",
    "method_note",
    "secondary_summary",
    "primary_source",
    "replication",
    "systematic_review",
    "independent_validation",
    "withdrawn_or_superseded",
}


class ManifestValidationError(ValueError):
    pass


def canonical_json_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def sha256_hex(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def validate_manifest(manifest: dict[str, Any]) -> None:
    required_fields = {
        "manifest_version",
        "manifest_id",
        "subject",
        "source",
        "evidence_level",
        "context",
        "duration",
        "limitations",
        "review",
        "previous_manifest_hash",
        "signature",
    }

    missing = required_fields.difference(manifest)
    if missing:
        raise ManifestValidationError(
            f"manifest is missing required fields: {sorted(missing)}"
        )

    if manifest["manifest_version"] != "EvidenceManifest.v1":
        raise ManifestValidationError("unsupported manifest version")

    require_non_empty(manifest["manifest_id"], "manifest_id")
    validate_subject(manifest["subject"])
    validate_source(manifest["source"])
    validate_evidence_level(manifest["evidence_level"])
    validate_context(manifest["context"])
    validate_duration(manifest["duration"])
    validate_limitations(manifest["limitations"])
    validate_review(manifest["review"])
    validate_previous_hash(manifest["previous_manifest_hash"])
    validate_signature(manifest["signature"], manifest["review"]["reviewer_key_id"])


def signing_payload(manifest: dict[str, Any]) -> bytes:
    validate_manifest(manifest)
    unsigned = dict(manifest)
    unsigned["signature"] = None
    return canonical_json_bytes(unsigned)


def manifest_commitment(manifest: dict[str, Any]) -> str:
    return sha256_hex(signing_payload(manifest))


def validate_subject(subject: Any) -> None:
    if not isinstance(subject, dict):
        raise ManifestValidationError("subject must be an object")

    require_non_empty(subject.get("logical_name"), "subject.logical_name")
    require_non_empty(subject.get("media_type"), "subject.media_type")
    validate_hash_digest(subject.get("content_hash"), "subject.content_hash")


def validate_source(source: Any) -> None:
    if not isinstance(source, dict):
        raise ManifestValidationError("source must be an object")

    for field in ("source_id", "source_kind", "access_basis", "retrieved_at_utc"):
        require_non_empty(source.get(field), f"source.{field}")

    parse_utc(source["retrieved_at_utc"], "source.retrieved_at_utc")


def validate_evidence_level(level: Any) -> None:
    if level not in EVIDENCE_LEVELS:
        raise ManifestValidationError("evidence_level is not in the controlled vocabulary")


def validate_context(context: Any) -> None:
    if not isinstance(context, dict):
        raise ManifestValidationError("context must be an object")

    require_non_empty(context.get("domain"), "context.domain")
    require_non_empty(context.get("scope_note"), "context.scope_note")

    tissue_context = context.get("tissue_context")
    if tissue_context is not None and not isinstance(tissue_context, str):
        raise ManifestValidationError("context.tissue_context must be null or a string")


def validate_duration(duration: Any) -> None:
    if not isinstance(duration, dict):
        raise ManifestValidationError("duration must be an object")

    kind = duration.get("kind")

    if kind == "instant":
        parse_utc(duration.get("observed_at_utc"), "duration.observed_at_utc")
        return

    if kind in {"interval", "aggregate"}:
        started = parse_utc(duration.get("started_at_utc"), "duration.started_at_utc")
        ended = parse_utc(duration.get("ended_at_utc"), "duration.ended_at_utc")

        if started > ended:
            raise ManifestValidationError("duration start must not be after duration end")

        if kind == "aggregate":
            count = duration.get("observation_count")
            if not isinstance(count, int) or isinstance(count, bool) or count <= 0:
                raise ManifestValidationError(
                    "duration.observation_count must be a positive integer"
                )
        return

    if kind == "unspecified_with_reason":
        require_non_empty(duration.get("reason"), "duration.reason")
        return

    raise ManifestValidationError("duration.kind is invalid")


def validate_limitations(limitations: Any) -> None:
    if not isinstance(limitations, list) or not limitations:
        raise ManifestValidationError("limitations must be a non-empty list")

    if any(not isinstance(item, str) or not item.strip() for item in limitations):
        raise ManifestValidationError("each limitation must be a non-empty string")


def validate_review(review: Any) -> None:
    if not isinstance(review, dict):
        raise ManifestValidationError("review must be an object")

    for field in (
        "reviewer_role",
        "reviewer_key_id",
        "reviewed_at_utc",
        "review_outcome",
    ):
        require_non_empty(review.get(field), f"review.{field}")

    parse_utc(review["reviewed_at_utc"], "review.reviewed_at_utc")


def validate_previous_hash(previous_hash: Any) -> None:
    if previous_hash is None:
        return

    validate_hash_digest(previous_hash, "previous_manifest_hash")


def validate_signature(signature: Any, reviewer_key_id: str) -> None:
    if signature is None:
        return

    if not isinstance(signature, dict):
        raise ManifestValidationError("signature must be null or an object")

    for field in ("algorithm", "key_id", "value_base64"):
        require_non_empty(signature.get(field), f"signature.{field}")

    if signature["key_id"] != reviewer_key_id:
        raise ManifestValidationError(
            "signature.key_id must equal review.reviewer_key_id"
        )


def validate_hash_digest(value: Any, field_name: str) -> None:
    if not isinstance(value, dict):
        raise ManifestValidationError(f"{field_name} must be an object")

    if value.get("algorithm") != "sha256":
        raise ManifestValidationError(f"{field_name}.algorithm must be sha256")

    digest = value.get("value_hex")
    if not isinstance(digest, str) or SHA256_HEX.fullmatch(digest) is None:
        raise ManifestValidationError(
            f"{field_name}.value_hex must be a 64-character hexadecimal SHA-256 digest"
        )


def require_non_empty(value: Any, field_name: str) -> None:
    if not isinstance(value, str) or not value.strip():
        raise ManifestValidationError(f"{field_name} must be a non-empty string")


def parse_utc(value: Any, field_name: str) -> datetime:
    require_non_empty(value, field_name)

    if not value.endswith("Z"):
        raise ManifestValidationError(f"{field_name} must use a UTC Z suffix")

    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise ManifestValidationError(f"{field_name} is not valid ISO-8601 UTC") from error
