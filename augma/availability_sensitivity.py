# SPDX-License-Identifier: MIT OR Apache-2.0
"""Exact occasion-weighted availability analysis; no imputed record mutation."""

from dataclasses import dataclass
from fractions import Fraction
import unittest


VERSION = "1.0.0"
MISSING_REASONS = (
    "uncertain_without_estimate",
    "prefer_not_to_answer",
    "no_response",
    "observation_unavailable",
)
MAX_COUNT = 9_007_199_254_740_991


def nonnegative_integer(value, name):
    if type(value) is not int or not 0 <= value <= MAX_COUNT:
        raise ValueError(f"{name}: bounded nonnegative integer required")


def ratio(value):
    if value is None:
        return {"status": "undefined", "value": None}
    if type(value) is not Fraction:
        raise ValueError("exact Fraction required")
    return {
        "status": "defined",
        "value": {
            "numerator": value.numerator,
            "denominator": value.denominator,
        },
    }


@dataclass(frozen=True)
class AvailabilityPanel:
    assigned: int
    numeric_responses: int
    observed_sum_minutes: int
    uncertain_without_estimate: int
    prefer_not_to_answer: int
    no_response: int
    observation_unavailable: int
    maximum_minutes_per_occasion: int

    def __post_init__(self):
        for name in self.__dataclass_fields__:
            nonnegative_integer(getattr(self, name), name)

        missing = sum(getattr(self, reason) for reason in MISSING_REASONS)
        if self.numeric_responses + missing != self.assigned:
            raise ValueError("response categories must partition assigned occasions")

        upper = self.numeric_responses * self.maximum_minutes_per_occasion
        if self.observed_sum_minutes > upper:
            raise ValueError("observed sum exceeds the declared availability cap")
        if self.numeric_responses == 0 and self.observed_sum_minutes != 0:
            raise ValueError("no numeric responses cannot contain observed minutes")


def describe(panel):
    if type(panel) is not AvailabilityPanel:
        raise ValueError("typed availability panel required")

    observed_mean = (
        Fraction(panel.observed_sum_minutes, panel.numeric_responses)
        if panel.numeric_responses else None
    )
    coverage = (
        Fraction(panel.numeric_responses, panel.assigned)
        if panel.assigned else None
    )
    missing_count = panel.assigned - panel.numeric_responses

    return {
        "engine_version": VERSION,
        "estimand": "mean_declared_availability_per_assigned_occasion",
        "unit": "minute",
        "weighting": "equal_weight_per_assigned_occasion",
        "assigned_occasions": panel.assigned,
        "numeric_responses": panel.numeric_responses,
        "missingness": {
            reason: getattr(panel, reason) for reason in MISSING_REASONS
        },
        "numeric_coverage": ratio(coverage),
        "observed_case_mean": ratio(observed_mean),
        "full_panel_mean": (
            ratio(Fraction(panel.observed_sum_minutes, panel.assigned))
            if panel.assigned and missing_count == 0
            else ratio(None)
        ),
        "missingness_policy": "unobserved_values_not_replaced_by_zero",
        "augmentation_effect": "not_established",
        "contribution_offer": "not_inferred",
        "operational_authority": "not_granted",
    }


def sensitivity(panel, assumed_missing_means):
    """Assumptions affect analysis only, never the aggregate observation record."""
    if type(panel) is not AvailabilityPanel:
        raise ValueError("typed availability panel required")
    if type(assumed_missing_means) is not dict:
        raise ValueError("assumptions must be a dictionary")
    if set(assumed_missing_means) != set(MISSING_REASONS):
        raise ValueError("one explicit assumption per missingness category required")

    for reason, value in assumed_missing_means.items():
        if type(value) is not Fraction:
            raise ValueError(f"{reason}: exact Fraction assumption required")
        if not 0 <= value <= panel.maximum_minutes_per_occasion:
            raise ValueError(f"{reason}: assumption outside declared cap")

    expected_total = Fraction(panel.observed_sum_minutes)
    for reason in MISSING_REASONS:
        expected_total += (
            getattr(panel, reason) * assumed_missing_means[reason]
        )

    assumed_mean = (
        expected_total / panel.assigned if panel.assigned else None
    )
    return {
        "engine_version": VERSION,
        "estimand": "assumption_based_mean_per_assigned_occasion",
        "unit": "minute",
        "assumed_missing_means": {
            reason: ratio(assumed_missing_means[reason])
            for reason in MISSING_REASONS
        },
        "mean_under_assumptions": ratio(assumed_mean),
        "interpretation": "sensitivity_result_not_observed_mean",
        "sampling_confidence_interval": False,
        "operational_authority": "not_granted",
    }


def bounded_mean(panel):
    """Missing-outcome bounds under the declared common availability cap."""
    zero = {reason: Fraction(0) for reason in MISSING_REASONS}
    upper = {
        reason: Fraction(panel.maximum_minutes_per_occasion)
        for reason in MISSING_REASONS
    }
    return {
        "lower": sensitivity(panel, zero)["mean_under_assumptions"],
        "upper": sensitivity(panel, upper)["mean_under_assumptions"],
        "interpretation": "missing_outcome_bounds_not_confidence_interval",
    }


class SensitivityTests(unittest.TestCase):
    def panel(self):
        return AvailabilityPanel(
            assigned=10,
            numeric_responses=6,
            observed_sum_minutes=120,
            uncertain_without_estimate=1,
            prefer_not_to_answer=1,
            no_response=1,
            observation_unavailable=1,
            maximum_minutes_per_occasion=60,
        )

    def test_observed_mean_and_coverage(self):
        report = describe(self.panel())
        self.assertEqual(
            report["observed_case_mean"]["value"],
            {"numerator": 20, "denominator": 1},
        )
        self.assertEqual(
            report["numeric_coverage"]["value"],
            {"numerator": 3, "denominator": 5},
        )
        self.assertEqual(report["full_panel_mean"]["status"], "undefined")

    def test_sensitivity_does_not_mutate_observed_data(self):
        panel = self.panel()
        before = describe(panel)
        assumptions = {reason: Fraction(10) for reason in MISSING_REASONS}
        result = sensitivity(panel, assumptions)
        self.assertEqual(
            result["mean_under_assumptions"]["value"],
            {"numerator": 16, "denominator": 1},
        )
        self.assertEqual(describe(panel), before)

    def test_bounds(self):
        bounds = bounded_mean(self.panel())
        self.assertEqual(
            bounds["lower"]["value"],
            {"numerator": 12, "denominator": 1},
        )
        self.assertEqual(
            bounds["upper"]["value"],
            {"numerator": 36, "denominator": 1},
        )

    def test_no_numeric_responses_is_not_zero_availability(self):
        panel = AvailabilityPanel(1, 0, 0, 0, 0, 1, 0, 60)
        self.assertEqual(
            describe(panel)["observed_case_mean"]["status"], "undefined"
        )

    def test_zero_assigned_is_undefined(self):
        panel = AvailabilityPanel(0, 0, 0, 0, 0, 0, 0, 60)
        self.assertEqual(
            bounded_mean(panel)["lower"]["status"], "undefined"
        )

    def test_partition_and_boolean_rejected(self):
        with self.assertRaises(ValueError):
            AvailabilityPanel(2, 1, 0, 0, 0, 0, 0, 60)
        with self.assertRaises(ValueError):
            AvailabilityPanel(True, 0, 0, 0, 0, 1, 0, 60)

    def test_missing_assumption_rejected(self):
        with self.assertRaises(ValueError):
            sensitivity(self.panel(), {})


if __name__ == "__main__":
    unittest.main()
