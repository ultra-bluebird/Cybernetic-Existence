from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from math import isfinite, pow
from typing import Mapping


class SoundClass(str, Enum):
    ROAD_TRAFFIC = "road_traffic"
    RAIL = "rail"
    AIRCRAFT = "aircraft"
    CONSTRUCTION = "construction"
    SIREN = "siren"
    HORN = "horn"
    MECHANICAL = "mechanical"
    AMPLIFIED_SOUND = "amplified_sound"
    BIOPHONY = "biophony"
    GEOPHONY = "geophony"
    UNKNOWN = "unknown"


@dataclass(frozen=True)
class AcousticMeasurement:
    timestamp_unix_s: int
    grid_cell: str
    laeq_db_a: float
    lafmax_db_a: float
    lcpeak_db_c: float
    quiet_minutes: float
    sensitive_minutes: float
    baseline_laeq_db_a: float
    sensor_confidence: float
    event_confidence: float
    dominant_sound_class: SoundClass
    octave_band_db: Mapping[str, float]


@dataclass(frozen=True)
class AcousticAssessment:
    restoration_index: float
    linear_energy_excess_ratio: float
    peak_exposure_flag: bool
    quiet_time_fraction: float
    classification_usable: bool
    explanation: str


@dataclass(frozen=True)
class AcousticPolicy:
    reference_excess_db: float = 20.0
    minimum_sensor_confidence: float = 0.70
    minimum_event_confidence: float = 0.75
    peak_attention_db_c: float = 105.0
    quiet_threshold_db_a: float = 50.0


def _bounded(value: float, minimum: float, maximum: float) -> float:
    return max(minimum, min(value, maximum))


def _require_finite(name: str, value: float) -> None:
    if not isfinite(value):
        raise ValueError(f"{name} must be finite")


def validate_measurement(measurement: AcousticMeasurement) -> None:
    if measurement.timestamp_unix_s <= 0:
        raise ValueError("timestamp_unix_s must be positive")

    if not measurement.grid_cell.strip():
        raise ValueError("grid_cell must be non-empty")

    for name, value in {
        "laeq_db_a": measurement.laeq_db_a,
        "lafmax_db_a": measurement.lafmax_db_a,
        "lcpeak_db_c": measurement.lcpeak_db_c,
        "quiet_minutes": measurement.quiet_minutes,
        "sensitive_minutes": measurement.sensitive_minutes,
        "baseline_laeq_db_a": measurement.baseline_laeq_db_a,
        "sensor_confidence": measurement.sensor_confidence,
        "event_confidence": measurement.event_confidence,
    }.items():
        _require_finite(name, value)

    if measurement.sensitive_minutes <= 0.0:
        raise ValueError("sensitive_minutes must be positive")

    if measurement.quiet_minutes < 0.0:
        raise ValueError("quiet_minutes must not be negative")

    if measurement.quiet_minutes > measurement.sensitive_minutes:
        raise ValueError("quiet_minutes must not exceed sensitive_minutes")

    if not 0.0 <= measurement.sensor_confidence <= 1.0:
        raise ValueError("sensor_confidence must be within [0, 1]")

    if not 0.0 <= measurement.event_confidence <= 1.0:
        raise ValueError("event_confidence must be within [0, 1]")

    for band, level in measurement.octave_band_db.items():
        if not band.strip():
            raise ValueError("octave-band label must be non-empty")
        _require_finite(f"octave_band_db[{band}]", level)


def assess_soundscape(
    measurement: AcousticMeasurement,
    policy: AcousticPolicy = AcousticPolicy(),
) -> AcousticAssessment:
    validate_measurement(measurement)

    if policy.reference_excess_db <= 0.0:
        raise ValueError("reference_excess_db must be positive")

    level_excess_db = measurement.laeq_db_a - measurement.baseline_laeq_db_a
    normalized_excess = _bounded(
        level_excess_db / policy.reference_excess_db,
        0.0,
        1.0,
    )
    quiet_time_fraction = _bounded(
        measurement.quiet_minutes / measurement.sensitive_minutes,
        0.0,
        1.0,
    )
    restoration_index = normalized_excess * (1.0 - quiet_time_fraction)
    linear_energy_excess_ratio = pow(10.0, level_excess_db / 10.0)

    classification_usable = (
        measurement.sensor_confidence >= policy.minimum_sensor_confidence
        and measurement.event_confidence >= policy.minimum_event_confidence
    )
    peak_exposure_flag = measurement.lcpeak_db_c >= policy.peak_attention_db_c

    if not classification_usable:
        explanation = (
            "Acoustic level measurements are retained, but event classification is "
            "not suitable for public source attribution until sensor or model "
            "confidence is restored."
        )
    elif peak_exposure_flag:
        explanation = (
            "The soundscape includes an elevated impulsive peak. Review source "
            "category, time pattern, and mitigation options without identifying "
            "or profiling people."
        )
    elif restoration_index >= 0.50:
        explanation = (
            "The location has sustained sound above its contextual baseline and "
            "limited quiet time during the selected sensitive period."
        )
    else:
        explanation = (
            "The location currently has moderate contextual acoustic excess or "
            "retains meaningful quiet time during the selected sensitive period."
        )

    return AcousticAssessment(
        restoration_index=restoration_index,
        linear_energy_excess_ratio=linear_energy_excess_ratio,
        peak_exposure_flag=peak_exposure_flag,
        quiet_time_fraction=quiet_time_fraction,
        classification_usable=classification_usable,
        explanation=explanation,
    )
