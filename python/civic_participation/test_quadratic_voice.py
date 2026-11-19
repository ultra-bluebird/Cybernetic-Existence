import unittest

from quadratic_voice import (
    QuadraticVoiceValidationError,
    evaluate_moderation_request,
    validate_equal_voice_ballot,
    validate_measurement_target,
)


class QuadraticVoiceTests(unittest.TestCase):
    def test_accepts_ballot_within_equal_budget(self) -> None:
        result = validate_equal_voice_ballot(
            votes_by_issue={
                "tree_canopy": 3,
                "cooling_centers": 4,
            },
            voice_credit_budget=25,
            maximum_absolute_votes_per_issue=5,
        )

        self.assertTrue(result.accepted)
        self.assertEqual(result.total_cost, 25)

    def test_rejects_ballot_over_equal_budget(self) -> None:
        result = validate_equal_voice_ballot(
            votes_by_issue={
                "tree_canopy": 4,
                "cooling_centers": 4,
            },
            voice_credit_budget=25,
            maximum_absolute_votes_per_issue=5,
        )

        self.assertFalse(result.accepted)
        self.assertEqual(result.total_cost, 32)

    def test_rejects_per_issue_vote_limit_breach(self) -> None:
        result = validate_equal_voice_ballot(
            votes_by_issue={"tree_canopy": 6},
            voice_credit_budget=49,
            maximum_absolute_votes_per_issue=5,
        )

        self.assertFalse(result.accepted)

    def test_rejects_identity_based_moderation(self) -> None:
        result = evaluate_moderation_request(
            reported_conduct="targeted_harassment",
            proposed_bases={"self_described_cybernetic_host_status"},
            evidence_reviewable=True,
        )

        self.assertEqual(result.action, "REJECT_PROFILE_BASED_MODERATION")
        self.assertTrue(result.human_review_required)

    def test_uses_reviewable_conduct_not_profile_data(self) -> None:
        result = evaluate_moderation_request(
            reported_conduct="targeted_harassment",
            proposed_bases={"reported_content"},
            evidence_reviewable=True,
        )

        self.assertEqual(result.action, "NARROW_TEMPORARY_BOUNDARY_WITH_REVIEW")
        self.assertTrue(result.appeal_available)

    def test_requires_actionable_conduct_category(self) -> None:
        result = evaluate_moderation_request(
            reported_conduct="identity_disagreement",
            proposed_bases={"reported_content"},
            evidence_reviewable=True,
        )

        self.assertEqual(result.action, "NO_RESTRICTION_WITHOUT_ACTIONABLE_CONDUCT")

    def test_validates_conservative_quiet_zone_measurement_target(self) -> None:
        self.assertTrue(validate_measurement_target(0.099))
        self.assertFalse(validate_measurement_target(0.1))

    def test_rejects_non_finite_measurement(self) -> None:
        with self.assertRaises(QuadraticVoiceValidationError):
            validate_measurement_target(float("nan"))


if __name__ == "__main__":
    unittest.main()
