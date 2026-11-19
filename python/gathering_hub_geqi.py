from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from math import isfinite
from typing import Optional


class GeqiDecision(str, Enum):
    REPORTABLE_FOR_HUMAN_REVIEW = "reportable_for_human_review"
    INCOMPLETE_ENVIRONMENTAL_EVIDENCE = "incomplete_environmental_evidence"
    CONFIGURATION_ERROR = "configuration_error"


@dataclass(frozen=True)
class GeqiWeights:
    air_quality: float
    noise_comfort: float
    thermal_comfort: float
    light_quality: float
    spatial_density: float

    def validate(self) -> None:
        values = (
            self.air_quality,
            self.noise_comfort,
            self.thermal_comfort,
            self.light_quality,
            self.spatial_density,
        )

        if not all(isfinite(value) for value in values):
            raise ValueError("GEQI weights must be finite")

        if any(value < 0 for value in values):
            raise ValueError("GEQI weights must not be negative")

        if abs(sum(values) - 1.0) > 1e-9:
            raise ValueError("GEQI weights must sum to exactly 1.0")


@dataclass(frozen=True)
class GeqiComponents:
    air_quality_score: Optional[float]
    noise_comfort_score: Optional[float]
    thermal_comfort_score: Optional[float]
    light_quality_score: Optional[float]
    spatial_density_score: Optional[float]
    calibrated: bool
    temporal_window_seconds: int
    privacy_preserving_occupancy_method: bool

    def all_scores(self) -> tuple[Optional[float], ...]:
        return (
            self.air_quality_score,
            self.noise_comfort_score,
            self.thermal_comfort_score,
            self.light_quality_score,
            self.spatial_density_score,
        )

    def validate(self) -> None:
        if self.temporal_window_seconds <= 0:
            raise ValueError("temporal_window_seconds must be greater than zero")

        for score in self.all_scores():
            if score is None:
                continue

            if not isfinite(score) or not 0.0 <= score <= 1.0:
                raise ValueError("each GEQI component score must be in the range [0.0, 1.0]")


@dataclass(frozen=True)
class GeqiReport:
    decision: GeqiDecision
    geqi_score: Optional[float]
    missing_components: tuple[str, ...]
    reasons: tuple[str, ...]
    physical_action_authorized: bool


COMPONENT_NAMES = (
    "air_quality_score",
    "noise_comfort_score",
    "thermal_comfort_score",
    "light_quality_score",
    "spatial_density_score",
)


def assess_geqi(
    weights: GeqiWeights,
    components: GeqiComponents,
) -> GeqiReport:
    weights.validate()
    components.validate()

    component_values = components.all_scores()
    missing_components = tuple(
        name
        for name, value in zip(COMPONENT_NAMES, component_values)
        if value is None
    )

    reasons: list[str] = []

    if not components.calibrated:
        reasons.append("sensor_or_model_calibration_is_not_confirmed")

    if not components.privacy_preserving_occupancy_method:
        reasons.append("spatial_density_method_is_not_privacy_preserving")

    if missing_components:
        reasons.append("one_or_more_environmental_components_are_missing")

    if reasons:
        return GeqiReport(
            decision=GeqiDecision.INCOMPLETE_ENVIRONMENTAL_EVIDENCE,
            geqi_score=None,
            missing_components=missing_components,
            reasons=tuple(reasons),
            physical_action_authorized=False,
        )

    air, noise, thermal, light, density = component_values
    assert air is not None
    assert noise is not None
    assert thermal is not None
    assert light is not None
    assert density is not None

    score = (
        weights.air_quality * air
        + weights.noise_comfort * noise
        + weights.thermal_comfort * thermal
        + weights.light_quality * light
        + weights.spatial_density * density
    )

    return GeqiReport(
        decision=GeqiDecision.REPORTABLE_FOR_HUMAN_REVIEW,
        geqi_score=score,
        missing_components=(),
        reasons=(
            "GEQI_is_a_transparent_environmental_decision_support_score",
            "review_component_scores_and_uncertainty_before_planning_use",
            "GEQI_does_not_authorize_ventilation_lighting_or_occupancy_control",
        ),
        physical_action_authorized=False,
    )


if __name__ == "__main__":
    report = assess_geqi(
        weights=GeqiWeights(
            air_quality=0.30,
            noise_comfort=0.20,
            thermal_comfort=0.25,
            light_quality=0.15,
            spatial_density=0.10,
        ),
        components=GeqiComponents(
            air_quality_score=0.82,
            noise_comfort_score=0.73,
            thermal_comfort_score=0.68,
            light_quality_score=0.85,
            spatial_density_score=0.76,
            calibrated=True,
            temporal_window_seconds=900,
            privacy_preserving_occupancy_method=True,
        ),
    )

    print(
        {
            "decision": report.decision.value,
            "geqi_score": report.geqi_score,
            "physical_action_authorized": report.physical_action_authorized,
            "reasons": report.reasons,
        }
    )
