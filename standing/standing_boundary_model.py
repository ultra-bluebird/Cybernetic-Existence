"""Proposed CyberLaw procedural model, not legal or enforcement authority.

Run tests:
    python research/standing/standing_boundary_model.py
"""

from dataclasses import dataclass
from enum import Enum
from itertools import product
import unittest


ATTRIBUTION = (
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
)

ATTRIBUTION_SCOPE = (
    "Document credit and configured workstream metadata only; "
    "not identity, consent, capability, or legal authority."
)


class Finding(Enum):
    SUPPORTED = "supported"
    UNRESOLVED = "unresolved"
    CONTRADICTED = "contradicted"


class IntakeRoute(Enum):
    ADMIT = "admit_for_review"
    ASSIST = "supported_clarification"
    REFER_OR_DECLINE = "reasoned_reviewable_referral_or_decline"


@dataclass(frozen=True)
class Intake:
    interest_described: Finding
    plausible_harm: Finding
    mandate_connection: Finding

    def __post_init__(self) -> None:
        if any(
            not isinstance(value, Finding)
            for value in (
                self.interest_described,
                self.plausible_harm,
                self.mandate_connection,
            )
        ):
            raise TypeError("Intake predicates must be Finding values.")


@dataclass(frozen=True)
class Decision:
    authorized: bool
    reasons: tuple[str, ...]


def route_intake(intake: Intake) -> tuple[IntakeRoute, tuple[str, ...]]:
    terms = {
        "interest_described": intake.interest_described,
        "plausible_harm": intake.plausible_harm,
        "mandate_connection": intake.mandate_connection,
    }
    contradicted = tuple(
        name for name, value in terms.items()
        if value is Finding.CONTRADICTED
    )
    if contradicted:
        return IntakeRoute.REFER_OR_DECLINE, contradicted

    unresolved = tuple(
        name for name, value in terms.items()
        if value is Finding.UNRESOLVED
    )
    if unresolved:
        return IntakeRoute.ASSIST, unresolved

    return IntakeRoute.ADMIT, ()


@dataclass(frozen=True)
class Restriction:
    authority: Finding
    action_evidence: Finding
    necessity: Finding
    alternatives_assessed: Finding
    proportionality: Finding
    duration_and_stop: Finding
    independent_review: Finding
    emergency: bool = False
    urgency_evidence: Finding = Finding.UNRESOLVED

    def __post_init__(self) -> None:
        predicates = (
            self.authority,
            self.action_evidence,
            self.necessity,
            self.alternatives_assessed,
            self.proportionality,
            self.duration_and_stop,
            self.independent_review,
            self.urgency_evidence,
        )
        if any(not isinstance(value, Finding) for value in predicates):
            raise TypeError("Restriction predicates must be Finding values.")
        if type(self.emergency) is not bool:
            raise TypeError("emergency must be a Boolean.")


def authorize_restriction(
    intake: Intake,
    restriction: Restriction,
) -> Decision:
    route, intake_reasons = route_intake(intake)
    if route is not IntakeRoute.ADMIT:
        return Decision(
            False,
            tuple(f"intake:{reason}" for reason in intake_reasons),
        )

    required = {
        "authority": restriction.authority,
        "action_evidence": restriction.action_evidence,
        "necessity": restriction.necessity,
        "alternatives_assessed": restriction.alternatives_assessed,
        "proportionality": restriction.proportionality,
        "duration_and_stop": restriction.duration_and_stop,
        "independent_review": restriction.independent_review,
    }
    if restriction.emergency:
        required["urgency_evidence"] = restriction.urgency_evidence

    unmet = tuple(
        f"{name}:{value.value}"
        for name, value in required.items()
        if value is not Finding.SUPPORTED
    )
    return Decision(not unmet, unmet)


@dataclass(frozen=True)
class Participation:
    response_received: bool
    effective_notice: Finding
    accessible_channel: Finding
    response_opportunity: Finding
    support_considered: Finding
    continuation_authority: Finding
    independent_review: Finding

    def __post_init__(self) -> None:
        if type(self.response_received) is not bool:
            raise TypeError("response_received must be a Boolean.")
        predicates = (
            self.effective_notice,
            self.accessible_channel,
            self.response_opportunity,
            self.support_considered,
            self.continuation_authority,
            self.independent_review,
        )
        if any(not isinstance(value, Finding) for value in predicates):
            raise TypeError("Participation predicates must be Finding values.")


