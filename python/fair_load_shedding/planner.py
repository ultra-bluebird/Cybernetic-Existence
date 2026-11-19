from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Iterable


class LoadSheddingValidationError(ValueError):
    pass


@dataclass(frozen=True)
class ServiceArea:
    label: str
    total_demand_mw: float
    essential_demand_mw: float
    planned_nonessential_outage_hours: float
    technical_exception_documented: bool = False

    def __post_init__(self) -> None:
        if not self.label.strip():
            raise LoadSheddingValidationError("label must be non-empty.")

        values = (
            self.total_demand_mw,
            self.essential_demand_mw,
            self.planned_nonessential_outage_hours,
        )
        if any(not isfinite(value) for value in values):
            raise LoadSheddingValidationError("Service-area values must be finite.")
        if self.total_demand_mw < 0.0:
            raise LoadSheddingValidationError("total_demand_mw must be non-negative.")
        if not 0.0 <= self.essential_demand_mw <= self.total_demand_mw:
            raise LoadSheddingValidationError(
                "essential_demand_mw must be between zero and total_demand_mw."
            )
        if self.planned_nonessential_outage_hours < 0.0:
            raise LoadSheddingValidationError(
                "planned_nonessential_outage_hours must be non-negative."
            )

    @property
    def curtailable_demand_mw(self) -> float:
        return self.total_demand_mw - self.essential_demand_mw


@dataclass(frozen=True)
class FairnessReport:
    jain_fairness_index: float
    essential_loads_preserved: bool
    maximum_outage_hours: float
    meets_fairness_target: bool
    requires_human_review: bool
    reason: str


def jain_fairness_index(values: Iterable[float]) -> float:
    numbers = list(values)
    if not numbers:
        raise LoadSheddingValidationError("At least one burden value is required.")
    if any(not isfinite(value) or value < 0.0 for value in numbers):
        raise LoadSheddingValidationError(
            "Burden values must be finite and non-negative."
        )

    total = sum(numbers)
    squared_total = sum(value * value for value in numbers)

    if squared_total == 0.0:
        return 1.0

    return (total * total) / (len(numbers) * squared_total)


def evaluate_plan(
    service_areas: Iterable[ServiceArea],
    fairness_target: float = 0.9,
    maximum_nonessential_outage_hours: float = 4.0,
) -> FairnessReport:
    areas = list(service_areas)
    if not areas:
        raise LoadSheddingValidationError("At least one service area is required.")
    if not isfinite(fairness_target) or not 0.0 < fairness_target <= 1.0:
        raise LoadSheddingValidationError(
            "fairness_target must be finite and greater than zero through one."
        )
    if not isfinite(maximum_nonessential_outage_hours) or maximum_nonessential_outage_hours <= 0.0:
        raise LoadSheddingValidationError(
            "maximum_nonessential_outage_hours must be finite and positive."
        )

    essential_preserved = all(
        area.essential_demand_mw <= area.total_demand_mw for area in areas
    )
    outage_hours = [area.planned_nonessential_outage_hours for area in areas]
    fairness = jain_fairness_index(outage_hours)
    maximum_outage = max(outage_hours)

    excessive_without_exception = any(
        area.planned_nonessential_outage_hours > maximum_nonessential_outage_hours
        and not area.technical_exception_documented
        for area in areas
    )

    fairness_met = fairness > fairness_target
    requires_review = (
        not essential_preserved
        or not fairness_met
        or excessive_without_exception
        or any(area.technical_exception_documented for area in areas)
    )

    if not essential_preserved:
        reason = "The plan is invalid because essential demand is not preserved."
    elif excessive_without_exception:
        reason = (
            "A non-essential outage exceeds the configured maximum without a documented "
            "technical exception."
        )
    elif not fairness_met:
        reason = "The plan does not meet the Jain fairness target."
    elif any(area.technical_exception_documented for area in areas):
        reason = (
            "The plan meets baseline calculations but contains a technical exception "
            "requiring documented human incident-command review."
        )
    else:
        reason = (
            "The plan preserves essential demand, remains within the non-essential "
            "outage bound, and exceeds the Jain fairness target."
        )

    return FairnessReport(
        jain_fairness_index=fairness,
        essential_loads_preserved=essential_preserved,
        maximum_outage_hours=maximum_outage,
        meets_fairness_target=fairness_met,
        requires_human_review=requires_review,
        reason=reason,
    )
