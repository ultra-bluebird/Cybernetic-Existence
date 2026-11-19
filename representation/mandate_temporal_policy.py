"""Research-only temporal mandate model.

Run:
    python research/representation/mandate_temporal_policy.py

No appointment is authenticated and no external action is authorized.
Times are integer ticks in a common, explicitly configured clock domain.
"""

from dataclasses import dataclass, replace
from enum import Enum
import unittest


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
ATTRIBUTION_SCOPE = (
    "Document credit and workstream metadata only; not identity, consent, "
    "capability authorization, execution evidence, or legal authority."
)


class ReviewLapsePolicy(Enum):
    AT_DUE_IF_UNREVIEWED = "at_due_if_unreviewed"
    AT_END_WITH_ESCALATION = "at_end_with_escalation"
    AFTER_GRACE_IF_UNREVIEWED = "after_grace_if_unreviewed"


@dataclass(frozen=True)
class TemporalMandate:
    start: int
    end: int
    review_due: int
    policy: ReviewLapsePolicy
    grace: int = 0
    reviewed_at: int | None = None
    withdrawn_at: int | None = None
    superseded_at: int | None = None

    def __post_init__(self):
        for name in ("start", "end", "review_due", "grace"):
            if type(getattr(self, name)) is not int:
                raise TypeError(f"{name} must be an integer.")
        if not 0 <= self.start <= self.review_due < self.end:
            raise ValueError("Require 0 <= start <= review_due < end.")
        if not isinstance(self.policy, ReviewLapsePolicy):
            raise TypeError("Invalid lapse policy.")
        if self.grace < 0:
            raise ValueError("grace cannot be negative.")
        if (
            self.policy is not ReviewLapsePolicy.AFTER_GRACE_IF_UNREVIEWED
            and self.grace != 0
        ):
            raise ValueError("Grace is only valid for the grace policy.")

        for name in ("reviewed_at", "withdrawn_at", "superseded_at"):
            value = getattr(self, name)
            if value is not None:
                if type(value) is not int:
                    raise TypeError(f"{name} must be an integer or None.")
                if value < self.start:
                    raise ValueError(f"{name} precedes the mandate.")

    def unreviewed_cutoff(self):
        if self.policy is ReviewLapsePolicy.AT_DUE_IF_UNREVIEWED:
            return self.review_due
        if self.policy is ReviewLapsePolicy.AFTER_GRACE_IF_UNREVIEWED:
            return min(self.end, self.review_due + self.grace)
        return self.end


@dataclass(frozen=True)
class OperationalContext:
    record_valid: bool
    underlying_basis_assessed: bool
    action_within_scope: bool
    review_reachable: bool
    adverse_action: bool

    def __post_init__(self):
        for value in (
            self.record_valid,
            self.underlying_basis_assessed,
            self.action_within_scope,
            self.review_reachable,
            self.adverse_action,
        ):
            if type(value) is not bool:
                raise TypeError("Context values must be Boolean.")


@dataclass(frozen=True)
class TemporalAssessment:
    temporal_conditions_hold: bool
    operational_requirements_met: bool
    review_overdue: bool
    reasons: tuple[str, ...]
    obligations: tuple[str, ...]
    authority_notice: str


