"""Research-only disclosure and fallback audit.

Run:
    python research/access/intake_privacy_and_fallback_audit.py

No sensitive values, networking, persistence, or external actions.
All test records are synthetic.
"""

from dataclasses import dataclass
from enum import Enum
import unittest


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
ATTRIBUTION_SCOPE = (
    "Document credit and workstream metadata only; not identity, consent, "
    "capability authorization, execution evidence, or legal authority."
)


class FieldFinding(Enum):
    TRACE_INCOMPLETE = "trace_incomplete"
    NO_RECORDED_PURPOSE_USE = "no_recorded_purpose_use"
    OUTSIDE_DECLARED_PURPOSE = "outside_declared_purpose"
    MANDATORY_BASIS_UNRESOLVED = "mandatory_basis_unresolved"


@dataclass(frozen=True)
class FieldUse:
    field_category: str
    declared_purpose: str
    mandatory: bool
    requirement_basis_assessed: bool
    trace_complete: bool
    recorded_use_purposes: frozenset[str]

    def __post_init__(self) -> None:
        for value in (self.field_category, self.declared_purpose):
            if not isinstance(value, str) or not value.strip():
                raise ValueError("Category and purpose are required.")
        for value in (
            self.mandatory,
            self.requirement_basis_assessed,
            self.trace_complete,
        ):
            if type(value) is not bool:
                raise TypeError("Assessment flags must be Boolean.")
        if not isinstance(self.recorded_use_purposes, frozenset):
            raise TypeError("Recorded purposes must be a frozenset.")
        if any(
            not isinstance(value, str) or not value.strip()
            for value in self.recorded_use_purposes
        ):
            raise ValueError("Invalid recorded purpose.")


def audit_field(record: FieldUse) -> frozenset[FieldFinding]:
    if not isinstance(record, FieldUse):
        raise TypeError("Expected FieldUse.")

    findings = set()
    if not record.trace_complete:
        findings.add(FieldFinding.TRACE_INCOMPLETE)
    elif record.declared_purpose not in record.recorded_use_purposes:
        findings.add(FieldFinding.NO_RECORDED_PURPOSE_USE)

    if record.recorded_use_purposes - {record.declared_purpose}:
        findings.add(FieldFinding.OUTSIDE_DECLARED_PURPOSE)

    if record.mandatory and not record.requirement_basis_assessed:
        findings.add(FieldFinding.MANDATORY_BASIS_UNRESOLVED)

    return frozenset(findings)


@dataclass(frozen=True)
class Tick:
    domain: str
    value: int

    def __post_init__(self) -> None:
        if not isinstance(self.domain, str) or not self.domain.strip():
            raise ValueError("Clock domain is required.")
        if type(self.value) is not int or self.value < 0:
            raise ValueError("Invalid clock tick.")


@dataclass(frozen=True)
class FallbackTrace:
    failure: Tick
    requested: Tick
    usable_assistance: Tick | None
    resumed_progress: Tick | None
    evidence_basis: str

    def __post_init__(self) -> None:
        ticks = (self.failure, self.requested) + tuple(
            item
            for item in (self.usable_assistance, self.resumed_progress)
            if item is not None
        )
        if any(not isinstance(item, Tick) for item in ticks):
            raise TypeError("All timestamps must be Tick values.")
        if len({item.domain for item in ticks}) != 1:
            raise ValueError("Clock conversion must be explicit.")
        if self.requested.value < self.failure.value:
            raise ValueError("Request cannot precede this failure event.")
        if (
            self.usable_assistance is not None
            and self.usable_assistance.value < self.requested.value
        ):
            raise ValueError("Assistance cannot precede the request.")
        if (
            self.resumed_progress is not None
            and self.resumed_progress.value < self.failure.value
        ):
            raise ValueError("Progress cannot precede the failure.")
        if not isinstance(self.evidence_basis, str) or not self.evidence_basis.strip():
            raise ValueError("An observation basis is required.")


class AssistanceState(Enum):
    PENDING_WITHIN_TARGET = "pending_within_target"
    PENDING_TARGET_MISSED = "pending_target_missed"
    OBSERVED_WITHIN_TARGET = "observed_within_target"
    OBSERVED_TARGET_MISSED = "observed_target_missed"


