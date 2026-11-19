"""Research-only, manifest-driven signing-descriptor comparison.

Run:
    python research/security/current_signing_difference_audit.py \
        config/research/signing_audit_policy.yaml

No signing, networking, persistence, or external action.
The supplied descriptors are not authenticated by this module.
"""

from dataclasses import dataclass, replace
from enum import Enum
from pathlib import Path
import json
import sys
import unittest


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"


class Direction(Enum):
    SUBSTITUTION = "substitution"
    EXPANSION = "expansion"
    CONTRACTION = "contraction"
    MIXED = "mixed"
    POLICY_CHANGE = "policy_change"
    NOT_CURRENT = "not_current"


@dataclass(frozen=True)
class Difference:
    field: str
    direction: Direction


@dataclass(frozen=True)
class Policy:
    version: str
    clock_domain: str
    vocabulary: tuple[tuple[str, frozenset[str]], ...]
    responses: tuple[tuple[Direction, tuple[str, ...]], ...]
    notice_key: str

    def terms(self, category: str) -> frozenset[str]:
        return dict(self.vocabulary)[category]


@dataclass(frozen=True)
class Descriptor:
    action: str
    audience: str
    purpose: str
    data_classes: frozenset[str]
    holder_role: str
    clock_domain: str
    starts: int
    expires: int
    policy_version: str

    def __post_init__(self) -> None:
        for value in (
            self.action, self.audience, self.purpose, self.holder_role,
            self.clock_domain, self.policy_version,
        ):
            if not isinstance(value, str) or not value or value != value.strip():
                raise ValueError("Expected nonempty canonical text.")
        if not isinstance(self.data_classes, frozenset) or not self.data_classes:
            raise ValueError("Data classes must be a nonempty frozenset.")
        if any(not isinstance(value, str) for value in self.data_classes):
            raise TypeError("Data-class terms must be text.")
        if type(self.starts) is not int or type(self.expires) is not int:
            raise TypeError("Validity endpoints must be integer ticks.")
        if not 0 <= self.starts < self.expires:
            raise ValueError("Expected a nonempty validity interval.")


@dataclass(frozen=True)
class AuditReceipt:
    differences: frozenset[Difference]
    proposed_responses: tuple[str, ...]
    policy_version: str
    assessed_at: int
    clock_domain: str
    notice_key: str


