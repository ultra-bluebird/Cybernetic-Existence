"""Research-only procedural audit replay.

Run:
    python research/audits/procedural_replay_contract.py

No networking, signatures, confidential content, or external action.
Replay tests declared record presence, not substantive fairness.
"""

from dataclasses import dataclass
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


class RecordState(Enum):
    PRESENT = "present"
    ABSENT = "absent"
    UNKNOWN = "unknown"


class CheckName(Enum):
    AUTHORITY_BASIS_RECORDED = "authority_basis_recorded"
    REASONS_RECORDED = "reasons_recorded"
    REVIEW_ROUTE_RECORDED = "review_route_recorded"
    EXPIRY_RULE_RECORDED = "expiry_rule_recorded"


class ReplayState(Enum):
    MATCH = "match"
    MISMATCH = "mismatch"
    MISSING_ARTIFACT = "missing_artifact"
    UNSUPPORTED_CONTRACT = "unsupported_contract"


@dataclass(frozen=True)
class Snapshot:
    history_revision: str
    observations: tuple[tuple[CheckName, RecordState], ...]

    def __post_init__(self) -> None:
        require_text(self.history_revision)
        if not isinstance(self.observations, tuple):
            raise TypeError("Observations must be a tuple.")
        seen = set()
        for item in self.observations:
            if not isinstance(item, tuple) or len(item) != 2:
                raise TypeError("Each observation must be a pair.")
            name, state = item
            if not isinstance(name, CheckName):
                raise TypeError("Invalid check name.")
            if not isinstance(state, RecordState):
                raise TypeError("Invalid record state.")
            if name in seen:
                raise ValueError("Duplicate observation.")
            seen.add(name)


@dataclass(frozen=True)
class ReplayPacket:
    contract_version: str
    evaluator_revision: str
    policy_revision: str
    snapshot: Snapshot | None
    original_output: tuple[tuple[CheckName, RecordState], ...] | None

    def __post_init__(self) -> None:
        for value in (
            self.contract_version,
            self.evaluator_revision,
            self.policy_revision,
        ):
            require_text(value)
        if self.snapshot is not None and not isinstance(self.snapshot, Snapshot):
            raise TypeError("Invalid snapshot.")
        if self.original_output is not None:
            Snapshot("original-output-validation", self.original_output)


@dataclass(frozen=True)
class ReplayReport:
    state: ReplayState
    recomputed_output: tuple[tuple[CheckName, RecordState], ...] | None
    differences: tuple[CheckName, ...]
    unresolved_checks: tuple[CheckName, ...]
    notice_key: str


SUPPORTED_CONTRACT = "record-presence-replay-v1"
EVALUATOR_REVISION = "reference-evaluator-v1"
POLICY_REVISION = "record-presence-policy-v1"


def evaluate(snapshot: Snapshot) -> tuple[tuple[CheckName, RecordState], ...]:
    if not isinstance(snapshot, Snapshot):
        raise TypeError("Expected Snapshot.")
    supplied = dict(snapshot.observations)
    return tuple(
        (name, supplied.get(name, RecordState.UNKNOWN))
        for name in CheckName
    )


def replay(packet: ReplayPacket) -> ReplayReport:
    if not isinstance(packet, ReplayPacket):
        raise TypeError("Expected ReplayPacket.")

    notice = "procedural-replay-is-not-substantive-validation"

    if (
        packet.contract_version != SUPPORTED_CONTRACT
        or packet.evaluator_revision != EVALUATOR_REVISION
        or packet.policy_revision != POLICY_REVISION
    ):
        return ReplayReport(
            ReplayState.UNSUPPORTED_CONTRACT,
            None,
            (),
            (),
            notice,
        )

    if packet.snapshot is None or packet.original_output is None:
        return ReplayReport(
            ReplayState.MISSING_ARTIFACT,
            None,
            (),
            (),
            notice,
        )

    recomputed = evaluate(packet.snapshot)
    original = dict(packet.original_output)
    differences = tuple(
        name
        for name, state in recomputed
        if name not in original or original[name] is not state
    )
    unresolved = tuple(
        name
        for name, state in recomputed
        if state is RecordState.UNKNOWN
    )

    return ReplayReport(
        ReplayState.MISMATCH if differences else ReplayState.MATCH,
        recomputed,
        differences,
        unresolved,
        notice,
    )


class ProceduralReplayTests(unittest.TestCase):
    def packet(self, snapshot, original):
        return ReplayPacket(
            SUPPORTED_CONTRACT,
            EVALUATOR_REVISION,
            POLICY_REVISION,
            snapshot,
            original,
        )

    def test_matching_output(self):
        snapshot = Snapshot(
            "synthetic-history",
            tuple((name, RecordState.PRESENT) for name in CheckName),
        )
        report = replay(self.packet(snapshot, evaluate(snapshot)))
        self.assertIs(report.state, ReplayState.MATCH)

    def test_omitted_observation_stays_unknown(self):
        snapshot = Snapshot("synthetic-history", ())
        report = replay(self.packet(snapshot, evaluate(snapshot)))
        self.assertEqual(report.unresolved_checks, tuple(CheckName))
        self.assertIs(report.state, ReplayState.MATCH)

    def test_match_can_contain_uncertainty(self):
        snapshot = Snapshot("synthetic-history", ())
        report = replay(self.packet(snapshot, evaluate(snapshot)))
        self.assertTrue(report.unresolved_checks)
        self.assertEqual(
            report.notice_key,
            "procedural-replay-is-not-substantive-validation",
        )

    def test_original_success_not_reproduced_from_unknown_input(self):
        snapshot = Snapshot("synthetic-history", ())
        original = tuple(
            (name, RecordState.PRESENT) for name in CheckName
        )
        report = replay(self.packet(snapshot, original))
        self.assertIs(report.state, ReplayState.MISMATCH)
        self.assertEqual(set(report.differences), set(CheckName))

    def test_missing_snapshot_is_not_a_match(self):
        report = replay(self.packet(None, ()))
        self.assertIs(report.state, ReplayState.MISSING_ARTIFACT)

    def test_unknown_contract_is_explicit(self):
        packet = ReplayPacket(
            "unsupported-contract",
            EVALUATOR_REVISION,
            POLICY_REVISION,
            None,
            None,
        )
        self.assertIs(
            replay(packet).state,
            ReplayState.UNSUPPORTED_CONTRACT,
        )

    def test_duplicate_observation_rejected(self):
        with self.assertRaises(ValueError):
            Snapshot(
                "synthetic-history",
                (
                    (CheckName.REASONS_RECORDED, RecordState.PRESENT),
                    (CheckName.REASONS_RECORDED, RecordState.ABSENT),
                ),
            )


if __name__ == "__main__":
    unittest.main()