@dataclass(frozen=True)
class FallbackReport:
    state: AssistanceState
    request_delay: int
    observed_assistance_delay: int | None
    pending_wait: int | None
    resumed_progress_delay: int | None
    notice_key: str


def audit_fallback(
    trace: FallbackTrace,
    now: Tick,
    assistance_target: int,
) -> FallbackReport:
    if not isinstance(trace, FallbackTrace) or not isinstance(now, Tick):
        raise TypeError("Expected typed trace and clock.")
    if now.domain != trace.failure.domain:
        raise ValueError("Clock domain mismatch.")
    if type(assistance_target) is not int or assistance_target < 0:
        raise ValueError("Target must be a nonnegative integer duration.")

    observed_times = [trace.requested.value]
    for item in (trace.usable_assistance, trace.resumed_progress):
        if item is not None:
            observed_times.append(item.value)
    if now.value < max(observed_times):
        raise ValueError("A trace cannot include events after the audit time.")

    delay = None
    pending = None
    if trace.usable_assistance is None:
        pending = now.value - trace.requested.value
        state = (
            AssistanceState.PENDING_WITHIN_TARGET
            if pending <= assistance_target
            else AssistanceState.PENDING_TARGET_MISSED
        )
    else:
        delay = trace.usable_assistance.value - trace.requested.value
        state = (
            AssistanceState.OBSERVED_WITHIN_TARGET
            if delay <= assistance_target
            else AssistanceState.OBSERVED_TARGET_MISSED
        )

    progress = (
        None
        if trace.resumed_progress is None
        else trace.resumed_progress.value - trace.failure.value
    )

    return FallbackReport(
        state=state,
        request_delay=trace.requested.value - trace.failure.value,
        observed_assistance_delay=delay,
        pending_wait=pending,
        resumed_progress_delay=progress,
        notice_key="measured-assistance-is-not-proof-of-remedy",
    )


class AccessAuditTests(unittest.TestCase):
    def tick(self, value):
        return Tick("synthetic-seconds", value)

    def test_incomplete_trace_does_not_prove_nonuse(self):
        record = FieldUse(
            "sensitive-category", "access-support",
            False, False, False, frozenset(),
        )
        findings = audit_field(record)
        self.assertIn(FieldFinding.TRACE_INCOMPLETE, findings)
        self.assertNotIn(FieldFinding.NO_RECORDED_PURPOSE_USE, findings)

    def test_complete_nonuse_trace_is_flagged(self):
        record = FieldUse(
            "sensitive-category", "access-support",
            True, False, True, frozenset(),
        )
        findings = audit_field(record)
        self.assertIn(FieldFinding.NO_RECORDED_PURPOSE_USE, findings)
        self.assertIn(FieldFinding.MANDATORY_BASIS_UNRESOLVED, findings)

    def test_observed_use_does_not_hide_another_purpose(self):
        record = FieldUse(
            "communication-preference", "access-support",
            False, True, True,
            frozenset({"access-support", "unrelated-analysis"}),
        )
        self.assertIn(
            FieldFinding.OUTSIDE_DECLARED_PURPOSE,
            audit_field(record),
        )

    def test_pending_assistance_remains_pending(self):
        trace = FallbackTrace(
            self.tick(0), self.tick(1), None, None,
            "Synthetic test observation.",
        )
        result = audit_fallback(trace, self.tick(10), 5)
        self.assertIs(result.state, AssistanceState.PENDING_TARGET_MISSED)
        self.assertIsNone(result.observed_assistance_delay)
        self.assertEqual(result.pending_wait, 9)

    def test_assistance_and_progress_are_distinct(self):
        trace = FallbackTrace(
            self.tick(0), self.tick(1), self.tick(3), None,
            "Synthetic accessible assistance observation.",
        )
        result = audit_fallback(trace, self.tick(5), 5)
        self.assertIs(result.state, AssistanceState.OBSERVED_WITHIN_TARGET)
        self.assertIsNone(result.resumed_progress_delay)

    def test_cross_clock_rejected(self):
        trace = FallbackTrace(
            self.tick(0), self.tick(1), None, None,
            "Synthetic test observation.",
        )
        with self.assertRaises(ValueError):
            audit_fallback(trace, Tick("other-clock", 5), 5)


if __name__ == "__main__":
    unittest.main()
