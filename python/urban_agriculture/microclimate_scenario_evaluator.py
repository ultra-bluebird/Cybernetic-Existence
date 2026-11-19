from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from math import isfinite
from typing import Iterable


class AssessmentStatus(str, Enum):
    MODEL_OUTPUT = "MODEL_OUTPUT"
    HOLD_FOR_REVIEW = "HOLD_FOR_REVIEW"
    NOT_CALCULATED = "NOT_CALCULATED"
    REJECT = "REJECT"


class RecommendationKind(str, Enum):
    OBSERVE = "OBSERVE"
    HOLD_FOR_REVIEW = "HOLD_FOR_REVIEW"
    PASSIVE_DESIGN_REVIEW = "PASSIVE_DESIGN_REVIEW"
    REJECT = "REJECT"


@dataclass(frozen=True)
class MicroclimateInputs:
    par_mol_m2_day: float | None
    air_temperature_c: float | None
    soil_temperature_c: float | None
    wind_speed_m_s: float | None
    relative_humidity_percent: float | None
    soil_moisture_fraction: float | None
    water_available_l_day: float | None
    usable_area_m2: float | None
    crop_par_requirement_mol_m2_day: float | None
    crop_temperature_min_c: float | None
    crop_temperature_max_c: float | None
    crop_soil_moisture_min: float | None
    crop_soil_moisture_max: float | None
    projected_yield_kg_day: float | None
    crop_value_per_kg: float | None
    eco_benefit_value_day: float | None
    water_cost_value_day: float | None
    energy_cost_value_day: float | None
    labor_cost_value_day: float | None
    uncertainty_state: str
    review_owner: str


@dataclass(frozen=True)
class ScenarioFinding:
    code: str
    decision: RecommendationKind
    summary: str


@dataclass(frozen=True)
class AgricultureScenarioResult:
    status: AssessmentStatus
    recommendation: RecommendationKind
    objective_value: float | None
    input_completeness: float
    findings: tuple[ScenarioFinding, ...]
    limitations: tuple[str, ...]
    non_actuating: bool
    identity_neutral: bool


def _is_valid_number(value: float | None, lower: float | None = None,
                     upper: float | None = None) -> bool:
    if value is None or not isfinite(value):
        return False
    if lower is not None and value < lower:
        return False
    if upper is not None and value > upper:
        return False
    return True


def _required_values(inputs: MicroclimateInputs) -> tuple[float | None, ...]:
    return (
        inputs.par_mol_m2_day,
        inputs.air_temperature_c,
        inputs.soil_temperature_c,
        inputs.wind_speed_m_s,
        inputs.relative_humidity_percent,
        inputs.soil_moisture_fraction,
        inputs.water_available_l_day,
        inputs.usable_area_m2,
        inputs.crop_par_requirement_mol_m2_day,
        inputs.crop_temperature_min_c,
        inputs.crop_temperature_max_c,
        inputs.crop_soil_moisture_min,
        inputs.crop_soil_moisture_max,
        inputs.projected_yield_kg_day,
        inputs.crop_value_per_kg,
        inputs.eco_benefit_value_day,
        inputs.water_cost_value_day,
        inputs.energy_cost_value_day,
        inputs.labor_cost_value_day,
    )


def _input_completeness(inputs: MicroclimateInputs) -> float:
    values = _required_values(inputs)
    present = sum(value is not None for value in values)
    return present / len(values)


