from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from math import isfinite, pow


STEFAN_BOLTZMANN_W_M2_K4 = 5.670374419e-8


class CoolingAssessmentState(str, Enum):
    VERIFIED_PERFORMING = "verified_performing"
    MONITORING = "monitoring"
    MAINTENANCE_REVIEW = "maintenance_review"
    SAFETY_REVIEW = "safety_review"
    SENSOR_REVIEW = "sensor_review"


@dataclass(frozen=True)
class RadiativeCoolingMeasurement:
    surface_temperature_c: float
    air_temperature_c: float
    substrate_temperature_c: float
    solar_irradiance_w_m2: float
    downwelling_longwave_w_m2: float
    solar_reflectance: float
    infrared_emissivity: float
    convective_heat_transfer_w_m2_k: float
    assembly_conductance_w_m2_k: float
    sky_view_factor: float
    surface_luminance_cd_m2: float
    wet_friction_coefficient: float
    dry_friction_coefficient: float
    sensor_confidence: float


@dataclass(frozen=True)
class RadiativeCoolingBaseline:
    initial_solar_reflectance: float
    initial_infrared_emissivity: float
    control_surface_temperature_c: float
    control_solar_reflectance: float


@dataclass(frozen=True)
class CoolingVerificationPolicy:
    minimum_sensor_confidence: float = 0.75
    minimum_solar_reflectance_ratio: float = 0.80
    minimum_infrared_emissivity_ratio: float = 0.95
    maximum_surface_luminance_cd_m2: float = 10000.0
    minimum_wet_friction_coefficient: float = 0.45
    minimum_dry_friction_coefficient: float = 0.50
    minimum_sky_view_factor_for_radiative_claim: float = 0.20
    reference_temperature_delta_c: float = 15.0


@dataclass(frozen=True)
class CoolingAssessment:
    net_surface_flux_w_m2: float
    emitted_longwave_flux_w_m2: float
    absorbed_solar_flux_w_m2: float
    convective_flux_w_m2: float
    conductive_flux_w_m2: float
    cooling_score: float
    solar_reflectance_degradation: float
    infrared_emissivity_degradation: float
    state: CoolingAssessmentState
    explanation: str


def _bounded(value: float, low: float, high: float) -> float:
    return max(low, min(value, high))


def _require_finite(name: str, value: float) -> None:
    if not isfinite(value):
        raise ValueError(f"{name} must be finite")


def _require_fraction(name: str, value: float) -> None:
    _require_finite(name, value)
    if value < 0.0 or value > 1.0:
        raise ValueError(f"{name} must be within [0, 1]")


def _kelvin(celsius: float) -> float:
    kelvin = celsius + 273.15
    if kelvin <= 0.0:
        raise ValueError("temperature must remain above absolute zero")
    return kelvin


def validate_measurement(measurement: RadiativeCoolingMeasurement) -> None:
    for name, value in {
        "surface_temperature_c": measurement.surface_temperature_c,
        "air_temperature_c": measurement.air_temperature_c,
        "substrate_temperature_c": measurement.substrate_temperature_c,
        "solar_irradiance_w_m2": measurement.solar_irradiance_w_m2,
        "downwelling_longwave_w_m2": measurement.downwelling_longwave_w_m2,
        "convective_heat_transfer_w_m2_k": (
            measurement.convective_heat_transfer_w_m2_k
        ),
        "assembly_conductance_w_m2_k": (
            measurement.assembly_conductance_w_m2_k
        ),
        "surface_luminance_cd_m2": measurement.surface_luminance_cd_m2,
        "wet_friction_coefficient": measurement.wet_friction_coefficient,
        "dry_friction_coefficient": measurement.dry_friction_coefficient,
    }.items():
        _require_finite(name, value)

    for name, value in {
        "solar_reflectance": measurement.solar_reflectance,
        "infrared_emissivity": measurement.infrared_emissivity,
        "sky_view_factor": measurement.sky_view_factor,
        "sensor_confidence": measurement.sensor_confidence,
    }.items():
        _require_fraction(name, value)

    if measurement.solar_irradiance_w_m2 < 0.0:
        raise ValueError("solar_irradiance_w_m2 must not be negative")

    if measurement.downwelling_longwave_w_m2 < 0.0:
        raise ValueError("downwelling_longwave_w_m2 must not be negative")

    if measurement.convective_heat_transfer_w_m2_k < 0.0:
        raise ValueError("convective_heat_transfer_w_m2_k must not be negative")

    if measurement.assembly_conductance_w_m2_k < 0.0:
        raise ValueError("assembly_conductance_w_m2_k must not be negative")

    if measurement.surface_luminance_cd_m2 < 0.0:
        raise ValueError("surface_luminance_cd_m2 must not be negative")

    if measurement.wet_friction_coefficient < 0.0:
        raise ValueError("wet_friction_coefficient must not be negative")

    if measurement.dry_friction_coefficient < 0.0:
        raise ValueError("dry_friction_coefficient must not be negative")


