# SPDX-License-Identifier: MIT OR Apache-2.0
"""Local missingness review, not mechanism identification or imputation.

Attribution: bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
Credit only; no consent, authentication, or external authority.
"""

from collections import Counter
from dataclasses import asdict, dataclass, replace
from fractions import Fraction
import re
import unittest


STATES = frozenset({
    "observed",
    "missing",
    "buffer_overflow",
    "censored",
    "withheld",
    "not_applicable",
})

MECHANISMS = frozenset({
    "undetermined",
    "MCAR_assumed",
    "MAR_assumed",
    "MNAR_sensitivity",
})

PRIVACY_CLASSES = frozenset({
    "host-local",
    "primitives-only",
    "bounded-telemetry",
    "host-released",
})


def text(value):
    return (
        type(value) is str
        and 0 < len(value.strip()) <= 512
    )


def decimal_fraction(value):
    """Accept bounded finite decimal text; reject floats and booleans."""
    pattern = r"-?(?:0|[1-9][0-9]{0,29})(?:\.[0-9]{1,12})?"
    if (
        type(value) is not str
        or re.fullmatch(pattern, value) is None
    ):
        raise ValueError("bounded finite decimal text required")
    return Fraction(value)


@dataclass(frozen=True)
class AnalysisContext:
    quantity: str
    unit: str
    estimand_reference: str
    window_reference: str
    frame_reference: str
    source_reference: str
    privacy_class: str
    retention_reference: str

    def __post_init__(self):
        required = (
            self.quantity,
            self.unit,
            self.estimand_reference,
            self.window_reference,
            self.frame_reference,
            self.source_reference,
            self.retention_reference,
        )
        if not all(text(value) for value in required):
            raise ValueError("quantity, units, and scope references required")
        if self.privacy_class not in PRIVACY_CLASSES:
            raise ValueError("unsupported privacy class")


@dataclass(frozen=True)
class ObservationSlot:
    state: str
    value: str | None
    basis_reference: str | None

    def __post_init__(self):
        if self.state not in STATES:
            raise ValueError("unsupported observation state")

        if (
            self.basis_reference is not None
            and not text(self.basis_reference)
        ):
            raise ValueError("invalid basis reference")

        if self.state == "observed":
            decimal_fraction(self.value)
        elif self.value is not None:
            raise ValueError(
                "non-observed value must remain null; "
                "store censoring information in its scoped basis"
            )

        if (
            self.state == "not_applicable"
            and self.basis_reference is None
        ):
            raise ValueError("non-applicability needs a review basis")


def review_missingness(
    slots,
    context,
    *,
    frame_complete,
    mechanism="undetermined",
    mechanism_basis_reference=None,
    value_bounds=None,
    bounds_basis_reference=None,
):
    """Review known slots for an equally weighted arithmetic-mean target.

    frame_complete is a caller-supplied assertion, not independently verified.
    Bounds are declared value bounds, not standard uncertainties.
    Censoring-specific bounds are not interpreted by this implementation.
    """
    if not (
        type(slots) is tuple
        and 0 < len(slots) <= 4096
        and all(type(slot) is ObservationSlot for slot in slots)
    ):
        raise ValueError("1..4096 typed observation slots required")

    if type(context) is not AnalysisContext:
        raise ValueError("typed analysis context required")

    if type(frame_complete) is not bool:
        raise ValueError("frame_complete must be boolean")

    if mechanism not in MECHANISMS:
        raise ValueError("unsupported mechanism declaration")

    if (
        mechanism_basis_reference is not None
        and not text(mechanism_basis_reference)
    ):
        raise ValueError("invalid mechanism basis")

    if (
        mechanism != "undetermined"
        and mechanism_basis_reference is None
    ):
        raise ValueError("mechanism assumptions need a basis")

    lower = upper = None
    if value_bounds is None:
        if bounds_basis_reference is not None:
            raise ValueError("bounds basis supplied without bounds")
    else:
        if not (
            type(value_bounds) is tuple
            and len(value_bounds) == 2
            and text(bounds_basis_reference)
        ):
            raise ValueError("two bounds and their basis required")

        lower, upper = (
            decimal_fraction(value) for value in value_bounds
        )
        if lower > upper:
            raise ValueError("reversed value bounds")

    counts = Counter(slot.state for slot in slots)
    observed = tuple(
        decimal_fraction(slot.value)
        for slot in slots
        if slot.state == "observed"
    )

    if lower is not None and any(
        value < lower or value > upper for value in observed
    ):
        raise ValueError("observed value outside declared global bounds")

    eligible_count = len(slots) - counts["not_applicable"]
    unresolved_count = eligible_count - len(observed)
    observed_sum = sum(observed, Fraction(0))

    observed_mean = (
        None
        if not observed
        else str(observed_sum / len(observed))
    )
    known_frame_fraction = (
        None
        if eligible_count == 0
        else str(Fraction(len(observed), eligible_count))
    )

    mean_bounds = None
    if (
        frame_complete
        and eligible_count > 0
        and lower is not None
    ):
        mean_bounds = {
            "lower_exact": str(
                (observed_sum + unresolved_count * lower)
                / eligible_count
            ),
            "upper_exact": str(
                (observed_sum + unresolved_count * upper)
                / eligible_count
            ),
            "interpretation": (
                "conditional complete-frame identification bounds; "
                "not a confidence interval"
            ),
        }

    overflow_slots = counts["buffer_overflow"]
    return {
        "context": asdict(context),
        "submitted_slots": [asdict(slot) for slot in slots],
        "state_counts": {
            state: counts[state] for state in sorted(STATES)
        },
        "known_eligible_slots": eligible_count,
        "known_unresolved_slots": unresolved_count,
        "known_frame_observed_fraction_exact": known_frame_fraction,
        "fraction_scope": "known supplied frame only",
        "frame_complete_as_declared": frame_complete,
        "frame_completeness_verified": False,
        "observed_only_mean_exact": observed_mean,
        "declared_mechanism": mechanism,
        "mechanism_basis_reference": mechanism_basis_reference,
        "mechanism_inferred_from_data": False,
        "recorded_overflow_slots": overflow_slots,
        "overflow_disclosure": (
            "overflow recorded; unlisted losses not assessed"
            if overflow_slots
            else "no overflow slots supplied; absence not established"
        ),
        "value_bounds_as_declared": value_bounds,
        "bounds_basis_reference": bounds_basis_reference,
        "complete_frame_mean_bounds": mean_bounds,
        "nonapplicability_basis_authenticity": "not established",
        "scientific_adequacy": "requires separate review",
        "imputation_performed": False,
        "publication_authorized": False,
        "external_action_authorized": False,
    }


