"""Research-only lifecycle for one scoped disclosure hold.

Run:
    python research/governance/omission_resistant_hold_lifecycle.py

No authentication, networking, persistence, signing, or external actions.
Events must be admitted through a separately secured authorization adapter.
"""

from dataclasses import dataclass, replace
from enum import Enum
import unittest


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
ATTRIBUTION_SCOPE = (
    "Document credit and workstream metadata only; not identity, consent, "
    "capability authorization, execution evidence, or legal authority."
)


def nonempty(value: str) -> None:
    if not isinstance(value, str) or not value.strip() or len(value) > 500:
        raise ValueError("Expected bounded nonempty text.")


class ObservationState(Enum):
    PRESENT = "present"
    ABSENT = "absent"
    UNKNOWN = "unknown"


class Phase(Enum):
    NONE = "none"
    ACTIVE = "active"
    WITHDRAWN = "withdrawn"
    EXPIRED = "expired"


class EventKind(Enum):
    ESTABLISH = "establish"
    WITHDRAW = "withdraw"


class Duty(Enum):
    REFRESH_OBSERVATION = "refresh_observation"
    RECONCILE_RECORDS = "reconcile_records"
    REVIEW_REPORTED_HOLD = "review_reported_hold"


@dataclass(frozen=True)
class Tick:
    domain: str
    value: int

    def __post_init__(self) -> None:
        nonempty(self.domain)
        if type(self.value) is not int or self.value < 0:
            raise ValueError("Tick value must be a nonnegative integer.")


def same_domain(left: Tick, right: Tick) -> None:
    if not isinstance(left, Tick) or not isinstance(right, Tick):
        raise TypeError("Expected Tick values.")
    if left.domain != right.domain:
        raise ValueError("Clock conversion must be explicit.")


@dataclass(frozen=True)
class LifecycleEvent:
    kind: EventKind
    expected_revision: int
    effective_at: Tick
    expires_at: Tick | None
    scope: str
    authority_record: str

    def __post_init__(self) -> None:
        if not isinstance(self.kind, EventKind):
            raise TypeError("Invalid event kind.")
        if type(self.expected_revision) is not int or self.expected_revision < 0:
            raise ValueError("Invalid expected revision.")
        if not isinstance(self.effective_at, Tick):
            raise TypeError("Invalid effective time.")
        nonempty(self.scope)
        nonempty(self.authority_record)

        if self.kind is EventKind.ESTABLISH:
            if not isinstance(self.expires_at, Tick):
                raise ValueError("Establishment requires expiry.")
            same_domain(self.effective_at, self.expires_at)
            if self.expires_at.value <= self.effective_at.value:
                raise ValueError("Expiry must follow establishment.")
        elif self.expires_at is not None:
            raise ValueError("Withdrawal does not set a new expiry.")


@dataclass(frozen=True)
class HoldState:
    revision: int
    scope: str
    clock_domain: str
    phase: Phase = Phase.NONE
    last_event_at: Tick | None = None
    expires_at: Tick | None = None
    authority_records: tuple[str, ...] = ()

    def __post_init__(self) -> None:
        if type(self.revision) is not int or self.revision < 0:
            raise ValueError("Invalid revision.")
        nonempty(self.scope)
        nonempty(self.clock_domain)
        if not isinstance(self.phase, Phase):
            raise TypeError("Invalid phase.")
        if not isinstance(self.authority_records, tuple):
            raise TypeError("Authority records must be a tuple.")
        for record in self.authority_records:
            nonempty(record)
        for tick in (self.last_event_at, self.expires_at):
            if tick is not None:
                if not isinstance(tick, Tick) or tick.domain != self.clock_domain:
                    raise ValueError("State clock mismatch.")
        if self.phase is Phase.ACTIVE and self.expires_at is None:
            raise ValueError("Active state requires bounded expiry.")


def phase_at(state: HoldState, now: Tick) -> Phase:
    if not isinstance(state, HoldState):
        raise TypeError("Expected HoldState.")
    if not isinstance(now, Tick) or now.domain != state.clock_domain:
        raise ValueError("Clock mismatch.")
    if (
        state.last_event_at is not None
        and now.value < state.last_event_at.value
    ):
        raise ValueError("Historical queries require an earlier state projection.")
    if (
        state.phase is Phase.ACTIVE
        and now.value >= state.expires_at.value
    ):
        return Phase.EXPIRED
    return state.phase


