"""Research-only procedural-force and confirmation model.

Run:
    python research/communication/procedural_force_and_confirmation.py

No translation, identity inference, consent certification, or external action.
All tests use synthetic annotations.
"""

from dataclasses import dataclass
from enum import Enum
import unittest


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
ATTRIBUTION_SCOPE = (
    "Document credit and workstream metadata only; not identity, consent, "
    "capability authorization, execution evidence, or legal authority."
)


def text(value: str) -> None:
    if not isinstance(value, str) or not value.strip():
        raise ValueError("Expected nonempty text.")


class Force(Enum):
    QUESTION = "question"
    REQUEST = "request"
    ASSERTION = "assertion"
    PERMISSION = "permission"
    REFUSAL = "refusal"
    CORRECTION = "correction"
    WITHDRAWAL = "withdrawal"
    UNKNOWN = "unknown"


class ComparisonFinding(Enum):
    FORCE_CHANGED = "force_changed"
    FORCE_UNRESOLVED = "force_unresolved"
    SCOPE_CHANGED = "scope_changed"
    AGENCY_CHANGED = "agency_changed"
    CONDITIONS_CHANGED = "conditions_changed"


@dataclass(frozen=True)
class MeaningAnnotation:
    force: Force
    scope: str
    agency: str
    conditions: str

    def __post_init__(self) -> None:
        if not isinstance(self.force, Force):
            raise TypeError("Invalid force annotation.")
        for value in (self.scope, self.agency, self.conditions):
            text(value)


def compare_annotations(
    source: MeaningAnnotation,
    target: MeaningAnnotation,
) -> frozenset[ComparisonFinding]:
    if not isinstance(source, MeaningAnnotation):
        raise TypeError("Invalid source annotation.")
    if not isinstance(target, MeaningAnnotation):
        raise TypeError("Invalid target annotation.")

    findings = set()
    if Force.UNKNOWN in (source.force, target.force):
        findings.add(ComparisonFinding.FORCE_UNRESOLVED)
    elif source.force is not target.force:
        findings.add(ComparisonFinding.FORCE_CHANGED)

    for field, finding in (
        ("scope", ComparisonFinding.SCOPE_CHANGED),
        ("agency", ComparisonFinding.AGENCY_CHANGED),
        ("conditions", ComparisonFinding.CONDITIONS_CHANGED),
    ):
        if getattr(source, field) != getattr(target, field):
            findings.add(finding)

    return frozenset(findings)


class ConfirmationRoute(Enum):
    NO_ADDITIONAL_REQUEST = "no_additional_request"
    REUSE_PRIOR_CONFIRMATION = "reuse_prior_confirmation"
    TARGETED_ACCESSIBLE_CLARIFICATION = "targeted_accessible_clarification"
    OFFER_ALTERNATIVE_SUPPORT = "offer_alternative_support"


@dataclass(frozen=True)
class ConfirmationContext:
    content_revision: str
    action_scope: str
    clarification_needed: bool
    consequential_ambiguity: bool
    accessible_channel_available: bool
    repeated_attempts: int

    def __post_init__(self) -> None:
        text(self.content_revision)
        text(self.action_scope)
        for value in (
            self.clarification_needed,
            self.consequential_ambiguity,
            self.accessible_channel_available,
        ):
            if type(value) is not bool:
                raise TypeError("Context flags must be Boolean.")
        if type(self.repeated_attempts) is not int or self.repeated_attempts < 0:
            raise ValueError("Invalid attempt count.")


@dataclass(frozen=True)
class PriorConfirmation:
    content_revision: str
    action_scope: str
    still_applicable: bool
    evidence_record: str

    def __post_init__(self) -> None:
        for value in (
            self.content_revision,
            self.action_scope,
            self.evidence_record,
        ):
            text(value)
        if type(self.still_applicable) is not bool:
            raise TypeError("Applicability must be Boolean.")


@dataclass(frozen=True)
class ConfirmationDecision:
    route: ConfirmationRoute
    explanation_code: str
    notice_key: str