def _validate_inputs(inputs: MicroclimateInputs) -> list[ScenarioFinding]:
    findings: list[ScenarioFinding] = []

    if inputs.review_owner.strip() == "" or inputs.review_owner == "OWNER_ASSIGNMENT_REQUIRED":
        findings.append(
            ScenarioFinding(
                code="REVIEW_OWNER_REQUIRED",
                decision=RecommendationKind.HOLD_FOR_REVIEW,
                summary="A responsible review role must be assigned before this scenario informs planning."
            )
        )

    if inputs.uncertainty_state not in {
        "QUANTIFIED",
        "QUALITATIVE",
        "NOT_STATED",
        "NOT_CALCULATED",
        "NOT_APPLICABLE",
        "REVIEW_REQUIRED",
    }:
        findings.append(
            ScenarioFinding(
                code="INVALID_UNCERTAINTY_STATE",
                decision=RecommendationKind.REJECT,
                summary="Uncertainty state is not in the approved controlled vocabulary."
            )
        )

    if inputs.uncertainty_state in {"NOT_STATED", "NOT_CALCULATED", "REVIEW_REQUIRED"}:
        findings.append(
            ScenarioFinding(
                code="UNCERTAINTY_REVIEW_REQUIRED",
                decision=RecommendationKind.HOLD_FOR_REVIEW,
                summary="Scenario uncertainty is incomplete and must remain review-required."
            )
        )

    numeric_checks = (
        ("PAR", inputs.par_mol_m2_day, 0.0, None),
        ("AIR_TEMPERATURE", inputs.air_temperature_c, -100.0, 100.0),
        ("SOIL_TEMPERATURE", inputs.soil_temperature_c, -100.0, 100.0),
        ("WIND_SPEED", inputs.wind_speed_m_s, 0.0, None),
        ("RELATIVE_HUMIDITY", inputs.relative_humidity_percent, 0.0, 100.0),
        ("SOIL_MOISTURE", inputs.soil_moisture_fraction, 0.0, 1.0),
        ("WATER_AVAILABLE", inputs.water_available_l_day, 0.0, None),
        ("USABLE_AREA", inputs.usable_area_m2, 0.0, None),
        ("CROP_PAR_REQUIREMENT", inputs.crop_par_requirement_mol_m2_day, 0.0, None),
        ("CROP_TEMPERATURE_MIN", inputs.crop_temperature_min_c, -100.0, 100.0),
        ("CROP_TEMPERATURE_MAX", inputs.crop_temperature_max_c, -100.0, 100.0),
        ("CROP_SOIL_MOISTURE_MIN", inputs.crop_soil_moisture_min, 0.0, 1.0),
        ("CROP_SOIL_MOISTURE_MAX", inputs.crop_soil_moisture_max, 0.0, 1.0),
        ("PROJECTED_YIELD", inputs.projected_yield_kg_day, 0.0, None),
        ("CROP_VALUE", inputs.crop_value_per_kg, 0.0, None),
        ("ECO_BENEFIT", inputs.eco_benefit_value_day, 0.0, None),
        ("WATER_COST", inputs.water_cost_value_day, 0.0, None),
        ("ENERGY_COST", inputs.energy_cost_value_day, 0.0, None),
        ("LABOR_COST", inputs.labor_cost_value_day, 0.0, None),
    )

    for field_name, value, lower, upper in numeric_checks:
        if value is None:
            findings.append(
                ScenarioFinding(
                    code=f"MISSING_{field_name}",
                    decision=RecommendationKind.HOLD_FOR_REVIEW,
                    summary=f"{field_name} is unavailable. The model must not substitute a favorable default."
                )
            )
        elif not _is_valid_number(value, lower, upper):
            findings.append(
                ScenarioFinding(
                    code=f"INVALID_{field_name}",
                    decision=RecommendationKind.REJECT,
                    summary=f"{field_name} is outside its accepted input range."
                )
            )

    if (
        _is_valid_number(inputs.crop_temperature_min_c, -100.0, 100.0)
        and _is_valid_number(inputs.crop_temperature_max_c, -100.0, 100.0)
        and inputs.crop_temperature_min_c is not None
        and inputs.crop_temperature_max_c is not None
        and inputs.crop_temperature_min_c > inputs.crop_temperature_max_c
    ):
        findings.append(
            ScenarioFinding(
                code="INVALID_CROP_TEMPERATURE_RANGE",
                decision=RecommendationKind.REJECT,
                summary="Crop minimum temperature cannot exceed crop maximum temperature."
            )
        )

    if (
        _is_valid_number(inputs.crop_soil_moisture_min, 0.0, 1.0)
        and _is_valid_number(inputs.crop_soil_moisture_max, 0.0, 1.0)
        and inputs.crop_soil_moisture_min is not None
        and inputs.crop_soil_moisture_max is not None
        and inputs.crop_soil_moisture_min > inputs.crop_soil_moisture_max
    ):
        findings.append(
            ScenarioFinding(
                code="INVALID_CROP_SOIL_MOISTURE_RANGE",
                decision=RecommendationKind.REJECT,
                summary="Crop minimum soil moisture cannot exceed crop maximum soil moisture."
            )
        )

    return findings


def _evaluate_microclimate_fit(inputs: MicroclimateInputs) -> list[ScenarioFinding]:
    findings: list[ScenarioFinding] = []

    if (
        inputs.par_mol_m2_day is not None
        and inputs.crop_par_requirement_mol_m2_day is not None
        and inputs.par_mol_m2_day < inputs.crop_par_requirement_mol_m2_day
    ):
        findings.append(
            ScenarioFinding(
                code="PAR_BELOW_CROP_REQUIREMENT",
                decision=RecommendationKind.PASSIVE_DESIGN_REVIEW,
                summary="Supplied photosynthetically active radiation is below the declared crop requirement. Review crop selection, passive design, or measurement assumptions."
            )
        )

    if (
        inputs.air_temperature_c is not None
        and inputs.crop_temperature_min_c is not None
        and inputs.air_temperature_c < inputs.crop_temperature_min_c
    ):
        findings.append(
            ScenarioFinding(
                code="AIR_TEMPERATURE_BELOW_CROP_RANGE",
                decision=RecommendationKind.PASSIVE_DESIGN_REVIEW,
                summary="Supplied air temperature is below the declared crop range. Review crop suitability and passive thermal design assumptions."
            )
        )

    if (
        inputs.air_temperature_c is not None
        and inputs.crop_temperature_max_c is not None
        and inputs.air_temperature_c > inputs.crop_temperature_max_c
    ):
        findings.append(
            ScenarioFinding(
                code="AIR_TEMPERATURE_ABOVE_CROP_RANGE",
                decision=RecommendationKind.PASSIVE_DESIGN_REVIEW,
                summary="Supplied air temperature is above the declared crop range. Review crop suitability and passive thermal design assumptions."
            )
        )

    if (
        inputs.soil_moisture_fraction is not None
        and inputs.crop_soil_moisture_min is not None
        and inputs.soil_moisture_fraction < inputs.crop_soil_moisture_min
    ):
        findings.append(
            ScenarioFinding(
                code="SOIL_MOISTURE_BELOW_CROP_RANGE",
                decision=RecommendationKind.HOLD_FOR_REVIEW,
                summary="Supplied soil moisture is below the declared crop range. Do not infer an irrigation action; review water evidence and plant requirements."
            )
        )

    if (
        inputs.soil_moisture_fraction is not None
        and inputs.crop_soil_moisture_max is not None
        and inputs.soil_moisture_fraction > inputs.crop_soil_moisture_max
    ):
        findings.append(
            ScenarioFinding(
                code="SOIL_MOISTURE_ABOVE_CROP_RANGE",
                decision=RecommendationKind.HOLD_FOR_REVIEW,
                summary="Supplied soil moisture is above the declared crop range. Review drainage, measurement, and plant-requirement evidence."
            )
        )

    return findings


