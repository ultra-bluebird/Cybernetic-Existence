from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Iterable


class ScenarioValidationError(ValueError):
    pass


@dataclass(frozen=True)
class UrbanScenario:
    scenario: str
    domain: str
    metric: str
    value: float
    uncertainty: float
    privacy_class: str
    method_version: str
    limitations: tuple[str, ...]
    essential_service_availability: float
    jain_fairness_index: float | None = None
    privacy_leakage_estimate: float = 0.0
    ble_identity_used: bool = False
    essential_service_independent_of_ble: bool = True

    def __post_init__(self) -> None:
        if not self.scenario.strip() or not self.domain.strip() or not self.metric.strip():
            raise ScenarioValidationError("scenario, domain, and metric must be non-empty.")

        if not self.method_version.strip():
            raise ScenarioValidationError("method_version must be non-empty.")

        if not self.limitations or any(not item.strip() for item in self.limitations):
            raise ScenarioValidationError("At least one non-empty limitation is required.")

        for field_name, value in (
            ("value", self.value),
            ("uncertainty", self.uncertainty),
            ("essential_service_availability", self.essential_service_availability),
            ("privacy_leakage_estimate", self.privacy_leakage_estimate),
        ):
            if not isfinite(value):
                raise ScenarioValidationError(f"{field_name} must be finite.")

        if self.uncertainty < 0.0:
            raise ScenarioValidationError("uncertainty must be non-negative.")

        if not 0.0 <= self.essential_service_availability <= 1.0:
            raise ScenarioValidationError(
                "essential_service_availability must be between zero and one."
            )

        if not 0.0 <= self.privacy_leakage_estimate <= 1.0:
            raise ScenarioValidationError(
                "privacy_leakage_estimate must be between zero and one."
            )

        if self.jain_fairness_index is not None:
            if not isfinite(self.jain_fairness_index) or not 0.0 <= self.jain_fairness_index <= 1.0:
                raise ScenarioValidationError(
                    "jain_fairness_index must be between zero and one when provided."
                )

        if self.ble_identity_used:
            raise ScenarioValidationError(
                "BLE identity use is prohibited in privacy-safe urban simulation output."
            )

        if not self.essential_service_independent_of_ble:
            raise ScenarioValidationError(
                "Essential service availability must remain independent of BLE."
            )


def validate_scenario(scenario: UrbanScenario) -> UrbanScenario:
    if scenario.privacy_leakage_estimate != 0.0:
        raise ScenarioValidationError(
            "Published privacy-safe scenarios require a zero BLE identity leakage estimate."
        )
    return scenario


def find_scenarios(
    scenarios: Iterable[UrbanScenario],
    domain: str,
    metric: str,
) -> list[UrbanScenario]:
    if not domain.strip() or not metric.strip():
        raise ScenarioValidationError("domain and metric must be non-empty.")

    matches = [
        scenario
        for scenario in scenarios
        if scenario.domain == domain and scenario.metric == metric
    ]
    return sorted(matches, key=lambda item: (item.uncertainty, item.scenario))


def cooling_center_demand_rate(
    baseline_rate: float,
    temperature_c: float,
    reference_temperature_c: float,
    temperature_coefficient: float,
    aggregate_high_risk_share: float,
    aggregate_high_risk_coefficient: float,
) -> float:
    values = (
        baseline_rate,
        temperature_c,
        reference_temperature_c,
        temperature_coefficient,
        aggregate_high_risk_share,
        aggregate_high_risk_coefficient,
    )

    if any(not isfinite(value) for value in values):
        raise ScenarioValidationError("Demand-model inputs must be finite.")

    if baseline_rate < 0.0:
        raise ScenarioValidationError("baseline_rate must be non-negative.")

    if not 0.0 <= aggregate_high_risk_share <= 1.0:
        raise ScenarioValidationError(
            "aggregate_high_risk_share must be between zero and one."
        )

    estimate = (
        baseline_rate
        + temperature_coefficient * (temperature_c - reference_temperature_c)
        + aggregate_high_risk_coefficient * aggregate_high_risk_share
    )

    return max(0.0, estimate)
