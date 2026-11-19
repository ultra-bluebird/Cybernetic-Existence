"""Research-only response projection.

Run:
    python research/authorization/introspection_and_explanation_views.py

Inputs must come from separately authenticated, authorized adapters.
No networking, persistence, token verification, or external action.
"""

from dataclasses import dataclass
from enum import Enum
import unittest


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
ATTRIBUTION_SCOPE = (
    "Document credit and workstream metadata only; not identity, consent, "
    "capability authorization, execution evidence, or legal authority."
)


class Activity(Enum):
    ACTIVE = "active"
    INACTIVE = "inactive"
    UNDETERMINED = "undetermined"


class ReasonClass(Enum):
    NONE = "none"
    HOLD = "hold"
    EXPIRED = "expired"
    SUPERSEDED = "superseded"
    ASSESSMENT_PENDING = "assessment_pending"


@dataclass(frozen=True)
class AccessContext:
    endpoint_access_authorized: bool
    token_metadata_visible: bool
    explanation_entitled: bool

    def __post_init__(self):
        for value in (
            self.endpoint_access_authorized,
            self.token_metadata_visible,
            self.explanation_entitled,
        ):
            if type(value) is not bool:
                raise TypeError("Access values must be Boolean.")


@dataclass(frozen=True)
class StatusAssessment:
    activity: Activity
    reason: ReasonClass
    disclosed_scopes: tuple[str, ...]
    explanation: str
    review_route: str

    def __post_init__(self):
        if not isinstance(self.activity, Activity):
            raise TypeError("Invalid activity.")
        if not isinstance(self.reason, ReasonClass):
            raise TypeError("Invalid reason.")
        if not isinstance(self.disclosed_scopes, tuple):
            raise TypeError("Scopes must be an immutable tuple.")
        if any(
            not isinstance(scope, str)
            or not scope
            or any(character.isspace() for character in scope)
            for scope in self.disclosed_scopes
        ):
            raise ValueError("Each scope must be a nonempty single term.")
        if len(set(self.disclosed_scopes)) != len(self.disclosed_scopes):
            raise ValueError("Duplicate scopes are not permitted.")
        for value in (self.explanation, self.review_route):
            if not isinstance(value, str) or not value.strip():
                raise ValueError("Explanation and review route are required.")
        if self.activity is Activity.ACTIVE and self.reason is not ReasonClass.NONE:
            raise ValueError("This narrow model requires no inactive reason when active.")
        if self.activity is Activity.INACTIVE and self.reason is ReasonClass.NONE:
            raise ValueError("Inactive assessments require a private reason class.")
        if (
            self.activity is Activity.UNDETERMINED
            and self.reason is not ReasonClass.ASSESSMENT_PENDING
        ):
            raise ValueError("Undetermined assessments require pending status.")


def validate_inputs(status, access):
    if not isinstance(status, StatusAssessment):
        raise TypeError("Expected StatusAssessment.")
    if not isinstance(access, AccessContext):
        raise TypeError("Expected AccessContext.")


def introspection_view(status, access):
    """Project a response; HTTP error mapping belongs to the adapter."""
    validate_inputs(status, access)
    if not access.endpoint_access_authorized:
        raise PermissionError("Introspection endpoint access is not authorized.")

    if (
        not access.token_metadata_visible
        or status.activity is not Activity.ACTIVE
    ):
        return {"active": False}

    response = {"active": True}
    if status.disclosed_scopes:
        response["scope"] = " ".join(status.disclosed_scopes)
    return response


def explanation_view(status, access):
    """Separate party/reviewer interface, not an RFC 7662 response."""
    validate_inputs(status, access)
    if not access.explanation_entitled:
        raise PermissionError("Explanation entitlement is not established.")

    return {
        "assessment_state": status.activity.value,
        "reason_class": status.reason.value,
        "explanation": status.explanation,
        "review_route": status.review_route,
        "notice": (
            "Procedural explanation only; not a credential, "
            "personhood finding, or execution authorization."
        ),
    }


class ProjectionTests(unittest.TestCase):
    def inactive(self):
        return StatusAssessment(
            Activity.INACTIVE,
            ReasonClass.HOLD,
            (),
            "Synthetic disclosure hold pending independent review.",
            "Synthetic accessible review service.",
        )

    def test_inactive_introspection_is_minimal(self):
        access = AccessContext(True, True, False)
        self.assertEqual(
            introspection_view(self.inactive(), access),
            {"active": False},
        )

    def test_endpoint_denial_is_not_an_inactive_response(self):
        with self.assertRaises(PermissionError):
            introspection_view(
                self.inactive(), AccessContext(False, False, False)
            )

    def test_hidden_token_metadata_is_not_disclosed(self):
        status = StatusAssessment(
            Activity.ACTIVE,
            ReasonClass.NONE,
            ("notice.translate",),
            "Synthetic current assessment.",
            "Synthetic accessible review service.",
        )
        self.assertEqual(
            introspection_view(status, AccessContext(True, False, False)),
            {"active": False},
        )

    def test_party_access_does_not_require_endpoint_credentials(self):
        result = explanation_view(
            self.inactive(), AccessContext(False, False, True)
        )
        self.assertEqual(result["reason_class"], "hold")

    def test_explanation_requires_separate_entitlement(self):
        with self.assertRaises(PermissionError):
            explanation_view(
                self.inactive(), AccessContext(True, True, False)
            )

    def test_unknown_state_is_not_reported_as_known_revocation(self):
        status = StatusAssessment(
            Activity.UNDETERMINED,
            ReasonClass.ASSESSMENT_PENDING,
            (),
            "Synthetic assessment needs additional information.",
            "Synthetic assisted clarification route.",
        )
        access = AccessContext(True, True, True)
        self.assertEqual(introspection_view(status, access), {"active": False})
        self.assertEqual(
            explanation_view(status, access)["assessment_state"],
            "undetermined",
        )


if __name__ == "__main__":
    unittest.main()
