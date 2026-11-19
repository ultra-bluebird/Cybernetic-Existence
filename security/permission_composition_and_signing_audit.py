"""Research-only scope attenuation and signing audit.

Run:
    python research/security/permission_composition_and_signing_audit.py

No keys, signatures, networking, persistence, or external actions.
All test records are synthetic.
"""

from dataclasses import dataclass, replace
from enum import Enum
import unittest


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
ATTRIBUTION_SCOPE = (
    "Document credit and workstream metadata only; not identity, consent, "
    "capability authorization, execution evidence, or legal authority."
)


def bounded_text(value: str) -> None:
    if (
        not isinstance(value, str)
        or not value.strip()
        or len(value) > 200
    ):
        raise ValueError("Expected bounded nonempty text.")


@dataclass(frozen=True)
class ScopeClause:
    action: str
    audience: str
    purpose: str
    data_classes: frozenset[str]

    def __post_init__(self) -> None:
        for value in (self.action, self.audience, self.purpose):
            bounded_text(value)
        if not isinstance(self.data_classes, frozenset):
            raise TypeError("data_classes must be a frozenset.")
        if not self.data_classes:
            raise ValueError("At least one data class is required.")
        for value in self.data_classes:
            bounded_text(value)

    def contained_in(self, parent: "ScopeClause") -> bool:
        if not isinstance(parent, ScopeClause):
            raise TypeError("Expected ScopeClause.")
        return (
            self.action == parent.action
            and self.audience == parent.audience
            and self.purpose == parent.purpose
            and self.data_classes <= parent.data_classes
        )


@dataclass(frozen=True)
class Grant:
    holder_role: str
    clock_domain: str
    starts: int
    expires: int
    clauses: tuple[ScopeClause, ...]
    onward_delegation: bool

    def __post_init__(self) -> None:
        bounded_text(self.holder_role)
        bounded_text(self.clock_domain)
        if type(self.starts) is not int or type(self.expires) is not int:
            raise TypeError("Times must be integer ticks.")
        if not 0 <= self.starts < self.expires:
            raise ValueError("Expected a nonempty validity interval.")
        if not isinstance(self.clauses, tuple) or not self.clauses:
            raise ValueError("A nonempty clause tuple is required.")
        if any(not isinstance(item, ScopeClause) for item in self.clauses):
            raise TypeError("Invalid clause.")
        if type(self.onward_delegation) is not bool:
            raise TypeError("onward_delegation must be Boolean.")


@dataclass(frozen=True)
class SigningDescriptor:
    operation: ScopeClause
    holder_role: str
    clock_domain: str
    starts: int
    expires: int
    policy_version: str

    def __post_init__(self) -> None:
        if not isinstance(self.operation, ScopeClause):
            raise TypeError("Invalid operation.")
        for value in (
            self.holder_role,
            self.clock_domain,
            self.policy_version,
        ):
            bounded_text(value)
        if type(self.starts) is not int or type(self.expires) is not int:
            raise TypeError("Times must be integer ticks.")
        if not 0 <= self.starts < self.expires:
            raise ValueError("Invalid descriptor interval.")


class AuditFinding(Enum):
    OUTSIDE_GRANT = "outside_grant"
    HOLDER_MISMATCH = "holder_mismatch"
    CLOCK_MISMATCH = "clock_mismatch"
    VALIDITY_EXPANSION = "validity_expansion"
    SIGNED_DESCRIPTOR_DIFFERS = "signed_descriptor_differs"


def attenuation_errors(parent: Grant, child: Grant) -> tuple[str, ...]:
    if not isinstance(parent, Grant) or not isinstance(child, Grant):
        raise TypeError("Expected Grant values.")

    errors = []
    if not parent.onward_delegation:
        errors.append("parent_does_not_permit_delegation")
    if parent.clock_domain != child.clock_domain:
        errors.append("clock_domain_mismatch")
    elif not parent.starts <= child.starts < child.expires <= parent.expires:
        errors.append("child_validity_exceeds_parent")

    for clause in child.clauses:
        if not any(clause.contained_in(item) for item in parent.clauses):
            errors.append("child_clause_not_contained_in_one_parent_clause")

    return tuple(errors)