def assess_operation(mandate, context, now):
    if not isinstance(mandate, TemporalMandate):
        raise TypeError("Expected TemporalMandate.")
    if not isinstance(context, OperationalContext):
        raise TypeError("Expected OperationalContext.")
    if type(now) is not int or now < 0:
        raise ValueError("now must be a nonnegative integer tick.")

    reasons = []
    obligations = []

    review_seen = (
        mandate.reviewed_at is not None
        and mandate.reviewed_at <= now
    )
    overdue = now >= mandate.review_due and (
        mandate.reviewed_at is None
        or mandate.reviewed_at > mandate.review_due
    )

    temporal = mandate.start <= now < mandate.end
    if not temporal:
        reasons.append("outside_effective_interval")

    for event, label in (
        (mandate.withdrawn_at, "withdrawn"),
        (mandate.superseded_at, "superseded"),
    ):
        if event is not None and event <= now:
            temporal = False
            reasons.append(label)

    cutoff = mandate.unreviewed_cutoff()
    qualifying_review = (
        review_seen
        and mandate.reviewed_at < cutoff
    )
    if now >= cutoff and not qualifying_review:
        temporal = False
        reasons.append("review_lapse_or_fixed_expiry")

    # Late review cannot silently revive a mandate that already lapsed.
    if overdue:
        obligations.append("record_missed_review_deadline")
        if not review_seen:
            obligations.append("escalate_for_independent_review")

    if not context.record_valid:
        reasons.append("record_correction_required")
    if not context.underlying_basis_assessed:
        reasons.append("appointment_basis_not_established")
    if not context.action_within_scope:
        reasons.append("action_outside_assessed_scope")
    if not context.review_reachable:
        obligations.append("restore_accessible_review")
        if context.adverse_action:
            reasons.append("adverse_action_requires_review_fallback")

    requirements_met = temporal and not reasons

    if not requirements_met:
        obligations.append(
            "offer_separately_assessed_continuity_support"
        )

    return TemporalAssessment(
        temporal_conditions_hold=temporal,
        operational_requirements_met=requirements_met,
        review_overdue=overdue,
        reasons=tuple(reasons),
        obligations=tuple(obligations),
        authority_notice=(
            "Research assessment only; not a credential or legal ruling."
        ),
    )


class TemporalPolicyTests(unittest.TestCase):
    def setUp(self):
        self.mandate = TemporalMandate(
            start=0,
            end=20,
            review_due=5,
            policy=ReviewLapsePolicy.AT_DUE_IF_UNREVIEWED,
        )
        self.context = OperationalContext(True, True, True, True, True)

    def test_unreviewed_lapses_at_due(self):
        self.assertTrue(
            assess_operation(self.mandate, self.context, 4)
            .operational_requirements_met
        )
        self.assertFalse(
            assess_operation(self.mandate, self.context, 5)
            .operational_requirements_met
        )

    def test_prior_review_allows_continuation_not_extension(self):
        mandate = replace(self.mandate, reviewed_at=4)
        self.assertTrue(
            assess_operation(mandate, self.context, 10)
            .operational_requirements_met
        )
        self.assertFalse(
            assess_operation(mandate, self.context, 20)
            .operational_requirements_met
        )

    def test_late_review_does_not_revive_lapsed_mandate(self):
        mandate = replace(self.mandate, reviewed_at=6)
        self.assertFalse(
            assess_operation(mandate, self.context, 7)
            .operational_requirements_met
        )

    def test_end_policy_reports_overdue_without_early_lapse(self):
        mandate = replace(
            self.mandate,
            policy=ReviewLapsePolicy.AT_END_WITH_ESCALATION,
        )
        result = assess_operation(mandate, self.context, 6)
        self.assertTrue(result.operational_requirements_met)
        self.assertTrue(result.review_overdue)

    def test_grace_review_before_cutoff(self):
        mandate = replace(
            self.mandate,
            policy=ReviewLapsePolicy.AFTER_GRACE_IF_UNREVIEWED,
            grace=3,
            reviewed_at=7,
        )
        self.assertTrue(
            assess_operation(mandate, self.context, 9)
            .operational_requirements_met
        )

    def test_withdrawal_stops_current_operation(self):
        mandate = replace(self.mandate, withdrawn_at=3)
        self.assertFalse(
            assess_operation(mandate, self.context, 3)
            .operational_requirements_met
        )

    def test_review_outage_does_not_erase_temporal_finding(self):
        context = replace(self.context, review_reachable=False)
        result = assess_operation(self.mandate, context, 2)
        self.assertTrue(result.temporal_conditions_hold)
        self.assertFalse(result.operational_requirements_met)
        self.assertIn(
            "offer_separately_assessed_continuity_support",
            result.obligations,
        )


if __name__ == "__main__":
    unittest.main()
