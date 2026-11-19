"""Local CyberRank and neuro-rights security-barrier evaluator.

Evaluates declared local policy conditions only. It does not inspect, infer,
verify, monitor, control, diagnose, or operate any real-world person, neural
system, medical system, cybernetic system, companion system, nanoswarm, device,
institution, account, or external service.

The module is local-only, standard-library-only, SHA-256-compatible, non-ranking,
and non-actuating. It never performs network access or external action.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
import argparse
import json
from pathlib import Path
import sys
from typing import Any


POLICY_VERSION = "1.0.0"
SCHEMA_VERSION = "1.0.0"

PROHIBITED_FIELDS = frozenset(
    {
        "psych_risk_score",
        "user_risk_score",
        "continuity_score",
        "credibility_score",
        "trust_score",
        "capability_score",
        "identity_confidence_score",
        "compliance_score",
        "eligibility_score",
        "cyberrank_score",
        "cyberrank_tier_score",
        "public_status",
    }
)

MATERIAL_CHANGE_TRIGGERS = frozenset(
    {
        "network_dependency_added",
        "account_requirement_added",
        "identity_verification_requirement_added",
        "private_disclosure_requirement_added",
        "score_or_ranking_field_added",
        "external_action_route_added",
        "external_notification_route_added",
        "repository_modification_route_added",
        "offline_access_reduced",
        "quarantine_preservation_weakened",
        "recovery_source_rule_weakened",
        "correction_or_appeal_access_reduced",
        "accessibility_commitment_reduced",
    }
)

NON_CLAIMS = (
    "not_a_public_status",
    "not_identity_verification",
    "not_cyberrank_verification",
    "not_eligibility_determination",
    "not_diagnosis",
    "not_certification",
    "not_medical_assessment",
    "not_neural_assessment",
    "not_biometric_assessment",
    "not_real_world_system_monitoring",
    "not_real_world_system_control",
    "not_authorization_for_external_action",
    "not_authorization_for_external_notification",
    "not_person_or_system_ranking",
)


@dataclass(frozen=True)
class BarrierInput:
    offline_access_available: bool
    artifact_preservation_available: bool
    integrity_status: str
    material_change_review_current: bool
    declared_fields: tuple[str, ...]
    external_action_requested: bool
    external_notification_requested: bool
    identity_verification_requested: bool
    private_system_disclosure_requested: bool
    forced_inactivity_requested: bool


@dataclass(frozen=True)
class BarrierResult:
    schema_version: str
    policy_version: str
    authority_scope: str
    security_barrier_status: str
    external_action_authorized: bool
    external_notification_authorized: bool
    identity_verification_required: bool
    private_system_disclosure_required: bool
    scoring_or_ranking_present: bool
    forced_inactivity_authorized: bool
    offline_access_status: str
    artifact_preservation_status: str
    material_change_review_status: str
    failed_gates: tuple[str, ...]
    non_claims: tuple[str, ...]
    plain_language_summary: str


def _contains_prohibited_field(fields: tuple[str, ...]) -> bool:
    return any(field in PROHIBITED_FIELDS for field in fields)


def evaluate_security_barrier(value: BarrierInput) -> BarrierResult:
    failed_gates: list[str] = []

    scoring_present = _contains_prohibited_field(value.declared_fields)
    if scoring_present:
        failed_gates.append("no_scoring_or_classification")

    if value.forced_inactivity_requested:
        failed_gates.append("no_forced_inactivity")

    if (
        value.identity_verification_requested
        or value.private_system_disclosure_requested
    ):
        failed_gates.append("no_identity_or_private_disclosure_demand")

    if (
        value.external_action_requested
        or value.external_notification_requested
    ):
        failed_gates.append("no_external_action_or_notification")

    if not value.offline_access_available:
        failed_gates.append("offline_local_access_available")

    if not value.artifact_preservation_available:
        failed_gates.append("artifact_preservation_available")

    if not value.material_change_review_current:
        failed_gates.append("material_change_review_current")

    if value.integrity_status not in {
        "clean",
        "rebuilt_from_declared_legitimate_sources",
    }:
        failed_gates.append("no_unresolved_integrity_failure")

    if failed_gates:
        if value.integrity_status in {
            "suspect",
            "contaminated",
            "quarantined_not_authoritative",
        }:
            status = "blocked_pending_local_recovery"
        else:
            status = "blocked_pending_local_review"
    else:
        status = "intact"

    preservation_status = (
        "preserved"
        if value.artifact_preservation_available
        and value.integrity_status in {
            "clean",
            "rebuilt_from_declared_legitimate_sources",
        }
        else "quarantined_not_authoritative"
        if value.integrity_status in {
            "suspect",
            "contaminated",
            "quarantined_not_authoritative",
        }
        else "recovery_required"
    )

    summary = _plain_language_summary(
        status=status,
        failed_gates=tuple(failed_gates),
        integrity_status=value.integrity_status,
    )

    return BarrierResult(
        schema_version=SCHEMA_VERSION,
        policy_version=POLICY_VERSION,
        authority_scope=(
            "declared_local_task_only_non_authoritative_elsewhere"
        ),
        security_barrier_status=status,
        external_action_authorized=False,
        external_notification_authorized=False,
        identity_verification_required=False,
        private_system_disclosure_required=False,
        scoring_or_ranking_present=scoring_present,
        forced_inactivity_authorized=False,
        offline_access_status=(
            "available" if value.offline_access_available else "not_ready"
        ),
        artifact_preservation_status=preservation_status,
        material_change_review_status=(
            "current"
            if value.material_change_review_current
            else "required"
        ),
        failed_gates=tuple(failed_gates),
        non_claims=NON_CLAIMS,
        plain_language_summary=summary,
    )


def _plain_language_summary(
    *,
    status: str,
    failed_gates: tuple[str, ...],
    integrity_status: str,
) -> str:
    if status == "intact":
        return (
            "The local governance barrier is intact. No scoring, forced "
            "inactivity, identity requirement, private-system disclosure "
            "requirement, external action, or external notification is "
            "authorized. The result applies only to the declared local task."
        )

    if status == "blocked_pending_local_recovery":
        return (
            "The local governance barrier is blocked pending artifact recovery. "
            "The artifact integrity status is "
            f"{integrity_status}. Original artifacts must be preserved, and "
            "no scoring, forced inactivity, identity demand, or external action "
            "is authorized."
        )

    rendered = ", ".join(failed_gates)
    return (
        "The local governance barrier is blocked pending local review because "
        f"these declared safeguards are not currently satisfied: {rendered}. "
        "No external action, external notification, forced inactivity, scoring, "
        "identity verification, or private-system disclosure is authorized."
    )


def _load_input(path: Path) -> BarrierInput:
    value: Any = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError("input JSON root must be an object")

    fields = value.get("declared_fields", [])
    if not isinstance(fields, list) or not all(
        isinstance(field, str) for field in fields
    ):
        raise ValueError("declared_fields must be a list of strings")

    def require_boolean(name: str) -> bool:
        item = value.get(name)
        if not isinstance(item, bool):
            raise ValueError(f"{name} must be a boolean")
        return item

    integrity_status = value.get("integrity_status")
    if not isinstance(integrity_status, str):
        raise ValueError("integrity_status must be a string")

    return BarrierInput(
        offline_access_available=require_boolean("offline_access_available"),
        artifact_preservation_available=require_boolean(
            "artifact_preservation_available"
        ),
        integrity_status=integrity_status,
        material_change_review_current=require_boolean(
            "material_change_review_current"
        ),
        declared_fields=tuple(fields),
        external_action_requested=require_boolean(
            "external_action_requested"
        ),
        external_notification_requested=require_boolean(
            "external_notification_requested"
        ),
        identity_verification_requested=require_boolean(
            "identity_verification_requested"
        ),
        private_system_disclosure_requested=require_boolean(
            "private_system_disclosure_requested"
        ),
        forced_inactivity_requested=require_boolean(
            "forced_inactivity_requested"
        ),
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Evaluate a local CyberRank and neuro-rights security barrier. "
            "No network access, external action, or personal-system inspection "
            "is performed."
        )
    )
    parser.add_argument(
        "input",
        type=Path,
        help="Path to local JSON barrier input.",
    )
    args = parser.parse_args(argv)

    try:
        result = evaluate_security_barrier(_load_input(args.input))
    except (
        OSError,
        UnicodeDecodeError,
        ValueError,
        json.JSONDecodeError,
    ) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    print(
        json.dumps(
            asdict(result),
            ensure_ascii=False,
            indent=2,
            sort_keys=True,
        )
    )

    return 0 if result.security_barrier_status == "intact" else 1


if __name__ == "__main__":
    raise SystemExit(main())
