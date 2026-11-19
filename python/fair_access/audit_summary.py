from __future__ import annotations

import csv
from collections import Counter
from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path


class AuditValidationError(ValueError):
    pass


@dataclass(frozen=True)
class MonthlyComplianceSummary:
    month: str
    total_events: int
    policy_violations: int
    compliant_events: int
    target_met: bool


REQUIRED_COLUMNS = {
    "event_time",
    "outcome",
    "audit_category",
    "policy_version",
}


def monthly_compliance_summary(input_path: str, month: str) -> MonthlyComplianceSummary:
    try:
        requested_month = datetime.strptime(month, "%Y-%m").date().replace(day=1)
    except ValueError as error:
        raise AuditValidationError("month must use YYYY-MM format.") from error

    path = Path(input_path)
    if not path.is_file():
        raise AuditValidationError("input_path must refer to an existing CSV file.")

    outcomes: Counter[str] = Counter()
    total_events = 0

    with path.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames is None or not REQUIRED_COLUMNS.issubset(reader.fieldnames):
            raise AuditValidationError(
                "CSV must include event_time, outcome, audit_category, and policy_version."
            )

        prohibited_columns = {
            "name",
            "email",
            "phone",
            "address",
            "device_identifier",
            "augmentation_status",
            "biometric_data",
            "reputation_score",
        }
        if prohibited_columns.intersection(reader.fieldnames):
            raise AuditValidationError(
                "Audit CSV contains prohibited personal or ranking columns."
            )

        for row in reader:
            try:
                event_date = datetime.fromisoformat(row["event_time"].replace("Z", "+00:00")).date()
            except ValueError as error:
                raise AuditValidationError("event_time must be ISO 8601 formatted.") from error

            if event_date.year == requested_month.year and event_date.month == requested_month.month:
                total_events += 1
                outcomes[row["outcome"]] += 1

    policy_violations = outcomes["POLICY_VIOLATION"]
    compliant_events = total_events - policy_violations

    return MonthlyComplianceSummary(
        month=requested_month.isoformat()[:7],
        total_events=total_events,
        policy_violations=policy_violations,
        compliant_events=compliant_events,
        target_met=policy_violations == 0,
    )


def iso_today() -> str:
    return date.today().isoformat()
