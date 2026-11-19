"""Research-only SQLite referral branches.

Run:
    python research/pathways/transactional_referral_branches.py

No referral is sent and no personal case content is stored.
Transfer assessments are assertions supplied by a separately governed adapter.
"""

from dataclasses import dataclass
from enum import Enum
import json
import sqlite3
import unittest


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
ATTRIBUTION_SCOPE = (
    "Document credit and workstream metadata only; not identity, consent, "
    "capability authorization, execution evidence, or legal authority."
)


def require_text(value):
    if not isinstance(value, str) or not value.strip() or len(value) > 500:
        raise ValueError("Expected bounded nonempty text.")


class Command(Enum):
    SEND = "send"
    RETRY = "retry"
    RECEIVE = "receive"
    ACCEPT = "accept"
    ASSESS = "assess"
    RECORD_ACTION = "record_action"
    DECLINE = "decline"
    REOPEN = "reopen"
    REASSIGN = "reassign"


TRANSITIONS = {
    ("proposed", Command.SEND): "sent",
    ("sent", Command.RETRY): "sent",
    ("sent", Command.RECEIVE): "received",
    ("received", Command.ACCEPT): "accepted",
    ("received", Command.DECLINE): "declined",
    ("accepted", Command.ASSESS): "assessed",
    ("accepted", Command.DECLINE): "declined",
    ("assessed", Command.RECORD_ACTION): "action_recorded",
    ("assessed", Command.DECLINE): "declined",
    ("declined", Command.REOPEN): "proposed",
}


@dataclass(frozen=True)
class TransferAssessment:
    receiver: str
    purpose: str
    data_classes: tuple[str, ...]
    basis_kind: str
    basis_record: str
    valid_until: int

    def __post_init__(self):
        for value in (
            self.receiver, self.purpose, self.basis_kind, self.basis_record
        ):
            require_text(value)
        if self.basis_kind not in (
            "express_permission",
            "other_assessed_basis",
        ):
            raise ValueError("Unsupported transfer basis.")
        if not isinstance(self.data_classes, tuple):
            raise TypeError("Data classes must be a tuple.")
        for value in self.data_classes:
            require_text(value)
        if len(self.data_classes) != len(set(self.data_classes)):
            raise ValueError("Duplicate data class.")
        if type(self.valid_until) is not int or self.valid_until < 0:
            raise ValueError("Invalid transfer validity.")


