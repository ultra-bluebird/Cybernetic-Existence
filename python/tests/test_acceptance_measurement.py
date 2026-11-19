import unittest

from acceptance_measurement import (
    AcceptanceResponses,
    LikertResponse,
    ResponseState,
    assess_acceptance,
    aggregate_reportable_scores,
)


def answered(value: int) -> LikertResponse:
    return LikertResponse(value=value, state=ResponseState.ANSWERED)


class AcceptanceMeasurementTests(unittest.TestCase):
    def test_complete_responses_produce_a_normalized_research_score(self) -> None:
        assessment = assess_acceptance(
            AcceptanceResponses(
                cognitive_understanding=answered(7),
                emotional_comfort=answered(7),
                behavioral_integration=answered(7),
                institutional_trust=answered(7),
            )
        )

        self.assertTrue(assessment.reportable)
        self.assertEqual(assessment.acceptance_score, 1.0)

    def test_prefer_not_to_answer_blocks_individual_composite(self) -> None:
        assessment = assess_acceptance(
            AcceptanceResponses(
                cognitive_understanding=answered(6),
                emotional_comfort=LikertResponse(
                    value=None,
                    state=ResponseState.PREFER_NOT_TO_ANSWER,
                ),
                behavioral_integration=answered(5),
                institutional_trust=answered(4),
            )
        )

        self.assertFalse(assessment.reportable)
        self.assertIsNone(assessment.acceptance_score)

    def test_group_reporting_requires_minimum_size(self) -> None:
        assessment = assess_acceptance(
            AcceptanceResponses(
                cognitive_understanding=answered(5),
                emotional_comfort=answered(5),
                behavioral_integration=answered(5),
                institutional_trust=answered(5),
            )
        )

        report = aggregate_reportable_scores([assessment], minimum_group_size=50)

        self.assertFalse(report["reportable"])
        self.assertEqual(report["reason"], "minimum_group_size_not_met")

    def test_invalid_answered_value_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            assess_acceptance(
                AcceptanceResponses(
                    cognitive_understanding=answered(8),
                    emotional_comfort=answered(5),
                    behavioral_integration=answered(5),
                    institutional_trust=answered(5),
                )
            )


if __name__ == "__main__":
    unittest.main()
