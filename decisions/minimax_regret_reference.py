"""Research-only minimax-regret calculation.

Run:
    python research/decisions/minimax_regret_reference.py

No legal authority, rights assessment, or external action.
Loss values must already have a reviewed common regret scale.
"""

from dataclasses import dataclass
from fractions import Fraction
import unittest


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
ATTRIBUTION_SCOPE = (
    "Document credit and workstream metadata only; not identity, consent, "
    "capability authorization, execution evidence, or legal authority."
)


@dataclass(frozen=True)
class LossProblem:
    actions: tuple[str, ...]
    scenarios: tuple[str, ...]
    losses: tuple[tuple[Fraction, ...], ...]
    common_scale_basis: str

    def __post_init__(self) -> None:
        for labels in (self.actions, self.scenarios):
            if not isinstance(labels, tuple) or not labels:
                raise ValueError("Nonempty immutable labels are required.")
            if any(
                not isinstance(label, str) or not label.strip()
                for label in labels
            ):
                raise ValueError("Labels must be nonempty text.")
            if len(labels) != len(set(labels)):
                raise ValueError("Labels must be unique.")

        if (
            not isinstance(self.common_scale_basis, str)
            or not self.common_scale_basis.strip()
        ):
            raise ValueError("A reviewed common-scale basis is required.")

        if not isinstance(self.losses, tuple):
            raise TypeError("Loss rows must be an immutable tuple.")
        if len(self.losses) != len(self.actions):
            raise ValueError("One loss row is required per action.")

        for row in self.losses:
            if not isinstance(row, tuple) or len(row) != len(self.scenarios):
                raise ValueError("Every action needs every scenario loss.")
            if any(not isinstance(value, Fraction) for value in row):
                raise TypeError("Use exact Fraction values; no missing cells.")


@dataclass(frozen=True)
class RegretResult:
    regrets: tuple[tuple[Fraction, ...], ...]
    worst_regrets: tuple[Fraction, ...]
    candidate_actions: tuple[str, ...]
    common_scale_basis: str


def minimax_regret(problem: LossProblem) -> RegretResult:
    if not isinstance(problem, LossProblem):
        raise TypeError("Expected LossProblem.")

    best_by_scenario = tuple(
        min(row[column] for row in problem.losses)
        for column in range(len(problem.scenarios))
    )
    regrets = tuple(
        tuple(
            loss - best_by_scenario[column]
            for column, loss in enumerate(row)
        )
        for row in problem.losses
    )
    worst = tuple(max(row) for row in regrets)
    minimum_worst = min(worst)

    return RegretResult(
        regrets=regrets,
        worst_regrets=worst,
        candidate_actions=tuple(
            action
            for action, value in zip(problem.actions, worst)
            if value == minimum_worst
        ),
        common_scale_basis=problem.common_scale_basis,
    )


class MinimaxRegretTests(unittest.TestCase):
    def problem(self) -> LossProblem:
        return LossProblem(
            actions=("synthetic-a", "synthetic-b", "synthetic-c"),
            scenarios=("synthetic-first", "synthetic-second"),
            losses=(
                (Fraction(0), Fraction(10)),
                (Fraction(4), Fraction(4)),
                (Fraction(6), Fraction(1)),
            ),
            common_scale_basis=(
                "Synthetic common interval scale for arithmetic testing only."
            ),
        )

    def test_reference_computation(self) -> None:
        result = minimax_regret(self.problem())
        self.assertEqual(
            result.worst_regrets,
            (Fraction(9), Fraction(4), Fraction(6)),
        )
        self.assertEqual(result.candidate_actions, ("synthetic-b",))

    def test_common_positive_scaling_and_scenario_offsets(self) -> None:
        original = self.problem()
        transformed = LossProblem(
            actions=original.actions,
            scenarios=original.scenarios,
            losses=tuple(
                (
                    Fraction(2) * row[0] + Fraction(7),
                    Fraction(2) * row[1] - Fraction(3),
                )
                for row in original.losses
            ),
            common_scale_basis=original.common_scale_basis,
        )
        self.assertEqual(
            minimax_regret(original).candidate_actions,
            minimax_regret(transformed).candidate_actions,
        )

    def test_scenario_specific_scaling_can_change_selection(self) -> None:
        original = self.problem()
        transformed = LossProblem(
            actions=original.actions,
            scenarios=original.scenarios,
            losses=tuple(
                (row[0], Fraction(10) * row[1])
                for row in original.losses
            ),
            common_scale_basis=(
                "Synthetic sensitivity case; not equivalent to original scale."
            ),
        )
        self.assertNotEqual(
            minimax_regret(original).candidate_actions,
            minimax_regret(transformed).candidate_actions,
        )

    def test_ties_are_preserved(self) -> None:
        problem = LossProblem(
            actions=("synthetic-a", "synthetic-b"),
            scenarios=("synthetic-first", "synthetic-second"),
            losses=(
                (Fraction(0), Fraction(2)),
                (Fraction(2), Fraction(0)),
            ),
            common_scale_basis="Synthetic common interval scale.",
        )
        self.assertEqual(
            minimax_regret(problem).candidate_actions,
            problem.actions,
        )

    def test_missing_scenario_loss_rejected(self) -> None:
        with self.assertRaises(ValueError):
            LossProblem(
                actions=("synthetic-a",),
                scenarios=("synthetic-first", "synthetic-second"),
                losses=((Fraction(1),),),
                common_scale_basis="Synthetic scale.",
            )


if __name__ == "__main__":
    unittest.main()
