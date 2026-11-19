"""Research-only effect-claim lifecycle.

Run:
    python research/assurance/effect_claim_lifecycle.py

No publication, signing, networking, or external actions.
Revision checks describe a protocol; persistent enforcement is not provided.
"""

from dataclasses import dataclass, replace
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


class ClaimKind(Enum):
    DESIGN = "design"
    TECHNICAL_PROPERTY = "technical_property"
    PRACTICAL_CASE = "practical_case"
    COMPARATIVE_EFFECT = "comparative_effect"


class EffectDirection(Enum):
    BENEFICIAL = "beneficial"
    HARMFUL = "harmful"
    MIXED = "mixed"
    NULL = "null"
    UNRESOLVED = "unresolved"


class ClaimState(Enum):
    DRAFT = "draft"
    PUBLISHED = "published"
    CONCERN = "concern"
    WITHDRAWN = "withdrawn"


class RecipientUpdate(Enum):
    PENDING = "pending"
    NOTICE_ACKNOWLEDGED = "notice_acknowledged"
    RELIANCE_UPDATE_REPORTED = "reliance_update_reported"
    RELIANCE_UPDATE_REVIEWED = "reliance_update_reviewed"


@dataclass(frozen=True)
class RecipientRecord:
    receiving_role: str
    state: RecipientUpdate
    evidence_record: str | None

    def __post_init__(self) -> None:
        text(self.receiving_role)
        if not isinstance(self.state, RecipientUpdate):
            raise TypeError("Invalid recipient-update state.")
        if self.state is RecipientUpdate.PENDING:
            if self.evidence_record is not None:
                raise ValueError("Pending update cannot assert completion evidence.")
        else:
            text(self.evidence_record)


@dataclass(frozen=True)
class EffectClaim:
    revision: int
    publishing_role: str
    kind: ClaimKind
    direction: EffectDirection
    proposition: str
    setting: str
    horizon: str
    evidence_record: str
    harm_assessment_status: str
    limitations: tuple[str, ...]
    state: ClaimState
    correction_history: tuple[str, ...]
    recipients: tuple[RecipientRecord, ...]
    recipient_discovery_complete: bool
    challenge_route: str

    def __post_init__(self) -> None:
        if type(self.revision) is not int or self.revision < 0:
            raise ValueError("Invalid revision.")
        if not isinstance(self.kind, ClaimKind):
            raise TypeError("Invalid claim kind.")
        if not isinstance(self.direction, EffectDirection):
            raise TypeError("Invalid effect direction.")
        if not isinstance(self.state, ClaimState):
            raise TypeError("Invalid lifecycle state.")
        for value in (
            self.publishing_role, self.proposition, self.setting,
            self.horizon, self.evidence_record,
            self.harm_assessment_status, self.challenge_route,
        ):
            text(value)
        for collection in (self.limitations, self.correction_history):
            if not isinstance(collection, tuple):
                raise TypeError("Record collections must be tuples.")
            for value in collection:
                text(value)
        if not self.limitations:
            raise ValueError("Limitations must be explicit.")
        if not isinstance(self.recipients, tuple):
            raise TypeError("Recipients must be a tuple.")
        if any(not isinstance(item, RecipientRecord) for item in self.recipients):
            raise TypeError("Invalid recipient record.")
        roles = [item.receiving_role for item in self.recipients]
        if len(roles) != len(set(roles)):
            raise ValueError("Duplicate receiving role.")
        if type(self.recipient_discovery_complete) is not bool:
            raise TypeError("Discovery status must be Boolean.")


