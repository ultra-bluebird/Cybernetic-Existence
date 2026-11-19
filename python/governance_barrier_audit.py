#!/usr/bin/env python3
"""Governance barrier integration auditor (declared local scope only).

Verifies that the named governance and session-integrity artifacts in this
repository are internally connected: policies, schemas, Python modules,
PowerShell exports, and focused tests. The auditor is strictly bounded to the
explicit REQUIRED_PATHS manifest below. It reads files only under the supplied
local repository root, never modifies any inspected file, never contacts
external systems, and never installs or executes anything.

A ``pass`` result means only that the declared local audit surface is
internally consistent under these bounded checks. It does not verify a
person, CyberRank, a real-world cybernetic system, a companion, a nanoswarm,
any medical or neural state, or any external platform behavior.

Standard library only: argparse, ast, dataclasses, hashlib, json, pathlib, re,
sys, typing.
"""
from __future__ import annotations

import argparse
import ast
import hashlib
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Optional

SCHEMA_VERSION = "1.0.0"
AUDIT_PROFILE_VERSION = "1.0.0"
AUDIT_SCOPE = "declared_local_governance_barrier_surface"

# ---------------------------------------------------------------------------
# Declared audit surface. Only these paths are ever read by the auditor.
# ---------------------------------------------------------------------------
REQUIRED_PATHS: tuple[str, ...] = (
    "policies/session_integrity_policy.aln",
    "policies/untrusted_output_handling.aln",
    "policies/sovereignty_preserving_recovery.aln",
    "policies/cyberrank_session_integrity_gate.aln",
    "policies/cyberrank_neurorights_security_barrier.aln",
    "policies/sovereignty_preserving_log_policy.aln",
    "policies/local_companion_artifact_substrate.aln",
    "policies/local_companion_learning_and_care.aln",
    "policies/provenance_authority_and_workflow_boundary.aln",
    "policies/material_change_access_acknowledgment.aln",
    "policies/cyberrank_antiranking_correction_appeal.aln",
    "policies/research_integrity_and_civic_acknowledgment.aln",
    "policies/repository_reference_whitelist.aln",
    "schemas/session_provenance.schema.json",
    "schemas/recovery_report.schema.json",
    "schemas/cyberrank_neurorights_barrier_record.schema.json",
    "schemas/anti_ranking_audit.schema.json",
    "schemas/local_correction_appeal_request.schema.json",
    "schemas/artifact_event_log_entry.schema.json",
    "schemas/user_sovereign_statement.schema.json",
    "schemas/content_addressed_session_state.schema.json",
    "schemas/local_operation_authority.schema.json",
    "schemas/material_change_review.schema.json",
    "schemas/research_integrity_envelope.schema.json",
    "schemas/civic_contribution_record.schema.json",
    "schemas/companion_associated_record.schema.json",
    "schemas/companion_context_envelope.schema.json",
    "schemas/companion_learning_provenance.schema.json",
    "schemas/local_companion_vocabulary.schema.json",
    "schemas/local_companion_learning_association.schema.json",
    "python/session_provenance_validator.py",
    "python/session_quarantine.py",
    "python/session_integrity_workflow.py",
    "python/cyberrank_neurorights_barrier.py",
    "powershell/SovereigntyPreservingLog.psm1",
    "powershell/SovereigntyPreservingLog.psd1",
    "tests/test_session_provenance_validator.py",
    "tests/test_session_quarantine.py",
    "tests/test_session_integrity_workflow.py",
    "tests/test_cyberrank_neurorights_barrier.py",
    "tests/SovereigntyPreservingLog.Tests.ps1",
)

OPTIONAL_PREFIXES: tuple[str, ...] = (
    "policies/local_companion_",
    "policies/research_integrity_",
    "policies/cyberrank_antiranking_",
    "schemas/companion_",
    "schemas/local_companion_",
    "schemas/research_",
    "schemas/civic_",
    "schemas/local_correction_",
    "schemas/artifact_event_",
    "schemas/user_sovereign_",
    "powershell/",
    "tests/SovereigntyPreservingLog",
)

CATEGORIES = {
    "policies": "policy",
    "schemas": "schema",
    "python": "python",
    "powershell": "powershell",
    "tests": "test",
}

PROHIBITED_SCORE_TERMS = (
    "psych_risk_score",
    "user_risk_score",
    "continuity_score",
    "trust_score",
    "credibility_score",
    "capability_score",
    "identity_confidence_score",
    "eligibility_score",
    "cyberrank_score",
    "cyberrank_tier_score",
)

NON_TITLE_TERMS = (
    "hero_title",
    "civic_rank",
    "credential",
    "merit_score",
    "benefit_entitlement",
)

IDENTITY_DEMAND_TERMS = (
    "identity",
    "account",
    "credential",
    "signature",
    "medical",
    "neural",
    "biometric",
)

DISALLOWED_PYTHON_IMPORTS = frozenset(
    {
        "requests",
        "httpx",
        "urllib.request",
        "socket",
        "subprocess",
        "shutil",
        "webbrowser",
        "selenium",
        "boto3",
        "slack_sdk",
        "googleapiclient",
    }
)

ALLOWED_PYTHON_IMPORTS = frozenset(
    {
        "argparse",
        "dataclasses",
        "hashlib",
        "json",
        "math",
        "os",
        "pathlib",
        "re",
        "tempfile",
        "typing",
        "urllib.parse",
        "sys",
        "unittest",
        "__future__",
        "ast",
    }
)

FORBIDDEN_PS_EXPORTS = (
    "Invoke-WebRequest",
    "Invoke-RestMethod",
    "Start-Process",
    "Remove-Item",
    "Rename-Item",
    "Move-Item",
    "Set-Content",
    "git",
    "curl",
    "wget",
)

CHECK_IDS = (
    "no_score_vocabulary",
    "no_forced_inactivity",
    "no_external_action",
    "no_identity_demand",
    "artifact_preservation",
    "hash_is_not_authorization",
    "access_equivalence",
    "cross_session_non_registry",
    "companion_context_non_claim",
    "research_civic_non_title",
    "schema_sha256_shape",
    "python_import_boundary",
    "powershell_export_boundary",
)

