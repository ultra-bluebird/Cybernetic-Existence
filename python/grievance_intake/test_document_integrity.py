import unittest

from document_integrity import (
    DigitizedField,
    evaluate_conversion,
    minimal_intake_record,
)


class DocumentIntegrityTests(unittest.TestCase):
    def test_accepts_fully_verified_source_matched_conversion(self) -> None:
        fields = [
            DigitizedField(
                name="request_type",
                source_visible=True,
                ocr_value="appeal",
                verified_value="appeal",
                reviewer_confirmed=True,
                source_match=True,
            ),
            DigitizedField(
                name="free_text_statement",
                source_visible=True,
                ocr_value="requested review",
                verified_value="requested review",
                reviewer_confirmed=True,
                source_match=True,
            ),
        ]

        report = evaluate_conversion(
            fields,
            page_count_from_source=1,
            page_count_from_scan=1,
        )

        self.assertTrue(report.accepted_for_routing)
        self.assertEqual(report.conversion_accuracy_percent, 100.0)

    def test_rejects_page_count_mismatch(self) -> None:
        report = evaluate_conversion(
            [
                DigitizedField(
                    name="request_type",
                    source_visible=True,
                    ocr_value="appeal",
                    verified_value="appeal",
                    reviewer_confirmed=True,
                    source_match=True,
                )
            ],
            page_count_from_source=2,
            page_count_from_scan=1,
        )

        self.assertFalse(report.accepted_for_routing)
        self.assertIn("Page-count mismatch", report.reason)

    def test_rejects_accuracy_at_or_below_ninety_nine_percent(self) -> None:
        fields = [
            DigitizedField(
                name=f"field_{index}",
                source_visible=True,
                ocr_value="value",
                verified_value="value",
                reviewer_confirmed=True,
                source_match=index != 0,
            )
            for index in range(100)
        ]

        report = evaluate_conversion(
            fields,
            page_count_from_source=1,
            page_count_from_scan=1,
        )

        self.assertFalse(report.accepted_for_routing)
        self.assertEqual(report.conversion_accuracy_percent, 99.0)

    def test_intake_record_excludes_tracking_and_identity_requirements(self) -> None:
        record = minimal_intake_record(
            request_type="grievance",
            received_at="2026-09-01T00:00:00Z",
            submission_channel="paper",
            accessibility_format_requested="large_print",
        )

        self.assertFalse(record["identity_or_health_data_required"])
        self.assertFalse(record["device_tracking_enabled"])
        self.assertFalse(record["ocr_is_authoritative"])


if __name__ == "__main__":
    unittest.main()