def _calculate_objective(inputs: MicroclimateInputs) -> float:
    assert inputs.projected_yield_kg_day is not None
    assert inputs.crop_value_per_kg is not None
    assert inputs.eco_benefit_value_day is not None
    assert inputs.water_cost_value_day is not None
    assert inputs.energy_cost_value_day is not None
    assert inputs.labor_cost_value_day is not None

    return (
        inputs.projected_yield_kg_day * inputs.crop_value_per_kg
        + inputs.eco_benefit_value_day
        - inputs.water_cost_value_day
        - inputs.energy_cost_value_day
        - inputs.labor_cost_value_day
    )


def evaluate_agriculture_scenario(
    inputs: MicroclimateInputs
) -> AgricultureScenarioResult:
    findings = _validate_inputs(inputs)
    completeness = _input_completeness(inputs)

    if any(finding.decision == RecommendationKind.REJECT for finding in findings):
        return AgricultureScenarioResult(
            status=AssessmentStatus.REJECT,
            recommendation=RecommendationKind.REJECT,
            objective_value=None,
            input_completeness=completeness,
            findings=tuple(findings),
            limitations=_limitations(),
            non_actuating=True,
            identity_neutral=True,
        )

    if completeness < 1.0:
        return AgricultureScenarioResult(
            status=AssessmentStatus.NOT_CALCULATED,
            recommendation=RecommendationKind.HOLD_FOR_REVIEW,
            objective_value=None,
            input_completeness=completeness,
            findings=tuple(findings),
            limitations=_limitations(),
            non_actuating=True,
            identity_neutral=True,
        )

    findings.extend(_evaluate_microclimate_fit(inputs))

    if any(
        finding.decision == RecommendationKind.HOLD_FOR_REVIEW
        for finding in findings
    ):
        return AgricultureScenarioResult(
            status=AssessmentStatus.HOLD_FOR_REVIEW,
            recommendation=RecommendationKind.HOLD_FOR_REVIEW,
            objective_value=None,
            input_completeness=completeness,
            findings=tuple(findings),
            limitations=_limitations(),
            non_actuating=True,
            identity_neutral=True,
        )

    return AgricultureScenarioResult(
        status=AssessmentStatus.MODEL_OUTPUT,
        recommendation=RecommendationKind.PASSIVE_DESIGN_REVIEW,
        objective_value=_calculate_objective(inputs),
        input_completeness=completeness,
        findings=tuple(findings),
        limitations=_limitations(),
        non_actuating=True,
        identity_neutral=True,
    )


def compare_agriculture_scenarios(
    scenarios: Iterable[tuple[str, MicroclimateInputs]]
) -> tuple[tuple[str, AgricultureScenarioResult], ...]:
    results = [
        (scenario_id, evaluate_agriculture_scenario(inputs))
        for scenario_id, inputs in scenarios
    ]

    return tuple(
        sorted(
            results,
            key=lambda item: (
                item[1].status != AssessmentStatus.MODEL_OUTPUT,
                -(item[1].objective_value or float("-inf")),
                item[0],
            ),
        )
    )


def _limitations() -> tuple[str, ...]:
    return (
        "This result is a local scenario-model output based on supplied non-personal inputs.",
        "This result does not predict actual crop yield, water use, building energy performance, thermal comfort, food access, or ecological outcome.",
        "This result does not verify identity, augmentation status, clinical status, legal compliance, property rights, community consent, or eligibility for services.",
        "This result does not authorize irrigation, shading, ventilation, HVAC, lighting, or any physical-system action.",
        "Unknown, unmodeled, expired, or review-required inputs must remain explicit and may not be substituted with favorable values.",
    )