def change_claim_state(
    claim: EffectClaim,
    expected_revision: int,
    following: ClaimState,
    assessment_record: str,
) -> EffectClaim:
    if not isinstance(claim, EffectClaim):
        raise TypeError("Expected EffectClaim.")
    if type(expected_revision) is not int or expected_revision != claim.revision:
        raise ValueError("Revision conflict.")
    if not isinstance(following, ClaimState):
        raise TypeError("Invalid target state.")
    text(assessment_record)

    permitted = {
        ClaimState.DRAFT: frozenset({ClaimState.PUBLISHED}),
        ClaimState.PUBLISHED: frozenset({
            ClaimState.CONCERN, ClaimState.WITHDRAWN,
        }),
        ClaimState.CONCERN: frozenset({
            ClaimState.PUBLISHED, ClaimState.WITHDRAWN,
        }),
        ClaimState.WITHDRAWN: frozenset(),
    }
    if following not in permitted[claim.state]:
        raise ValueError("Unsupported state transition.")

    recipients = claim.recipients
    if following is ClaimState.WITHDRAWN:
        recipients = tuple(
            RecipientRecord(item.receiving_role, RecipientUpdate.PENDING, None)
            for item in recipients
        )

    return replace(
        claim,
        revision=claim.revision + 1,
        state=following,
        correction_history=claim.correction_history + (assessment_record,),
        recipients=recipients,
    )


def withdrawal_followup(claim: EffectClaim) -> tuple[str, ...]:
    if not isinstance(claim, EffectClaim):
        raise TypeError("Expected EffectClaim.")
    if claim.state is not ClaimState.WITHDRAWN:
        return ("withdrawal_not_recorded",)

    findings = []
    if not claim.recipient_discovery_complete:
        findings.append("recipient_discovery_incomplete")
    if any(
        item.state is not RecipientUpdate.RELIANCE_UPDATE_REVIEWED
        for item in claim.recipients
    ):
        findings.append("known_recipient_correction_not_fully_reviewed")
    return tuple(findings)


class EffectClaimTests(unittest.TestCase):
    def claim(self) -> EffectClaim:
        return EffectClaim(
            revision=0,
            publishing_role="Synthetic research publisher.",
            kind=ClaimKind.PRACTICAL_CASE,
            direction=EffectDirection.MIXED,
            proposition="Synthetic outcome with benefit and burden.",
            setting="Synthetic bounded setting.",
            horizon="Synthetic follow-up period.",
            evidence_record="Controlled synthetic outcome record.",
            harm_assessment_status="Specified burdens assessed; others unresolved.",
            limitations=("No population-wide effect is established.",),
            state=ClaimState.PUBLISHED,
            correction_history=(),
            recipients=(
                RecipientRecord(
                    "Synthetic adopting institution",
                    RecipientUpdate.PENDING,
                    None,
                ),
            ),
            recipient_discovery_complete=False,
            challenge_route="Synthetic independent challenge process.",
        )

    def test_harm_claim_is_a_first_class_claim(self):
        harmful = replace(self.claim(), direction=EffectDirection.HARMFUL)
        self.assertIs(harmful.direction, EffectDirection.HARMFUL)

    def test_concern_does_not_automatically_withdraw(self):
        concerned = change_claim_state(
            self.claim(), 0, ClaimState.CONCERN,
            "Synthetic unresolved reliability concern.",
        )
        self.assertIs(concerned.state, ClaimState.CONCERN)

    def test_withdrawal_can_precede_recipient_updates(self):
        withdrawn = change_claim_state(
            self.claim(), 0, ClaimState.WITHDRAWN,
            "Synthetic accepted reanalysis.",
        )
        self.assertIs(withdrawn.state, ClaimState.WITHDRAWN)
        self.assertIn(
            "known_recipient_correction_not_fully_reviewed",
            withdrawal_followup(withdrawn),
        )

    def test_unknown_recipients_prevent_complete_followup_claim(self):
        withdrawn = change_claim_state(
            self.claim(), 0, ClaimState.WITHDRAWN,
            "Synthetic accepted correction.",
        )
        reviewed = replace(
            withdrawn,
            recipients=(
                RecipientRecord(
                    "Synthetic adopting institution",
                    RecipientUpdate.RELIANCE_UPDATE_REVIEWED,
                    "Controlled synthetic follow-up review.",
                ),
            ),
        )
        self.assertIn(
            "recipient_discovery_incomplete",
            withdrawal_followup(reviewed),
        )

    def test_stale_revision_rejected(self):
        with self.assertRaises(ValueError):
            change_claim_state(
                self.claim(), 3, ClaimState.WITHDRAWN,
                "Synthetic stale command.",
            )


if __name__ == "__main__":
    unittest.main()
