"""Regression tests for recipient closure vocabulary 2.0.0.

Python 3.10 or newer; standard library only.
SPDX-License-Identifier: MIT OR Apache-2.0
"""

import unittest

from research.continuity.recipient_closure_v2 import (
    RecipientReview,
    Transfer,
    review_closure,
)


class RecipientClosureTests(unittest.TestCase):
    def test_six_reference_cases(self):
        cases = (
            (
                ("P", "P"), ("complete", "complete"),
                "confirmed", "P",
            ),
            (
                ("P", "P"), ("complete", "unresolved"),
                "confirmed", "U",
            ),
            (
                ("P", "F"), ("complete", "complete"),
                "confirmed", "F",
            ),
            (
                ("P", "F"), ("complete", "complete"),
                "unresolved", "U",
            ),
            (
                ("P", "P"), ("complete", "complete"),
                "unresolved", "P",
            ),
            (
                ("P", "F"), ("complete", "unresolved"),
                "confirmed", "F",
            ),
        )

        for allowed, inventory, presence, expected in cases:
            with self.subTest(
                allowed=allowed,
                inventory=inventory,
                presence=presence,
            ):
                record = RecipientReview(
                    allowed,
                    inventory,
                    (Transfer(0, 1, presence, "P"),),
                )
                self.assertEqual(
                    review_closure(record)["result"], expected
                )

    def test_one_confirmed_prohibited_path_is_sufficient(self):
        record = RecipientReview(
            ("P", "F", "P"),
            ("complete",) * 3,
            (
                Transfer(0, 1, "confirmed", "P"),
                Transfer(0, 2, "confirmed", "P"),
            ),
        )
        result = review_closure(record)
        self.assertEqual(result["result"], "F")
        self.assertEqual(
            result["failures"][0]["witness"]["party_positions"],
            [0, 1],
        )

    def test_prohibited_origin(self):
        record = RecipientReview(("F",), ("complete",), ())
        self.assertEqual(review_closure(record)["result"], "F")

    def test_self_loop_terminates(self):
        record = RecipientReview(
            ("P",), ("complete",),
            (Transfer(0, 0, "confirmed", "P"),),
        )
        self.assertEqual(review_closure(record)["result"], "P")

    def test_empty_graph_inventory_rejected(self):
        with self.assertRaisesRegex(ValueError, "party_dimensions"):
            review_closure(RecipientReview((), (), ()))

    def test_source_out_of_range(self):
        with self.assertRaisesRegex(ValueError, "graph_limits"):
            review_closure(
                RecipientReview(("P",), ("complete",), (), source=1)
            )

    def test_not_observed_is_not_ruled_out(self):
        record = RecipientReview(
            ("P", "P"), ("complete", "complete"),
            (Transfer(0, 1, "not_observed", "P"),),
        )
        with self.assertRaisesRegex(ValueError, "transfer_value"):
            review_closure(record)

    def test_duplicate_pair_rejected(self):
        edge = Transfer(0, 1, "confirmed", "P")
        record = RecipientReview(
            ("P", "P"), ("complete", "complete"), (edge, edge)
        )
        with self.assertRaisesRegex(ValueError, "duplicate_directed_pair"):
            review_closure(record)

    def test_schema_mismatch(self):
        record = RecipientReview(
            ("P",), ("complete",), (), schema_version="1.0.0"
        )
        with self.assertRaisesRegex(ValueError, "recipient_schema"):
            review_closure(record)


if __name__ == "__main__":
    unittest.main()