def reject_duplicates(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate policy key.")
        result[key] = value
    return result


def load_policy(text: str) -> Policy:
    if not isinstance(text, str) or len(text.encode("utf-8")) > 32768:
        raise ValueError("Invalid or oversized policy document.")
    raw = json.loads(text, object_pairs_hook=reject_duplicates)
    expected = {
        "contract", "policy_version", "attribution", "clock_domain",
        "vocabulary", "difference_responses", "notice_key",
    }
    if not isinstance(raw, dict) or set(raw) != expected:
        raise ValueError("Unexpected policy fields.")
    if raw["contract"] != "signing-audit-research-v1":
        raise ValueError("Unsupported contract.")
    if raw["attribution"] != ATTRIBUTION:
        raise ValueError("Unexpected attribution.")

    for field in ("policy_version", "clock_domain", "notice_key"):
        value = raw[field]
        if not isinstance(value, str) or not value or value != value.strip():
            raise ValueError("Invalid policy metadata.")

    categories = {
        "actions", "audiences", "purposes", "data_classes", "holder_roles"
    }
    vocabulary = raw["vocabulary"]
    if not isinstance(vocabulary, dict) or set(vocabulary) != categories:
        raise ValueError("Invalid vocabulary categories.")
    for terms in vocabulary.values():
        if (
            not isinstance(terms, list) or not terms
            or any(
                not isinstance(term, str)
                or not term
                or term != term.strip()
                for term in terms
            )
            or len(terms) != len(set(terms))
        ):
            raise ValueError("Invalid vocabulary terms.")

    routes = raw["difference_responses"]
    if not isinstance(routes, dict) or set(routes) != {
        item.value for item in Direction
    }:
        raise ValueError("Incomplete response mapping.")
    for responses in routes.values():
        if (
            not isinstance(responses, list) or not responses
            or any(not isinstance(item, str) or not item.strip()
                   for item in responses)
        ):
            raise ValueError("Invalid response declarations.")

    return Policy(
        raw["policy_version"],
        raw["clock_domain"],
        tuple(sorted(
            (category, frozenset(terms))
            for category, terms in vocabulary.items()
        )),
        tuple(
            (direction, tuple(routes[direction.value]))
            for direction in Direction
        ),
        raw["notice_key"],
    )


def validate_descriptor(policy: Policy, item: Descriptor) -> None:
    if not isinstance(policy, Policy) or not isinstance(item, Descriptor):
        raise TypeError("Expected typed policy and descriptor.")
    for field, category in (
        ("action", "actions"),
        ("audience", "audiences"),
        ("purpose", "purposes"),
        ("holder_role", "holder_roles"),
    ):
        if getattr(item, field) not in policy.terms(category):
            raise ValueError(f"Unregistered {field}.")
    if not item.data_classes <= policy.terms("data_classes"):
        raise ValueError("Unregistered data class.")
    if item.clock_domain != policy.clock_domain:
        raise ValueError("Explicit clock conversion is required.")


def compare(
    policy: Policy,
    approved: Descriptor,
    observed: Descriptor,
    now: int,
) -> AuditReceipt:
    validate_descriptor(policy, approved)
    validate_descriptor(policy, observed)
    if type(now) is not int or now < 0:
        raise ValueError("now must be a nonnegative integer tick.")

    differences = set()
    for field in ("action", "audience", "purpose", "holder_role"):
        if getattr(approved, field) != getattr(observed, field):
            differences.add(Difference(field, Direction.SUBSTITUTION))

    added = observed.data_classes - approved.data_classes
    removed = approved.data_classes - observed.data_classes
    if added or removed:
        direction = (
            Direction.MIXED if added and removed
            else Direction.EXPANSION if added
            else Direction.CONTRACTION
        )
        differences.add(Difference("data_classes", direction))

    if (approved.starts, approved.expires) != (
        observed.starts, observed.expires
    ):
        observed_within = (
            approved.starts <= observed.starts
            and observed.expires <= approved.expires
        )
        approved_within = (
            observed.starts <= approved.starts
            and approved.expires <= observed.expires
        )
        direction = (
            Direction.CONTRACTION if observed_within
            else Direction.EXPANSION if approved_within
            else Direction.MIXED
        )
        differences.add(Difference("validity", direction))

    if approved.policy_version != observed.policy_version:
        differences.add(Difference("policy_version", Direction.POLICY_CHANGE))
    if approved.policy_version != policy.version:
        differences.add(Difference(
            "approved_policy_compatibility", Direction.POLICY_CHANGE
        ))

    for label, descriptor in (("approved", approved), ("observed", observed)):
        if not descriptor.starts <= now < descriptor.expires:
            differences.add(Difference(label, Direction.NOT_CURRENT))

    response_map = dict(policy.responses)
    responses = tuple(sorted({
        response
        for difference in differences
        for response in response_map[difference.direction]
    }))
    return AuditReceipt(
        frozenset(differences),
        responses,
        policy.version,
        now,
        policy.clock_domain,
        policy.notice_key,
    )


class SigningDifferenceTests(unittest.TestCase):
    policy = None

    def setUp(self) -> None:
        self.approved = Descriptor(
            "translate", "translation-service", "communication-access",
            frozenset({"notice-text"}), "intake-workload",
            self.policy.clock_domain, 1, 10, self.policy.version,
        )

    def test_unchanged_current_descriptor(self) -> None:
        receipt = compare(self.policy, self.approved, self.approved, 5)
        self.assertEqual(receipt.differences, frozenset())

    def test_contraction_is_not_silently_accepted(self) -> None:
        observed = replace(self.approved, expires=8)
        receipt = compare(self.policy, self.approved, observed, 5)
        self.assertIn(
            Difference("validity", Direction.CONTRACTION),
            receipt.differences,
        )

    def test_expansion_is_distinguished(self) -> None:
        observed = replace(
            self.approved,
            data_classes=frozenset({"notice-text", "appeal-record"}),
        )
        receipt = compare(self.policy, self.approved, observed, 5)
        self.assertIn(
            Difference("data_classes", Direction.EXPANSION),
            receipt.differences,
        )

    def test_exact_expiry_is_not_current(self) -> None:
        receipt = compare(self.policy, self.approved, self.approved, 10)
        self.assertIn(
            Difference("approved", Direction.NOT_CURRENT),
            receipt.differences,
        )

    def test_unknown_action_is_rejected_not_corrected(self) -> None:
        with self.assertRaises(ValueError):
            compare(
                self.policy,
                self.approved,
                replace(self.approved, action="tranlsate"),
                5,
            )

    def test_repeatability_regression(self) -> None:
        first = compare(self.policy, self.approved, self.approved, 5)
        second = compare(self.policy, self.approved, self.approved, 5)
        self.assertEqual(first, second)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Provide the research policy document path.")
    SigningDifferenceTests.policy = load_policy(
        Path(sys.argv[1]).read_text(encoding="utf-8")
    )
    unittest.main(argv=[sys.argv[0]])