@dataclass(frozen=True)
class SilenceAssessment:
    observation: str
    cause: str
    interest_status: Finding
    consent_status: Finding
    fault_status: Finding


def assess_silence(participation: Participation) -> SilenceAssessment:
    observation = (
        "response_received"
        if participation.response_received
        else "no_response_recorded"
    )
    return SilenceAssessment(
        observation=observation,
        cause="not_determined_by_this_model",
        interest_status=Finding.UNRESOLVED,
        consent_status=Finding.UNRESOLVED,
        fault_status=Finding.UNRESOLVED,
    )


def continuation_on_record(participation: Participation) -> Decision:
    if participation.response_received:
        return Decision(False, ("use_ordinary_participation_path",))

    required = {
        "effective_notice": participation.effective_notice,
        "accessible_channel": participation.accessible_channel,
        "response_opportunity": participation.response_opportunity,
        "support_considered": participation.support_considered,
        "continuation_authority": participation.continuation_authority,
        "independent_review": participation.independent_review,
    }
    unmet = tuple(
        f"{name}:{value.value}"
        for name, value in required.items()
        if value is not Finding.SUPPORTED
    )
    return Decision(not unmet, unmet)


class BoundaryTests(unittest.TestCase):
    def test_all_intake_combinations(self) -> None:
        for values in product(Finding, repeat=3):
            intake = Intake(*values)
            route, reasons = route_intake(intake)
            if Finding.CONTRADICTED in values:
                self.assertIs(route, IntakeRoute.REFER_OR_DECLINE)
                self.assertTrue(reasons)
            elif Finding.UNRESOLVED in values:
                self.assertIs(route, IntakeRoute.ASSIST)
                self.assertTrue(reasons)
            else:
                self.assertIs(route, IntakeRoute.ADMIT)
                self.assertEqual(reasons, ())

    def test_restriction_implies_admission_exhaustively(self) -> None:
        supported = Finding.SUPPORTED
        for intake_values in product(Finding, repeat=3):
            intake = Intake(*intake_values)
            for restriction_values in product(Finding, repeat=7):
                restriction = Restriction(*restriction_values)
                decision = authorize_restriction(intake, restriction)
                expected = (
                    all(value is supported for value in intake_values)
                    and all(
                        value is supported for value in restriction_values
                    )
                )
                self.assertEqual(decision.authorized, expected)

    def test_admission_does_not_imply_restriction(self) -> None:
        supported = Finding.SUPPORTED
        intake = Intake(supported, supported, supported)
        restriction = Restriction(
            Finding.UNRESOLVED,
            supported,
            supported,
            supported,
            supported,
            supported,
            supported,
        )
        self.assertIs(route_intake(intake)[0], IntakeRoute.ADMIT)
        self.assertFalse(
            authorize_restriction(intake, restriction).authorized
        )

    def test_emergency_does_not_bypass_missing_evidence(self) -> None:
        supported = Finding.SUPPORTED
        intake = Intake(supported, supported, supported)
        restriction = Restriction(
            authority=supported,
            action_evidence=Finding.UNRESOLVED,
            necessity=supported,
            alternatives_assessed=supported,
            proportionality=supported,
            duration_and_stop=supported,
            independent_review=supported,
            emergency=True,
            urgency_evidence=supported,
        )
        self.assertFalse(
            authorize_restriction(intake, restriction).authorized
        )

    def test_emergency_requires_supported_urgency(self) -> None:
        supported = Finding.SUPPORTED
        intake = Intake(supported, supported, supported)
        restriction = Restriction(
            *([supported] * 7),
            emergency=True,
            urgency_evidence=Finding.UNRESOLVED,
        )
        self.assertFalse(
            authorize_restriction(intake, restriction).authorized
        )

    def test_silence_never_establishes_interest_consent_or_fault(self) -> None:
        for values in product(Finding, repeat=6):
            participation = Participation(False, *values)
            assessment = assess_silence(participation)
            self.assertIs(assessment.interest_status, Finding.UNRESOLVED)
            self.assertIs(assessment.consent_status, Finding.UNRESOLVED)
            self.assertIs(assessment.fault_status, Finding.UNRESOLVED)
            expected = all(
                value is Finding.SUPPORTED for value in values
            )
            self.assertEqual(
                continuation_on_record(participation).authorized,
                expected,
            )

    def test_invalid_input_rejected(self) -> None:
        with self.assertRaises(TypeError):
            Intake("supported", Finding.SUPPORTED, Finding.SUPPORTED)


if __name__ == "__main__":
    unittest.main()
