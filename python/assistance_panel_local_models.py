from __future__ import annotations

from dataclasses import dataclass
from typing import Final


ALLOWED_GESTURES: Final[set[str]] = {
    "open_home",
    "repeat_response",
    "increase_text_size",
    "decrease_text_size",
    "increase_volume",
    "decrease_volume",
    "request_help",
    "cancel",
}


@dataclass(frozen=True)
class LocalIntent:
    intent: str
    confidence: float
    requires_clarification: bool


@dataclass(frozen=True)
class GestureResult:
    gesture: str
    confidence: float
    accepted: bool


def normalize_local_intent(intent: str, confidence: float) -> LocalIntent:
    allowed_intents = {
        "find_cooling_center",
        "find_water_service",
        "find_accessible_transit",
        "find_public_restroom",
        "find_shelter",
        "find_city_service",
        "read_heat_alert",
        "read_emergency_guidance",
        "repeat_response",
        "privacy_notice",
    }

    if intent not in allowed_intents:
        return LocalIntent(
            intent="request_help",
            confidence=0.0,
            requires_clarification=True,
        )

    bounded_confidence = max(0.0, min(1.0, float(confidence)))
    return LocalIntent(
        intent=intent,
        confidence=bounded_confidence,
        requires_clarification=bounded_confidence < 0.70,
    )


def validate_gesture(gesture: str, confidence: float, shutter_open: bool) -> GestureResult:
    bounded_confidence = max(0.0, min(1.0, float(confidence)))
    accepted = (
        shutter_open
        and gesture in ALLOWED_GESTURES
        and bounded_confidence >= 0.80
    )
    return GestureResult(
        gesture=gesture if gesture in ALLOWED_GESTURES else "cancel",
        confidence=bounded_confidence,
        accepted=accepted,
    )


def aggregate_event_bucket(event_counts: dict[str, int], minimum_public_count: int = 10) -> dict[str, int | str]:
    if minimum_public_count < 1:
        raise ValueError("minimum_public_count must be positive")

    result: dict[str, int | str] = {}
    for event_name, count in event_counts.items():
        if count < 0:
            raise ValueError("event counts must be non-negative")
        result[event_name] = count if count >= minimum_public_count else "suppressed"
    return result
