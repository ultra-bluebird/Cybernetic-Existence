from __future__ import annotations

from dataclasses import dataclass
from math import isfinite


class QueueingValidationError(ValueError):
    pass


@dataclass(frozen=True)
class AnonymousCrosswalkQueueResult:
    arrival_rate_per_s: float
    service_rate_per_s: float
    mean_wait_s: float
    stable: bool
    ble_identity_used: bool
    identity_data_retained: bool


def anonymous_mm1_wait_time(
    arrival_rate_per_s: float,
    service_rate_per_s: float,
) -> AnonymousCrosswalkQueueResult:
    if not isfinite(arrival_rate_per_s) or not isfinite(service_rate_per_s):
        raise QueueingValidationError("Arrival and service rates must be finite.")

    if arrival_rate_per_s < 0.0:
        raise QueueingValidationError("arrival_rate_per_s must be non-negative.")

    if service_rate_per_s <= 0.0:
        raise QueueingValidationError("service_rate_per_s must be positive.")

    if arrival_rate_per_s >= service_rate_per_s:
        return AnonymousCrosswalkQueueResult(
            arrival_rate_per_s=arrival_rate_per_s,
            service_rate_per_s=service_rate_per_s,
            mean_wait_s=float("inf"),
            stable=False,
            ble_identity_used=False,
            identity_data_retained=False,
        )

    mean_wait_s = arrival_rate_per_s / (
        service_rate_per_s * (service_rate_per_s - arrival_rate_per_s)
    )

    return AnonymousCrosswalkQueueResult(
        arrival_rate_per_s=arrival_rate_per_s,
        service_rate_per_s=service_rate_per_s,
        mean_wait_s=mean_wait_s,
        stable=True,
        ble_identity_used=False,
        identity_data_retained=False,
    )
