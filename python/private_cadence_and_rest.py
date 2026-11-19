from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from math import cos, isfinite, pi
from threading import RLock


def seconds(value: float, field: str) -> None:
    if (
        isinstance(value, bool)
        or not isinstance(value, (int, float))
        or not isfinite(value)
        or value < 0
    ):
        raise ValueError(f"{field} must be finite non-negative seconds.")


def positive(value: float, field: str) -> None:
    seconds(value, field)
    if value <= 0:
        raise ValueError(f"{field} must be positive.")


def text(value: str, field: str) -> None:
    if not isinstance(value, str) or not value.strip() or len(value) > 4096:
        raise ValueError(f"{field} must be non-empty text within the limit.")


@dataclass(frozen=True)
class ReminderOpportunity:
    private_only: bool
    audible_notification: bool
    automatic_followup: bool = False
    absence_reporting: bool = False


class PrivateCadence:
    """On-demand local timing; no logs, callbacks, or missed-event count."""

    def __init__(self) -> None:
        self._interval: float | None = None
        self._next: float | None = None
        self._silent = True
        self._last_time = 0.0
        self._lock = RLock()

    def _now(self, now_s: float) -> None:
        seconds(now_s, "Current time")
        if now_s < self._last_time:
            raise ValueError("The local clock cannot move backwards.")
        self._last_time = now_s

    def configure(
        self,
        *,
        interval_s: float,
        silent: bool,
        explicit: bool,
        now_s: float,
    ) -> None:
        positive(interval_s, "Interval")
        if type(silent) is not bool:
            raise ValueError("Silent mode must be boolean.")
        if explicit is not True:
            raise PermissionError("Participant selection is required.")
        with self._lock:
            self._now(now_s)
            next_s = now_s + interval_s
            if not isfinite(next_s):
                raise ValueError("Next reminder time must be finite.")
            self._interval = interval_s
            self._next = next_s
            self._silent = silent

    def take_opportunity(self, now_s: float) -> ReminderOpportunity | None:
        with self._lock:
            self._now(now_s)
            if self._interval is None or self._next is None:
                return None
            if now_s < self._next:
                return None
            next_s = now_s + self._interval
            if not isfinite(next_s):
                self.disable()
                raise ValueError("Next reminder time must be finite.")
            self._next = next_s
            return ReminderOpportunity(
                private_only=True,
                audible_notification=not self._silent,
            )

    def defer(self, *, delay_s: float, now_s: float) -> None:
        positive(delay_s, "Deferral")
        with self._lock:
            self._now(now_s)
            if self._interval is None:
                raise PermissionError("Cadence is disabled.")
            next_s = now_s + delay_s
            if not isfinite(next_s):
                raise ValueError("Deferred time must be finite.")
            self._next = next_s

    def disable(self) -> None:
        with self._lock:
            self._interval = None
            self._next = None
            self._silent = True


class Resource(str, Enum):
    REST = "rest"
    WATER = "drinking_water"
    FOOD = "food_access"
    CLIMATE = "climate_safety_location"


@dataclass(frozen=True)
class ResourcePathway:
    resource: Resource
    available: bool
    accessible: bool
    fallback: str

    def __post_init__(self) -> None:
        if not isinstance(self.resource, Resource):
            raise ValueError("Unsupported resource.")
        if type(self.available) is not bool or type(self.accessible) is not bool:
            raise ValueError("Availability declarations must be booleans.")
        text(self.fallback, "Accessible fallback")

    def access_status(self) -> dict[str, object]:
        usable = self.available and self.accessible
        return {
            "resource": self.resource.value,
            "status": "pathway_available" if usable else "fallback_required",
            "justification_required": False,
            "private_disclosure_required": False,
            "fallback": self.fallback,
            "physical_availability_independently_verified": False,
        }


class CueStyle(str, Enum):
    ANIMATED = "optional_smooth_visual"
    STATIC = "static_pause"


@dataclass(frozen=True)
class CueSettings:
    style: CueStyle
    cycle_seconds: float
    minimum_size_px: float
    maximum_size_px: float

    def __post_init__(self) -> None:
        if not isinstance(self.style, CueStyle):
            raise ValueError("Unsupported cue style.")
        positive(self.cycle_seconds, "Visual cycle duration")
        positive(self.minimum_size_px, "Minimum size")
        positive(self.maximum_size_px, "Maximum size")
        if self.maximum_size_px < self.minimum_size_px:
            raise ValueError("Maximum size cannot be smaller than minimum.")


class OptionalBreathingCue:
    """Visual descriptor only; no physiological input or state inference."""

    def __init__(self, settings: CueSettings) -> None:
        if not isinstance(settings, CueSettings):
            raise ValueError("Use validated cue settings.")
        self._settings = settings
        self._start: float | None = None
        self._last_time = 0.0
        self._lock = RLock()

    def _now(self, now_s: float) -> None:
        seconds(now_s, "Current time")
        if now_s < self._last_time:
            raise ValueError("The local clock cannot move backwards.")
        self._last_time = now_s

    def start(self, *, explicit: bool, now_s: float) -> None:
        if explicit is not True:
            raise PermissionError("Participant start is required.")
        with self._lock:
            self._now(now_s)
            self._start = now_s

    def stop(self) -> None:
        with self._lock:
            self._start = None

    def describe(self, now_s: float) -> dict[str, object]:
        with self._lock:
            self._now(now_s)
            if self._start is None:
                return {"status": "stopped", "size_px": None}

            if self._settings.style == CueStyle.STATIC:
                return {
                    "status": "optional_static_pause",
                    "size_px": self._settings.minimum_size_px,
                    "state_claim": None,
                }

            phase = (
                (now_s - self._start) % self._settings.cycle_seconds
            ) / self._settings.cycle_seconds
            weight = (1 - cos(2 * pi * phase)) / 2
            size = (
                self._settings.minimum_size_px
                + (self._settings.maximum_size_px
                   - self._settings.minimum_size_px) * weight
            )
            return {
                "status": "optional_visual_cycle",
                "size_px": size,
                "state_claim": None,
                "observed_breathing": False,
            }