def validate_baseline(baseline: RadiativeCoolingBaseline) -> None:
    _require_fraction(
        "initial_solar_reflectance",
        baseline.initial_solar_reflectance,
    )
    _require_fraction(
        "initial_infrared_emissivity",
        baseline.initial_infrared_emissivity,
    )
    _require_fraction(
        "control_solar_reflectance",
        baseline.control_solar_reflectance,
    )
    _require_finite(
        "control_surface_temperature_c",
        baseline.control_surface_temperature_c,
    )

    if baseline.initial_solar_reflectance <= 0.0:
        raise ValueError("initial_solar_reflectance must be positive")

    if baseline.initial_infrared_emissivity <= 0.0:
        raise ValueError("initial_infrared_emissivity must be positive")


def validate_policy(policy: CoolingVerificationPolicy) -> None:
    _require_fraction(
        "minimum_sensor_confidence",
        policy.minimum_sensor_confidence,
    )
    _require_fraction(
        "minimum_solar_reflectance_ratio",
        policy.minimum_solar_reflectance_ratio,
    )
    _require_fraction(
        "minimum_infrared_emissivity_ratio",
        policy.minimum_infrared_emissivity_ratio,
    )
    _require_fraction(
        "minimum_sky_view_factor_for_radiative_claim",
        policy.minimum_sky_view_factor_for_radiative_claim,
    )

    for name, value in {
        "maximum_surface_luminance_cd_m2": (
            policy.maximum_surface_luminance_cd_m2
        ),
        "minimum_wet_friction_coefficient": (
            policy.minimum_wet_friction_coefficient
        ),
        "minimum_dry_friction_coefficient": (
            policy.minimum_dry_friction_coefficient
        ),
        "reference_temperature_delta_c": (
            policy.reference_temperature_delta_c
        ),
    }.items():
        _require_finite(name, value)
        if value <= 0.0:
            raise ValueError(f"{name} must be positive")


