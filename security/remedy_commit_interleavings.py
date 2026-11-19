"""Finite research model for remedy content and check-execute races.

Run:
    python research/security/remedy_commit_interleavings.py

No signing, networking, storage, or real-world execution.
The guarded commit is an assumed atomic transition in this model.
"""

from collections import deque
from dataclasses import dataclass, replace
from enum import Enum
import unittest


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
ATTRIBUTION_SCOPE = (
    "Document credit and workstream metadata only; not identity, consent, "
    "capability authorization, execution evidence, or legal authority."
)


class Event(Enum):
    CHECK = "check"
    WITHDRAW = "withdraw"
    MUTATE_CONTENT = "mutate_content"
    COMMIT = "commit"


class CommitMode(Enum):
    UNSAFE_CHECK_THEN_USE = "unsafe_check_then_use"
    ATOMIC_GUARD = "atomic_guard"


@dataclass(frozen=True)
class State:
    authority_current: bool = True
    authority_epoch: int = 0
    checked_epoch: int | None = None
    check_completed: bool = False
    body_matches_approval: bool = True
    mutation_used: bool = False
    committed: bool = False
    rejected: bool = False
    unauthorized_commit: bool = False
    altered_content_commit: bool = False

    def __post_init__(self) -> None:
        for value in (
            self.authority_current,
            self.check_completed,
            self.body_matches_approval,
            self.mutation_used,
            self.committed,
            self.rejected,
            self.unauthorized_commit,
            self.altered_content_commit,
        ):
            if type(value) is not bool:
                raise TypeError("State flags must be Boolean.")
        if type(self.authority_epoch) is not int or self.authority_epoch < 0:
            raise ValueError("Invalid authority epoch.")
        if self.checked_epoch is not None:
            if type(self.checked_epoch) is not int or self.checked_epoch < 0:
                raise ValueError("Invalid checked epoch.")
        if self.committed and self.rejected:
            raise ValueError("A modeled attempt cannot commit and reject.")


def successors(
    state: State,
    mode: CommitMode,
) -> tuple[tuple[Event, State], ...]:
    if not isinstance(state, State) or not isinstance(mode, CommitMode):
        raise TypeError("Expected State and CommitMode.")

    transitions = []

    if not state.check_completed and not state.committed and not state.rejected:
        accepted = state.authority_current and state.body_matches_approval
        transitions.append((
            Event.CHECK,
            replace(
                state,
                check_completed=True,
                checked_epoch=state.authority_epoch if accepted else None,
                rejected=not accepted,
            ),
        ))

    if state.authority_current:
        transitions.append((
            Event.WITHDRAW,
            replace(
                state,
                authority_current=False,
                authority_epoch=state.authority_epoch + 1,
            ),
        ))

    if not state.mutation_used and not state.committed and not state.rejected:
        transitions.append((
            Event.MUTATE_CONTENT,
            replace(
                state,
                body_matches_approval=False,
                mutation_used=True,
            ),
        ))

    if (
        state.check_completed
        and state.checked_epoch is not None
        and not state.committed
        and not state.rejected
    ):
        if mode is CommitMode.ATOMIC_GUARD:
            permitted = (
                state.authority_current
                and state.checked_epoch == state.authority_epoch
                and state.body_matches_approval
            )
        else:
            permitted = True

        transitions.append((
            Event.COMMIT,
            replace(
                state,
                committed=permitted,
                rejected=not permitted,
                unauthorized_commit=(
                    permitted and not state.authority_current
                ),
                altered_content_commit=(
                    permitted and not state.body_matches_approval
                ),
            ),
        ))

    return tuple(transitions)


def explore(
    mode: CommitMode,
) -> dict[State, tuple[Event, ...]]:
    if not isinstance(mode, CommitMode):
        raise TypeError("Expected CommitMode.")

    initial = State()
    paths = {initial: ()}
    queue = deque([initial])

    while queue:
        state = queue.popleft()
        for event, following in successors(state, mode):
            if following not in paths:
                paths[following] = paths[state] + (event,)
                queue.append(following)

    return paths


class InterleavingTests(unittest.TestCase):
    def test_unsafe_model_has_withdrawal_race(self) -> None:
        paths = explore(CommitMode.UNSAFE_CHECK_THEN_USE)
        witnesses = [
            path
            for state, path in paths.items()
            if state.unauthorized_commit
        ]
        self.assertTrue(witnesses)
        self.assertIn(
            (Event.CHECK, Event.WITHDRAW, Event.COMMIT),
            witnesses,
        )

    def test_unsafe_model_has_content_race(self) -> None:
        paths = explore(CommitMode.UNSAFE_CHECK_THEN_USE)
        self.assertTrue(any(
            state.altered_content_commit for state in paths
        ))

    def test_guarded_model_prevents_both_modeled_failures(self) -> None:
        paths = explore(CommitMode.ATOMIC_GUARD)
        self.assertTrue(any(state.committed for state in paths))
        for state in paths:
            self.assertFalse(state.unauthorized_commit)
            self.assertFalse(state.altered_content_commit)

    def test_later_withdrawal_does_not_relabel_prior_commit(self) -> None:
        paths = explore(CommitMode.ATOMIC_GUARD)
        completed_then_withdrawn = [
            state
            for state in paths
            if state.committed and not state.authority_current
        ]
        self.assertTrue(completed_then_withdrawn)
        self.assertTrue(all(
            not state.unauthorized_commit
            for state in completed_then_withdrawn
        ))

    def test_rejected_attempt_cannot_later_commit(self) -> None:
        paths = explore(CommitMode.ATOMIC_GUARD)
        for state in paths:
            if state.rejected:
                self.assertFalse(any(
                    following.committed
                    for _, following in successors(
                        state, CommitMode.ATOMIC_GUARD
                    )
                ))


if __name__ == "__main__":
    unittest.main()
