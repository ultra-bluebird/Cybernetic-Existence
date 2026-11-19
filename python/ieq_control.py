from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from math import exp, isfinite
from typing import Mapping


class OperatingMode(str, Enum):
    NORMAL = "normal"
    OUTDOOR_PARTICLE_EVENT = "outdoor_particle_event"
    INDOOR_SOURCE_EVENT = "indoor_source_event"
    SENSOR_DEGRADED = "sensor_degraded"
    MAINTENANCE_REQUIRED = "maintenance_required"


@dataclass(frozen=True)
class IEQMeasurement:
    timestamp_unix_s: int
    indoor_co2_ppm: float
    indoor_pm25_ug_m3: float
    indoor_pm10_ug_m3: float
    indoor_tvoc_ppb: float
    indoor_temperature_c: float
    indoor_relative_humidity_percent: float
    outdoor_pm25_ug_m3: float
    filter_pressure_drop_pa: float
    supply_airflow_m3_s: float
    occupancy_estimate: float
    sensor_confidence: Mapping[str, float]


@dataclass(frozen=True)
class IEQConfiguration:
    co2_target_ppm: float = 900.0
    co2_max_ppm: float = 1400.0
    pm25_target_ug_m3: float = 10.0
    pm25_max_ug_m3: float = 35.0
    pm10_target_ug_m3: float = 45.0
    tvoc_target_ppb: float = 300.0
    temperature_target_c: float = 22.0
    temperature_deadband_c: float = 1.5
    humidity_min_percent: float = 30.0
    humidity_max_percent: float = 60.0
    outdoor_pm25_event_ug_m3: float = 35.0
    filter_pressure_drop_service_pa: float = 250.0
    minimum_outdoor_air_fraction: float = 0.15
    maximum_outdoor_air_fraction: float = 1.0
    minimum_fan_fraction: float = 0.30
    maximum_fan_fraction: float = 1.0
    minimum_sensor_confidence: float = 0.65


@dataclass(frozen=True)
class ControlCommand:
    mode: OperatingMode
    outdoor_air_fraction: float
    supply_fan_fraction: float
    thermal_setpoint_c: float
    portable_cleaner_enabled: bool
    maintenance_required: bool
    explanation: str


def _bounded(value: float, minimum: float, maximum: float) -> float:
    return max(minimum, min(value, maximum))


def _require_finite(name: str, value: float) -> None:
    if not isfinite(value):
        raise ValueError(f"{name} must be finite")
    if value < 0.0:
        raise ValueError(f"{name} must not be negative")


def validate_measurement(measurement: IEQMeasurement) -> None:
    if measurement.timestamp_unix_s <= 0:
        raise ValueError("timestamp_unix_s must be positive")

    values = {
        "indoor_co2_ppm": measurement.indoor_co2_ppm,
        "indoor_pm25_ug_m3": measurement.indoor_pm25_ug_m3,
        "indoor_pm10_ug_m3": measurement.indoor_pm10_ug_m3,
        "indoor_tvoc_ppb": measurement.indoor_tvoc_ppb,
        "indoor_relative_humidity_percent": measurement.indoor_relative_humidity_percent,
        "outdoor_pm25_ug_m3": measurement.outdoor_pm25_ug_m3,
        "filter_pressure_drop_pa": measurement.filter_pressure_drop_pa,
        "supply_airflow_m3_s": measurement.supply_airflow_m3_s,
        "occupancy_estimate": measurement.occupancy_estimate,
    }

    for name, value in values.items():
        _require_finite(name, value)

    if not isfinite(measurement.indoor_temperature_c):
        raise ValueError("indoor_temperature_c must be finite")

    if measurement.indoor_co2_ppm < 250.0 or measurement.indoor_co2_ppm > 10000.0:
        raise ValueError("indoor_co2_ppm is outside the accepted operational range")

    if measurement.indoor_relative_humidity_percent > 100.0:
        raise ValueError("indoor_relative_humidity_percent must not exceed 100")

    for sensor_name, confidence in measurement.sensor_confidence.items():
        if not sensor_name:
            raise ValueError("sensor confidence entries require a sensor name")
        if not isfinite(confidence) or confidence < 0.0 or confidence > 1.0:
            raise ValueError("sensor confidence must be within [0, 1]")


def _confidence(measurement: IEQMeasurement, sensor_name: str) -> float:
    return measurement.sensor_confidence.get(sensor_name, 0.0)


def _severity(value: float, target: float, maximum: float) -> float:
    if maximum <= target:
        raise ValueError("maximum must exceed target")
    return _bounded((value - target) / (maximum - target), 0.0, 1.0)


def _smoke_response_fraction(
    measurement: IEQMeasurement,
    configuration: IEQConfiguration,
) -> float:
    outdoor_excess = _severity(
        measurement.outdoor_pm25_ug_m3,
        configuration.pm25_target_ug_m3,
        configuration.outdoor_pm25_event_ug_m3,
    )
    attenuation = exp(-2.2 * outdoor_excess)
    return _bounded(
        configuration.minimum_outdoor_air_fraction
        + (
            configuration.maximum_outdoor_air_fraction
            - configuration.minimum_outdoor_air_fraction
        )
        * attenuation,
        configuration.minimum_outdoor_air_fraction,
        configuration.maximum_outdoor_air_fraction,
    )


