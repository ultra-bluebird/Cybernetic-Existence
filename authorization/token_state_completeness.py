"""Record-only CyberLaw authorization research model.

Run:
    python research/authorization/token_state_completeness.py

No cryptographic verification, networking, storage, or external action.
All records in tests are synthetic.
"""

from dataclasses import dataclass
from enum import Enum
from itertools import product
import unittest


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
ATTRIBUTION_SCOPE = (
    "Document credit and workstream metadata only; not identity, consent, "
    "capability authorization, execution evidence, or legal authority."
)


class RecordResult(Enum):
    CONSISTENT = "record_conditions_consistent"
    BLOCKED = "record_conditions_blocked"
    INCOMPLETE = "record_conditions_incomplete"


@dataclass(frozen=True)
class Assessment:
    result: RecordResult
    reasons: tuple[str, ...]
    duties: tuple[str, ...]
    notice: str


GRANT_TEXT = (
    "issuer",
    "holder_binding",
    "audience",
    "action",
    "purpose",
    "data_boundary",
    "conditions",
    "review_route",
    "policy_version",
    "assessment_version",
)
GRANT_TIME = ("not_before", "expires")
STATUS_TEXT = ("policy_version", "assessment_version", "hold_status")
STATUS_BOOL = ("active", "superseded")
STATUS_TIME = ("checked_at", "valid_until")


def assess_records(grant, status, request, now, max_status_age):
    if not all(isinstance(item, dict) for item in (grant, status, request)):
        raise TypeError("grant, status, and request must be dictionaries.")
    if type(now) is not int or now < 0:
        raise ValueError("now must be a nonnegative integer tick.")
    if type(max_status_age) is not int or max_status_age < 0:
        raise ValueError("max_status_age must be nonnegative.")

    errors = []

    def check_text(record, names, prefix):
        for name in names:
            value = record.get(name)
            if (
                not isinstance(value, str)
                or not value.strip()
                or len(value) > 500
            ):
                errors.append(f"{prefix}.{name}:missing_or_invalid")

    def check_ticks(record, names, prefix):
        for name in names:
            value = record.get(name)
            if type(value) is not int or value < 0:
                errors.append(f"{prefix}.{name}:missing_or_invalid")

    check_text(grant, GRANT_TEXT, "grant")
    check_ticks(grant, GRANT_TIME, "grant")
    check_text(status, STATUS_TEXT, "status")
    check_ticks(status, STATUS_TIME, "status")
    check_text(
        request,
        ("audience", "action", "purpose", "data_boundary"),
        "request",
    )

    for name in STATUS_BOOL:
        if type(status.get(name)) is not bool:
            errors.append(f"status.{name}:missing_or_invalid")

    duties = (
        "Preserve accessible intake and an independent challenge route.",
        "Assess continuity assistance through its separate authority.",
    )
    notice = (
        "Record-only research result. Cryptographic authenticity, status "
        "binding, lawful authority, and substantive fairness are not verified."
    )

    if errors:
        return Assessment(
            RecordResult.INCOMPLETE, tuple(errors), duties, notice
        )

    if status["hold_status"] not in ("none", "applies", "unresolved"):
        return Assessment(
            RecordResult.INCOMPLETE,
            ("status.hold_status:unsupported_value",),
            duties,
            notice,
        )

    reasons = []
    if grant["not_before"] >= grant["expires"]:
        reasons.append("invalid_grant_interval")
    if not grant["not_before"] <= now < grant["expires"]:
        reasons.append("outside_grant_interval")

    if not status["checked_at"] <= now < status["valid_until"]:
        reasons.append("status_not_current")
    if now - status["checked_at"] > max_status_age:
        reasons.append("status_too_old")

    if not status["active"]:
        reasons.append("inactive")
    if status["superseded"]:
        reasons.append("superseded")
    if status["hold_status"] == "applies":
        reasons.append("applicable_appeal_hold")
    if status["hold_status"] == "unresolved":
        reasons.append("appeal_hold_applicability_unresolved")

    for field in ("policy_version", "assessment_version"):
        if grant[field] != status[field]:
            reasons.append(f"{field}_changed")

    for field in ("audience", "action", "purpose", "data_boundary"):
        if grant[field] != request[field]:
            reasons.append(f"{field}_mismatch")

    result = RecordResult.BLOCKED if reasons else RecordResult.CONSISTENT
    return Assessment(result, tuple(reasons), duties, notice)


def synthetic_records():
    grant = {
        field: f"synthetic-{field}"
        for field in GRANT_TEXT
    }
    grant.update(not_before=0, expires=30)
    status = {
        "policy_version": grant["policy_version"],
        "assessment_version": grant["assessment_version"],
        "hold_status": "none",
        "active": True,
        "superseded": False,
        "checked_at": 8,
        "valid_until": 14,
    }
    request = {
        field: grant[field]
        for field in ("audience", "action", "purpose", "data_boundary")
    }
    return grant, status, request


class TokenStateTests(unittest.TestCase):
    def test_complete_consistent_records(self):
        records = synthetic_records()
        result = assess_records(*records, now=10, max_status_age=3)
        self.assertIs(result.result, RecordResult.CONSISTENT)

    def test_each_required_field_omission_is_incomplete(self):
        groups = (
            (0, GRANT_TEXT + GRANT_TIME),
            (1, STATUS_TEXT + STATUS_BOOL + STATUS_TIME),
        )
        for group, fields in groups:
            for field in fields:
                records = list(synthetic_records())
                del records[group][field]
                result = assess_records(
                    *records, now=10, max_status_age=3
                )
                self.assertIs(result.result, RecordResult.INCOMPLETE)

    def test_hold_and_supersession_combinations(self):
        for hold, superseded in product(
            ("none", "applies", "unresolved"), (False, True)
        ):
            grant, status, request = synthetic_records()
            status.update(hold_status=hold, superseded=superseded)
            result = assess_records(
                grant, status, request, now=10, max_status_age=3
            )
            expected = hold == "none" and not superseded
            self.assertEqual(
                result.result is RecordResult.CONSISTENT, expected
            )

    def test_changed_assessment_blocks_old_grant(self):
        grant, status, request = synthetic_records()
        status["assessment_version"] = "corrected-synthetic-assessment"
        result = assess_records(
            grant, status, request, now=10, max_status_age=3
        )
        self.assertIn("assessment_version_changed", result.reasons)

    def test_stale_status_cannot_establish_current_permission(self):
        records = synthetic_records()
        result = assess_records(*records, now=12, max_status_age=3)
        self.assertIn("status_too_old", result.reasons)

    def test_exact_expiry_is_outside_validity(self):
        records = synthetic_records()
        result = assess_records(*records, now=30, max_status_age=30)
        self.assertIn("outside_grant_interval", result.reasons)

    def test_unknown_hold_status_is_incomplete(self):
        grant, status, request = synthetic_records()
        status["hold_status"] = "not_checked"
        result = assess_records(
            grant, status, request, now=10, max_status_age=3
        )
        self.assertIs(result.result, RecordResult.INCOMPLETE)


if __name__ == "__main__":
    unittest.main()
