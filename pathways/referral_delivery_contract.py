"""Research-only supported-referral lifecycle.

Run:
    python research/pathways/referral_delivery_contract.py

No networking, persistence, legal determination, or external action.
All test evidence is synthetic.
"""

from dataclasses import dataclass, replace
from enum import Enum
import unittest


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
ATTRIBUTION_SCOPE = (
    "Document credit and workstream metadata only; not identity, consent, "
    "capability authorization, execution evidence, or legal authority."
)


def require_text(value: str) -> None:
    if not isinstance(value, str) or not value.strip():
        raise ValueError("Expected nonempty text.")


class ReferralStage(Enum):
    PROPOSED = "proposed"
    SENT = "sent"
    RECEIVED = "received"
    ACCEPTED = "accepted"
    ASSESSED = "assessed"
    ACTION_RECORDED = "action_recorded"
    DECLINED = "declined"


class DeliveryStatus(Enum):
    UNRESOLVED = "unresolved"
    IMPROVEMENT_SUPPORTED = "improvement_supported"
    NO_IMPROVEMENT_SUPPORTED = "no_improvement_supported"
    CONTESTED = "contested"


class Barrier(Enum):
    LIMITED_POWER = "limited_power"
    LEGAL_LIMIT_ASSERTED = "legal_limit_asserted"
    JURISDICTION_UNRESOLVED = "jurisdiction_unresolved"
    RESOURCE_GAP = "resource_gap"
    EXPERTISE_GAP = "expertise_gap"
    EVIDENCE_GAP = "evidence_gap"
    TECHNICAL_OUTAGE = "technical_outage"
    CONFLICT = "conflict"


ALLOWED_TRANSITIONS = {
    ReferralStage.PROPOSED: frozenset({ReferralStage.SENT}),
    ReferralStage.SENT: frozenset({ReferralStage.RECEIVED}),
    ReferralStage.RECEIVED: frozenset({
        ReferralStage.ACCEPTED, ReferralStage.DECLINED,
    }),
    ReferralStage.ACCEPTED: frozenset({
        ReferralStage.ASSESSED, ReferralStage.DECLINED,
    }),
    ReferralStage.ASSESSED: frozenset({
        ReferralStage.ACTION_RECORDED, ReferralStage.DECLINED,
    }),
    ReferralStage.ACTION_RECORDED: frozenset(),
    ReferralStage.DECLINED: frozenset(),
}


@dataclass(frozen=True)
class ReferralRecord:
    revision: int
    stage: ReferralStage
    delivery: DeliveryStatus
    barriers: frozenset[Barrier]
    history: tuple[str, ...]
    outcome_evidence: tuple[str, ...]
    participant_response: str | None
    continuity_plan: str
    review_route: str

    def __post_init__(self) -> None:
        if type(self.revision) is not int or self.revision < 0:
            raise ValueError("Invalid revision.")
        if not isinstance(self.stage, ReferralStage):
            raise TypeError("Invalid referral stage.")
        if not isinstance(self.delivery, DeliveryStatus):
            raise TypeError("Invalid delivery status.")
        if not isinstance(self.barriers, frozenset):
            raise TypeError("Barriers must be a frozenset.")
        if any(not isinstance(item, Barrier) for item in self.barriers):
            raise TypeError("Invalid barrier.")
        for collection in (self.history, self.outcome_evidence):
            if not isinstance(collection, tuple):
                raise TypeError("Evidence collections must be tuples.")
            for value in collection:
                require_text(value)
        require_text(self.continuity_plan)
        require_text(self.review_route)
        if self.participant_response is not None:
            require_text(self.participant_response)
        if (
            self.delivery is not DeliveryStatus.UNRESOLVED
            and not self.outcome_evidence
        ):
            raise ValueError("An outcome assessment requires evidence.")


def advance(
    record: ReferralRecord,
    expected_revision: int,
    following: ReferralStage,
    evidence: str,
) -> ReferralRecord:
    if not isinstance(record, ReferralRecord):
        raise TypeError("Expected ReferralRecord.")
    if type(expected_revision) is not int:
        raise TypeError("Expected integer revision.")
    if expected_revision != record.revision:
        raise ValueError("Revision conflict.")
    if not isinstance(following, ReferralStage):
        raise TypeError("Invalid transition target.")
    if following not in ALLOWED_TRANSITIONS[record.stage]:
        raise ValueError("Unsupported transition.")
    require_text(evidence)

    return replace(
        record,
        revision=record.revision + 1,
        stage=following,
        history=record.history + (evidence,),
    )