def assess_radiative_cooling(
    measurement: RadiativeCoolingMeasurement,
    baseline: RadiativeCoolingBaseline,
    policy: CoolingVerificationPolicy = CoolingVerificationPolicy(),
) -> CoolingAssessment:
    validate_measurement(measurement)
    validate_baseline(baseline)
    validate_policy(policy)

    surface_temperature_k = _kelvin(measurement.surface_temperature_c)

    emitted_longwave_flux_w_m2 = (
        measurement.infrared_emissivity
        * STEFAN_BOLTZMANN_W_M2_K4
        * pow(surface_temperature_k, 4.0)
    )
    absorbed_solar_flux_w_m2 = (
        (1.0 - measurement.solar_reflectance)
        * measurement.solar_irradiance_w_m2
    )
    longwave_absorbed_flux_w_m2 = (
        measurement.infrared_emissivity
        * measurement.downwelling_longwave_w_m2
    )
    convective_flux_w_m2 = (
        measurement.convective_heat_transfer_w_m2_k
        * (measurement.surface_temperature_c - measurement.air_temperature_c)
    )
    conductive_flux_w_m2 = (
        measurement.assembly_conductance_w_m2_k
        * (
            measurement.surface_temperature_c
            - measurement.substrate_temperature_c
        )
    )
    net_surface_flux_w_m2 = (
        emitted_longwave_flux_w_m2
        - longwave_absorbed_flux_w_m2
        - absorbed_solar_flux_w_m2
        - convective_flux_w_m2
        - conductive_flux_w_m2
    )

    treatment_delta_c = (
        measurement.surface_temperature_c - measurement.air_temperature_c
    )
    control_delta_c = (
        baseline.control_surface_temperature_c - measurement.air_temperature_c
    )
    temperature_improvement = (
        control_delta_c - treatment_delta_c
    ) / policy.reference_temperature_delta_c
    cooling_score = _bounded(
        temperature_improvement * measurement.sensor_confidence,
        0.0,
        1.0,
    )

    solar_reflectance_ratio = (
        measurement.solar_reflectance / baseline.initial_solar_reflectance
    )
    infrared_emissivity_ratio = (
        measurement.infrared_emissivity / baseline.initial_infrared_emissivity
    )
    solar_reflectance_degradation = _bounded(
        1.0 - solar_reflectance_ratio,
        0.0,
        1.0,
    )
    infrared_emissivity_degradation = _bounded(
        1.0 - infrared_emissivity_ratio,
        0.0,
        1.0,
    )

    low_confidence = (
        measurement.sensor_confidence < policy.minimum_sensor_confidence
    )
    low_sky_visibility = (
        measurement.sky_view_factor
        < policy.minimum_sky_view_factor_for_radiative_claim
    )
    glare_risk = (
        measurement.surface_luminance_cd_m2
        > policy.maximum_surface_luminance_cd_m2
    )
    traction_risk = (
        measurement.wet_friction_coefficient
        < policy.minimum_wet_friction_coefficient
        or measurement.dry_friction_coefficient
        < policy.minimum_dry_friction_coefficient
    )
    optical_degradation = (
        solar_reflectance_ratio < policy.minimum_solar_reflectance_ratio
        or infrared_emissivity_ratio
        < policy.minimum_infrared_emissivity_ratio
    )

    if low_confidence:
        state = CoolingAssessmentState.SENSOR_REVIEW
        explanation = (
            "Cooling performance is not classified because measurement confidence "
            "is below the published verification threshold."
        )
    elif glare_risk or traction_risk:
        state = CoolingAssessmentState.SAFETY_REVIEW
        explanation = (
            "Thermal performance may not override pedestrian, rolling-access, "
            "cycling, visual-comfort, glare, or surface-traction requirements. "
            "Initiate an accessibility and safety review."
        )
    elif optical_degradation:
        state = CoolingAssessmentState.MAINTENANCE_REVIEW
        explanation = (
            "Measured optical properties have declined below the published "
            "performance-retention threshold. Inspect for soiling, weathering, "
            "coating damage, drainage issues, and cleaning or repair options."
        )
    elif low_sky_visibility:
        state = CoolingAssessmentState.MONITORING
        explanation = (
            "The installation has limited sky visibility. Continue paired thermal "
            "measurement, but do not make a strong radiative-cooling claim without "
            "geometry-aware longwave and control-surface verification."
        )
    else:
        state = CoolingAssessmentState.VERIFIED_PERFORMING
        explanation = (
            "The current measurement supports continued performance verification "
            "under the specified paired-control, optical-property, safety, and "
            "sensor-confidence conditions."
        )

    return CoolingAssessment(
        net_surface_flux_w_m2=net_surface_flux_w_m2,
        emitted_longwave_flux_w_m2=emitted_longwave_flux_w_m2,
        absorbed_solar_flux_w_m2=absorbed_solar_flux_w_m2,
        convective_flux_w_m2=convective_flux_w_m2,
        conductive_flux_w_m2=conductive_flux_w_m2,
        cooling_score=cooling_score,
        solar_reflectance_degradation=solar_reflectance_degradation,
        infrared_emissivity_degradation=infrared_emissivity_degradation,
        state=state,
        explanation=explanation,
    )
