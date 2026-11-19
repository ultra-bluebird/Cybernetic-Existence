# SPDX-License-Identifier: MIT OR Apache-2.0
"""Local claim-boundary rules for the Capacity Commons Evidence Firewall."""

from dataclasses import dataclass
from enum import Enum
from itertools import product
import unittest


VERSION = "1.0.0"


class Family(str, Enum):
    AFFECT = "affect"
    AUTONOMOUS_MOTIVATION = "autonomous_motivation"
    EXPOSURE = "exposure"
    PARTICIPATION = "participation"
    RECIPIENT_ACCEPTANCE = "recipient_acceptance"
    RECIPIENT_BENEFIT = "recipient_benefit"
    MISSINGNESS_BOUNDS = "missingness_bounds"
    SAMPLING_UNCERTAINTY = "sampling_uncertainty"
    HISTORICAL_ACCEPTANCE = "historical_acceptance"
    CURRENT_SUITABILITY = "current_suitability"
    DISPATCH_ASSESSMENT = "dispatch_assessment"
    DELIVERY = "delivery"


class Origin(str, Enum):
    OBSERVED = "observed"
    SYNTHETIC = "synthetic"
    ASSUMPTION = "assumption"
    DESIGN = "design"


class Disposition(str, Enum):
    BOUNDED_SUPPORT = "bounded_support"
    BLOCKED = "blocked"
    UNRESOLVED = "unresolved"


def checked_text(value: object, name: str) -> str:
    if not isinstance(value, str):
        raise ValueError(f"{name} must be text")
    if not 1 <= len(value) <= 512 or value != value.strip():
        raise ValueError(f"{name} must be trimmed nonempty text")
    if any(ord(char) < 32 or ord(char) == 127 for char in value):
        raise ValueError(f"{name} contains control characters")
    return value


def tri_state(value: object, name: str) -> None:
    if value is not None and type(value) is not bool:
        raise ValueError(f"{name} must be Boolean or None")


@dataclass(frozen=True)
class Scope:
    population: str
    intervention: str
    outcome_definition: str
    follow_up: str

    def __post_init__(self):
        for name in (
            "population", "intervention", "outcome_definition", "follow_up"
        ):
            checked_text(getattr(self, name), name)


@dataclass(frozen=True)
class Claim:
    proposition: str
    family: Family
    origin: Origin
    scope: Scope
    causal: bool = False

    def __post_init__(self):
        checked_text(self.proposition, "proposition")
        if type(self.family) is not Family:
            raise ValueError("invalid claim family")
        if type(self.origin) is not Origin:
            raise ValueError("invalid claim origin")
        if type(self.scope) is not Scope:
            raise ValueError("invalid claim scope")
        if type(self.causal) is not bool:
            raise ValueError("causal must be Boolean")


@dataclass(frozen=True)
class Evidence:
    family: Family
    origin: Origin
    scope: Scope
    available: bool | None
    proposition_support_reviewed: bool | None
    measurement_reviewed: bool | None
    causal_design_reviewed: bool | None

    def __post_init__(self):
        if type(self.family) is not Family:
            raise ValueError("invalid evidence family")
        if type(self.origin) is not Origin:
            raise ValueError("invalid evidence origin")
        if type(self.scope) is not Scope:
            raise ValueError("invalid evidence scope")
        for name in (
            "available",
            "proposition_support_reviewed",
            "measurement_reviewed",
            "causal_design_reviewed",
        ):
            tri_state(getattr(self, name), name)


@dataclass(frozen=True)
class Review:
    schema_version: str
    disposition: Disposition
    reasons: tuple[str, ...]


