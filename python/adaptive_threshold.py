from __future__ import annotations

from dataclasses import dataclass
from statistics import median
from typing import Iterable

@dataclass(frozen=True)
class ThresholdPolicy:
    minimum: float
    maximum: float
    target_error_rate: float
    learning_rate: float
    max_step: float
    minimum_trusted_samples: int

@dataclass
class AdaptiveThreshold:
    policy: ThresholdPolicy
    current: float

    def update(self, trusted_error_rates: Iterable[float]) -> float:
        samples = list(trusted_error_rates)

        if len(samples) < self.policy.minimum_trusted_samples:
            return self.current

        if any(not 0.0 <= value <= 1.0 for value in samples):
            raise ValueError("trusted_error_rates must be within [0, 1]")

        robust_error_rate = median(samples)
        proposed_delta = self.policy.learning_rate * (
            robust_error_rate - self.policy.target_error_rate
        )

        bounded_delta = max(
            -self.policy.max_step,
            min(self.policy.max_step, proposed_delta),
        )

        self.current = max(
            self.policy.minimum,
            min(self.policy.maximum, self.current + bounded_delta),
        )

        return self.current

def hard_reject(
    *,
    unknown_field: bool,
    signature_valid: bool,
    nonce_fresh: bool,
    lease_active: bool,
    generation_revoked: bool,
    authority_expanded: bool,
    raw_payload_audit_write: bool,
) -> bool:
    return (
        unknown_field
        or not signature_valid
        or not nonce_fresh
        or not lease_active
        or generation_revoked
        or authority_expanded
        or raw_payload_audit_write
    )

def requires_quarantine(
    *,
    anomaly_score: float,
    threshold: float,
    deterministic_reject: bool,
) -> bool:
    if not 0.0 <= anomaly_score <= 1.0:
        raise ValueError("anomaly_score must be within [0, 1]")

    return deterministic_reject or anomaly_score >= threshold
