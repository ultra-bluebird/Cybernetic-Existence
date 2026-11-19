"""Research-only recovery-profile review.

Run:
    python research/remedies/reversibility_and_substrate_review.py

No diagnosis, personhood assessment, networking, or external action.
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
        or len(value) > 2000
    ):
        raise ValueError("Expected bounded nonempty text.")


class RecoveryDimension(Enum):
    STATE = "state"
    FUNCTION = "function"
    CONTINUITY = "continuity"
    OPPORTUNITY = "opportunity"


class RecoveryStatus(Enum):
    RECOVERY_SUPPORTED = "recovery_supported"
    PARTIAL_RECOVERY_SUPPORTED = "partial_recovery_supported"
    NONRECOVERY_SUPPORTED = "nonrecovery_supported"
    UNKNOWN = "unknown"
    NOT_APPLICABLE = "not_applicable"


class ReviewDuty(Enum):
    ASSESS_UNKNOWN_RECOVERY = "assess_unknown_recovery"
    RECORD_RESIDUAL_LOSS = "record_residual_loss"
    EXAMINE_OPTION_PRESERVATION = "examine_option_preservation"
    EXAMINE_DELAY_CONSEQUENCES = "examine_delay_consequences"


@dataclass(frozen=True)
class RecoveryAssessment:
    dimension: RecoveryDimension
    status: RecoveryStatus
    basis: str
    horizon: str
    affected_aspect: str

    def __post_init__(self) -> None:
        if not isinstance(self.dimension, RecoveryDimension):
            raise TypeError("Invalid recovery dimension.")
        if not isinstance(self.status, RecoveryStatus):
            raise TypeError("Invalid recovery status.")
        for value in (self.basis, self.horizon, self.affected_aspect):
            bounded_text(value)


@dataclass(frozen=True)
class ReversibilityProfile:
    interest_description: str
    material_description: str
    causal_mechanism: str
    action_consequences: str
    waiting_consequences: str
    dimensions: tuple[RecoveryAssessment, ...]
    mandate_basis: str
    challenge_route: str

    def __post_init__(self) -> None:
        for value in (
            self.interest_description,
            self.material_description,
            self.causal_mechanism,
            self.action_consequences,
            self.waiting_consequences,
            self.mandate_basis,
            self.challenge_route,
        ):
            bounded_text(value)

        if not isinstance(self.dimensions, tuple):
            raise TypeError("Recovery assessments must be a tuple.")
        if any(
            not isinstance(item, RecoveryAssessment)
            for item in self.dimensions
        ):
            raise TypeError("Invalid recovery assessment.")

        actual = [item.dimension for item in self.dimensions]
        if len(actual) != len(set(actual)):
            raise ValueError("Duplicate recovery dimension.")
        if set(actual) != set(RecoveryDimension):
            raise ValueError("Every recovery dimension must be addressed.")


@dataclass(frozen=True)
class ReviewResult:
    unknown_dimensions: frozenset[RecoveryDimension]
    residual_loss_dimensions: frozenset[RecoveryDimension]
    duties: frozenset[ReviewDuty]
    contract_version: str
    notice_key: str


def review_profile(profile: ReversibilityProfile) -> ReviewResult:
    if not isinstance(profile, ReversibilityProfile):
        raise TypeError("Expected ReversibilityProfile.")

    unknown = frozenset(
        item.dimension
        for item in profile.dimensions
        if item.status is RecoveryStatus.UNKNOWN
    )
    residual = frozenset(
        item.dimension
        for item in profile.dimensions
        if item.status in (
            RecoveryStatus.PARTIAL_RECOVERY_SUPPORTED,
            RecoveryStatus.NONRECOVERY_SUPPORTED,
        )
    )

    duties = {ReviewDuty.EXAMINE_DELAY_CONSEQUENCES}
    if unknown:
        duties.add(ReviewDuty.ASSESS_UNKNOWN_RECOVERY)
        duties.add(ReviewDuty.EXAMINE_OPTION_PRESERVATION)
    if residual:
        duties.add(ReviewDuty.RECORD_RESIDUAL_LOSS)
        duties.add(ReviewDuty.EXAMINE_OPTION_PRESERVATION)

    return ReviewResult(
        unknown_dimensions=unknown,
        residual_loss_dimensions=residual,
        duties=frozenset(duties),
        contract_version="recovery-review-research-v1",
        notice_key="research-recovery-review",
    )


def synthetic_profile() -> ReversibilityProfile:
    statuses = {
        RecoveryDimension.STATE: RecoveryStatus.PARTIAL_RECOVERY_SUPPORTED,
        RecoveryDimension.FUNCTION: RecoveryStatus.UNKNOWN,
        RecoveryDimension.CONTINUITY: RecoveryStatus.NONRECOVERY_SUPPORTED,
        RecoveryDimension.OPPORTUNITY: RecoveryStatus.UNKNOWN,
    }
    return ReversibilityProfile(
        interest_description="Synthetic habitat and participation interests.",
        material_description="Synthetic description; not a worth classification.",
        causal_mechanism="Synthetic disturbance of a stated dependency.",
        action_consequences="Synthetic partial repair with residual loss.",
        waiting_consequences="Synthetic risk of missing a recovery window.",
        dimensions=tuple(
            RecoveryAssessment(
                dimension=dimension,
                status=statuses[dimension],
                basis="Synthetic assessed basis, not real ecological evidence.",
                horizon="Synthetic review horizon; not a forecast.",
                affected_aspect=f"Synthetic {dimension.value} aspect.",
            )
            for dimension in RecoveryDimension
        ),
        mandate_basis="Synthetic bounded research mandate.",
        challenge_route="Synthetic accessible independent review.",
    )


class RecoveryReviewTests(unittest.TestCase):
    def test_unknown_is_preserved(self) -> None:
        result = review_profile(synthetic_profile())
        self.assertIn(
            RecoveryDimension.FUNCTION,
            result.unknown_dimensions,
        )

    def test_residual_loss_is_not_called_full_restoration(self) -> None:
        result = review_profile(synthetic_profile())
        self.assertIn(
            RecoveryDimension.CONTINUITY,
            result.residual_loss_dimensions,
        )
        self.assertIn(ReviewDuty.RECORD_RESIDUAL_LOSS, result.duties)

    def test_irrelevant_material_label_does_not_change_findings(self) -> None:
        original = synthetic_profile()
        relabeled = replace(
            original,
            material_description="Different synthetic material description.",
        )
        self.assertEqual(
            review_profile(original),
            review_profile(relabeled),
        )

    def test_every_dimension_is_required(self) -> None:
        profile = synthetic_profile()
        with self.assertRaises(ValueError):
            replace(profile, dimensions=profile.dimensions[:-1])

    def test_duplicate_dimension_rejected(self) -> None:
        profile = synthetic_profile()
        with self.assertRaises(ValueError):
            replace(
                profile,
                dimensions=profile.dimensions[:-1] + (profile.dimensions[0],),
            )

    def test_waiting_consequences_remain_a_review_duty(self) -> None:
        result = review_profile(synthetic_profile())
        self.assertIn(
            ReviewDuty.EXAMINE_DELAY_CONSEQUENCES,
            result.duties,
        )


if __name__ == "__main__":
    unittest.main()
