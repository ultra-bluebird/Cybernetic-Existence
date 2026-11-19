import unittest

from equity_prioritization import (
    CandidateProject,
    PlanningWeights,
    ResiliencePlanningError,
    prioritize,
)


class EquityPrioritizationTests(unittest.TestCase):
    def weights(self) -> PlanningWeights:
        return PlanningWeights(
            social_need=0.60,
            ecological_benefit=0.25,
            feasibility=0.15,
        )

    def test_prioritizes_eligible_human_needs_project(self) -> None:
        decisions = prioritize(
            [
                CandidateProject(
                    label="cooling_and_shade_hub",
                    social_need=0.9,
                    ecological_benefit=0.7,
                    feasibility=0.6,
                    displacement_risk=0.1,
                    rights_accessibility_risk=0.1,
                    uncertainty=0.1,
                )
            ],
            self.weights(),
        )

        self.assertTrue(decisions[0].eligible)
        self.assertGreater(decisions[0].uncertainty_adjusted_score, 0.0)

    def test_blocks_high_ecological_benefit_when_displacement_risk_is_too_high(self) -> None:
        decisions = prioritize(
            [
                CandidateProject(
                    label="green_roof_redevelopment",
                    social_need=0.8,
                    ecological_benefit=1.0,
                    feasibility=0.9,
                    displacement_risk=0.3,
                    rights_accessibility_risk=0.1,
                    uncertainty=0.1,
                )
            ],
            self.weights(),
        )

        self.assertFalse(decisions[0].eligible)
        self.assertIn("displacement-risk", decisions[0].reason)

    def test_rejects_wealth_substituting_weight_configuration(self) -> None:
        with self.assertRaises(ResiliencePlanningError):
            PlanningWeights(
                social_need=0.5,
                ecological_benefit=0.25,
                feasibility=0.25,
            )

    def test_blocks_candidate_below_human_needs_floor(self) -> None:
        decisions = prioritize(
            [
                CandidateProject(
                    label="low_need_project",
                    social_need=0.39,
                    ecological_benefit=0.9,
                    feasibility=0.9,
                    displacement_risk=0.0,
                    rights_accessibility_risk=0.0,
                    uncertainty=0.0,
                )
            ],
            self.weights(),
        )

        self.assertFalse(decisions[0].eligible)
        self.assertIn("human-needs floor", decisions[0].reason)


if __name__ == "__main__":
    unittest.main()
