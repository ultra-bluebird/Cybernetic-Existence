from __future__ import annotations

from dataclasses import dataclass
from typing import Sequence
import math


@dataclass(frozen=True)
class CrossingConfiguration:
    intersection_public_code: int
    crossing_public_code: int
    walk_duration_seconds: float
    clearance_duration_seconds: float
    audible_enabled: bool
    tactile_enabled: bool
    bluetooth_supplement_enabled: bool
    tactile_arrow_parallel_to_crossing: bool
    manual_pushbutton_available: bool
    visual_signal_available: bool


@dataclass(frozen=True)
class ValidationResult:
    valid: bool
    reasons: tuple[str, ...]


def validate_configuration(
    configuration: CrossingConfiguration,
) -> ValidationResult:
    reasons: list[str] = []

    if configuration.intersection_public_code < 0:
        reasons.append("Intersection public code must be non-negative.")

    if configuration.crossing_public_code < 0:
        reasons.append("Crossing public code must be non-negative.")

    for label, value in {
        "walk_duration_seconds": configuration.walk_duration_seconds,
        "clearance_duration_seconds": configuration.clearance_duration_seconds,
    }.items():
        if not math.isfinite(value) or value <= 0.0:
            reasons.append(f"{label} must be finite and greater than zero.")

    if not configuration.visual_signal_available:
        reasons.append(
            "A visual pedestrian signal is required; Bluetooth cannot replace it."
        )

    if not configuration.manual_pushbutton_available:
        reasons.append(
            "A physical pedestrian pushbutton is required for independent access."
        )

    if not configuration.audible_enabled:
        reasons.append(
            "Audible APS indication must remain available independently of Bluetooth."
        )

    if not configuration.tactile_enabled:
        reasons.append(
            "Tactile APS indication must remain available independently of Bluetooth."
        )

    if not configuration.tactile_arrow_parallel_to_crossing:
        reasons.append(
            "The tactile arrow must align with the associated crossing direction."
        )

    if configuration.bluetooth_supplement_enabled and not (
        configuration.audible_enabled
        and configuration.tactile_enabled
        and configuration.visual_signal_available
    ):
        reasons.append(
            "Bluetooth may only operate as a supplement to standard APS channels."
        )

    return ValidationResult(
        valid=not reasons,
        reasons=tuple(reasons),
    )
