from __future__ import annotations

from dataclasses import dataclass, field
from math import isfinite

MIN_EVIDENCE = 8
ELIGIBLE_THRESHOLD = 0.60
QUARANTINE_THRESHOLD = -0.50

@dataclass
class ComponentConfidence:
    component_id: str
    learning_rate: float
    score: float = 0.0
    observations: int = 0
    verified_integrity_violation: bool = False
    recent_events: list[float] = field(default_factory=list)

    def observe(
        self,
        event_score: float,
        verified_integrity_violation: bool = False,
    ) -> None:
        if not isfinite(event_score) or not -1.0 <= event_score <= 1.0:
            raise ValueError("event_score must be finite and within [-1, 1]")

        if not 0.0 < self.learning_rate <= 1.0:
            raise ValueError("learning_rate must be within (0, 1]")

        self.score = max(
            -1.0,
            min(
                1.0,
                (1.0 - self.learning_rate) * self.score
                + self.learning_rate * event_score,
            ),
        )

        self.observations += 1
        self.verified_integrity_violation = (
            self.verified_integrity_violation or verified_integrity_violation
        )
        self.recent_events.append(event_score)

        if len(self.recent_events) > 32:
            self.recent_events.pop(0)

    def eligible(self) -> bool:
        return (
            self.observations >= MIN_EVIDENCE
            and self.score >= ELIGIBLE_THRESHOLD
            and not self.verified_integrity_violation
        )

    def quarantined(self) -> bool:
        return (
            self.observations >= MIN_EVIDENCE
            and (
                self.score <= QUARANTINE_THRESHOLD
                or self.verified_integrity_violation
            )
        )

    def disposition(self) -> str:
        if self.quarantined():
            return "QUARANTINE_REVIEW"
        if self.eligible():
            return "ELIGIBLE_FOR_SIMULATOR_QUORUM"
        return "INSUFFICIENT_OR_MIXED_EVIDENCE"