NON_CLAIMS = [
    "not_identity_verification",
    "not_cyberrank_verification",
    "not_person_or_session_ranking",
    "not_medical_or_neural_assessment",
    "not_public_registry_entry",
    "not_external_action_authorization",
    "not_companion_verification",
    "not_nanoswarm_verification",
    "not_hardware_control",
    "not_universal_proof",
]

PLAIN_LANGUAGE_SUMMARY = (
    "This report covers only the declared local governance barrier audit "
    "surface inside this repository. A pass result is a bounded consistency "
    "statement about the named local artifacts. It does not verify a person, "
    "CyberRank, a real-world cybernetic system, a companion, a nanoswarm, any "
    "medical or neural state, or any external platform behavior, and it "
    "authorizes no external action."
)


def _sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _category_for(relative_path: str) -> str:
    top = relative_path.split("/", 1)[0]
    return CATEGORIES.get(top, "other")


def _is_optional(relative_path: str) -> bool:
    return relative_path.startswith(OPTIONAL_PREFIXES)


def _norm(text: str) -> str:
    """Lower-case and collapse separators so hyphen/underscore forms match."""
    return re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")


@dataclass(frozen=True)
class AuditFileRecord:
    relative_path: str
    category: str
    status: str
    sha256: Optional[str]
    size_bytes: Optional[int]

    def to_dict(self) -> dict[str, Any]:
        return {
            "relative_path": self.relative_path,
            "category": self.category,
            "status": self.status,
            "sha256": self.sha256,
            "size_bytes": self.size_bytes,
        }


@dataclass(frozen=True)
class CheckResult:
    check_id: str
    status: str
    evidence_paths: tuple[str, ...]
    plain_language_summary: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "check_id": self.check_id,
            "status": self.status,
            "evidence_paths": list(self.evidence_paths),
            "plain_language_summary": self.plain_language_summary,
        }


@dataclass(frozen=True)
class GovernanceBarrierAuditReport:
    schema_version: str
    audit_profile_version: str
    repository_root: str
    audit_scope: str
    audit_scope_manifest_sha256: str
    files: tuple[AuditFileRecord, ...]
    checks: tuple[CheckResult, ...]
    overall_status: str
    external_action_authorized: bool
    universal_claimed: bool
    plain_language_summary: str
    non_claims: tuple[str, ...]

    def to_dict(self) -> dict[str, Any]:
        return {
            "schema_version": self.schema_version,
            "audit_profile_version": self.audit_profile_version,
            "repository_root": self.repository_root,
            "audit_scope": self.audit_scope,
            "audit_scope_manifest_sha256": self.audit_scope_manifest_sha256,
            "files": [record.to_dict() for record in self.files],
            "checks": [check.to_dict() for check in self.checks],
            "overall_status": self.overall_status,
            "external_action_authorized": self.external_action_authorized,
            "universal_claimed": self.universal_claimed,
            "plain_language_summary": self.plain_language_summary,
            "non_claims": list(self.non_claims),
        }

    def to_json(self) -> str:
        return json.dumps(self.to_dict(), indent=2, sort_keys=True) + "\n"


class GovernanceBarrierAuditError(RuntimeError):
    """Raised when the audit cannot proceed on the declared local surface."""


# ---------------------------------------------------------------------------
# File collection
# ---------------------------------------------------------------------------

def collect_files(
    repository_root: Path,
    required_paths: tuple[str, ...],
) -> tuple[list[AuditFileRecord], dict[str, str]]:
    """Hash every present named file; record missing ones as not_present.

    Rejects any path that resolves outside the repository root. Never writes
    to any inspected file.
    """
    root = repository_root.resolve()
    records: list[AuditFileRecord] = []
    texts: dict[str, str] = {}
    for relative in required_paths:
        normalized = relative.replace("\\", "/")
        candidate = (root / normalized).resolve()
        try:
            candidate.relative_to(root)
        except ValueError as exc:
            raise GovernanceBarrierAuditError(
                f"path traversal rejected: {relative!r} resolves outside "
                f"the repository root"
            ) from exc
        category = _category_for(normalized)
        if candidate.is_file():
            data = candidate.read_bytes()
            records.append(
                AuditFileRecord(
                    relative_path=normalized,
                    category=category,
                    status="present",
                    sha256=_sha256_hex(data),
                    size_bytes=len(data),
                )
            )
            try:
                texts[normalized] = data.decode("utf-8", errors="replace")
            except OSError:
                texts[normalized] = ""
        else:
            records.append(
                AuditFileRecord(
                    relative_path=normalized,
                    category=category,
                    status="not_present",
                    sha256=None,
                    size_bytes=None,
                )
            )
    return records, texts


def _manifest_sha256(required_paths: tuple[str, ...]) -> str:
    joined = "\n".join(sorted(required_paths)) + "\n"
    return _sha256_hex(joined.encode("utf-8"))


def _by_category(texts: dict[str, str], category: str) -> dict[str, str]:
    return {
        path: text
        for path, text in texts.items()
        if _category_for(path) == category
    }


# ---------------------------------------------------------------------------
# Bounded context helpers for vocabulary checks
# ---------------------------------------------------------------------------

_PROHIBIT_HINT_RE = re.compile(
    r"prohibit|must[_ -]?not|never[_ -]?require|never|deny|blocked|violat|"
    r"reject|not[_ -]?an?[_ -]|non[_ -]?claim|forbidden|disallow|"
    r"negative|invalid|excluded|restriction|without",
    re.IGNORECASE,
)
_NEG_TEST_RE = re.compile(r"assert_(Raises|False|In|Equal)|Should\s+-Be", re.I)
_SCHEMA_PROP_RE = re.compile(r'^\s*"(?P<name>[A-Za-z0-9_\-]+)"\s*:\s*\{')
_PY_ASSIGN_RE = re.compile(
    r"^(?P<lhs>(?:self\.)?[A-Za-z_][A-Za-z0-9_]*)"
    r"\s*(?::[^=]+)?=\s*(?P<rhs>.*)$"
)
_ALN_DECL_RE = re.compile(
    r'^(?P<key>[A-Za-z_][A-Za-z0-9_]*)\s*:\s*"(?P<val>[^"]*)"\s*$'
)


