"""Tests for replay-bound wording inspection.

Python 3.10 or newer; standard library only.
SPDX-License-Identifier: MIT OR Apache-2.0
"""

from itertools import product
import unittest

from research.world_save.correction_replay import Event, replay
from research.world_save.wording_inspection import inspect_history


def make_events(kinds):
    events = []
    current = ""

    for position, kind in enumerate(kinds, 1):
        if kind == "establish":
            replacement = "Synthetic accepted milestone."
        elif kind in {"wording_revision", "correct_record"}:
            replacement = f"Synthetic wording at position {position}."
        else:
            replacement = ""

        events.append(Event(
            sequence=position,
            kind=kind,
            expected_revision=position - 1,
            previous_text=current,
            replacement_text=replacement,
            reason="Synthetic regression fixture.",
        ))

        if kind in {"establish", "wording_revision", "correct_record"}:
            current = replacement

    return tuple(events)


class WordingInspectionTests(unittest.TestCase):
    def test_empty_history_is_unavailable(self):
        result = inspect_history((), "Any displayed statement.")
        self.assertEqual(
            result["comparison_outcome"], "reference_unavailable"
        )
        self.assertFalse(result["historical_acceptance_recorded"])

    def test_all_kind_histories_through_length_six(self):
        count = 1
        suffix_kinds = (
            "wording_revision",
            "correct_record",
            "person_change",
            "material_change",
        )

        for length in range(1, 7):
            for suffix in product(suffix_kinds, repeat=length - 1):
                kinds = ("establish",) + suffix
                events = make_events(kinds)

                with self.subTest(kinds=kinds):
                    projection = replay(events)

                    replacements = [
                        event.replacement_text
                        for event in events
                        if event.kind in {
                            "establish",
                            "wording_revision",
                            "correct_record",
                        }
                    ]
                    expected_text = replacements[-1]
                    expected_attribution = (
                        "record_corrected"
                        if "correct_record" in kinds
                        else "accepted_in_record"
                    )

                    self.assertEqual(projection["revision"], length)
                    self.assertEqual(
                        projection["current_wording"], expected_text
                    )
                    self.assertEqual(
                        projection["current_attribution"],
                        expected_attribution,
                    )

                    result = inspect_history(events, expected_text)
                    self.assertEqual(
                        result["comparison_outcome"],
                        "matches_replayed_wording",
                    )
                    self.assertFalse(
                        result["accepted_origin_authenticated"]
                    )

                count += 1

        expected_count = 1 + (4**6 - 1) // 3
        self.assertEqual(count, expected_count)

    def test_invalid_history_is_not_used_as_reference(self):
        events = make_events(("establish",))
        with self.assertRaises(ValueError):
            inspect_history(events + events, "Any text.")

    def test_punctuation_change_is_mismatch(self):
        events = make_events(("establish",))
        original = events[0].replacement_text
        result = inspect_history(events, original + "!")
        self.assertEqual(
            result["comparison_outcome"], "unexplained_text_mismatch"
        )

    def test_unicode_forms_are_not_silently_normalized(self):
        composed = "Caf\u00e9"
        decomposed = "Cafe\u0301"

        event = Event(
            1, "establish", 0, "", composed,
            "Synthetic exact-string fixture.",
        )
        result = inspect_history((event,), decomposed)
        self.assertEqual(
            result["comparison_outcome"], "unexplained_text_mismatch"
        )

    def test_prefix_match_does_not_establish_latest_history(self):
        full = make_events(("establish", "wording_revision"))
        prefix = full[:1]

        result = inspect_history(
            prefix, prefix[0].replacement_text
        )

        self.assertEqual(
            result["comparison_outcome"], "matches_replayed_wording"
        )
        self.assertFalse(result["history_completeness_established"])

    def test_corrected_attribution_survives_wording_revision(self):
        events = make_events((
            "establish", "correct_record", "wording_revision"
        ))
        result = inspect_history(
            events, events[-1].replacement_text
        )
        self.assertEqual(
            result["current_attribution"], "record_corrected"
        )


if __name__ == "__main__":
    unittest.main()