def plan_confirmation(
    context: ConfirmationContext,
    prior: PriorConfirmation | None,
    maximum_repeated_attempts: int,
) -> ConfirmationDecision:
    if not isinstance(context, ConfirmationContext):
        raise TypeError("Expected ConfirmationContext.")
    if prior is not None and not isinstance(prior, PriorConfirmation):
        raise TypeError("Invalid prior confirmation.")
    if (
        type(maximum_repeated_attempts) is not int
        or maximum_repeated_attempts < 0
    ):
        raise ValueError("A nonnegative repetition limit is required.")

    notice = "clarification-planning-is-not-consent"

    if not context.clarification_needed:
        return ConfirmationDecision(
            ConfirmationRoute.NO_ADDITIONAL_REQUEST,
            "no_current_clarification_need",
            notice,
        )

    reusable = (
        prior is not None
        and prior.still_applicable
        and prior.content_revision == context.content_revision
        and prior.action_scope == context.action_scope
    )
    if reusable:
        return ConfirmationDecision(
            ConfirmationRoute.REUSE_PRIOR_CONFIRMATION,
            "matching_current_confirmation_record",
            notice,
        )

    if not context.consequential_ambiguity:
        return ConfirmationDecision(
            ConfirmationRoute.NO_ADDITIONAL_REQUEST,
            "additional_mandatory_confirmation_not_justified",
            notice,
        )

    if (
        not context.accessible_channel_available
        or context.repeated_attempts >= maximum_repeated_attempts
    ):
        return ConfirmationDecision(
            ConfirmationRoute.OFFER_ALTERNATIVE_SUPPORT,
            "change_method_instead_of_repeating_requirement",
            notice,
        )

    return ConfirmationDecision(
        ConfirmationRoute.TARGETED_ACCESSIBLE_CLARIFICATION,
        "resolve_only_the_consequential_ambiguity",
        notice,
    )


class CommunicationTests(unittest.TestCase):
    def annotation(self, force: Force) -> MeaningAnnotation:
        return MeaningAnnotation(
            force,
            "synthetic recipient and purpose",
            "participant",
            "synthetic limited conditions",
        )

    def context(self, attempts=0, accessible=True):
        return ConfirmationContext(
            "synthetic-revision",
            "synthetic-disclosure-scope",
            True,
            True,
            accessible,
            attempts,
        )

    def test_question_becoming_permission_is_detected(self):
        findings = compare_annotations(
            self.annotation(Force.QUESTION),
            self.annotation(Force.PERMISSION),
        )
        self.assertIn(ComparisonFinding.FORCE_CHANGED, findings)

    def test_unknown_does_not_become_a_definite_mismatch(self):
        findings = compare_annotations(
            self.annotation(Force.UNKNOWN),
            self.annotation(Force.PERMISSION),
        )
        self.assertIn(ComparisonFinding.FORCE_UNRESOLVED, findings)
        self.assertNotIn(ComparisonFinding.FORCE_CHANGED, findings)

    def test_matching_confirmation_is_reused(self):
        prior = PriorConfirmation(
            "synthetic-revision",
            "synthetic-disclosure-scope",
            True,
            "controlled synthetic confirmation record",
        )
        decision = plan_confirmation(self.context(), prior, 2)
        self.assertIs(
            decision.route,
            ConfirmationRoute.REUSE_PRIOR_CONFIRMATION,
        )

    def test_changed_scope_does_not_reuse_confirmation(self):
        prior = PriorConfirmation(
            "synthetic-revision",
            "different-scope",
            True,
            "controlled synthetic confirmation record",
        )
        decision = plan_confirmation(self.context(), prior, 2)
        self.assertIs(
            decision.route,
            ConfirmationRoute.TARGETED_ACCESSIBLE_CLARIFICATION,
        )

    def test_repetition_limit_changes_support_path(self):
        decision = plan_confirmation(self.context(attempts=2), None, 2)
        self.assertIs(
            decision.route,
            ConfirmationRoute.OFFER_ALTERNATIVE_SUPPORT,
        )

    def test_inaccessible_channel_does_not_trigger_same_question(self):
        decision = plan_confirmation(
            self.context(accessible=False), None, 2
        )
        self.assertIs(
            decision.route,
            ConfirmationRoute.OFFER_ALTERNATIVE_SUPPORT,
        )


if __name__ == "__main__":
    unittest.main()
