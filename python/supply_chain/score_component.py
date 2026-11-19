from __future__ import annotations

from dataclasses import dataclass
from math import isfinite


@dataclass(frozen=True)
class AssuranceInputs:
    provenance: float
    vulnerability_review: float
    test_verification: float
    license_clarity: float
    remediation_readiness: float


@dataclass(frozen=True)
class SoftwareRiskInputs:
    exploitability: float
    impact: float
    criticality: float
    attack_surface: float
    exposure_age: float


@dataclass(frozen=True)
class ComponentScores:
    assurance_score: float
    software_risk_score: float


class ScoreValidationError(ValueError):
    pass


def calculate_assurance(inputs: AssuranceInputs) -> float:
    _validate_unit_interval(
        inputs.provenance,
        inputs.vulnerability_review,
        inputs.test_verification,
        inputs.license_clarity,
        inputs.remediation_readiness,
    )

    return (
        0.25 * inputs.provenance
        + 0.25 * inputs.vulnerability_review
        + 0.20 * inputs.test_verification
        + 0.15 * inputs.license_clarity
        + 0.15 * inputs.remediation_readiness
    )


def calculate_software_risk(inputs: SoftwareRiskInputs) -> float:
    _validate_unit_interval(
        inputs.exploitability,
        inputs.impact,
        inputs.criticality,
        inputs.attack_surface,
        inputs.exposure_age,
    )

    return (
        0.30 * inputs.exploitability
        + 0.25 * inputs.impact
        + 0.20 * inputs.criticality
        + 0.15 * inputs.attack_surface
        + 0.10 * inputs.exposure_age
    )


def score_component(
    assurance: AssuranceInputs,
    risk: SoftwareRiskInputs,
) -> ComponentScores:
    return ComponentScores(
        assurance_score=calculate_assurance(assurance),
        software_risk_score=calculate_software_risk(risk),
    )


def release_allowed(
    scores: ComponentScores,
    integrity_verified: bool,
    unresolved_critical_exposure: bool,
    sbom_is_fresh: bool,
    minimum_assurance: float = 0.80,
    maximum_risk: float = 0.40,
) -> bool:
    _validate_unit_interval(minimum_assurance, maximum_risk)

    return (
        integrity_verified
        and not unresolved_critical_exposure
        and sbom_is_fresh
        and scores.assurance_score >= minimum_assurance
        and scores.software_risk_score <= maximum_risk
    )


def _validate_unit_interval(*values: float) -> None:
    for value in values:
        if not isfinite(value) or not 0.0 <= value <= 1.0:
            raise ScoreValidationError(
                "all assurance and risk inputs must be finite values in [0, 1]"
            )