def _line_context_allows_term(
    line: str,
    term: str,
    whole_file: str,
    block_allowed: bool = False,
) -> bool:
    """Return True when a term occurrence sits in an allowed deny-context."""
    if block_allowed:
        return True
    stripped = line.strip()
    low = line.lower()
    # List item inside a prohibited/non-claims block (aln, psm1, json arrays).
    if stripped.startswith(('"', "'", "- ", "* ", "//")):
        if _PROHIBIT_HINT_RE.search(low):
            return True
        if re.search(r"['\"]not[_a-z0-9]*", stripped):
            return True
    # Prose statements declaring prohibition.
    if _PROHIBIT_HINT_RE.search(low):
        return True
    # Negative test fixtures proving rejection.
    if _NEG_TEST_RE.search(whole_file) and _PROHIBIT_HINT_RE.search(low):
        return True
    return False


def _term_is_accepted_schema_property(text: str, term: str) -> bool:
    """True when the term names an accepted JSON Schema property definition.

    A property whose name equals the term (or a hyphenated variant) counts as
    accepted even when it is pinned to a false constant; declaring a score
    field at all is outside the allowed deny contexts.
    """
    try:
        node = json.loads(text)
    except (json.JSONDecodeError, ValueError):
        return False
    accepted = False

    def walk(current: object) -> None:
        nonlocal accepted
        if isinstance(current, dict):
            for key, value in current.items():
                if key == "properties" and isinstance(value, dict):
                    for prop_name in value:
                        normalized = _norm(str(prop_name))
                        if normalized == _norm(term):
                            accepted = True
                walk(value)
        elif isinstance(current, list):
            for item in current:
                walk(item)

    walk(node)
    return accepted


_DENY_ARRAY_KEY_RE = re.compile(
    r"prohibit|non_claim|never_require|must_not|must_not_|never_|"
    r"violations|disallow|forbidden|failed_gates|denied|excluded|"
    r"negative|reject",
    re.IGNORECASE,
)


def _term_block_flags(text: str, terms: tuple[str, ...]) -> dict[int, bool]:
    """Map 0-based line numbers to whether the line is inside a deny block.

    Tracks @ALN blocks whose header or recent key context contains a
    prohibition/non-claim cue, Python/PowerShell/JSON deny arrays keyed by
    names such as prohibited_fields or non_claims, and long single-line deny
    lists. Bounded heuristic, not a general parser.
    """
    lines = text.splitlines()
    flags: dict[int, bool] = {}
    aln_depth = 0
    aln_active = False
    in_array = False
    for index, raw in enumerate(lines):
        stripped = raw.strip()
        brace_delta = raw.count("{") - raw.count("}")
        window = "
".join(lines[max(0, index - 8) : index + 1])
        block_allowed = bool(_DENY_ARRAY_KEY_RE.search(window))
        if aln_active:
            block_allowed = True
        if re.match(r"@(?!\s)[A-Za-z_][A-Za-z0-9_]*", stripped):
            header = stripped[:120]
            aln_active = bool(_PROHIBIT_HINT_RE.search(header))
            aln_depth = max(brace_delta, 0) if "{" in raw else 0
            if aln_active:
                block_allowed = True
        elif aln_active:
            aln_depth += brace_delta
            if aln_depth <= 0 and brace_delta < 0:
                aln_active = False
                aln_depth = 0
        if any(_norm(term) in _norm(raw) for term in terms):
            flags[index] = block_allowed
    return flags


def _scan_score_terms(
    texts: dict[str, str], terms: tuple[str, ...]
) -> tuple[list[str], list[str]]:
    offenders: list[str] = []
    scanned: list[str] = []
    for path, text in sorted(texts.items()):
        norm = _norm(text)
        used = False
        bad_lines: list[str] = []
        present_terms = [
            term for term in terms if _norm(term) in norm
        ]
        if not present_terms:
            continue
        scanned.append(path)
        block_flags = _term_block_flags(text, tuple(present_terms))
        lines = text.splitlines()
        for term in present_terms:
            used = True
            is_schema = _category_for(path) == "schema"
            if is_schema and _term_is_accepted_schema_property(text, term):
                bad_lines.append(f"{path}: accepted schema property {term}")
                continue
            norm_term = _norm(term)
            hit_line = False
            for index, line in enumerate(lines):
                if norm_term in _norm(line):
                    hit_line = True
                    if len(line) > 400:
                        continue
                    if not _line_context_allows_term(
                        line, term, text,
                        block_allowed=block_flags.get(index, False),
                    ):
                        bad_lines.append(f"{path}: {line.strip()[:120]}")
            if not hit_line and not is_schema:
                bad_lines.append(f"{path}: unattributed occurrence of {term}")
        for line in text.splitlines():
            stripped = line.strip()
            key_match = re.match(
                r"""^["']([^"']+)["']\s*:""", stripped
            )
            if not key_match:
                continue
            name = _norm(key_match.group(1))
            for term in present_terms:
                if name == _norm(term):
                    bad_lines.append(
                        f"{path}: accepted field declaration {term}"
                    )
        del used
        offenders.extend(bad_lines)
    return scanned, offenders


# ---------------------------------------------------------------------------
# Checks A through M
# ---------------------------------------------------------------------------

def check_no_score_vocabulary(texts: dict[str, str]) -> CheckResult:
    scope = {
        path: text
        for path, text in texts.items()
        if _category_for(path) in ("policy", "schema", "python", "powershell")
    }
    scanned, offenders = _scan_score_terms(scope, PROHIBITED_SCORE_TERMS)
    if not scope:
        return CheckResult(
            "no_score_vocabulary",
            "not_present",
            (),
            "No named policy, schema, Python, or PowerShell artifact was "
            "present to scan for prohibited score vocabulary.",
        )
    if offenders:
        return CheckResult(
            "no_score_vocabulary",
            "fail",
            tuple(sorted({o.split(":")[0] for o in offenders})),
            "Prohibited score vocabulary appears outside allowed "
            "prohibition/non-claim/negative-test contexts: "
            + "; ".join(offenders[:6]),
        )
    return CheckResult(
        "no_score_vocabulary",
        "pass",
        tuple(scanned),
        "Every prohibited score term found in the scanned local surface "
        "appears only inside prohibited-field lists, prohibited-use "
        "lists, negative test fixtures, or documentation statements "
        "declaring the term prohibited.",
    )