def decide_control(
    measurement: IEQMeasurement,
    configuration: IEQConfiguration = IEQConfiguration(),
) -> ControlCommand:
    validate_measurement(measurement)

    essential_sensor_confidence = min(
        _confidence(measurement, "co2"),
        _confidence(measurement, "pm25"),
        _confidence(measurement, "outdoor_pm25"),
        _confidence(measurement, "filter_pressure"),
    )

    filter_requires_service = (
        measurement.filter_pressure_drop_pa
        >= configuration.filter_pressure_drop_service_pa
    )

    if filter_requires_service:
        return ControlCommand(
            mode=OperatingMode.MAINTENANCE_REQUIRED,
            outdoor_air_fraction=configuration.minimum_outdoor_air_fraction,
            supply_fan_fraction=configuration.maximum_fan_fraction,
            thermal_setpoint_c=configuration.temperature_target_c,
            portable_cleaner_enabled=True,
            maintenance_required=True,
            explanation=(
                "Filter pressure drop has reached the published service threshold. "
                "Maintain protective airflow, enable supplementary cleaning, and "
                "request filter inspection or replacement."
            ),
        )

    if essential_sensor_confidence < configuration.minimum_sensor_confidence:
        return ControlCommand(
            mode=OperatingMode.SENSOR_DEGRADED,
            outdoor_air_fraction=configuration.minimum_outdoor_air_fraction,
            supply_fan_fraction=0.70,
            thermal_setpoint_c=configuration.temperature_target_c,
            portable_cleaner_enabled=True,
            maintenance_required=True,
            explanation=(
                "One or more essential IEQ measurements has insufficient confidence. "
                "Use a conservative protective operating state and request sensor "
                "inspection, co-location comparison, or calibration."
            ),
        )

    indoor_pm25_severity = _severity(
        measurement.indoor_pm25_ug_m3,
        configuration.pm25_target_ug_m3,
        configuration.pm25_max_ug_m3,
    )
    co2_severity = _severity(
        measurement.indoor_co2_ppm,
        configuration.co2_target_ppm,
        configuration.co2_max_ppm,
    )
    outdoor_particle_event = (
        measurement.outdoor_pm25_ug_m3
        >= configuration.outdoor_pm25_event_ug_m3
    )
    indoor_particle_event = (
        measurement.indoor_pm25_ug_m3 >= configuration.pm25_max_ug_m3
        or measurement.indoor_pm10_ug_m3 >= configuration.pm10_target_ug_m3 * 1.5
    )
    elevated_tvoc = measurement.indoor_tvoc_ppb >= configuration.tvoc_target_ppb

    temperature_offset = (
        measurement.indoor_temperature_c - configuration.temperature_target_c
    )
    thermal_setpoint = _bounded(
        configuration.temperature_target_c - 0.30 * temperature_offset,
        configuration.temperature_target_c - configuration.temperature_deadband_c,
        configuration.temperature_target_c + configuration.temperature_deadband_c,
    )

    if outdoor_particle_event:
        outdoor_air_fraction = _smoke_response_fraction(measurement, configuration)
        fan_fraction = _bounded(
            0.55 + 0.35 * max(indoor_pm25_severity, co2_severity),
            configuration.minimum_fan_fraction,
            configuration.maximum_fan_fraction,
        )
        return ControlCommand(
            mode=OperatingMode.OUTDOOR_PARTICLE_EVENT,
            outdoor_air_fraction=outdoor_air_fraction,
            supply_fan_fraction=fan_fraction,
            thermal_setpoint_c=thermal_setpoint,
            portable_cleaner_enabled=True,
            maintenance_required=False,
            explanation=(
                "Outdoor particle concentrations are elevated. Reduce outdoor-air "
                "intake within configured safety bounds, increase filtered "
                "recirculation, and activate supplementary air cleaning."
            ),
        )

    if indoor_particle_event or elevated_tvoc:
        outdoor_air_fraction = _bounded(
            configuration.minimum_outdoor_air_fraction + 0.45,
            configuration.minimum_outdoor_air_fraction,
            configuration.maximum_outdoor_air_fraction,
        )
        return ControlCommand(
            mode=OperatingMode.INDOOR_SOURCE_EVENT,
            outdoor_air_fraction=outdoor_air_fraction,
            supply_fan_fraction=configuration.maximum_fan_fraction,
            thermal_setpoint_c=thermal_setpoint,
            portable_cleaner_enabled=True,
            maintenance_required=True,
            explanation=(
                "Indoor particle or volatile-organic levels indicate a possible "
                "source event. Increase clean-air delivery, investigate the source, "
                "and preserve an accessible maintenance record."
            ),
        )

    outdoor_air_fraction = _bounded(
        configuration.minimum_outdoor_air_fraction + 0.75 * co2_severity,
        configuration.minimum_outdoor_air_fraction,
        configuration.maximum_outdoor_air_fraction,
    )
    fan_fraction = _bounded(
        configuration.minimum_fan_fraction
        + 0.45 * max(co2_severity, indoor_pm25_severity),
        configuration.minimum_fan_fraction,
        configuration.maximum_fan_fraction,
    )

    return ControlCommand(
        mode=OperatingMode.NORMAL,
        outdoor_air_fraction=outdoor_air_fraction,
        supply_fan_fraction=fan_fraction,
        thermal_setpoint_c=thermal_setpoint,
        portable_cleaner_enabled=indoor_pm25_severity > 0.25,
        maintenance_required=False,
        explanation=(
            "Indoor and outdoor measurements support normal demand-responsive "
            "operation with bounded outdoor-air intake, filtration, thermal control, "
            "and non-identifying occupancy-aware ventilation."
        ),
    )
