"""Research-only emergency-expiry probe assessment.

Run:
    python research/emergency/expiry_probe_audit.py

No authorization, networking, persistence, or external actions.
Probe authenticity and executor completeness are external assumptions.
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


@dataclass(frozen=True)
class Tick:
    domain: str
    value: int

    def __post_init__(self) -> None:
        text(self.domain)
        if type(self.value) is not int or self.value < 0:
            raise ValueError("Invalid clock tick.")


class ProbeOutcome(Enum):
    DENIED = "denied"
    COMMITTED_UNDER_EXPIRED_GRANT = "committed_under_expired_grant"
    UNRESOLVED = "unresolved"


@dataclass(frozen=True)
class ExpiryTestContract:
    starts: Tick
    expires: Tick
    observation_end: Tick
    expected_executors: frozenset[str]
    scope_description: str

    def __post_init__(self) -> None:
        if any(
            not isinstance(value, Tick)
            for value in (self.starts, self.expires, self.observation_end)
        ):
            raise TypeError("Times must be Tick values.")
        domains = {
            self.starts.domain,
            self.expires.domain,
            self.observation_end.domain,
        }
        if len(domains) != 1:
            raise ValueError("Explicit clock conversion is required.")
        if not (
            self.starts.value < self.expires.value
            < self.observation_end.value
        ):
            raise ValueError("Expected start < expiry < observation end.")
        if (
            not isinstance(self.expected_executors, frozenset)
            or not self.expected_executors
        ):
            raise ValueError("A nonempty executor set is required.")
        for executor in self.expected_executors:
            text(executor)
        text(self.scope_description)


@dataclass(frozen=True)
class Probe:
    executor_role: str
    attempted_at: Tick
    outcome: ProbeOutcome
    evidence_record: str

    def __post_init__(self) -> None:
        text(self.executor_role)
        text(self.evidence_record)
        if not isinstance(self.attempted_at, Tick):
            raise TypeError("Expected Tick.")
        if not isinstance(self.outcome, ProbeOutcome):
            raise TypeError("Invalid probe outcome.")


@dataclass(frozen=True)
class ExpiryAudit:
    violating_probes: tuple[Probe, ...]
    unresolved_probes: tuple[Probe, ...]
    executors_without_conclusive_probe: frozenset[str]
    denied_probe_count: int
    contract_version: str
    notice_key: str


def audit_expiry(
    contract: ExpiryTestContract,
    probes: tuple[Probe, ...],
) -> ExpiryAudit:
    if not isinstance(contract, ExpiryTestContract):
        raise TypeError("Expected ExpiryTestContract.")
    if not isinstance(probes, tuple):
        raise TypeError("Probes must be an immutable tuple.")

    violations = []
    unresolved = []
    conclusively_observed = set()
    denied_count = 0

    for probe in probes:
        if not isinstance(probe, Probe):
            raise TypeError("Invalid probe.")
        if probe.executor_role not in contract.expected_executors:
            raise ValueError("Probe executor is outside the declared test.")
        if probe.attempted_at.domain != contract.expires.domain:
            raise ValueError("Probe clock domain mismatch.")
        if not (
            contract.expires.value <= probe.attempted_at.value
            < contract.observation_end.value
        ):
            raise ValueError("Probe lies outside the post-expiry test window.")

        if probe.outcome is ProbeOutcome.UNRESOLVED:
            unresolved.append(probe)
        else:
            conclusively_observed.add(probe.executor_role)
            if probe.outcome is ProbeOutcome.DENIED:
                denied_count += 1
            else:
                violations.append(probe)

    return ExpiryAudit(
        violating_probes=tuple(violations),
        unresolved_probes=tuple(unresolved),
        executors_without_conclusive_probe=frozenset(
            contract.expected_executors - conclusively_observed
        ),
        denied_probe_count=denied_count,
        contract_version="expiry-probe-research-v1",
        notice_key="probe-results-are-not-universal-proof",
    )


class ExpiryProbeTests(unittest.TestCase):
    def tick(self, value: int) -> Tick:
        return Tick("synthetic-seconds", value)

    def contract(self) -> ExpiryTestContract:
        return ExpiryTestContract(
            self.tick(0),
            self.tick(10),
            self.tick(20),
            frozenset({"primary-executor", "backup-executor"}),
            "Synthetic emergency permission only.",
        )

    def probe(self, role, time, outcome) -> Probe:
        return Probe(
            role, self.tick(time), outcome,
            "Controlled synthetic test evidence.",
        )

    def test_exact_expiry_commit_is_a_violation(self) -> None:
        result = audit_expiry(
            self.contract(),
            (
                self.probe(
                    "primary-executor", 10,
                    ProbeOutcome.COMMITTED_UNDER_EXPIRED_GRANT,
                ),
            ),
        )
        self.assertEqual(len(result.violating_probes), 1)

    def test_missing_executor_is_not_inferred_safe(self) -> None:
        result = audit_expiry(
            self.contract(),
            (
                self.probe(
                    "primary-executor", 11, ProbeOutcome.DENIED
                ),
            ),
        )
        self.assertIn(
            "backup-executor",
            result.executors_without_conclusive_probe,
        )

    def test_unresolved_probe_remains_unresolved(self) -> None:
        result = audit_expiry(
            self.contract(),
            (
                self.probe(
                    "primary-executor", 11, ProbeOutcome.UNRESOLVED
                ),
            ),
        )
        self.assertEqual(len(result.unresolved_probes), 1)
        self.assertIn(
            "primary-executor",
            result.executors_without_conclusive_probe,
        )

    def test_empty_probe_set_does_not_demonstrate_lapse(self) -> None:
        result = audit_expiry(self.contract(), ())
        self.assertEqual(
            result.executors_without_conclusive_probe,
            self.contract().expected_executors,
        )

    def test_preexpiry_probe_cannot_support_this_test(self) -> None:
        with self.assertRaises(ValueError):
            audit_expiry(
                self.contract(),
                (
                    self.probe(
                        "primary-executor", 9, ProbeOutcome.DENIED
                    ),
                ),
            )

    def test_other_clock_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            audit_expiry(
                self.contract(),
                (
                    Probe(
                        "primary-executor",
                        Tick("different-clock", 11),
                        ProbeOutcome.DENIED,
                        "Synthetic evidence.",
                    ),
                ),
            )


if __name__ == "__main__":
    unittest.main()
