from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Iterable


class ChargingAllocationValidationError(ValueError):
    pass


@dataclass(frozen=True)
class ChargingSession:
    session_label: str
    technical_maximum_current_a: float
    requested_current_a: float
    vin_retained: bool = False
    driver_identity_retained: bool = False
    payment_tier_used: bool = False
    vehicle_history_retained: bool = False
    residential_ranking_used: bool = False

    def __post_init__(self) -> None:
        if not self.session_label.strip():
            raise ChargingAllocationValidationError(
                "session_label must be non-empty."
            )

        for field_name, value in (
            ("technical_maximum_current_a", self.technical_maximum_current_a),
            ("requested_current_a", self.requested_current_a),
        ):
            if not isfinite(value) or value < 0.0:
                raise ChargingAllocationValidationError(
                    f"{field_name} must be finite and non-negative."
                )

        if self.requested_current_a > self.technical_maximum_current_a:
            raise ChargingAllocationValidationError(
                "requested_current_a must not exceed technical_maximum_current_a."
            )


@dataclass(frozen=True)
class ChargingAllocation:
    session_label: str
    allocated_current_a: float


@dataclass(frozen=True)
class AllocationResult:
    allocations: tuple[ChargingAllocation, ...]
    total_allocated_current_a: float
    unused_current_a: float
    vin_retained: bool
    driver_identity_retained: bool
    payment_tier_used: bool
    residential_ranking_used: bool


def allocate_max_min_current(
    sessions: Iterable[ChargingSession],
    available_site_current_a: float,
) -> AllocationResult:
    active_sessions = list(sessions)

    if not active_sessions:
        raise ChargingAllocationValidationError(
            "At least one active charging session is required."
        )
    if not isfinite(available_site_current_a) or available_site_current_a < 0.0:
        raise ChargingAllocationValidationError(
            "available_site_current_a must be finite and non-negative."
        )

    if any(
        (
            session.vin_retained,
            session.driver_identity_retained,
            session.payment_tier_used,
            session.vehicle_history_retained,
            session.residential_ranking_used,
        )
        for session in active_sessions
    ):
        raise ChargingAllocationValidationError(
            "Identity, VIN, payment tier, vehicle history, and residential ranking are prohibited."
        )

    caps = [
        min(session.technical_maximum_current_a, session.requested_current_a)
        for session in active_sessions
    ]
    allocations = [0.0 for _ in active_sessions]
    remaining_current = available_site_current_a
    unallocated = set(range(len(active_sessions)))

    while unallocated and remaining_current > 0.0:
        equal_share = remaining_current / len(unallocated)
        capped = {
            index
            for index in unallocated
            if caps[index] <= allocations[index] + equal_share
        }

        if not capped:
            for index in unallocated:
                allocations[index] += equal_share
            remaining_current = 0.0
            break

        for index in capped:
            increment = caps[index] - allocations[index]
            allocations[index] += increment
            remaining_current -= increment

        unallocated -= capped

    structured_allocations = tuple(
        ChargingAllocation(
            session_label=session.session_label,
            allocated_current_a=allocation,
        )
        for session, allocation in zip(active_sessions, allocations, strict=True)
    )

    total_allocated = sum(item.allocated_current_a for item in structured_allocations)
    return AllocationResult(
        allocations=structured_allocations,
        total_allocated_current_a=total_allocated,
        unused_current_a=max(0.0, available_site_current_a - total_allocated),
        vin_retained=False,
        driver_identity_retained=False,
        payment_tier_used=False,
        residential_ranking_used=False,
    )