def apply_event(state: HoldState, event: LifecycleEvent) -> HoldState:
    if not isinstance(state, HoldState) or not isinstance(event, LifecycleEvent):
        raise TypeError("Expected typed state and event.")
    if event.expected_revision != state.revision:
        raise ValueError("Revision conflict; rebuild from accepted history.")
    if event.scope != state.scope:
        raise ValueError("Event scope does not match this lifecycle.")
    if event.effective_at.domain != state.clock_domain:
        raise ValueError("Event clock mismatch.")
    if (
        state.last_event_at is not None
        and event.effective_at.value < state.last_event_at.value
    ):
        raise ValueError("This increment requires ordered effective events.")

    current = phase_at(state, event.effective_at)

    if event.kind is EventKind.ESTABLISH:
        if state.revision != 0 or current is not Phase.NONE:
            raise ValueError("Renewal or replacement needs a separate contract.")
        return replace(
            state,
            revision=state.revision + 1,
            phase=Phase.ACTIVE,
            last_event_at=event.effective_at,
            expires_at=event.expires_at,
            authority_records=(event.authority_record,),
        )

    if current is not Phase.ACTIVE:
        raise ValueError("Withdrawal requires a currently active hold.")

    return replace(
        state,
        revision=state.revision + 1,
        phase=Phase.WITHDRAWN,
        last_event_at=event.effective_at,
        authority_records=state.authority_records + (event.authority_record,),
    )


@dataclass(frozen=True)
class Assessment:
    phase: Phase
    disclosure_restricted: bool
    observation: ObservationState
    duties: frozenset[Duty]
    profile_version: str
    contract_version: str
    snapshot_revision: int
    assessed_at: Tick
    notice_key: str


def assess(
    state: HoldState,
    observation: ObservationState,
    now: Tick,
    profile_version: str,
    contract_version: str,
    notice_key: str,
) -> Assessment:
    if not isinstance(observation, ObservationState):
        raise TypeError("Expected an explicit observation state.")
    for value in (profile_version, contract_version, notice_key):
        nonempty(value)

    current = phase_at(state, now)
    active = current is Phase.ACTIVE
    duties = set()

    if observation is ObservationState.UNKNOWN:
        duties.add(Duty.REFRESH_OBSERVATION)
    elif observation is ObservationState.ABSENT and active:
        duties.add(Duty.RECONCILE_RECORDS)
    elif observation is ObservationState.PRESENT and not active:
        duties.add(Duty.REVIEW_REPORTED_HOLD)

    return Assessment(
        phase=current,
        disclosure_restricted=active,
        observation=observation,
        duties=frozenset(duties),
        profile_version=profile_version,
        contract_version=contract_version,
        snapshot_revision=state.revision,
        assessed_at=now,
        notice_key=notice_key,
    )


class OmissionResistanceTests(unittest.TestCase):
    def tick(self, value: int) -> Tick:
        return Tick("synthetic-seconds", value)

    def setUp(self) -> None:
        initial = HoldState(0, "synthetic-disclosure-scope", "synthetic-seconds")
        self.state = apply_event(
            initial,
            LifecycleEvent(
                EventKind.ESTABLISH,
                0,
                self.tick(1),
                self.tick(10),
                initial.scope,
                "controlled synthetic establishment assessment",
            ),
        )

    def receipt(self, observation, now=5):
        return assess(
            self.state,
            observation,
            self.tick(now),
            "synthetic-profile",
            "single-hold-lifecycle-v1",
            "research-notice",
        )

    def test_unknown_observation_does_not_lift_hold(self) -> None:
        receipt = self.receipt(ObservationState.UNKNOWN)
        self.assertTrue(receipt.disclosure_restricted)
        self.assertIn(Duty.REFRESH_OBSERVATION, receipt.duties)

    def test_absent_observation_requires_reconciliation(self) -> None:
        receipt = self.receipt(ObservationState.ABSENT)
        self.assertTrue(receipt.disclosure_restricted)
        self.assertIn(Duty.RECONCILE_RECORDS, receipt.duties)

    def test_all_observation_changes_preserve_active_state(self) -> None:
        for first in ObservationState:
            for second in ObservationState:
                self.assertTrue(self.receipt(first).disclosure_restricted)
                self.assertTrue(self.receipt(second).disclosure_restricted)
        self.assertEqual(self.state.revision, 1)

    def test_withdrawal_changes_lifecycle(self) -> None:
        withdrawn = apply_event(
            self.state,
            LifecycleEvent(
                EventKind.WITHDRAW,
                1,
                self.tick(6),
                None,
                self.state.scope,
                "controlled synthetic withdrawal assessment",
            ),
        )
        self.assertIs(phase_at(withdrawn, self.tick(6)), Phase.WITHDRAWN)

    def test_expiry_ends_hold_without_adapter_permission(self) -> None:
        receipt = self.receipt(ObservationState.UNKNOWN, now=10)
        self.assertFalse(receipt.disclosure_restricted)
        self.assertIs(receipt.phase, Phase.EXPIRED)

    def test_stale_revision_cannot_withdraw(self) -> None:
        with self.assertRaises(ValueError):
            apply_event(
                self.state,
                LifecycleEvent(
                    EventKind.WITHDRAW,
                    0,
                    self.tick(6),
                    None,
                    self.state.scope,
                    "synthetic stale withdrawal attempt",
                ),
            )

    def test_reported_hold_after_expiry_does_not_auto_renew(self) -> None:
        receipt = self.receipt(ObservationState.PRESENT, now=11)
        self.assertFalse(receipt.disclosure_restricted)
        self.assertIn(Duty.REVIEW_REPORTED_HOLD, receipt.duties)


if __name__ == "__main__":
    unittest.main()
