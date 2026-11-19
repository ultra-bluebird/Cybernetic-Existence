import unittest

from acceptance_conditions import (
    AcceptanceResponses,
    AcceptanceWeights,
    ChacsWeights,
    LikertResponse,
    ResponseState,
    SourceEstimate,
    aggregate_reportable_scores,
    assess_acceptance,
    calculate_chacs,
)


def answered(value: int) -> LikertResponse:
    return LikertResponse(value=value, state=ResponseState.ANSWERED)


def source(
    normalized_value: float = 0.70,
    coverage: float = 0.90,
    provenance: float = 0.90,
    timeliness: float = 0.90,
    method_validity: float = 0.90,
    standard_error: float = 0.02,
) -> SourceEstimate:
    return SourceEstimate(
        normalized_value=normalized_value,
        coverage=coverage,
        provenance=provenance,
        timeliness=timeliness,
        method_validity=method_validity,
        standard_error=standard_error,
    )


def chacs_weights() -> ChacsWeights:
    return ChacsWeights(
        public_discourse=0.25,
        news_tone=0.20,
        institutional_response=0.25,
        complaint_burden=0.20,
        uncertainty_penalty=0.10,
    )


class AcceptanceConditionsTests(unittest.TestCase):
    def test_complete_likert_responses_produce_normalized_score(self) -> None:
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
        self.assertEqual(assessment.missing_or_withheld_domain_count, 0)

    def test_withheld_response_suppresses_individual_composite(self) -> None:
        assessment = assess_acceptance(
            AcceptanceResponses(
                cognitive_understanding=answered(6),
                emotional_comfort=LikertResponse(
                    value=None,
                    state=ResponseState.PREFER_NOT_TO_ANSWER,
                ),
                behavioral_integration=answered(6),
                institutional_trust=answered(5),
            )
        )

        self.assertFalse(assessment.reportable)
        self.assertIsNone(assessment.acceptance_score)
        self.assertEqual(assessment.missing_or_withheld_domain_count, 1)

    def test_invalid_likert_value_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            assess_acceptance(
                AcceptanceResponses(
                    cognitive_understanding=answered(8),
                    emotional_comfort=answered(5),
                    behavioral_integration=answered(5),
                    institutional_trust=answered(5),
                )
            )

    def test_invalid_acceptance_weight_total_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            assess_acceptance(
                AcceptanceResponses(
                    cognitive_understanding=answered(5),
                    emotional_comfort=answered(5),
                    behavioral_integration=answered(5),
                    institutional_trust=answered(5),
                ),
                weights=AcceptanceWeights(
                    cognitive_understanding=0.25,
                    emotional_comfort=0.25,
                    behavioral_integration=0.25,
                    institutional_trust=0.15,
                ),
            )

    def test_group_report_requires_minimum_aggregation_threshold(self) -> None:
        assessment = assess_acceptance(
            AcceptanceResponses(
                cognitive_understanding=answered(5),
                emotional_comfort=answered(5),
                behavioral_integration=answered(5),
                institutional_trust=answered(5),
            )
        )

        report = aggregate_reportable_scores(
            [assessment],
            minimum_group_size=50,
        )

        self.assertFalse(report.reportable)
        self.assertEqual(report.group_size, 1)
        self.assertEqual(report.reason, "minimum_group_size_not_met")

    def test_chacs_returns_score_for_sufficient_evidence(self) -> None:
        result = calculate_chacs(
            public_discourse=source(),
            news_tone=source(),
            institutional_response=source(),
            complaint_burden=source(normalized_value=0.20),
            weights=chacs_weights(),
            minimum_evidence_quality=0.50,
            maximum_standard_error=0.10,
        )

        self.assertFalse(result.suppressed)
        self.assertIsNotNone(result.score)
        self.assertIsNotNone(result.lower_bound)
        self.assertIsNotNone(result.upper_bound)
        self.assertGreaterEqual(result.score, 0.0)
        self.assertLessEqual(result.score, 100.0)

    def test_chacs_suppresses_low_quality_evidence(self) -> None:
        result = calculate_chacs(
            public_discourse=source(coverage=0.40),
            news_tone=source(),
            institutional_response=source(),
            complaint_burden=source(normalized_value=0.20),
            weights=chacs_weights(),
            minimum_evidence_quality=0.50,
            maximum_standard_error=0.10,
        )

        self.assertTrue(result.suppressed)
        self.assertIsNone(result.score)
        self.assertIn("evidence-quality", result.reason)

    def test_chacs_suppresses_excessive_uncertainty(self) -> None:
        result = calculate_chacs(
            public_discourse=source(standard_error=0.25),
            news_tone=source(standard_error=0.25),
            institutional_response=source(standard_error=0.25),
            complaint_burden=source(
                normalized_value=0.20,
                standard_error=0.25,
            ),
            weights=chacs_weights(),
            minimum_evidence_quality=0.50,
            maximum_standard_error=0.10,
        )

        self.assertTrue(result.suppressed)
        self.assertIsNone(result.score)
        self.assertIn("uncertainty", result.reason)

    def test_invalid_chacs_weight_total_is_rejected(self) -> None:
        with self.assertRaises(ValueError):
            calculate_chacs(
                public_discourse=source(),
                news_tone=source(),
                institutional_response=source(),
                complaint_burden=source(normalized_value=0.20),
                weights=ChacsWeights(
                    public_discourse=0.20,
                    news_tone=0.20,
                    institutional_response=0.20,
                    complaint_burden=0.20,
                    uncertainty_penalty=0.10,
                ),
                minimum_evidence_quality=0.50,
                maximum_standard_error=0.10,
            )


if __name__ == "__main__":
    unittest.main()
