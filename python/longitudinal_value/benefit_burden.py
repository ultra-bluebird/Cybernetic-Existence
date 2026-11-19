from __future__ import annotations

from dataclasses import dataclass
from math import isfinite


@dataclass(frozen=True)
class BenefitInputs:
    functional_value: float
    agency: float
    comfort: float
    trust: float
    independence: float
    willingness_to_continue: float


@dataclass(frozen=True)
class BurdenInputs:
    workload: float
    correction: float
    fatigue: float
    maintenance: float
    privacy: float


@dataclass(frozen=True)
class BenefitBurdenReport:
    raw_ratio: float
    bounded_ratio: float
    benefit_total: float
    burden_total: float


class BenefitBurdenError(ValueError):
    pass


def calculate_benefit_burden(
    benefits: BenefitInputs,
    burdens: BurdenInputs,
) -> BenefitBurdenReport:
    _validate_unit_interval(
        benefits.functional_value,
        benefits.agency,
        benefits.comfort,
        benefits.trust,
        benefits.independence,
        benefits.willingness_to_continue,
        burdens.workload,
        burdens.correction,
        burdens.fatigue,
        burdens.maintenance,
        burdens.privacy,
    )

    benefit_total = (
        benefits.functional_value
        + benefits.agency
        + benefits.comfort
        + benefits.trust
        + benefits.independence
        + benefits.willingness_to_continue
    )

    burden_total = (
        burdens.workload
        + burdens.correction
        + burdens.fatigue
        + burdens.maintenance
        + burdens.privacy
    )

    raw_ratio = benefit_total / (1.0 + burden_total)
    bounded_ratio = raw_ratio / (1.0 + raw_ratio)

    return BenefitBurdenReport(
        raw_ratio=raw_ratio,
        bounded_ratio=bounded_ratio,
        benefit_total=benefit_total,
        burden_total=burden_total,
    )


def _validate_unit_interval(*values: float) -> None:
    for value in values:
        if not isfinite(value) or not 0.0 <= value <= 1.0:
            raise BenefitBurdenError(
                "all benefit and burden inputs must be finite values in [0, 1]"
            )
