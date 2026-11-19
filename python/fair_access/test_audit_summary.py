import csv
import tempfile
import unittest
from pathlib import Path

from audit_summary import AuditValidationError, monthly_compliance_summary


class MonthlyComplianceSummaryTests(unittest.TestCase):
    def write_csv(self, rows, columns=None):
        temporary = tempfile.NamedTemporaryFile(
            mode="w",
            suffix=".csv",
            encoding="utf-8",
            newline="",
            delete=False,
        )
        temporary.close()

        fieldnames = columns or [
            "event_time",
            "outcome",
            "audit_category",
            "policy_version",
        ]

        with Path(temporary.name).open("w", encoding="utf-8", newline="") as handle:
            writer = csv.DictWriter(handle, fieldnames=fieldnames)
            writer.writeheader()
            writer.writerows(rows)

        self.addCleanup(Path(temporary.name).unlink)
        return temporary.name

    def test_zero_violations_meets_monthly_target(self):
        path = self.write_csv(
            [
                {
                    "event_time": "2026-09-01T12:00:00Z",
                    "outcome": "ALLOW",
                    "audit_category": "allowed_without_sensitive_person_data",
                    "policy_version": "1.0.0",
                },
                {
                    "event_time": "2026-09-02T12:00:00Z",
                    "outcome": "ALLOW_WITH_NARROW_SAFETY_BOUNDARY",
                    "audit_category": "reviewable_specific_safety_boundary",
                    "policy_version": "1.0.0",
                },
            ]
        )

        summary = monthly_compliance_summary(path, "2026-09")

        self.assertEqual(summary.total_events, 2)
        self.assertEqual(summary.policy_violations, 0)
        self.assertTrue(summary.target_met)

    def test_policy_violation_fails_monthly_target(self):
        path = self.write_csv(
            [
                {
                    "event_time": "2026-09-01T12:00:00Z",
                    "outcome": "POLICY_VIOLATION",
                    "audit_category": "prohibited_basis_detected",
                    "policy_version": "1.0.0",
                }
            ]
        )

        summary = monthly_compliance_summary(path, "2026-09")

        self.assertEqual(summary.policy_violations, 1)
        self.assertFalse(summary.target_met)

    def test_rejects_personal_or_ranking_audit_columns(self):
        path = self.write_csv(
            [
                {
                    "event_time": "2026-09-01T12:00:00Z",
                    "outcome": "ALLOW",
                    "audit_category": "allowed_without_sensitive_person_data",
                    "policy_version": "1.0.0",
                    "augmentation_status": "not_permitted",
                }
            ],
            columns=[
                "event_time",
                "outcome",
                "audit_category",
                "policy_version",
                "augmentation_status",
            ],
        )

        with self.assertRaises(AuditValidationError):
            monthly_compliance_summary(path, "2026-09")


if __name__ == "__main__":
    unittest.main()