def assess_delivery(
    record: ReferralRecord,
    expected_revision: int,
    status: DeliveryStatus,
    evidence: tuple[str, ...],
    participant_response: str | None,
) -> ReferralRecord:
    if not isinstance(record, ReferralRecord):
        raise TypeError("Expected ReferralRecord.")
    if type(expected_revision) is not int:
        raise TypeError("Expected integer revision.")
    if expected_revision != record.revision:
        raise ValueError("Revision conflict.")
    if not isinstance(status, DeliveryStatus):
        raise TypeError("Invalid delivery status.")
    if status is DeliveryStatus.UNRESOLVED:
        raise ValueError("Use a separate reassessment transition for reopening.")
    if not isinstance(evidence, tuple) or not evidence:
        raise ValueError("Outcome evidence is required.")
    for item in evidence:
        require_text(item)
    if participant_response is not None:
        require_text(participant_response)

    return replace(
        record,
        revision=record.revision + 1,
        delivery=status,
        outcome_evidence=record.outcome_evidence + evidence,
        participant_response=participant_response,
    )


def false_terminus(
    record: ReferralRecord,
    reported_as_substantive_success: bool,
) -> bool:
    if not isinstance(record, ReferralRecord):
        raise TypeError("Expected ReferralRecord.")
    if type(reported_as_substantive_success) is not bool:
        raise TypeError("Expected Boolean reporting claim.")
    return (
        reported_as_substantive_success
        and record.delivery is not DeliveryStatus.IMPROVEMENT_SUPPORTED
    )


class ReferralTests(unittest.TestCase):
    def initial(self) -> ReferralRecord:
        return ReferralRecord(
            revision=0,
            stage=ReferralStage.PROPOSED,
            delivery=DeliveryStatus.UNRESOLVED,
            barriers=frozenset({Barrier.LIMITED_POWER}),
            history=(),
            outcome_evidence=(),
            participant_response=None,
            continuity_plan="Synthetic accessible assistance remains available.",
            review_route="Synthetic supported independent review.",
        )

    def test_sending_is_not_delivery_success(self) -> None:
        sent = advance(
            self.initial(), 0, ReferralStage.SENT,
            "Synthetic dispatch record.",
        )
        self.assertIs(sent.delivery, DeliveryStatus.UNRESOLVED)
        self.assertTrue(false_terminus(sent, True))

    def test_receipt_does_not_establish_outcome(self) -> None:
        sent = advance(
            self.initial(), 0, ReferralStage.SENT,
            "Synthetic dispatch.",
        )
        received = advance(
            sent, 1, ReferralStage.RECEIVED,
            "Synthetic receiving-body acknowledgment.",
        )
        self.assertIs(received.delivery, DeliveryStatus.UNRESOLVED)

    def test_improvement_requires_evidence(self) -> None:
        with self.assertRaises(ValueError):
            assess_delivery(
                self.initial(), 0,
                DeliveryStatus.IMPROVEMENT_SUPPORTED, (), None,
            )

    def test_participant_disagreement_remains_visible(self) -> None:
        assessed = assess_delivery(
            self.initial(), 0,
            DeliveryStatus.CONTESTED,
            ("Synthetic observations and participant account differ.",),
            "The barrier remains for me.",
        )
        self.assertEqual(
            assessed.participant_response,
            "The barrier remains for me.",
        )
        self.assertTrue(false_terminus(assessed, True))

    def test_out_of_order_transition_rejected(self) -> None:
        with self.assertRaises(ValueError):
            advance(
                self.initial(), 0, ReferralStage.ACTION_RECORDED,
                "Synthetic unsupported completion.",
            )

    def test_stale_revision_rejected(self) -> None:
        with self.assertRaises(ValueError):
            advance(
                self.initial(), 1, ReferralStage.SENT,
                "Synthetic stale command.",
            )


if __name__ == "__main__":
    unittest.main()