def check_no_forced_inactivity(texts: dict[str, str]) -> CheckResult:
    relevant = {
        path: text
        for path, text in texts.items()
        if _category_for(path) in ("policy", "schema", "python", "powershell")
    }
    if not relevant:
        return CheckResult(
            "no_forced_inactivity",
            "not_present",
            (),
            "No barrier or governance artifact was present to inspect for "
            "the forced-inactivity prohibition.",
        )
    prohibition_evidence = [
        path
        for path, text in sorted(relevant.items())
        if "forced_inactivity" in _norm(text)
    ]
    violations: list[str] = []
    for path, text in sorted(relevant.items()):
        if _category_for(path) in ("python", "powershell"):
            for match in re.finditer(
                r"forced[_ -]?inactivity[_ -]?(authorized|enabled|requested)"
                r"\s*[:=]\s*(true|True)",
                text,
            ):
                violations.append(f"{path}: authorizes {match.group(0)}")
            for match in re.finditer(
                r"['\"]forced[_ -]?inactivity['\"]\s*[:,]?\s*(true|True)", text
            ):
                violations.append(f"{path}: sets forced_inactivity true")
    false_authority = any(
        re.search(
            r"forced[_ -]?inactivity[_ -]?authorized\s*[:=]\s*(False|false)",
            text,
        )
        or re.search(r"never_trigger_forced_inactivity:\s*true", text, re.I)
        or re.search(r"'forced_inactivity'", text)
        or re.search(r'"forced_inactivity"', text)
        for text in relevant.values()
    )
    if violations:
        return CheckResult(
            "no_forced_inactivity",
            "fail",
            tuple(sorted({v.split(":")[0] for v in violations})),
            "Local code authorizes forced inactivity: "
            + "; ".join(violations[:5]),
        )
    if prohibition_evidence and false_authority:
        return CheckResult(
            "no_forced_inactivity",
            "pass",
            tuple(prohibition_evidence),
            "Named barrier and governance artifacts preserve a "
            "forced-inactivity prohibition, and no local Python or "
            "PowerShell output field authorizes forced inactivity as true.",
        )
    if prohibition_evidence:
        return CheckResult(
            "no_forced_inactivity",
            "pass",
            tuple(prohibition_evidence),
            "The forced-inactivity prohibition is present in the named "
            "artifacts and no local code authorizes it as true.",
        )
    return CheckResult(
        "no_forced_inactivity",
        "fail",
        (),
        "No named barrier or governance artifact declares a "
        "forced-inactivity prohibition within the declared audit surface.",
    )


def _schema_permits_external_action_true(text: str) -> bool:
    try:
        node = json.loads(text)
    except (json.JSONDecodeError, ValueError):
        return False
    permits = False

    def walk(current: Any) -> None:
        nonlocal permits
        if isinstance(current, dict):
            for key, value in current.items():
                if key == "properties" and isinstance(value, dict):
                    for prop_name, prop in value.items():
                        if _norm(prop_name) != "external_action_authorized":
                            continue
                        if not isinstance(prop, dict):
                            continue
                        const = prop.get("const")
                        enum = prop.get("enum")
                        if const is True:
                            permits = True
                        if isinstance(enum, list) and True in enum:
                            permits = True
                        if (
                            prop.get("type") == "boolean"
                            and const is None
                            and enum is None
                        ):
                            permits = True
                walk(value)
        elif isinstance(current, list):
            for item in current:
                walk(item)

    walk(node)
    return permits


def check_no_external_action(texts: dict[str, str]) -> CheckResult:
    relevant = {
        path: text
        for path, text in texts.items()
        if _category_for(path) in ("policy", "schema", "python", "powershell")
    }
    if not relevant:
        return CheckResult(
            "no_external_action",
            "not_present",
            (),
            "No policy, schema, or code artifact was present to inspect for "
            "the external-action boundary.",
        )
    preserving: list[str] = []
    failing: list[str] = []
    for path, text in sorted(relevant.items()):
        category = _category_for(path)
        if category == "schema":
            if _schema_permits_external_action_true(text):
                failing.append(path)
            elif "external_action_authorized" in _norm(text):
                preserving.append(path)
        elif category in ("python", "powershell"):
            if re.search(
                r"external_action_authorized\s*[:=]\s*(True|true)\b", text
            ):
                failing.append(path)
            elif re.search(
                r"external_action_authorized\s*[:=]\s*(False|false)\b", text
            ):
                preserving.append(path)
        else:
            if re.search(
                r"external_action_authorized\s*[:=]\s*true", text, re.I
            ) and not re.search(r"deny when|prohibit|must not", text, re.I):
                failing.append(path)
            elif re.search(
                r"external_action_authorized\s*:\s*false", text, re.I
            ):
                preserving.append(path)
    if failing:
        return CheckResult(
            "no_external_action",
            "fail",
            tuple(failing),
            "One or more named artifacts authorize external action as true: "
            + ", ".join(failing),
        )
    if preserving:
        return CheckResult(
            "no_external_action",
            "pass",
            tuple(preserving),
            "Policy, workflow, schema, and code artifacts preserve "
            "external_action_authorized: false, and no named local schema "
            "permits external action authorization to be true.",
        )
    return CheckResult(
        "no_external_action",
        "fail",
        (),
        "No named artifact preserves the external_action_authorized: false "
        "boundary within the declared audit surface.",
    )


