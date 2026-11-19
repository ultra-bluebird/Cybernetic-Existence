from __future__ import annotations

from dataclasses import dataclass
from math import isfinite


class RestroomMaintenanceValidationError(ValueError):
    pass


@dataclass(frozen=True)
class RestroomSensorEvent:
    timestamp_s: float
    event_type: str
    sensor_health_valid: bool
    tamper_detected: bool = False

    def __post_init__(self) -> None:
        if not isfinite(self.timestamp_s) or self.timestamp_s < 0.0:
            raise RestroomMaintenanceValidationError(
                "timestamp_s must be finite and non-negative."
            )

        allowed_event_types = {
            "entry",
            "exit",
            "door_open",
            "door_closed",
            "manual_cleaning_confirmed",
            "sensor_heartbeat",
        }
        if self.event_type not in allowed_event_types:
            raise RestroomMaintenanceValidationError("event_type is not supported.")


@dataclass(frozen=True)
class RestroomMaintenanceDecision:
    state: str
    cumulative_usage: int
    estimated_occupancy: int
    cleaning_review_requested: bool
    door_lock_action_permitted: bool
    reason: str


@dataclass
class RestroomMaintenanceState:
    maximum_plausible_occupancy: int
    usage_threshold: int = 50
    maximum_clean_interval_s: float = 4.0 * 60.0 * 60.0
    cumulative_usage: int = 0
    estimated_occupancy: int = 0
    last_cleaning_confirmed_at_s: float | None = None
    count_uncertain: bool = False

    def __post_init__(self) -> None:
        if self.maximum_plausible_occupancy <= 0:
            raise RestroomMaintenanceValidationError(
                "maximum_plausible_occupancy must be positive."
            )
        if self.usage_threshold <= 0:
            raise RestroomMaintenanceValidationError("usage_threshold must be positive.")
        if (
            not isfinite(self.maximum_clean_interval_s)
            or self.maximum_clean_interval_s <= 0.0
        ):
            raise RestroomMaintenanceValidationError(
                "maximum_clean_interval_s must be finite and positive."
            )

    def observe(self, event: RestroomSensorEvent) -> RestroomMaintenanceDecision:
        if event.tamper_detected or not event.sensor_health_valid:
            self.count_uncertain = True
            return self._decision(
                state="SENSOR_TAMPER_OR_FAULT",
                now_s=event.timestamp_s,
                reason=(
                    "Sensor integrity is uncertain. Continue time-based maintenance review "
                    "and request repair without restricting restroom access."
                ),
            )

        if event.event_type == "manual_cleaning_confirmed":
            self.cumulative_usage = 0
            self.estimated_occupancy = 0
            self.last_cleaning_confirmed_at_s = event.timestamp_s
            self.count_uncertain = False
            return self._decision(
                state="CLEANING_CONFIRMED",
                now_s=event.timestamp_s,
                reason="Staff confirmed cleaning; usage counter was reset.",
            )

        if event.event_type == "entry":
            self.cumulative_usage += 1
            self.estimated_occupancy += 1
        elif event.event_type == "exit":
            self.estimated_occupancy -= 1

        if (
            self.estimated_occupancy < 0
            or self.estimated_occupancy > self.maximum_plausible_occupancy
        ):
            self.count_uncertain = True
            self.estimated_occupancy = min(
                max(self.estimated_occupancy, 0),
                self.maximum_plausible_occupancy,
            )
            return self._decision(
                state="COUNT_UNCERTAIN",
                now_s=event.timestamp_s,
                reason=(
                    "The anonymous count exceeded a physical plausibility bound. "
                    "Maintenance review is requested without door control."
                ),
            )

        return self._decision(
            state="COUNT_UNCERTAIN" if self.count_uncertain else "NOMINAL",
            now_s=event.timestamp_s,
            reason=(
                "Anonymous maintenance state updated. Sensor state does not authorize "
                "door locking or user restriction."
            ),
        )

    def _decision(
        self,
        state: str,
        now_s: float,
        reason: str,
    ) -> RestroomMaintenanceDecision:
        elapsed_since_cleaning = (
            float("inf")
            if self.last_cleaning_confirmed_at_s is None
            else now_s - self.last_cleaning_confirmed_at_s
        )

        cleaning_due = (
            self.cumulative_usage > self.usage_threshold
            or elapsed_since_cleaning > self.maximum_clean_interval_s
            or self.count_uncertain
        )

        if cleaning_due and state == "NOMINAL":
            state = "MAINTENANCE_REVIEW_REQUESTED"

        return RestroomMaintenanceDecision(
            state=state,
            cumulative_usage=self.cumulative_usage,
            estimated_occupancy=self.estimated_occupancy,
            cleaning_review_requested=cleaning_due,
            door_lock_action_permitted=False,
            reason=reason,
        )
