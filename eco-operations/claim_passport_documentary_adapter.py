# SPDX-License-Identifier: MIT OR Apache-2.0
"""Claim-scoped documentary adapter; no scientific or consent adjudication.

Dependency: existing schemas/policy_evidence_report.py, schema version 1.0.0.

Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
Credit only; no consent, authentication, or external authority.
"""

import hashlib
import json
import re

from schemas.policy_evidence_report import (
    SCHEMA_VERSION,
    FindingState,
    ValidationReport,
    build_report,
)


FORMAT = "claim-passport-documentary-adapter-v1"

CLAIM_FIELDS = frozenset({
    "claim_text",
    "intended_use",
    "boundary_reference",
    "observation_support_reference",
    "reviewed_revision_sha256",
})

MANIFEST_FIELDS = frozenset({
    "format",
    "claim",
    "obligations",
    "access_reference",
    "retention_reference",
})


def text(value):
    return type(value) is str and 0 < len(value.strip()) <= 512


def digest_text(value):
    return (
        type(value) is str
        and re.fullmatch(r"[0-9a-f]{64}", value) is not None
    )


def unique_object(pairs):
    """Reject duplicate JSON names instead of selecting the final value."""
    result = {}
    for name, value in pairs:
        if name in result:
            raise ValueError("duplicate JSON member")
        result[name] = value
    return result


def claim_value(claim):
    if not (
        type(claim) is dict
        and set(claim) == CLAIM_FIELDS
        and all(text(value) for value in claim.values())
        and digest_text(claim["reviewed_revision_sha256"])
    ):
        raise ValueError("complete bounded claim contract required")


def read_manifest(manifest_bytes, expected_sha256):
    if not (
        type(manifest_bytes) is bytes
        and 0 < len(manifest_bytes) <= 65536
        and digest_text(expected_sha256)
    ):
        raise ValueError("bounded manifest bytes and SHA-256 pin required")

    actual = hashlib.sha256(manifest_bytes).hexdigest()
    if actual != expected_sha256:
        raise ValueError("manifest commitment mismatch")

    try:
        decoded = manifest_bytes.decode("utf-8")
        manifest = json.loads(
            decoded,
            object_pairs_hook=unique_object,
        )
    except (UnicodeError, ValueError, RecursionError) as error:
        raise ValueError("unsupported manifest encoding or structure") from error

    if not (
        type(manifest) is dict
        and set(manifest) == MANIFEST_FIELDS
        and manifest["format"] == FORMAT
        and text(manifest["access_reference"])
        and text(manifest["retention_reference"])
    ):
        raise ValueError("unsupported adapter manifest")

    claim_value(manifest["claim"])

    declared = manifest["obligations"]
    if not (
        type(declared) is list
        and 0 < len(declared) <= 256
    ):
        raise ValueError("nonempty bounded obligation inventory required")

    paths = []
    for path in declared:
        if not (
            type(path) is list
            and 0 < len(path) <= 8
            and all(text(part) for part in path)
        ):
            raise ValueError("bounded documentary obligation path required")
        paths.append(tuple(path))

    if len(set(paths)) != len(paths):
        raise ValueError("duplicate manifest obligation")

    return manifest, decoded, tuple(paths), actual


def documentary_passport(
    manifest_bytes,
    expected_manifest_sha256,
    current_claim,
    submitted_report,
):
    """Construct a local documentary summary from supplied check assertions.

    This function does not execute the branch validators or authenticate
    their findings. It reconstructs documentary coverage from the manifest.
    """
    if SCHEMA_VERSION != "1.0.0":
        raise ValueError("dependency version requires separate review")
    if type(submitted_report) is not ValidationReport:
        raise ValueError("typed documentary report required")

    claim_value(current_claim)
    manifest, decoded, required_paths, actual_digest = read_manifest(
        manifest_bytes, expected_manifest_sha256
    )

    if submitted_report.binding.manifest_content != decoded:
        raise ValueError("report is not bound to the supplied manifest text")

    rebuilt = build_report(
        submitted_report.binding,
        required_paths,
        submitted_report.checks,
        submitted_report.unchecked_present_fields,
        submitted_report.forbidden_present_fields,
    )

    scope_matches = current_claim == manifest["claim"]
    coverage_matches = submitted_report.required_paths == required_paths

    if not scope_matches:
        summary = "unresolved"
    elif rebuilt.policy is FindingState.FAILED:
        summary = "incomplete"
    elif (
        not coverage_matches
        or rebuilt.policy is not FindingState.VERIFIED
    ):
        summary = "unresolved"
    else:
        summary = "complete"

    return {
        "format": FORMAT,
        "claim": dict(current_claim),
        "manifest_claim": dict(manifest["claim"]),
        "manifest_sha256": actual_digest,
        "manifest_bytes_match_expected_commitment": True,
        "manifest_origin_authenticated": False,
        "manifest_adequacy": "requires separate review",
        "claim_scope_matches": scope_matches,
        "submitted_coverage_matches_manifest": coverage_matches,
        "documentary_summary": summary,
        "summary_scope": (
            "supplied documentary checks under this adapter contract only"
        ),
        "required_paths": [list(path) for path in required_paths],
        "checks": [
            {
                "path": list(check.path),
                "state": check.state.value,
                "explanation": check.explanation,
            }
            for check in rebuilt.checks
        ],
        "issues": [
            {
                "code": issue.code.value,
                "path": list(issue.path),
                "explanation": issue.explanation,
                "correction": issue.correction,
            }
            for issue in rebuilt.issues
        ],
        "access_reference": manifest["access_reference"],
        "retention_reference": manifest["retention_reference"],
        "branch_validators_executed_by_adapter": False,
        "finding_authenticity": "not established",
        "scientific_support": "not assessed by this adapter",
        "rights_holder_decision": "not adjudicated",
        "rights_holder_process_must_be_consulted_separately": True,
        "dependency_inventory_completeness": "not assessed",
        "psychological_continuity_verified": False,
        "publication_authorized": False,
        "external_action_authorized": False,
        "ordinary_assistance_available": True,
    }
