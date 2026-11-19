from __future__ import annotations

from dataclasses import asdict, dataclass
import argparse
import hashlib
import json
import re
from pathlib import Path
import sys
from typing import Any


class ValidationError(ValueError):
    pass


ALLOWED_SOURCE_TYPES = {
    "user_provided_content",
    "verified_repository_artifact",
    "reviewed_local_derivation",
}
EXCLUDED_SOURCE_TYPES = {
    "quarantined_session_artifact",
    "untrusted_connector_return",
    "untrusted_cache_return",
    "untrusted_search_return",
    "untrusted_memory_return",
    "untrusted_summary_fragment",
}
REQUIRED_SECTIONS = {
    "@meta",
    "@INVARIANTS",
    "@GROUPS",
    "@CATALOG",
    "@FORMULAS",
    "@ARCHITECTURE",
    "@GOVERNANCE",
    "@STRESS_TEST_FINDINGS",
    "@CROSS_REFERENCES",
    "@SESSION_SUMMARY",
}
QUARANTINE_TERMS = {
    "lottery",
    "gambling",
    "casino",
    "sportsbook",
    "博彩",
    "彩票",
    "赌场",
}


@dataclass(frozen=True)
class TrustedSource:
    source_id: str
    source_type: str
    content: str


@dataclass(frozen=True)
class QuarantinedArtifact:
    artifact_id: str
    quarantine_reason: str
    content: str | None
    sha256: str | None


@dataclass(frozen=True)
class IntegrityReport:
    trusted_source_count: int
    quarantined_artifact_count: int
    trusted_source_hashes: dict[str, str]
    quarantined_artifact_hashes: dict[str, str | None]
    required_sections_present: tuple[str, ...]
    required_sections_missing: tuple[str, ...]
    unexpected_token_flags: tuple[str, ...]
    quarantine_dependency_detected: bool
    structural_validation_status: str
    semantic_validation_status: str
    token_review_status: str
    ecological_validity_status: str
    output_sha256: str
    reconstruction_eligible: bool
    interpretation: tuple[str, ...]