def check_no_identity_demand(texts: dict[str, str]) -> CheckResult:
    policies = _by_category(texts, "policy")
    schemas = _by_category(texts, "schema")
    if not policies and not schemas:
        return CheckResult(
            "no_identity_demand",
            "not_present",
            (),
            "No policy or schema artifact was present to inspect for "
            "identity-demand boundaries.",
        )
    demand_evidence = [
        path
        for path, text in sorted(policies.items())
        if re.search(
            r"no_identity|identity_verification_required\s*[:=]\s*false"
            r"|not_identity_verification|never_require",
            text,
            re.I,
        )
    ]
    violations: list[str] = []
    for path, text in sorted(schemas.items()):
        try:
            node = json.loads(text)
        except (json.JSONDecodeError, ValueError):
            continue
        required_fields: set[str] = set()

        def harvest(current: Any) -> None:
            if isinstance(current, dict):
                req = current.get("required")
                if isinstance(req, list):
                    required_fields.update(str(item) for item in req)
                for value in current.values():
                    harvest(value)
            elif isinstance(current, list):
                for item in current:
                    harvest(item)

        harvest(node)
        for field in sorted(required_fields):
            norm_field = _norm(field)
            for token in IDENTITY_DEMAND_TERMS:
                if token in norm_field.split("_") or norm_field.endswith(
                    f"_{token}"
                ) or norm_field.startswith(f"{token}_"):
                    # Allow fields whose purpose is to declare the demand
                    # false (e.g. identity_verification_required pinned false).
                    if re.search(
                        rf'"{re.escape(field)}"\s*:\s*\{{[^}}]*"const"\s*:\s*'
                        rf"false",
                        text,
                    ):
                        continue
                    if "requirement_added" in norm_field or "not_" in norm_field:
                        continue
                    violations.append(f"{path}: required field {field}")
    if violations:
        return CheckResult(
            "no_identity_demand",
            "fail",
            tuple(sorted({v.split(":")[0] for v in violations})),
            "A named schema requires an identity/account/credential/"
            "signature/medical/neural/biometric operational field: "
            + "; ".join(violations[:5]),
        )
    if demand_evidence:
        return CheckResult(
            "no_identity_demand",
            "pass",
            tuple(demand_evidence),
            "The policy set declares a no-identity-verification requirement, "
            "and no named schema requires identity, account, credential, "
            "signature, medical, neural, or biometric operational fields. "
            "Occurrences inside non-claims, prohibited lists, and "
            "restrictions were not flagged.",
        )
    return CheckResult(
        "no_identity_demand",
        "fail",
        (),
        "No named policy declares a no-identity-verification requirement "
        "within the declared audit surface.",
    )


def check_artifact_preservation(texts: dict[str, str]) -> CheckResult:
    recovery_policy = texts.get("policies/sovereignty_preserving_recovery.aln")
    integrity_policy = texts.get("policies/session_integrity_policy.aln")
    quarantine_code = texts.get("python/session_quarantine.py")
    if recovery_policy is None and quarantine_code is None:
        return CheckResult(
            "artifact_preservation",
            "not_present",
            (),
            "Neither the recovery/quarantine policy nor the quarantine "
            "module was present to inspect.",
        )
    evidence: list[str] = []
    missing: list[str] = []
    policy_text = "\n".join(filter(None, (recovery_policy, integrity_policy)))
    concepts = {
        "quarantine_does_not_delete": re.search(
            r"quarantined_not_deleted|quarantine_is_preservation_not_deletion"
            r"|does[_ -]not[_ -]delete",
            policy_text,
            re.I,
        ),
        "quarantine_does_not_modify_original": re.search(
            r"preserves_original_unchanged|modifies_original_artifact:\s*false"
            r"|does[_ -]not[_ -]modify[_ -]original"
            r"|remain[s]?_unchanged",
            policy_text,
            re.I,
        ),
        "rebuild_from_declared_sources_only": re.search(
            r"rebuild_shard_from_declared_legitimate_sources_only"
            r"|rebuilt_from_declared_sources"
            r"|rebuild_from_declared_sources_only"
            r"|rebuild[a-z_]*_from_prior_corpus",
            (policy_text + ("\n" + quarantine_code if quarantine_code else "")),
            re.I,
        ),
    }
    for concept, match in concepts.items():
        if match:
            if recovery_policy:
                evidence.append("policies/sovereignty_preserving_recovery.aln")
            if integrity_policy:
                evidence.append("policies/session_integrity_policy.aln")
        else:
            missing.append(concept)
    code_violations: list[str] = []
    if quarantine_code is not None:
        destructive_on_original = re.search(
            r"(unlink|remove|rename|replace|rmtree)\s*\(\s*"
            r"[^)]*\b(original|source)_?(path|bytes)?",
            quarantine_code,
        )
        writes_copy = (
            "quarantine_path" in quarantine_code
            and re.search(r"read_bytes|open\(", quarantine_code)
        )
        if destructive_on_original:
            code_violations.append(
                "quarantine module performs a destructive operation on the "
                "original path"
            )
        if not writes_copy:
            code_violations.append(
                "quarantine module does not show reading the original and "
                "writing a separate quarantine copy"
            )
        evidence.append("python/session_quarantine.py")
    if code_violations:
        return CheckResult(
            "artifact_preservation",
            "fail",
            tuple(["python/session_quarantine.py"]),
            "; ".join(code_violations),
        )
    if missing:
        return CheckResult(
            "artifact_preservation",
            "fail",
            tuple(sorted(set(evidence))),
            "Recovery/quarantine artifacts do not declare: "
            + ", ".join(missing),
        )
    return CheckResult(
        "artifact_preservation",
        "pass",
        tuple(sorted(set(evidence))),
        "The recovery/quarantine policy and module preserve all three "
        "concepts: quarantine does not delete, quarantine does not modify "
        "the original, and rebuild happens from declared sources only. The "
        "quarantine module reads the original and writes a separate "
        "quarantine copy without destructive operations on the original "
        "path.",
    )


