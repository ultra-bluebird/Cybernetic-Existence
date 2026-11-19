# SPDX-License-Identifier: MIT OR Apache-2.0
"""Learning-model scenarios and voluntary native-time proposals."""

from dataclasses import dataclass
from fractions import Fraction
import math
import unittest


VERSION = "1.0.0"


def finite_number(value, name):
    if type(value) not in (int, float):
        raise ValueError(f"{name}: ordinary integer or float required")
    try:
        result = float(value)
    except (OverflowError, ValueError) as exc:
        raise ValueError(f"{name}: unsupported numeric magnitude") from exc
    if not math.isfinite(result):
        raise ValueError(f"{name}: finite value required")
    return result


def time_to_target(initial_skill, target_skill, learning_rate):
    """Return model time units, not labor hours or validated mastery."""
    initial = finite_number(initial_skill, "initial_skill")
    target = finite_number(target_skill, "target_skill")
    rate = finite_number(learning_rate, "learning_rate")

    if not 0 <= initial <= target < 1:
        raise ValueError("require 0 <= initial <= target < 1")
    if rate <= 0:
        raise ValueError("learning_rate must be positive")
    if initial == target:
        return 0.0

    result = (
        math.log1p(-initial) - math.log1p(-target)
    ) / rate
    if not math.isfinite(result):
        raise ValueError("time-to-target exceeds supported numeric range")
    return result


def readiness_scenario(initial_skill, target_skill, base_rate, multiplier):
    rate = finite_number(base_rate, "base_rate")
    factor = finite_number(multiplier, "multiplier")
    if factor <= 0:
        raise ValueError("multiplier must be positive")

    comparison = time_to_target(initial_skill, target_skill, rate)
    augmented = time_to_target(
        initial_skill, target_skill, rate * factor
    )
    return {
        "engine_version": VERSION,
        "classification": "model_scenario_not_observed_learning_effect",
        "comparison_time": comparison,
        "augmented_time": augmented,
        "signed_earlier_readiness": comparison - augmented,
        "time_unit": "same_unit_as_inverse_learning_rate",
        "saved_labor": "not_established",
        "available_capacity": "not_inferred",
    }


def nonnegative_minutes(value, name):
    if type(value) is not int or not 0 <= value <= 1_000_000:
        raise ValueError(f"{name}: bounded nonnegative integer required")


@dataclass(frozen=True)
class AvailabilityDeclaration:
    """One prespecified period; None means unavailable as numeric evidence."""
    available_minutes: int | None
    response_state: str

    def __post_init__(self):
        allowed = {
            "declared",
            "uncertain_without_estimate",
            "prefer_not_to_answer",
            "missing",
        }
        if type(self.response_state) is not str or self.response_state not in allowed:
            raise ValueError("unsupported response state")
        if self.response_state == "declared":
            nonnegative_minutes(self.available_minutes, "available_minutes")
        elif self.available_minutes is not None:
            raise ValueError("unanswered availability must not be imputed")


def contribution_proposal(declaration, rate, cap_minutes):
    if type(declaration) is not AvailabilityDeclaration:
        raise ValueError("typed availability declaration required")
    if type(rate) is not Fraction or not 0 <= rate <= 1:
        raise ValueError("exact chosen rate between zero and one required")
    nonnegative_minutes(cap_minutes, "cap_minutes")

    if declaration.response_state != "declared":
        return {
            "engine_version": VERSION,
            "status": "no_numeric_proposal",
            "availability_state": declaration.response_state,
            "proposed_minutes": None,
            "operational_authority": "not_granted",
        }

    exact = min(
        rate * declaration.available_minutes,
        Fraction(cap_minutes),
    )
    rounded_down = exact.numerator // exact.denominator
    return {
        "engine_version": VERSION,
        "status": "voluntary_proposal_not_completed_contribution",
        "availability_state": declaration.response_state,
        "proposed_minutes": rounded_down,
        "rounding": "down_to_whole_minute",
        "obligation_created": False,
        "operational_authority": "not_granted",
    }


class AccountingTests(unittest.TestCase):
    def test_hypothetical_learning_times(self):
        scenario = readiness_scenario(0, 0.8, 0.1, 3)
        self.assertAlmostEqual(
            scenario["comparison_time"], -math.log(0.2) / 0.1
        )
        self.assertAlmostEqual(
            scenario["augmented_time"],
            scenario["comparison_time"] / 3,
        )

    def test_slower_learning_is_not_clamped_to_a_gain(self):
        scenario = readiness_scenario(0, 0.8, 0.1, 0.5)
        self.assertLess(scenario["signed_earlier_readiness"], 0)

    def test_existing_target_requires_no_model_time(self):
        self.assertEqual(time_to_target(0.8, 0.8, 0.1), 0)

    def test_invalid_model_inputs_rejected(self):
        for target in (1, float("nan"), float("inf"), True):
            with self.assertRaises(ValueError):
                time_to_target(0, target, 0.1)

    def test_proposal_is_capped_and_not_authorized(self):
        declaration = AvailabilityDeclaration(120, "declared")
        result = contribution_proposal(declaration, Fraction(1, 5), 15)
        self.assertEqual(result["proposed_minutes"], 15)
        self.assertEqual(result["operational_authority"], "not_granted")

    def test_zero_rate_is_valid(self):
        declaration = AvailabilityDeclaration(120, "declared")
        result = contribution_proposal(declaration, Fraction(0), 120)
        self.assertEqual(result["proposed_minutes"], 0)
        self.assertFalse(result["obligation_created"])

    def test_missing_availability_is_not_zero(self):
        declaration = AvailabilityDeclaration(None, "missing")
        result = contribution_proposal(declaration, Fraction(1, 5), 120)
        self.assertIsNone(result["proposed_minutes"])

    def test_unknown_cannot_contain_imputed_minutes(self):
        with self.assertRaises(ValueError):
            AvailabilityDeclaration(0, "uncertain_without_estimate")


if __name__ == "__main__":
    unittest.main()