def audit_signing(
    grant: Grant,
    approved: SigningDescriptor,
    observed: SigningDescriptor,
) -> frozenset[AuditFinding]:
    if not isinstance(grant, Grant):
        raise TypeError("Expected Grant.")
    if not all(
        isinstance(item, SigningDescriptor)
        for item in (approved, observed)
    ):
        raise TypeError("Expected SigningDescriptor values.")

    findings = set()
    if not any(
        approved.operation.contained_in(clause)
        for clause in grant.clauses
    ):
        findings.add(AuditFinding.OUTSIDE_GRANT)
    if approved.holder_role != grant.holder_role:
        findings.add(AuditFinding.HOLDER_MISMATCH)
    if approved.clock_domain != grant.clock_domain:
        findings.add(AuditFinding.CLOCK_MISMATCH)
    elif not (
        grant.starts <= approved.starts
        < approved.expires <= grant.expires
    ):
        findings.add(AuditFinding.VALIDITY_EXPANSION)
    if approved != observed:
        findings.add(AuditFinding.SIGNED_DESCRIPTOR_DIFFERS)

    return frozenset(findings)


class CompositionAuditTests(unittest.TestCase):
    def setUp(self) -> None:
        self.translation = ScopeClause(
            "translate",
            "translation-service",
            "communication-access",
            frozenset({"notice-text"}),
        )
        self.review = ScopeClause(
            "review",
            "independent-review-service",
            "appeal-review",
            frozenset({"appeal-record"}),
        )
        self.parent = Grant(
            "intake-workload",
            "synthetic-clock",
            0,
            20,
            (self.translation, self.review),
            True,
        )
        self.approved = SigningDescriptor(
            self.translation,
            "intake-workload",
            "synthetic-clock",
            1,
            10,
            "synthetic-policy",
        )

    def test_narrow_child_is_structurally_attenuated(self) -> None:
        child = Grant(
            "delegated-workload",
            "synthetic-clock",
            2,
            10,
            (self.translation,),
            False,
        )
        self.assertEqual(attenuation_errors(self.parent, child), ())

    def test_clause_cross_product_is_rejected(self) -> None:
        mixed = replace(
            self.translation,
            data_classes=frozenset({"appeal-record"}),
        )
        child = Grant(
            "delegated-workload",
            "synthetic-clock",
            2,
            10,
            (mixed,),
            False,
        )
        self.assertIn(
            "child_clause_not_contained_in_one_parent_clause",
            attenuation_errors(self.parent, child),
        )

    def test_time_expansion_is_rejected(self) -> None:
        child = Grant(
            "delegated-workload",
            "synthetic-clock",
            2,
            21,
            (self.translation,),
            False,
        )
        self.assertIn(
            "child_validity_exceeds_parent",
            attenuation_errors(self.parent, child),
        )

    def test_no_implicit_onward_delegation(self) -> None:
        parent = replace(self.parent, onward_delegation=False)
        self.assertIn(
            "parent_does_not_permit_delegation",
            attenuation_errors(parent, parent),
        )

    def test_unchanged_descriptor_has_no_local_findings(self) -> None:
        self.assertEqual(
            audit_signing(self.parent, self.approved, self.approved),
            frozenset(),
        )

    def test_signed_scope_substitution_is_detected(self) -> None:
        observed = replace(self.approved, operation=self.review)
        findings = audit_signing(
            self.parent, self.approved, observed
        )
        self.assertIn(
            AuditFinding.SIGNED_DESCRIPTOR_DIFFERS,
            findings,
        )

    def test_approved_request_can_itself_exceed_the_grant(self) -> None:
        excessive = replace(
            self.approved,
            operation=replace(
                self.translation,
                data_classes=frozenset({"private-neural-data"}),
            ),
        )
        findings = audit_signing(self.parent, excessive, excessive)
        self.assertIn(AuditFinding.OUTSIDE_GRANT, findings)

    def test_cross_clock_comparison_is_not_silent(self) -> None:
        altered = replace(self.approved, clock_domain="other-clock")
        findings = audit_signing(self.parent, altered, altered)
        self.assertIn(AuditFinding.CLOCK_MISMATCH, findings)


if __name__ == "__main__":
    unittest.main()