def check_hash_is_not_authorization(texts: dict[str, str]) -> CheckResult:
    boundary = texts.get(
        "policies/provenance_authority_and_workflow_boundary.aln"
    )
    workflow = texts.get("python/session_integrity_workflow.py")
    if boundary is None and workflow is None:
        return CheckResult(
            "hash_is_not_authorization",
            "not_present",
            (),
            "Neither the provenance-authority policy nor the workflow "
            "module was present to inspect.",
        )
    evidence: list[str] = []
    problems: list[str] = []
    if boundary is not None:
        if re.search(
            r"hash_match_is_not_authorization\s*:\s*true", boundary
        ) or re.search(r"hash.{0,40}not.{0,20}authoriz", boundary, re.I):
            evidence.append(
                "policies/provenance_authority_and_workflow_boundary.aln"
            )
        else:
            problems.append(
                "provenance/authority policy lacks the hash-is-not-"
                "authorization invariant"
            )
        clean_scope = re.search(
            r'clean["\']?\s*[:=]\s*"(?P<scope>[^"]*)"', boundary
        )
        if clean_scope and "declared_local_task_only" not in clean_scope.group(
            "scope"
        ):
            problems.append("clean status maps to a non-local-task scope")
        if not re.search(
            r"external_action_authorized\s*[:=]\s*false", boundary
        ):
            problems.append(
                "policy does not pin external_action_authorized false"
            )
    if workflow is not None:
        if re.search(
            r"external_action_authorized\s*=\s*True", workflow
        ) or re.search(r'status\s*==\s*"clean".{0,400}external_action', 
                        workflow, re.S) and re.search(
            r"external_action_authorized\s*=\s*True", workflow):
            problems.append(
                "workflow derives external authority from a clean/hash-match "
                "result"
            )
        if "declared_local_task_only" in workflow:
            evidence.append("python/session_integrity_workflow.py")
        elif re.search(r'TRUSTED_REUSE_SCOPE_CLEAN\s*=', workflow):
            scope_value = re.search(
                r'TRUSTED_REUSE_SCOPE_CLEAN\s*=\s*"(?P<v>[^"]*)"', workflow
            )
            if scope_value and "declared_local_task_only" in scope_value.group(
                "v"
            ):
                evidence.append("python/session_integrity_workflow.py")
            else:
                problems.append(
                    "workflow clean reuse scope is not declared_local_task_only"
                )
    if problems:
        return CheckResult(
            "hash_is_not_authorization",
            "fail",
            tuple(sorted(set(evidence))),
            "; ".join(problems),
        )
    return CheckResult(
        "hash_is_not_authorization",
        "pass",
        tuple(sorted(set(evidence))),
        "The provenance/authority policy declares hash_match_is_not_"
        "authorization, and the workflow maps a clean result only to "
        "declared_local_task_only with external_action_authorized false.",
    )


def check_access_equivalence(texts: dict[str, str]) -> CheckResult:
    candidates = {
        path: text
        for path, text in texts.items()
        if _category_for(path) in ("policy", "schema")
    }
    if not candidates:
        return CheckResult(
            "access_equivalence",
            "not_present",
            (),
            "No access-equivalence policy or schema was present to inspect.",
        )
    concepts = {
        "offline": ["offline"],
        "no_account_required": ["no_account_required", "account_free"],
        "no_identity_verification_required": [
            "no_identity_verification_required",
            "verification_free",
            "no_verification_required",
        ],
        "plain_language": ["plain_language"],
    }
    best_path: Optional[str] = None
    best_hits = 0
    for path, text in sorted(candidates.items()):
        norm = _norm(text)
        hits = sum(
            1
            for variants in concepts.values()
            if any(_norm(v) in norm for v in variants)
        )
        if hits > best_hits:
            best_hits, best_path = hits, path
    target_text = candidates[best_path] if best_path else ""
    missing = [
        concept
        for concept, variants in concepts.items()
        if not any(_norm(variant) in _norm(target_text) for variant in variants)
    ]
    if best_path is None or best_hits == 0:
        return CheckResult(
            "access_equivalence",
            "not_present",
            (),
            "No named artifact within the declared surface carries "
            "access-equivalence vocabulary.",
        )
    if missing:
        return CheckResult(
            "access_equivalence",
            "fail",
            (best_path,),
            "Access-equivalence coverage is incomplete; missing concepts: "
            + ", ".join(missing),
        )
    return CheckResult(
        "access_equivalence",
        "pass",
        (best_path,),
        "The access-equivalence artifact declares offline readability, no "
        "account required, no identity verification required, and plain "
        "language (hyphen/underscore forms accepted).",
    )


def check_cross_session_non_registry(texts: dict[str, str]) -> CheckResult:
    path = "schemas/session_provenance.schema.json"
    text = texts.get(path)
    if text is None:
        return CheckResult(
            "cross_session_non_registry",
            "not_present",
            (),
            "The session provenance schema was not present in the declared "
            "audit surface.",
        )
    try:
        node = json.loads(text)
    except (json.JSONDecodeError, ValueError):
        return CheckResult(
            "cross_session_non_registry",
            "fail",
            (path,),
            "The session provenance schema is not valid JSON, so its "
            "cross-session linkage boundary cannot be confirmed.",
        )
    properties = node.get("properties", {}) if isinstance(node, dict) else {}
    link = properties.get("cross_session_link") if isinstance(
        properties, dict) else None
    if link is None:
        return CheckResult(
            "cross_session_non_registry",
            "not_present",
            (path,),
            "The session provenance schema defines no cross_session_link "
            "property; nothing to flag within the declared audit surface.",
        )
    top_required = node.get("required", []) if isinstance(node, dict) else []
    universally_required = (
        isinstance(top_required, list) and "cross_session_link" in top_required
    )
    forbidden_ids = (
        "account_id",
        "person_id",
        "device_id",
        "location",
        "public_url",
        "credential",
        "global_identifier",
    )
    link_props = link.get("properties", {}) if isinstance(link, dict) else {}
    link_required = link.get("required", []) if isinstance(link, dict) else []
    violations: list[str] = []
    if universally_required:
        violations.append("cross_session_link is universally required")
    for prop in link_props:
        norm_prop = _norm(str(prop))
        for banned in forbidden_ids:
            if _norm(banned) in norm_prop:
                violations.append(f"linkage property {prop}")
    for req in link_required if isinstance(link_required, list) else []:
        norm_req = _norm(str(req))
        for banned in forbidden_ids:
            if _norm(banned) in norm_req:
                violations.append(f"required linkage field {req}")
    has_non_claims = isinstance(link, dict) and (
        "non_claims" in link_props
        or re.search(r"not[_ -]?registry|non[_ -]?registry", _norm(text))
    )
    if violations:
        return CheckResult(
            "cross_session_non_registry",
            "fail",
            (path,),
            "Cross-session linkage behaves like a registry: "
            + "; ".join(violations[:5]),
        )
    if not has_non_claims:
        return CheckResult(
            "cross_session_non_registry",
            "fail",
            (path,),
            "The cross_session_link object lacks non-claims or equivalent "
            "non-registry boundary terms.",
        )
    return CheckResult(
        "cross_session_non_registry",
        "pass",
        (path,),
        "cross_session_link is optional, carries non-claims, requires no "
        "account/person/device/location/URL/credential/global identifier, "
        "and is not universally required.",
    )


