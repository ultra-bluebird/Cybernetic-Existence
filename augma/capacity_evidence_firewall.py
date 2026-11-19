# SPDX-License-Identifier: MIT OR Apache-2.0
"""Local capacity-commons decision and evidence kernel."""

from dataclasses import dataclass
from enum import Enum
from fractions import Fraction
import unittest


class DispatchResult(str, Enum):
    BLOCKED = "blocked"
    UNRESOLVED = "unresolved"
    ELIGIBLE_FOR_ATOMIC_RESERVATION = "eligible_for_atomic_reservation"


@dataclass(frozen=True)
class DispatchSnapshot:
    consented: bool | None
    paused: bool | None
    permitted: bool | None
    within_cap: bool | None
    cooldown_satisfied: bool | None

    def __post_init__(self):
        for value in (
            self.consented,
            self.paused,
            self.permitted,
            self.within_cap,
            self.cooldown_satisfied,
        ):
            if value is not None and type(value) is not bool:
                raise ValueError("predicates must be Boolean or None")


def assess_dispatch(snapshot: DispatchSnapshot) -> DispatchResult:
    """Assessment only; authoritative atomic rechecking remains required."""
    if type(snapshot) is not DispatchSnapshot:
        raise ValueError("invalid dispatch snapshot")

    requirements = (
        snapshot.consented,
        None if snapshot.paused is None else not snapshot.paused,
        snapshot.permitted,
        snapshot.within_cap,
        snapshot.cooldown_satisfied,
    )
    if any(value is False for value in requirements):
        return DispatchResult.BLOCKED
    if any(value is None for value in requirements):
        return DispatchResult.UNRESOLVED
    return DispatchResult.ELIGIBLE_FOR_ATOMIC_RESERVATION


def validate_counts(assigned: int, completed: int, unknown: int) -> None:
    for value in (assigned, completed, unknown):
        if type(value) is not int or value < 0:
            raise ValueError("counts must be nonnegative integers")
    if completed + unknown > assigned:
        raise ValueError("completed and unknown exceed assigned")


def participation_bounds(
    assigned: int, completed: int, unknown: int
) -> tuple[Fraction | None, Fraction | None]:
    validate_counts(assigned, completed, unknown)
    if assigned == 0:
        return None, None
    return (
        Fraction(completed, assigned),
        Fraction(completed + unknown, assigned),
    )


def sensitivity(
    assigned: int,
    completed: int,
    unknown: int,
    theta: Fraction,
) -> Fraction | None:
    validate_counts(assigned, completed, unknown)
    if type(theta) is not Fraction or not 0 <= theta <= 1:
        raise ValueError("theta must be an exact Fraction between zero and one")
    if assigned == 0:
        return None
    return (completed + theta * unknown) / assigned


class FirewallTests(unittest.TestCase):
    def test_pause_blocks_even_with_other_unknowns(self):
        snapshot = DispatchSnapshot(None, True, None, None, None)
        self.assertEqual(assess_dispatch(snapshot), DispatchResult.BLOCKED)

    def test_unknown_is_not_permission(self):
        snapshot = DispatchSnapshot(True, False, True, None, True)
        self.assertEqual(assess_dispatch(snapshot), DispatchResult.UNRESOLVED)

    def test_eligibility_is_not_execution(self):
        snapshot = DispatchSnapshot(True, False, True, True, True)
        self.assertEqual(
            assess_dispatch(snapshot),
            DispatchResult.ELIGIBLE_FOR_ATOMIC_RESERVATION,
        )

    def test_sensitivity_endpoints_match_bounds(self):
        for assigned in range(12):
            for completed in range(assigned + 1):
                for unknown in range(assigned - completed + 1):
                    lower, upper = participation_bounds(
                        assigned, completed, unknown
                    )
                    self.assertEqual(
                        sensitivity(assigned, completed, unknown, Fraction(0)),
                        lower,
                    )
                    self.assertEqual(
                        sensitivity(assigned, completed, unknown, Fraction(1)),
                        upper,
                    )

    def test_undefined_is_preserved(self):
        self.assertEqual(participation_bounds(0, 0, 0), (None, None))

    def test_invalid_counts_rejected(self):
        for values in ((True, 0, 0), (2, 2, 1), (-1, 0, 0)):
            with self.assertRaises(ValueError):
                participation_bounds(*values)


if __name__ == "__main__":
    unittest.main()