class ReferralStore:
    def __init__(self, connection, clock_domain):
        require_text(clock_domain)
        self.connection = connection
        self.clock_domain = clock_domain
        self.connection.executescript("""
            CREATE TABLE IF NOT EXISTS branches (
                name TEXT PRIMARY KEY,
                matter TEXT NOT NULL,
                receiver TEXT NOT NULL,
                revision INTEGER NOT NULL,
                stage TEXT NOT NULL,
                last_tick INTEGER NOT NULL,
                due_tick INTEGER NOT NULL,
                retries INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS branch_events (
                branch_name TEXT NOT NULL,
                revision INTEGER NOT NULL,
                event_type TEXT NOT NULL,
                event_tick INTEGER NOT NULL,
                reason TEXT NOT NULL,
                transfer_assessment TEXT,
                PRIMARY KEY (branch_name, revision)
            );
        """)

    def create(self, name, matter, receiver, now, stage_duration):
        for value in (name, matter, receiver):
            require_text(value)
        self._time(now, stage_duration)
        with self.connection:
            self.connection.execute(
                "INSERT INTO branches VALUES (?, ?, ?, 0, ?, ?, ?, 0)",
                (name, matter, receiver, "proposed", now, now + stage_duration),
            )

    def _time(self, now, duration):
        if type(now) is not int or now < 0:
            raise ValueError("Invalid clock tick.")
        if type(duration) is not int or duration <= 0:
            raise ValueError("Stage duration must be positive.")

    def read(self, name):
        row = self.connection.execute(
            "SELECT matter, receiver, revision, stage, last_tick, due_tick, "
            "retries FROM branches WHERE name = ?", (name,)
        ).fetchone()
        if row is None:
            raise ValueError("Unknown branch.")
        return row

    def apply(
        self, name, expected_revision, command, now, domain,
        stage_duration, reason, transfer=None, new_receiver=None,
        maximum_retries=0,
    ):
        require_text(name)
        require_text(reason)
        self._time(now, stage_duration)
        if domain != self.clock_domain:
            raise ValueError("Clock conversion must be explicit.")
        if type(expected_revision) is not int or expected_revision < 0:
            raise ValueError("Invalid expected revision.")
        if not isinstance(command, Command):
            raise TypeError("Invalid command.")
        if type(maximum_retries) is not int or maximum_retries < 0:
            raise ValueError("Invalid retry policy.")

        self.connection.execute("BEGIN IMMEDIATE")
        try:
            matter, receiver, revision, stage, last_tick, due, retries = (
                self.read(name)
            )
            if revision != expected_revision:
                raise ValueError("Revision conflict.")
            if now < last_tick:
                raise ValueError("Clock moved backwards.")

            if command is Command.REASSIGN:
                if stage == "action_recorded":
                    raise ValueError("Reassessment needs a separate contract.")
                require_text(new_receiver)
                if new_receiver == receiver:
                    raise ValueError("Reassignment requires a different receiver.")
                receiver = new_receiver
                following = "proposed"
                retries = 0
            else:
                following = TRANSITIONS.get((stage, command))
                if following is None:
                    raise ValueError("Unsupported lifecycle transition.")

            if command is Command.RETRY:
                if retries >= maximum_retries:
                    raise ValueError("Retry limit reached; escalate.")
                retries += 1

            transfer_json = None
            if command in (Command.SEND, Command.RETRY, Command.REASSIGN):
                if not isinstance(transfer, TransferAssessment):
                    raise ValueError("A current transfer assessment is required.")
                if transfer.receiver != receiver or now >= transfer.valid_until:
                    raise ValueError("Transfer assessment does not cover recipient/time.")
                transfer_json = json.dumps({
                    "receiver": transfer.receiver,
                    "purpose": transfer.purpose,
                    "data_classes": transfer.data_classes,
                    "basis_kind": transfer.basis_kind,
                    "basis_record": transfer.basis_record,
                    "valid_until": transfer.valid_until,
                }, sort_keys=True)

            # Retrying does not reset the existing stage deadline.
            next_due = due if command is Command.RETRY else now + stage_duration
            next_revision = revision + 1

            self.connection.execute(
                "UPDATE branches SET receiver=?, revision=?, stage=?, "
                "last_tick=?, due_tick=?, retries=? WHERE name=?",
                (receiver, next_revision, following, now, next_due, retries, name),
            )
            self.connection.execute(
                "INSERT INTO branch_events VALUES (?, ?, ?, ?, ?, ?)",
                (
                    name, next_revision, command.value,
                    now, reason, transfer_json,
                ),
            )
            self.connection.commit()
            return self.read(name)
        except Exception:
            self.connection.rollback()
            raise


class ReferralStoreTests(unittest.TestCase):
    def setUp(self):
        self.connection = sqlite3.connect(":memory:")
        self.store = ReferralStore(self.connection, "synthetic-seconds")
        self.store.create("primary review", "synthetic matter", "body-a", 0, 5)
        self.transfer = TransferAssessment(
            "body-a", "bounded review", ("minimal-referral",),
            "express_permission", "controlled synthetic permission record", 50,
        )

    def tearDown(self):
        self.connection.close()

    def apply(self, revision, command, now, **options):
        return self.store.apply(
            "primary review", revision, command, now,
            "synthetic-seconds", 5, "Synthetic transition reason.",
            **options,
        )

    def test_send_without_transfer_basis_is_rejected(self):
        with self.assertRaises(ValueError):
            self.apply(0, Command.SEND, 1)
        self.assertEqual(self.store.read("primary review")[2], 0)

    def test_retry_does_not_reset_deadline(self):
        sent = self.apply(0, Command.SEND, 1, transfer=self.transfer)
        retried = self.apply(
            1, Command.RETRY, 3,
            transfer=self.transfer, maximum_retries=1,
        )
        self.assertEqual(sent[5], retried[5])

    def test_decline_and_reopen_preserve_history(self):
        self.apply(0, Command.SEND, 1, transfer=self.transfer)
        self.apply(1, Command.RECEIVE, 2)
        self.apply(2, Command.DECLINE, 3)
        reopened = self.apply(3, Command.REOPEN, 4)
        self.assertEqual(reopened[3], "proposed")
        count = self.connection.execute(
            "SELECT COUNT(*) FROM branch_events"
        ).fetchone()[0]
        self.assertEqual(count, 4)

    def test_stale_revision_cannot_append_event(self):
        self.apply(0, Command.SEND, 1, transfer=self.transfer)
        with self.assertRaises(ValueError):
            self.apply(0, Command.RECEIVE, 2)
        self.assertEqual(self.store.read("primary review")[2], 1)

    def test_parallel_branches_are_independent(self):
        self.store.create(
            "secondary review", "synthetic matter", "body-b", 0, 5
        )
        self.apply(0, Command.SEND, 1, transfer=self.transfer)
        self.assertEqual(self.store.read("secondary review")[3], "proposed")


if __name__ == "__main__":
    unittest.main()
