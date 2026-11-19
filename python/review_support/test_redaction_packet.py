import unittest

from redaction_packet import (
    RedactionCandidate,
    apply_non_overlapping_redactions,
    build_reviewer_packet,
    find_redaction_candidates,
    meets_redaction_targets,
    redaction_quality,
)


class RedactionPacketTests(unittest.TestCase):
    def test_finds_common_direct_identifier_candidates(self) -> None:
        text = (
            "Contact person@example.org or 555-123-4567 about "
            "case AB-12345 at 123 Main Street."
        )

        candidates = find_redaction_candidates(text)
        categories = {candidate.category for candidate in candidates}

        self.assertIn("EMAIL_REDACTED", categories)
        self.assertIn("PHONE_REDACTED", categories)
        self.assertIn("ACCOUNT_REFERENCE_REDACTED", categories)
        self.assertIn("PRECISE_ADDRESS_REDACTED", categories)

    def test_preserves_context_with_typed_redaction(self) -> None:
        text = "The appeal concerns case AB-12345 and requests a corrected notice."
        candidate = RedactionCandidate(
            category="ACCOUNT_REFERENCE_REDACTED",
            start=text.index("case"),
            end=text.index(" and"),
            replacement="[ACCOUNT_REFERENCE_REDACTED]",
        )

        packet = build_reviewer_packet(
            request_type="appeal",
            issue_summary=text,
            requested_remedy="Corrected notice",
            verified_candidates=[candidate],
        )

        self.assertIn("[ACCOUNT_REFERENCE_REDACTED]", packet.issue_summary)
        self.assertIn("requests a corrected notice", packet.issue_summary)
        self.assertFalse(packet.direct_identifier_values_in_packet)

    def test_rejects_overlapping_redactions_for_human_resolution(self) -> None:
        with self.assertRaises(ValueError):
            apply_non_overlapping_redactions(
                "abcdef",
                [
                    RedactionCandidate("A", 0, 4, "[A]"),
                    RedactionCandidate("B", 3, 6, "[B]"),
                ],
            )

    def test_redaction_targets_are_strict(self) -> None:
        recall, context_loss = redaction_quality(
            sensitive_tokens_found=100,
            sensitive_tokens_removed=100,
            necessary_context_tokens=100,
            necessary_context_tokens_lost=4,
        )

        self.assertTrue(meets_redaction_targets(recall, context_loss))
        self.assertFalse(meets_redaction_targets(0.99, 0.01))
        self.assertFalse(meets_redaction_targets(1.0, 0.05))


if __name__ == "__main__":
    unittest.main()
