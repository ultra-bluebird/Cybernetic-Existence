from __future__ import annotations

from dataclasses import dataclass
from math import prod
from typing import Mapping, Sequence


@dataclass(frozen=True)
class AcceptanceIndicators:
    othering_language_rate: float
    positive_representation_rate: float
    rights_policy_expansion_score: float
    inclusive_media_integration_score: float
    equal_economic_participation_score: float
    evidence_quality: float


@dataclass(frozen=True)
class AcceptanceTrajectoryInput:
    time_index: float
    event_score: float
    education_access_score: float


@dataclass(frozen=True)
class PlatformBenefits:
    eco_benefit: float
    social_benefit: float
    rights_protection: float
    technical_reliability: float


@dataclass(frozen=True)
class ComponentRightsProfile:
    component_name: str
    identity_free_baseline_function: bool
    accessible_alternative_available: bool
    graceful_manual_degradation: bool
    privacy_preserving_audit_trail: bool
    accessible_appeal_path: bool
    identity_respect_verified: bool


@dataclass(frozen=True)
class ComplianceResult:
    compliant: bool
    unmet_features: tuple[str, ...]
    compliance_product: int


def _require_unit_interval(value: float, label: str) -> None:
    if not 0.0 <= value <= 1.0:
        raise ValueError(f"{label} must be within [0, 1].")


def social_acceptance_score(indicators: AcceptanceIndicators) -> float:
    values = (
        indicators.othering_language_rate,
        indicators.positive_representation_rate,
        indicators.rights_policy_expansion_score,
        indicators.inclusive_media_integration_score,
        indicators.equal_economic_participation_score,
        indicators.evidence_quality,
    )

    for value in values:
        _require_unit_interval(value, "Acceptance indicator")

    non_othering_language = 1.0 - indicators.othering_language_rate

    raw_score = (
        0.22 * non_othering_language
        + 0.20 * indicators.positive_representation_rate
        + 0.24 * indicators.rights_policy_expansion_score
        + 0.16 * indicators.inclusive_media_integration_score
        + 0.18 * indicators.equal_economic_participation_score
    )

    return raw_score * indicators.evidence_quality


def acceptance_trajectory(
    inputs: AcceptanceTrajectoryInput,
    coefficients: Mapping[str, float],
) -> float:
    required_coefficients = {
        "intercept",
        "time",
        "events",
        "education",
    }

    if set(coefficients) != required_coefficients:
        raise ValueError(
            "Coefficients must contain only intercept, time, events, and education."
        )

    _require_unit_interval(inputs.event_score, "Event score")
    _require_unit_interval(inputs.education_access_score, "Education access score")

    return (
        coefficients["intercept"]
        + coefficients["time"] * inputs.time_index
        + coefficients["events"] * inputs.event_score
        + coefficients["education"] * inputs.education_access_score
    )


def integrated_platform_benefit(benefits: PlatformBenefits) -> float:
    values = (
        benefits.eco_benefit,
        benefits.social_benefit,
        benefits.rights_protection,
        benefits.technical_reliability,
    )

    for value in values:
        _require_unit_interval(value, "Platform benefit")

    if benefits.rights_protection == 0.0:
        return 0.0

    return prod(values)


def verify_component_rights(
    profile: ComponentRightsProfile,
) -> ComplianceResult:
    checks = {
        "identity_free_baseline_function": (
            profile.identity_free_baseline_function
        ),
        "accessible_alternative_available": (
            profile.accessible_alternative_available
        ),
        "graceful_manual_degradation": (
            profile.graceful_manual_degradation
        ),
        "privacy_preserving_audit_trail": (
            profile.privacy_preserving_audit_trail
        ),
        "accessible_appeal_path": profile.accessible_appeal_path,
        "identity_respect_verified": profile.identity_respect_verified,
    }

    unmet = tuple(name for name, passed in checks.items() if not passed)
    compliance_product = int(all(checks.values()))

    return ComplianceResult(
        compliant=not unmet,
        unmet_features=unmet,
        compliance_product=compliance_product,
    )


def infrastructure_suite_compliant(
    profiles: Sequence[ComponentRightsProfile],
) -> bool:
    if not profiles:
        return False

    return all(verify_component_rights(profile).compliant for profile in profiles)
