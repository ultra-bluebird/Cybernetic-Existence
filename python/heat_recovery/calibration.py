from __future__ import annotations

from dataclasses import dataclass
from math import exp, isfinite
from typing import Iterable, Literal

SolarRegime = Literal["daytime_direct_solar", "nighttime_radiational_cooling"]


class CalibrationInputError(ValueError):
    """Raised when a calibration input is physically or mathematically invalid."""


@dataclass(frozen=True)
class CalibrationConstants:
    alpha: float
    beta_per_hour: float
    gamma: float
    delta: float

    def __post_init__(self) -> None:
        values = {
            "alpha": self.alpha,
            "beta_per_hour": self.beta_per_hour,
            "gamma": self.gamma,
            "delta": self.delta,
        }
        for name, value in values.items():
            if not isfinite(value):
                raise CalibrationInputError(f"{name} must be finite.")
        if self.alpha < 0:
            raise CalibrationInputError("alpha must be non-negative.")
        if self.beta_per_hour < 0:
            raise CalibrationInputError("beta_per_hour must be non-negative.")
        if self.delta < 0:
            raise CalibrationInputError("delta must be non-negative.")


@dataclass(frozen=True)
class VegetationPatch:
    leaf_area_index: float
    reflectance_coefficient: float
    distance_m: float

    def __post_init__(self) -> None:
        if not isfinite(self.leaf_area_index) or self.leaf_area_index < 0:
            raise CalibrationInputError("leaf_area_index must be finite and non-negative.")
        if (
            not isfinite(self.reflectance_coefficient)
            or not 0.0 <= self.reflectance_coefficient <= 1.0
        ):
            raise CalibrationInputError(
                "reflectance_coefficient must be finite and within [0.0, 1.0]."
            )
        if not isfinite(self.distance_m) or self.distance_m <= 0:
            raise CalibrationInputError("distance_m must be finite and greater than zero.")


@dataclass(frozen=True)
class CorridorObservation:
    thermal_lag_hours: float
    vegetation_condition_index: float
    built_mass_density_kg_m2: float
    radiative_cooling_efficiency: float
    regime: SolarRegime

    def __post_init__(self) -> None:
        if not isfinite(self.thermal_lag_hours) or self.thermal_lag_hours < 0:
            raise CalibrationInputError(
                "thermal_lag_hours must be finite and non-negative."
            )
        if (
            not isfinite(self.vegetation_condition_index)
            or not 0.0 <= self.vegetation_condition_index <= 1.0
        ):
            raise CalibrationInputError(
                "vegetation_condition_index must be finite and within [0.0, 1.0]."
            )
        if (
            not isfinite(self.built_mass_density_kg_m2)
            or self.built_mass_density_kg_m2 < 0
        ):
            raise CalibrationInputError(
                "built_mass_density_kg_m2 must be finite and non-negative."
            )
        if (
            not isfinite(self.radiative_cooling_efficiency)
            or not 0.0 <= self.radiative_cooling_efficiency <= 1.0
        ):
            raise CalibrationInputError(
                "radiative_cooling_efficiency must be finite and within [0.0, 1.0]."
            )
        if self.regime not in ("daytime_direct_solar", "nighttime_radiational_cooling"):
            raise CalibrationInputError("regime is not supported.")


@dataclass(frozen=True)
class RecoveryResult:
    coefficient: float
    vegetation_reflectance_term: float
    vegetation_condition_term: float
    built_mass_cooling_term: float
    lag_attenuation: float
    regime_multiplier: float


def _regime_multiplier(regime: SolarRegime) -> float:
    if regime == "daytime_direct_solar":
        return 1.0
    if regime == "nighttime_radiational_cooling":
        return 1.12
    raise CalibrationInputError("regime is not supported.")


def calculate_heat_recovery(
    patches: Iterable[VegetationPatch],
    observation: CorridorObservation,
    constants: CalibrationConstants,
) -> RecoveryResult:
    """
    Calculate the normalized corridor heat-island recovery coefficient.

    H_recovery =
        regime_multiplier * alpha * sum((Ai * Ri / di^2) * exp(-beta * Tlag))
        + gamma * VCI
        - delta * Bm * eta_cool
    """
    patch_list = tuple(patches)
    if not patch_list:
        raise CalibrationInputError("At least one vegetation patch is required.")

    attenuation = exp(-constants.beta_per_hour * observation.thermal_lag_hours)
    spatial_sum = sum(
        (patch.leaf_area_index * patch.reflectance_coefficient)
        / (patch.distance_m * patch.distance_m)
        for patch in patch_list
    )
    multiplier = _regime_multiplier(observation.regime)

    vegetation_reflectance_term = (
        multiplier * constants.alpha * spatial_sum * attenuation
    )
    vegetation_condition_term = (
        constants.gamma * observation.vegetation_condition_index
    )
    built_mass_cooling_term = (
        constants.delta
        * observation.built_mass_density_kg_m2
        * observation.radiative_cooling_efficiency
    )
    coefficient = (
        vegetation_reflectance_term
        + vegetation_condition_term
        - built_mass_cooling_term
    )

    return RecoveryResult(
        coefficient=coefficient,
        vegetation_reflectance_term=vegetation_reflectance_term,
        vegetation_condition_term=vegetation_condition_term,
        built_mass_cooling_term=built_mass_cooling_term,
        lag_attenuation=attenuation,
        regime_multiplier=multiplier,
    )
