from __future__ import annotations

from dataclasses import dataclass
from math import isfinite


@dataclass(frozen=True)
class ContinuityEvidence:
    independent_failure_domains: int
    encrypted_offsite_backup_verified: bool
    backup_restore_test_within_days: int
    open_export_formats: bool
    documented_local_offline_access: bool
    proprietary_api_lock_in_fraction: float
    identity_optional_for_basic_access: bool
    biometric_or_brain_bound_identity_required: bool
    documented_key_recovery_process: bool
    accessible_human_recovery_path: bool
    revocable_consent_controls: bool


@dataclass(frozen=True)
class SovereignContinuityResult:
    redundancy_score: float
    recoverability_score: float
    interoperability_score: float
    autonomy_score: float
    governance_score: float
    sovereign_continuity_score: float
    blocking_conditions: tuple[str, ...]
    rationale: str


def _finite_nonnegative(name: str, value: float) -> None:
    if not isfinite(value) or value < 0.0:
        raise ValueError(f"{name} must be finite and non-negative.")


def calculate_sovereign_continuity(
    evidence: ContinuityEvidence,
) -> SovereignContinuityResult:
    _finite_nonnegative(
        "independent_failure_domains",
        float(evidence.independent_failure_domains),
    )
    _finite_nonnegative(
        "backup_restore_test_within_days",
        float(evidence.backup_restore_test_within_days),
    )
    _finite_nonnegative(
        "proprietary_api_lock_in_fraction",
        evidence.proprietary_api_lock_in_fraction,
    )

    if evidence.proprietary_api_lock_in_fraction > 1.0:
        raise ValueError("proprietary_api_lock_in_fraction must be within [0, 1].")

    redundancy = min(
        1.0,
        evidence.independent_failure_domains / 3.0,
    )

    restore_recency = max(
        0.0,
        1.0 - evidence.backup_restore_test_within_days / 365.0,
    )
    recoverability = (
        0.55 * float(evidence.encrypted_offsite_backup_verified)
        + 0.25 * restore_recency
        + 0.20 * float(evidence.documented_key_recovery_process)
    )

    interoperability = (
        0.65 * float(evidence.open_export_formats)
        + 0.35 * (1.0 - evidence.proprietary_api_lock_in_fraction)
    )

    autonomy = (
        0.45 * float(evidence.documented_local_offline_access)
        + 0.35 * float(evidence.identity_optional_for_basic_access)
        + 0.20 * float(evidence.accessible_human_recovery_path)
    )

    governance = float(evidence.revocable_consent_controls)

    blocking_conditions = []

    if evidence.independent_failure_domains < 2:
        blocking_conditions.append("insufficient_independent_failure_domains")

    if not evidence.encrypted_offsite_backup_verified:
        blocking_conditions.append("verified_encrypted_offsite_backup_missing")

    if not evidence.open_export_formats:
        blocking_conditions.append("open_export_formats_missing")

    if not evidence.identity_optional_for_basic_access:
        blocking_conditions.append("identity_required_for_basic_access")

    if evidence.biometric_or_brain_bound_identity_required:
        blocking_conditions.append("brain_bound_or_biometric_identity_required")

    if not evidence.accessible_human_recovery_path:
        blocking_conditions.append("accessible_human_recovery_path_missing")

    score = (
        0.25 * redundancy
        + 0.25 * recoverability
        + 0.20 * interoperability
        + 0.20 * autonomy
        + 0.10 * governance
    )

    if blocking_conditions:
        score = min(score, 0.49)

    return SovereignContinuityResult(
        redundancy_score=redundancy,
        recoverability_score=recoverability,
        interoperability_score=interoperability,
        autonomy_score=autonomy,
        governance_score=governance,
        sovereign_continuity_score=score,
        blocking_conditions=tuple(blocking_conditions),
        rationale=(
            "This score measures continuity and autonomy of access under "
            "failure, disconnection, migration, and identity-system change. "
            "A high score requires demonstrated restoration, interoperable "
            "exports, offline pathways, and no biometric or brain-bound "
            "identity requirement for basic access."
        ),
    )