def review_claim(claim: Claim, evidence: Evidence) -> Review:
    """Evaluate declared compatibility, not authenticity or factual truth.

    Review flags must originate from an accountable external review process.
    Their presence here does not authenticate that process.
    """
    if type(claim) is not Claim or type(evidence) is not Evidence:
        raise ValueError("typed claim and evidence are required")

    blocked = []
    unresolved = []

    if claim.family is not evidence.family:
        blocked.append("evidence_family_mismatch")
    if claim.origin is not evidence.origin:
        blocked.append("evidence_origin_mismatch")
    if claim.scope != evidence.scope:
        blocked.append("reviewed_scope_mismatch")

    requirements = {
        "evidence_available": evidence.available,
        "proposition_support_reviewed": evidence.proposition_support_reviewed,
        "measurement_reviewed": evidence.measurement_reviewed,
    }

    if claim.causal:
        if claim.origin is not Origin.OBSERVED:
            blocked.append("nonobservational_origin_cannot_establish_empirical_cause")
        requirements["causal_design_reviewed"] = evidence.causal_design_reviewed

    for name, value in requirements.items():
        if value is False:
            blocked.append(name + "_failed")
        elif value is None:
            unresolved.append(name + "_unresolved")

    if blocked:
        return Review(
            VERSION,
            Disposition.BLOCKED,
            tuple(blocked + unresolved),
        )
    if unresolved:
        return Review(
            VERSION,
            Disposition.UNRESOLVED,
            tuple(unresolved),
        )
    return Review(
        VERSION,
        Disposition.BOUNDED_SUPPORT,
        ("declared_evidence_supports_only_the_exact_reviewed_claim",),
    )


class ClaimBoundaryTests(unittest.TestCase):
    def scope(self) -> Scope:
        return Scope(
            "Consenting pilot participants",
            "Assigned invitation workflow",
            "Prespecified late-follow-up participation",
            "Protocol-defined enrollment-relative window",
        )

    def evidence(self, family=Family.PARTICIPATION) -> Evidence:
        return Evidence(
            family=family,
            origin=Origin.OBSERVED,
            scope=self.scope(),
            available=True,
            proposition_support_reviewed=True,
            measurement_reviewed=True,
            causal_design_reviewed=None,
        )

    def claim(self, family=Family.PARTICIPATION, causal=False) -> Claim:
        return Claim(
            proposition="The bounded reported result has the stated interpretation.",
            family=family,
            origin=Origin.OBSERVED,
            scope=self.scope(),
            causal=causal,
        )

    def test_same_family_bounded_support(self):
        result = review_claim(self.claim(), self.evidence())
        self.assertEqual(result.disposition, Disposition.BOUNDED_SUPPORT)

    def test_all_cross_family_promotions_blocked(self):
        for source, target in product(Family, repeat=2):
            if source is target:
                continue
            result = review_claim(
                self.claim(family=target),
                self.evidence(family=source),
            )
            self.assertEqual(result.disposition, Disposition.BLOCKED)

    def test_unknown_causal_review_is_unresolved(self):
        result = review_claim(self.claim(causal=True), self.evidence())
        self.assertEqual(result.disposition, Disposition.UNRESOLVED)

    def test_synthetic_evidence_cannot_become_observed(self):
        evidence = Evidence(
            Family.PARTICIPATION, Origin.SYNTHETIC, self.scope(),
            True, True, True, True,
        )
        result = review_claim(self.claim(), evidence)
        self.assertEqual(result.disposition, Disposition.BLOCKED)

    def test_scope_change_requires_new_review(self):
        changed_scope = Scope(
            "All augmentation users",
            "Assigned invitation workflow",
            "Prespecified late-follow-up participation",
            "Protocol-defined enrollment-relative window",
        )
        claim = Claim(
            "A broader population has the reported result.",
            Family.PARTICIPATION,
            Origin.OBSERVED,
            changed_scope,
        )
        result = review_claim(claim, self.evidence())
        self.assertEqual(result.disposition, Disposition.BLOCKED)

    def test_known_failure_dominates_unknown(self):
        evidence = Evidence(
            Family.PARTICIPATION, Origin.OBSERVED, self.scope(),
            False, None, True, None,
        )
        result = review_claim(self.claim(), evidence)
        self.assertEqual(result.disposition, Disposition.BLOCKED)
        self.assertIn("evidence_available_failed", result.reasons)
        self.assertIn("proposition_support_reviewed_unresolved", result.reasons)

    def test_boolean_review_fields_are_strict(self):
        with self.assertRaises(ValueError):
            Evidence(
                Family.PARTICIPATION, Origin.OBSERVED, self.scope(),
                1, True, True, None,
            )

    def test_no_operational_authorization_output(self):
        result = review_claim(self.claim(), self.evidence())
        self.assertEqual(
            set(result.__dataclass_fields__),
            {"schema_version", "disposition", "reasons"},
        )


if __name__ == "__main__":
    unittest.main()
