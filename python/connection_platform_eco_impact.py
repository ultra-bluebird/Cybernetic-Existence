from dataclasses import dataclass
from decimal import Decimal
from typing import Iterable


ZERO = Decimal("0")


@dataclass(frozen=True)
class EnergyActivity:
    activity_ref: str
    category: str
    energy_kwh: Decimal
    emissions_factor_kgco2e_per_kwh: Decimal
    factor_scope_documented: bool
    factor_period_documented: bool
    provenance_complete: bool


@dataclass(frozen=True)
class OperationalFootprint:
    total_energy_kwh: Decimal
    total_emissions_kgco2e: Decimal
    reportable: bool
    reasons: tuple[str, ...]


@dataclass(frozen=True)
class IndirectImpactClaim:
    claim_ref: str
    baseline_documented: bool
    counterfactual_documented: bool
    intervention_documented: bool
    emissions_factor_documented: bool
    uncertainty_documented: bool
    confounds_assessed: bool
    individual_tracking_used: bool
    identity_inference_used: bool


@dataclass(frozen=True)
class IndirectImpactAssessment:
    claim_ref: str
    reportable_as_causal: bool
    permitted_label: str
    reasons: tuple[str, ...]


def calculate_operational_footprint(
    activities: Iterable[EnergyActivity],
) -> OperationalFootprint:
    total_energy = ZERO
    total_emissions = ZERO
    reasons: list[str] = []

    for activity in activities:
        if activity.energy_kwh < ZERO:
            raise ValueError("energy_kwh must not be negative")

        if activity.emissions_factor_kgco2e_per_kwh < ZERO:
            raise ValueError("emissions factor must not be negative")

        if not activity.factor_scope_documented:
            reasons.append(f"MISSING_FACTOR_SCOPE:{activity.activity_ref}")

        if not activity.factor_period_documented:
            reasons.append(f"MISSING_FACTOR_PERIOD:{activity.activity_ref}")

        if not activity.provenance_complete:
            reasons.append(f"MISSING_PROVENANCE:{activity.activity_ref}")

        total_energy += activity.energy_kwh
        total_emissions += (
            activity.energy_kwh
            * activity.emissions_factor_kgco2e_per_kwh
        )

    return OperationalFootprint(
        total_energy_kwh=total_energy.quantize(Decimal("0.001")),
        total_emissions_kgco2e=total_emissions.quantize(Decimal("0.001")),
        reportable=not reasons,
        reasons=tuple(reasons),
    )


def assess_indirect_impact_claim(
    claim: IndirectImpactClaim,
) -> IndirectImpactAssessment:
    reasons: list[str] = []

    if not claim.baseline_documented:
        reasons.append("BASELINE_NOT_DOCUMENTED")

    if not claim.counterfactual_documented:
        reasons.append("COUNTERFACTUAL_NOT_DOCUMENTED")

    if not claim.intervention_documented:
        reasons.append("INTERVENTION_NOT_DOCUMENTED")

    if not claim.emissions_factor_documented:
        reasons.append("EMISSIONS_FACTOR_NOT_DOCUMENTED")

    if not claim.uncertainty_documented:
        reasons.append("UNCERTAINTY_NOT_DOCUMENTED")

    if not claim.confounds_assessed:
        reasons.append("CONFOUNDS_NOT_ASSESSED")

    if claim.individual_tracking_used:
        reasons.append("INDIVIDUAL_TRACKING_PROHIBITED")

    if claim.identity_inference_used:
        reasons.append("IDENTITY_INFERENCE_PROHIBITED")

    return IndirectImpactAssessment(
        claim_ref=claim.claim_ref,
        reportable_as_causal=not reasons,
        permitted_label=(
            "EVIDENCE_LIMITED_CAUSAL_ESTIMATE"
            if not reasons
            else "NON_CAUSAL_RESEARCH_HYPOTHESIS"
        ),
        reasons=tuple(reasons),
    )