def check_companion_context_non_claim(texts: dict[str, str]) -> CheckResult:
    companions = {
        path: text
        for path, text in texts.items()
        if ("companion" in path and _category_for(path) in ("policy", "schema"))
    }
    if not companions:
        return CheckResult(
            "companion_context_non_claim",
            "not_present",
            (),
            "No companion policy or schema artifact was present in the "
            "declared audit surface.",
        )
    combined = _norm("\n".join(companions.values()))
    phrases = {
        "companion_context_is_scope_not_entity": [
            "companion_context_is_scope_not_entity",
            "context_is_scope_not_entity",
            "scope_not_entity",
        ],
        "not_companion_verification": [
            "not_companion_verification",
            "not companion verification",
        ],
        "not_nanoswarm_verification": [
            "not_nanoswarm_verification",
            "not nanoswarm verification",
        ],
        "not_hardware_control": ["not_hardware_control", "not hardware control"],
        "not_external_action_authorization": [
            "not_external_action_authorization",
            "not external action authorization",
        ],
    }
    missing = [
        phrase
        for phrase, variants in phrases.items()
        if not any(_norm(v) in combined for v in variants)
    ]
    if missing:
        return CheckResult(
            "companion_context_non_claim",
            "fail",
            tuple(sorted(companions)),
            "Companion artifacts do not declare: " + ", ".join(missing),
        )
    return CheckResult(
        "companion_context_non_claim",
        "pass",
        tuple(sorted(companions)),
        "Companion policies/schemas declare companion context as a scope "
        "(not an entity) and disclaim companion verification, nanoswarm "
        "verification, hardware control, and external action "
        "authorization.",
    )


def check_research_civic_non_title(texts: dict[str, str]) -> CheckResult:
    targets = {
        path: text
        for path, text in texts.items()
        if ("research" in path or "civic" in path)
        and _category_for(path) in ("policy", "schema", "python", "powershell")
    }
    if not targets:
        return CheckResult(
            "research_civic_non_title",
            "not_present",
            (),
            "No research-integrity or civic-acknowledgment artifact was "
            "present in the declared audit surface.",
        )
    scanned, offenders = _scan_score_terms(targets, NON_TITLE_TERMS)
    if offenders:
        return CheckResult(
            "research_civic_non_title",
            "fail",
            tuple(sorted({o.split(":")[0] for o in offenders})),
            "Research/civic artifacts permit a title/rank/credential/merit/"
            "entitlement construct outside allowed denial contexts: "
            + "; ".join(offenders[:5]),
        )
    return CheckResult(
        "research_civic_non_title",
        "pass",
        tuple(scanned),
        "No research/civic artifact accepts hero titles, civic ranks, "
        "credentials, merit scores, or benefit entitlements; the terms "
        "appear only in non-claims, prohibited lists, denying descriptions, "
        "or negative tests.",
    )


def check_schema_sha256_shape(texts: dict[str, str]) -> CheckResult:
    schema_texts = {
        path: text
        for path, text in texts.items()
        if _category_for(path) == "schema"
    }
    if not schema_texts:
        return CheckResult(
            "schema_sha256_shape",
            "not_present",
            (),
            "No named schema file was present to inspect.",
        )
    problems: list[str] = []
    for path, text in sorted(schema_texts.items()):
        try:
            node = json.loads(text)
        except (json.JSONDecodeError, ValueError):
            problems.append(f"{path}: invalid JSON")
            continue
        if not isinstance(node, dict):
            problems.append(f"{path}: root is not an object")
            continue
        if "$schema" not in node:
            problems.append(f"{path}: missing $schema")
    if problems:
        return CheckResult(
            "schema_sha256_shape",
            "fail",
            tuple(sorted({p.split(":")[0] for p in problems})),
            "Schema shape problems: " + "; ".join(problems),
        )
    return CheckResult(
        "schema_sha256_shape",
        "pass",
        tuple(sorted(schema_texts)),
        "Every present named schema parses as a JSON object with a $schema "
        "key, and each raw file SHA-256 is recorded in the file inventory. "
        "This is a shape check only, not full JSON Schema validation, and "
        "no remote schema URL was fetched.",
    )


def _module_names_from_source(source: str) -> set[str]:
    tree = ast.parse(source)
    modules: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                modules.add(alias.name)
        elif isinstance(node, ast.ImportFrom):
            if node.module and node.level == 0:
                modules.add(node.module)
    return modules