def sha256_fingerprint(value: Any) -> str:
    normalized = json.dumps(
        value,
        ensure_ascii=True,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return "sha256:" + hashlib.sha256(normalized).hexdigest()


def validate_trusted_source(source: TrustedSource) -> None:
    if not isinstance(source.source_id, str) or not source.source_id.strip():
        raise ValidationError("source_id must be a non-empty string.")
    if source.source_type not in ALLOWED_SOURCE_TYPES:
        raise ValidationError(
            f"source_type must be one of: {', '.join(sorted(ALLOWED_SOURCE_TYPES))}."
        )
    if not isinstance(source.content, str) or not source.content.strip():
        raise ValidationError("trusted source content must be non-empty text.")


def validate_quarantined_artifact(value: QuarantinedArtifact) -> None:
    if not isinstance(value.artifact_id, str) or not value.artifact_id.strip():
        raise ValidationError("artifact_id must be a non-empty string.")
    if (
        not isinstance(value.quarantine_reason, str)
        or not value.quarantine_reason.strip()
    ):
        raise ValidationError(
            "quarantine_reason must be non-empty text."
        )
    if value.sha256 is not None:
        if not value.sha256.startswith("sha256:") or len(value.sha256) != 71:
            raise ValidationError(
                "quarantined sha256 must use sha256:<64-lowercase-hex>."
            )


def find_required_sections(content: str) -> tuple[tuple[str, ...], tuple[str, ...]]:
    present = tuple(
        section
        for section in sorted(REQUIRED_SECTIONS)
        if section in content
    )
    missing = tuple(
        section
        for section in sorted(REQUIRED_SECTIONS)
        if section not in content
    )
    return present, missing


def find_unexpected_tokens(content: str) -> tuple[str, ...]:
    lowered = content.lower()
    flags = {
        term
        for term in QUARANTINE_TERMS
        if term in lowered or term in content
    }

    non_ascii_segments = re.findall(r"[^\x00-\x7F]{4,}", content)
    if non_ascii_segments:
        flags.add("non_ascii_token_review_required")

    return tuple(sorted(flags))


def evaluate_integrity(
    trusted_sources: list[TrustedSource],
    quarantined_artifacts: list[QuarantinedArtifact],
    reconstructed_shard: str,
) -> IntegrityReport:
    if not trusted_sources:
        raise ValidationError(
            "At least one trusted source is required for reconstruction."
        )
    if not isinstance(reconstructed_shard, str) or not reconstructed_shard.strip():
        raise ValidationError(
            "reconstructed_shard must be non-empty text."
        )

    source_hashes: dict[str, str] = {}
    for source in trusted_sources:
        validate_trusted_source(source)
        if source.source_id in source_hashes:
            raise ValidationError(f"Duplicate source_id: {source.source_id}.")
        source_hashes[source.source_id] = sha256_fingerprint(source.content)

    quarantine_hashes: dict[str, str | None] = {}
    for artifact in quarantined_artifacts:
        validate_quarantined_artifact(artifact)
        if artifact.artifact_id in quarantine_hashes:
            raise ValidationError(
                f"Duplicate artifact_id: {artifact.artifact_id}."
            )
        quarantine_hashes[artifact.artifact_id] = (
            artifact.sha256
            if artifact.sha256 is not None
            else (
                sha256_fingerprint(artifact.content)
                if artifact.content is not None
                else None
            )
        )

    present, missing = find_required_sections(reconstructed_shard)
    token_flags = find_unexpected_tokens(reconstructed_shard)

    quarantine_dependency_detected = False
    for artifact in quarantined_artifacts:
        if artifact.content and artifact.content in reconstructed_shard:
            quarantine_dependency_detected = True
            break

    structural_status = "passed" if not missing else "failed"
    semantic_status = (
        "passed"
        if "@INVARIANTS" in reconstructed_shard
        and "advisory_only: true" in reconstructed_shard
        and "local_only_execution: true" in reconstructed_shard
        and "reproducibility_via_run_manifest: true" in reconstructed_shard
        else "failed"
    )
    token_status = "passed" if not token_flags else "review_required"

    eligible = (
        structural_status == "passed"
        and semantic_status == "passed"
        and not quarantine_dependency_detected
        and token_status == "passed"
    )

    interpretation = [
        "This verifier treats quarantined artifacts as non-authoritative and "
        "does not use their content as a reconstruction source.",
        "Token flags require review. They do not support identity, language, "
        "preference, or intent inference.",
        "A passed result establishes only local structural and provenance "
        "conditions. Ecological validity is not determined by software.",
    ]
    if missing:
        interpretation.append(
            "Required shard sections are missing from the reconstructed artifact."
        )
    if token_flags:
        interpretation.append(
            "Unexpected token flags require domain review before canonical release."
        )
    if quarantine_dependency_detected:
        interpretation.append(
            "A quarantined artifact appears in the reconstructed content; "
            "canonical release is blocked."
        )

    return IntegrityReport(
        trusted_source_count=len(trusted_sources),
        quarantined_artifact_count=len(quarantined_artifacts),
        trusted_source_hashes=source_hashes,
        quarantined_artifact_hashes=quarantine_hashes,
        required_sections_present=present,
        required_sections_missing=missing,
        unexpected_token_flags=token_flags,
        quarantine_dependency_detected=quarantine_dependency_detected,
        structural_validation_status=structural_status,
        semantic_validation_status=semantic_status,
        token_review_status=token_status,
        ecological_validity_status="not_determined_by_software",
        output_sha256=sha256_fingerprint(reconstructed_shard),
        reconstruction_eligible=eligible,
        interpretation=tuple(interpretation),
    )


def _load_json(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as source:
            value = json.load(source)
    except OSError as error:
        raise ValidationError(f"Could not read {path}: {error}") from error
    except json.JSONDecodeError as error:
        raise ValidationError(f"Invalid JSON in {path}: {error}") from error

    if not isinstance(value, dict):
        raise ValidationError("Input JSON root must be an object.")
    return value


def _serialize(value: Any) -> Any:
    if hasattr(value, "__dataclass_fields__"):
        return {
            key: _serialize(item)
            for key, item in asdict(value).items()
        }
    if isinstance(value, tuple):
        return [_serialize(item) for item in value]
    if isinstance(value, list):
        return [_serialize(item) for item in value]
    if isinstance(value, dict):
        return {key: _serialize(item) for key, item in value.items()}
    return value


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Verify a locally reconstructed ALN shard against trusted-source "
            "and quarantine constraints."
        )
    )
    parser.add_argument("input_json", type=Path)
    args = parser.parse_args()

    try:
        payload = _load_json(args.input_json)
        required = {
            "trusted_sources",
            "quarantined_artifacts",
            "reconstructed_shard",
        }
        if set(payload) != required:
            raise ValidationError(
                "Input must contain exactly trusted_sources, "
                "quarantined_artifacts, and reconstructed_shard."
            )
        if not isinstance(payload["trusted_sources"], list):
            raise ValidationError("trusted_sources must be an array.")
        if not isinstance(payload["quarantined_artifacts"], list):
            raise ValidationError(
                "quarantined_artifacts must be an array."
            )

        result = evaluate_integrity(
            [
                TrustedSource(**item)
                for item in payload["trusted_sources"]
            ],
            [
                QuarantinedArtifact(**item)
                for item in payload["quarantined_artifacts"]
            ],
            payload["reconstructed_shard"],
        )
    except (TypeError, ValidationError) as error:
        print(f"validation error: {error}", file=sys.stderr)
        return 2

    print(json.dumps(_serialize(result), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
