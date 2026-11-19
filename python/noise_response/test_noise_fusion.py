import unittest

from noise_fusion import (
    NoiseEvidence,
    evaluate_noise_review,
    privacy_safe_noise_audit_record,
)


class NoiseFusionTests(unittest.TestCase):
    def test_measurement_above_night_threshold_requires_human_review(self) -> None:
        decision = evaluate_noise_review(
            NoiseEvidence(
                leq_dba=56.0,
                measurement_validated=True,
                sensor_health_valid=True,
                uncertainty=0.1,
                complaint_evidence_level=0,
                accessibility_or_sleep_disruption_context=0.0,
            )
        )

        self.assertEqual(decision.state, "REVIEW_REQUIRED")
        self.assertFalse(decision.automated_enforcement_performed)

    def test_complaint_context_can_request_review_without_frequency_ranking(self) -> None:
        decision = evaluate_noise_review(
            NoiseEvidence(
                leq_dba=50.0,
                measurement_validated=True,
                sensor_health_valid=True,
                uncertainty=0.1,
                complaint_evidence_level=1,
                accessibility_or_sleep_disruption_context=0.8,
            )
        )

        self.assertEqual(decision.state, "REVIEW_REQUIRED")
        self.assertFalse(decision.automated_enforcement_performed)

    def test_invalid_sensor_requires_calibration_check(self) -> None:
        decision = evaluate_noise_review(
            NoiseEvidence(
                leq_dba=70.0,
                measurement_validated=False,
                sensor_health_valid=False,
                uncertainty=0.1,
                complaint_evidence_level=2,
                accessibility_or_sleep_disruption_context=1.0,
            )
        )

        self.assertEqual(decision.state, "CALIBRATION_AND_CONTEXT_CHECK")
        self.assertFalse(decision.automated_enforcement_performed)

    def test_privacy_audit_excludes_audio_identity_and_scoring(self) -> None:
        record = privacy_safe_noise_audit_record()

        self.assertFalse(record["raw_audio_retained"])
        self.assertFalse(record["voiceprint_created"])
        self.assertFalse(record["reporter_identity_retained"])
        self.assertFalse(record["reporter_frequency_score_used"])
        self.assertFalse(record["automated_enforcement_performed"])


if __name__ == "__main__":
    unittest.main()
