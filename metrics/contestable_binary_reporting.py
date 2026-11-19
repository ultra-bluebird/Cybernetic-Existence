"""Research-only binary reporting with explicit missing-case bounds.

Run:
    python research/metrics/contestable_binary_reporting.py

No real case data, networking, storage, or external actions.
Wilson intervals assume independent binary observations.
Missing-case bounds concern the fixed declared eligible cohort.
"""

from dataclasses import dataclass
from math import sqrt
from statistics import NormalDist
import unittest


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
ATTRIBUTION_SCOPE = (
    "Document credit and workstream metadata only; not identity, consent, "
    "capability authorization, execution evidence, or legal authority."
)


@dataclass(frozen=True)
class BinaryCounts:
    eligible: int
    assessed: int
    events: int

    def __post_init__(self) -> None:
        for value in (self.eligible, self.assessed, self.events):
            if type(value) is not int:
                raise TypeError("Counts must be integers, not Boolean values.")
        if not 0 <= self.events <= self.assessed <= self.eligible:
            raise ValueError("Require 0 <= events <= assessed <= eligible.")

    @property
    def missing(self) -> int:
        return self.eligible - self.assessed


@dataclass(frozen=True)
class BinaryReport:
    eligible: int
    assessed: int
    events: int
    missing: int
    observed_proportion: float | None
    assessed_wilson_interval: tuple[float, float] | None
    fixed_cohort_missing_bounds: tuple[float, float] | None
    confidence_level: float
    interpretation_codes: tuple[str, ...]


def wilson_interval(
    events: int,
    assessed: int,
    confidence_level: float,
) -> tuple[float, float] | None:
    BinaryCounts(assessed, assessed, events)
    if (
        isinstance(confidence_level, bool)
        or not isinstance(confidence_level, (int, float))
        or not 0 < confidence_level < 1
    ):
        raise ValueError("Confidence level must be strictly between zero and one.")

    if assessed == 0:
        return None

    z = NormalDist().inv_cdf((1 + confidence_level) / 2)
    proportion = events / assessed
    denominator = 1 + z * z / assessed
    center = (proportion + z * z / (2 * assessed)) / denominator
    half_width = (
        z
        * sqrt(
            proportion * (1 - proportion) / assessed
            + z * z / (4 * assessed * assessed)
        )
        / denominator
    )
    return (
        max(0.0, center - half_width),
        min(1.0, center + half_width),
    )


def report_binary(
    counts: BinaryCounts,
    confidence_level: float = 0.95,
) -> BinaryReport:
    if not isinstance(counts, BinaryCounts):
        raise TypeError("Expected BinaryCounts.")

    interval = wilson_interval(
        counts.events, counts.assessed, confidence_level
    )
    observed = (
        counts.events / counts.assessed
        if counts.assessed > 0
        else None
    )
    missing_bounds = (
        (
            counts.events / counts.eligible,
            (counts.events + counts.missing) / counts.eligible,
        )
        if counts.eligible > 0
        else None
    )

    codes = [
        "counts_precede_percentages",
        "wilson_interval_is_for_assessed_binary_observations",
        "missing_bounds_are_not_a_confidence_interval",
        "no_inference_of_participant_credibility",
        "sampling_and_dependence_require_separate_review",
    ]
    if counts.assessed == 0:
        codes.append("observed_proportion_undefined")
    if counts.missing > 0:
        codes.append("eligible_outcomes_unresolved")
    if counts.eligible == 0:
        codes.append("no_declared_eligible_cases")

    return BinaryReport(
        eligible=counts.eligible,
        assessed=counts.assessed,
        events=counts.events,
        missing=counts.missing,
        observed_proportion=observed,
        assessed_wilson_interval=interval,
        fixed_cohort_missing_bounds=missing_bounds,
        confidence_level=float(confidence_level),
        interpretation_codes=tuple(codes),
    )


class ReportingTests(unittest.TestCase):
    def test_missing_cases_are_visible(self) -> None:
        result = report_binary(BinaryCounts(10, 5, 4))
        self.assertEqual(result.missing, 5)
        self.assertAlmostEqual(result.observed_proportion, 0.8)
        self.assertEqual(
            result.fixed_cohort_missing_bounds, (0.4, 0.9)
        )

    def test_zero_assessed_is_not_success(self) -> None:
        result = report_binary(BinaryCounts(5, 0, 0))
        self.assertIsNone(result.observed_proportion)
        self.assertIsNone(result.assessed_wilson_interval)
        self.assertEqual(
            result.fixed_cohort_missing_bounds, (0.0, 1.0)
        )

    def test_empty_cohort_is_undefined(self) -> None:
        result = report_binary(BinaryCounts(0, 0, 0))
        self.assertIsNone(result.fixed_cohort_missing_bounds)

    def test_no_missing_outcomes_gives_exact_cohort_fraction(self) -> None:
        result = report_binary(BinaryCounts(5, 5, 4))
        self.assertEqual(
            result.fixed_cohort_missing_bounds, (0.8, 0.8)
        )
        self.assertLess(result.assessed_wilson_interval[0], 0.8)
        self.assertGreater(result.assessed_wilson_interval[1], 0.8)

    def test_no_events_does_not_prove_zero_population_risk(self) -> None:
        result = report_binary(BinaryCounts(5, 5, 0))
        self.assertGreater(result.assessed_wilson_interval[1], 0.0)

    def test_all_events_does_not_prove_perfect_population_performance(self) -> None:
        result = report_binary(BinaryCounts(5, 5, 5))
        self.assertLess(result.assessed_wilson_interval[0], 1.0)

    def test_invalid_counts_rejected(self) -> None:
        with self.assertRaises(ValueError):
            BinaryCounts(5, 3, 4)
        with self.assertRaises(TypeError):
            BinaryCounts(True, 0, 0)

    def test_more_unresolved_cases_widens_fixed_cohort_bounds(self) -> None:
        complete = report_binary(BinaryCounts(5, 5, 4))
        incomplete = report_binary(BinaryCounts(10, 5, 4))
        self.assertLess(
            incomplete.fixed_cohort_missing_bounds[0],
            complete.fixed_cohort_missing_bounds[0],
        )
        self.assertGreater(
            incomplete.fixed_cohort_missing_bounds[1],
            complete.fixed_cohort_missing_bounds[1],
        )


if __name__ == "__main__":
    unittest.main()
