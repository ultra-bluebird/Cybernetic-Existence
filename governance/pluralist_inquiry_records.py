"""Research-only testimony-aware records and bounded inquiry.

Run:
    python research/governance/pluralist_inquiry_records.py

No legal adjudication, networking, persistence, or external actions.
All test material is synthetic.
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
    if (
        not isinstance(value, str)
        or not value.strip()
        or len(value) > 3000
    ):
        raise ValueError("Expected bounded nonempty text.")


class EvidenceRole(Enum):
    TESTIMONY = "testimony"
    CONTEXT = "context"
    INTERPRETATION = "interpretation"
    NORMATIVE_ARGUMENT = "normative_argument"


class ContentHandling(Enum):
    NOT_COLLECTED = "not_collected"
    LIMITED_DISCLOSURE = "limited_disclosure"
    PROTECTED_RECORD = "protected_record"


class InquiryRoute(Enum):
    DO_NOT_REQUEST = "do_not_request"
    EXPLAIN_AND_OFFER_ALTERNATIVES = "explain_and_offer_alternatives"
    LIMITED_INQUIRY_WITH_SUPPORT = "limited_inquiry_with_support"


@dataclass(frozen=True)
class InquiryNeed:
    relevant_to_decision: bool
    necessary_for_decision: bool
    authority_basis_assessed: bool
    safeguards_assessed: bool
    less_intrusive_route_available: bool

    def __post_init__(self) -> None:
        for value in (
            self.relevant_to_decision,
            self.necessary_for_decision,
            self.authority_basis_assessed,
            self.safeguards_assessed,
            self.less_intrusive_route_available,
        ):
            if type(value) is not bool:
                raise TypeError("Inquiry assessment values must be Boolean.")


def plan_inquiry(need: InquiryNeed) -> InquiryRoute:
    if not isinstance(need, InquiryNeed):
        raise TypeError("Expected InquiryNeed.")
    if (
        not need.relevant_to_decision
        or not need.necessary_for_decision
        or need.less_intrusive_route_available
    ):
        return InquiryRoute.DO_NOT_REQUEST
    if not need.authority_basis_assessed or not need.safeguards_assessed:
        return InquiryRoute.EXPLAIN_AND_OFFER_ALTERNATIVES
    return InquiryRoute.LIMITED_INQUIRY_WITH_SUPPORT


@dataclass(frozen=True)
class Statement:
    source_description: str
    roles: frozenset[EvidenceRole]
    handling: ContentHandling
    text: str | None
    protected_record_path: str | None

    def __post_init__(self) -> None:
        require_text(self.source_description)
        if not isinstance(self.roles, frozenset) or not self.roles:
            raise ValueError("At least one explicit statement role is required.")
        if any(not isinstance(role, EvidenceRole) for role in self.roles):
            raise TypeError("Invalid evidence role.")
        if not isinstance(self.handling, ContentHandling):
            raise TypeError("Invalid content handling.")

        if self.handling is ContentHandling.NOT_COLLECTED:
            if self.text is not None or self.protected_record_path is not None:
                raise ValueError("Noncollection cannot contain hidden content.")
        elif self.handling is ContentHandling.LIMITED_DISCLOSURE:
            require_text(self.text)
            if self.protected_record_path is not None:
                raise ValueError("Use one declared content route.")
        else:
            require_text(self.protected_record_path)
            if self.text is not None:
                raise ValueError("Protected content must not be copied here.")


@dataclass(frozen=True)
class ArgumentAssessment:
    argument_kind: str
    claim: str
    grounds: str
    warrant: str
    backing: str
    qualifier: str
    rebuttal: str
    assessment_record: str

    def __post_init__(self) -> None:
        for value in (
            self.argument_kind,
            self.claim,
            self.grounds,
            self.warrant,
            self.backing,
            self.qualifier,
            self.rebuttal,
            self.assessment_record,
        ):
            require_text(value)


@dataclass(frozen=True)
class FindingRecord:
    participant_material: tuple[Statement, ...]
    relied_upon_material: tuple[Statement, ...]
    evidence_conclusion: str
    limitations: tuple[str, ...]
    question_decided: str
    separate_authority_basis: str
    supporting_arguments: tuple[ArgumentAssessment, ...]
    practical_response: str
    inability_to_act: str | None
    supported_challenge_route: str
    template_key: str
    template_version: str

    def __post_init__(self) -> None:
        for collection in (
            self.participant_material,
            self.relied_upon_material,
        ):
            if not isinstance(collection, tuple):
                raise TypeError("Material collections must be tuples.")
            if any(not isinstance(item, Statement) for item in collection):
                raise TypeError("Invalid statement.")

        for statement in self.relied_upon_material:
            if statement.handling is ContentHandling.NOT_COLLECTED:
                raise ValueError("Uncollected content cannot support a finding.")

        if not isinstance(self.limitations, tuple):
            raise TypeError("Limitations must be a tuple.")
        for limitation in self.limitations:
            require_text(limitation)

        if not isinstance(self.supporting_arguments, tuple):
            raise TypeError("Arguments must be a tuple.")
        if any(
            not isinstance(item, ArgumentAssessment)
            for item in self.supporting_arguments
        ):
            raise TypeError("Invalid argument assessment.")

        for value in (
            self.evidence_conclusion,
            self.question_decided,
            self.separate_authority_basis,
            self.practical_response,
            self.supported_challenge_route,
            self.template_key,
            self.template_version,
        ):
            require_text(value)
        if self.inability_to_act is not None:
            require_text(self.inability_to_act)


class PluralistRecordTests(unittest.TestCase):
    def testimony(self) -> Statement:
        return Statement(
            source_description="Synthetic participant's own account.",
            roles=frozenset({EvidenceRole.TESTIMONY, EvidenceRole.CONTEXT}),
            handling=ContentHandling.LIMITED_DISCLOSURE,
            text="I could not use the notice or find another way to respond.",
            protected_record_path=None,
        )

    def finding(self) -> FindingRecord:
        testimony = self.testimony()
        return FindingRecord(
            participant_material=(testimony,),
            relied_upon_material=(testimony,),
            evidence_conclusion=(
                "Synthetic finding supported by the participant's testimony."
            ),
            limitations=("No independent corroboration in this fixture.",),
            question_decided="Synthetic notice-access question.",
            separate_authority_basis="Controlled synthetic internal policy.",
            supporting_arguments=(),
            practical_response="Offer accessible notice and supported review.",
            inability_to_act=None,
            supported_challenge_route="Synthetic assisted independent review.",
            template_key="pluralist-finding",
            template_version="research-v1",
        )

    def test_account_can_be_the_relied_upon_evidence(self) -> None:
        finding = self.finding()
        self.assertEqual(
            finding.participant_material,
            finding.relied_upon_material,
        )

    def test_unnecessary_inquiry_is_not_requested(self) -> None:
        need = InquiryNeed(True, False, True, True, False)
        self.assertIs(plan_inquiry(need), InquiryRoute.DO_NOT_REQUEST)

    def test_less_intrusive_route_is_preferred(self) -> None:
        need = InquiryNeed(True, True, True, True, True)
        self.assertIs(plan_inquiry(need), InquiryRoute.DO_NOT_REQUEST)

    def test_unassessed_authority_does_not_open_inquiry(self) -> None:
        need = InquiryNeed(True, True, False, True, False)
        self.assertIs(
            plan_inquiry(need),
            InquiryRoute.EXPLAIN_AND_OFFER_ALTERNATIVES,
        )

    def test_noncollection_cannot_hide_recorded_content(self) -> None:
        with self.assertRaises(ValueError):
            replace(
                self.testimony(),
                handling=ContentHandling.NOT_COLLECTED,
            )

    def test_noncollected_content_cannot_be_relied_upon(self) -> None:
        withheld = Statement(
            source_description="Content not requested.",
            roles=frozenset({EvidenceRole.CONTEXT}),
            handling=ContentHandling.NOT_COLLECTED,
            text=None,
            protected_record_path=None,
        )
        with self.assertRaises(ValueError):
            replace(self.finding(), relied_upon_material=(withheld,))

    def test_inability_to_act_can_be_stated_explicitly(self) -> None:
        finding = replace(
            self.finding(),
            inability_to_act="This body lacks power to order external relief.",
            practical_response="Provide a supported referral and continuity plan.",
        )
        self.assertIsNotNone(finding.inability_to_act)


if __name__ == "__main__":
    unittest.main()