class MissingnessReviewTests(unittest.TestCase):
    """Synthetic expectations only; execution must be reported separately."""

    def setUp(self):
        self.context = AnalysisContext(
            quantity="synthetic concentration",
            unit="mg/L",
            estimand_reference="synthetic equal-weight mean",
            window_reference="synthetic reporting window",
            frame_reference="synthetic four-opportunity design",
            source_reference="synthetic source",
            privacy_class="host-local",
            retention_reference="synthetic local retention policy",
        )
        self.slots = (
            ObservationSlot("observed", "2", "synthetic reading"),
            ObservationSlot("observed", "4", "synthetic reading"),
            ObservationSlot("buffer_overflow", None, "synthetic log"),
            ObservationSlot("buffer_overflow", None, "synthetic log"),
        )

    def review(self, **changes):
        arguments = {
            "frame_complete": True,
            "value_bounds": ("0", "20"),
            "bounds_basis_reference": "synthetic physical bounds",
        }
        arguments.update(changes)
        return review_missingness(
            self.slots, self.context, **arguments
        )

    def test_conditional_bounds(self):
        result = self.review()
        self.assertEqual(result["observed_only_mean_exact"], "3")
        bounds = result["complete_frame_mean_bounds"]
        self.assertEqual(bounds["lower_exact"], "3/2")
        self.assertEqual(bounds["upper_exact"], "23/2")

    def test_overflow_is_disclosed(self):
        self.assertEqual(self.review()["recorded_overflow_slots"], 2)

    def test_mechanism_is_not_inferred(self):
        result = self.review()
        self.assertEqual(result["declared_mechanism"], "undetermined")
        self.assertFalse(result["mechanism_inferred_from_data"])

    def test_incomplete_frame_withholds_full_mean_bounds(self):
        result = self.review(frame_complete=False)
        self.assertIsNone(result["complete_frame_mean_bounds"])

    def test_assumption_needs_basis(self):
        with self.assertRaises(ValueError):
            self.review(mechanism="MAR_assumed")

    def test_global_bounds_must_include_observed_values(self):
        with self.assertRaises(ValueError):
            self.review(value_bounds=("0", "1"))

    def test_nonapplicability_needs_basis(self):
        with self.assertRaises(ValueError):
            ObservationSlot("not_applicable", None, None)

    def test_no_imputation_or_authority(self):
        result = self.review()
        self.assertFalse(result["imputation_performed"])
        self.assertFalse(result["external_action_authorized"])

    def test_input_preservation(self):
        before = self.slots
        self.review()
        self.assertEqual(self.slots, before)

    def test_float_rejected(self):
        with self.assertRaises(ValueError):
            ObservationSlot("observed", 2.0, "synthetic reading")

    def test_censored_value_is_not_an_observed_number(self):
        with self.assertRaises(ValueError):
            ObservationSlot("censored", "1", "synthetic detection limit")

    def test_all_unresolved_keeps_observed_mean_null(self):
        slots = (
            ObservationSlot("missing", None, None),
            ObservationSlot("withheld", None, None),
        )
        result = review_missingness(
            slots, self.context, frame_complete=True
        )
        self.assertIsNone(result["observed_only_mean_exact"])


if __name__ == "__main__":
    unittest.main()