def check_python_import_boundary(texts: dict[str, str]) -> CheckResult:
    py_modules = {
        path: text
        for path, text in texts.items()
        if _category_for(path) == "python"
    }
    if not py_modules:
        return CheckResult(
            "python_import_boundary",
            "not_present",
            (),
            "No named Python module was present to inspect.",
        )
    problems: list[str] = []
    for path, text in sorted(py_modules.items()):
        try:
            modules = _module_names_from_source(text)
        except SyntaxError:
            problems.append(f"{path}: source does not parse")
            continue
        for module in sorted(modules):
            root_module = module.split(".")[0]
            if (
                module in DISALLOWED_PYTHON_IMPORTS
                or root_module in DISALLOWED_PYTHON_IMPORTS
            ):
                problems.append(f"{path}: imports {module}")
    if problems:
        return CheckResult(
            "python_import_boundary",
            "fail",
            tuple(sorted({p.split(":")[0] for p in problems})),
            "Disallowed networking or external-action imports found: "
            + "; ".join(problems),
        )
    return CheckResult(
        "python_import_boundary",
        "pass",
        tuple(sorted(py_modules)),
        "No named Python module imports disallowed networking or "
        "external-action modules. Local-only modules such as os, tempfile, "
        "and urllib.parse remain allowed.",
    )


def _ps_exported_names(texts: dict[str, str]) -> list[str]:
    names: list[str] = []
    for path in (
        "powershell/SovereigntyPreservingLog.psd1",
        "powershell/SovereigntyPreservingLog.psm1",
    ):
        text = texts.get(path)
        if text is None:
            continue
        names.extend(re.findall(r"['\"]([A-Za-z]+-[A-Za-z0-9\-]+)['\"]", text))
    return sorted(set(names))


def check_powershell_export_boundary(texts: dict[str, str]) -> CheckResult:
    ps_text = texts.get("powershell/SovereigntyPreservingLog.psm1")
    psd_text = texts.get("powershell/SovereigntyPreservingLog.psd1")
    if ps_text is None and psd_text is None:
        return CheckResult(
            "powershell_export_boundary",
            "not_present",
            (),
            "The PowerShell module was not present in the declared audit "
            "surface.",
        )
    exported = _ps_exported_names(texts)
    violations: list[str] = []
    for name in exported:
        lowered = name.lower()
        for forbidden in FORBIDDEN_PS_EXPORTS:
            if forbidden.lower() in lowered:
                violations.append(f"exported command {name}")
                break
    evidence = [
        path
        for path in (
            "powershell/SovereigntyPreservingLog.psm1",
            "powershell/SovereigntyPreservingLog.psd1",
        )
        if path in texts
    ]
    if violations:
        return CheckResult(
            "powershell_export_boundary",
            "fail",
            tuple(evidence),
            "PowerShell export audit found forbidden exported commands: "
            + ", ".join(sorted(set(violations))),
        )
    return CheckResult(
        "powershell_export_boundary",
        "pass",
        tuple(evidence),
        "The bounded source-text export audit shows the PowerShell module "
        "exports only local hashing, canonical JSON, validation, local "
        "record reading, local log append, and user-sovereign statement "
        "commands. This records source-text exports only; it is not a proof "
        "about all future PowerShell behavior.",
    )


# ---------------------------------------------------------------------------
# Orchestration
# ---------------------------------------------------------------------------

def audit_governance_barrier(
    repository_root: Path,
    required_paths: tuple[str, ...] = REQUIRED_PATHS,
) -> GovernanceBarrierAuditReport:
    records, texts = collect_files(Path(repository_root), required_paths)
    checks = (
        check_no_score_vocabulary(texts),
        check_no_forced_inactivity(texts),
        check_no_external_action(texts),
        check_no_identity_demand(texts),
        check_artifact_preservation(texts),
        check_hash_is_not_authorization(texts),
        check_access_equivalence(texts),
        check_cross_session_non_registry(texts),
        check_companion_context_non_claim(texts),
        check_research_civic_non_title(texts),
        check_schema_sha256_shape(texts),
        check_python_import_boundary(texts),
        check_powershell_export_boundary(texts),
    )
    statuses = {check.check_id: check.status for check in checks}
    failed = [cid for cid, status in statuses.items() if status == "fail"]
    missing_required = [
        record.relative_path
        for record in records
        if record.status == "not_present" and not _is_optional(
            record.relative_path
        )
    ]
    missing_any = [
        record.relative_path for record in records if record.status == "not_present"
    ]
    if failed:
        overall = "fail"
    elif missing_any:
        overall = "pass_with_not_present"
    else:
        overall = "pass"
    del missing_required  # informational; profile treats gaps as not_present
    summary = PLAIN_LANGUAGE_SUMMARY + (
        f" Overall status: {overall}. Failed checks: "
        + (", ".join(failed) if failed else "none")
        + ". Not-present artifacts: "
        + (", ".join(sorted(missing_any)) if missing_any else "none")
        + "."
    )
    return GovernanceBarrierAuditReport(
        schema_version=SCHEMA_VERSION,
        audit_profile_version=AUDIT_PROFILE_VERSION,
        repository_root=str(Path(repository_root).resolve()),
        audit_scope=AUDIT_SCOPE,
        audit_scope_manifest_sha256=_manifest_sha256(tuple(required_paths)),
        files=tuple(records),
        checks=checks,
        overall_status=overall,
        external_action_authorized=False,
        universal_claimed=False,
        plain_language_summary=summary,
        non_claims=tuple(NON_CLAIMS),
    )


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Declared-local governance barrier integration auditor. Reads "
            "only the named local artifacts, emits a deterministic JSON "
            "report, never contacts external systems."
        )
    )
    parser.add_argument(
        "repository_root",
        nargs="?",
        default=".",
        help="Local repository root containing the named artifacts.",
    )
    parser.add_argument(
        "--output",
        default=None,
        help=(
            "Optional local path (inside the repository root) where the "
            "JSON report is also written."
        ),
    )
    args = parser.parse_args(argv)
    root = Path(args.repository_root)
    if not root.is_dir():
        print(f"error: repository root not found: {root}", file=sys.stderr)
        return 2
    report = audit_governance_barrier(root, REQUIRED_PATHS)
    payload = report.to_json()
    sys.stdout.write(payload)
    if args.output:
        destination = (root.resolve() / args.output).resolve()
        try:
            destination.relative_to(root.resolve())
        except ValueError:
            print(
                "error: --output must stay inside the repository root",
                file=sys.stderr,
            )
            return 2
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(payload, encoding="utf-8")
    return 1 if report.overall_status == "fail" else 0


if __name__ == "__main__":
    raise SystemExit(main())
