import unittest

from privacy_safe_ecology import (
    AcousticFrameAssessment,
    CwsiInput,
    ReflectanceSample,
    cwsi,
    evi,
    ndvi,
    normalized_evenness,
    shannon_entropy,
    summarize_acoustic_frame,
    summarize_reflectance_sample,
)


class PrivacySafeEcologyTests(unittest.TestCase):
    def test_speech_like_audio_is_not_retained(self) -> None:
        summary = summarize_acoustic_frame(
            AcousticFrameAssessment(
                speech_likelihood=0.72,
                ecological_signal_quality=0.95,
                species_group_probabilities={
                    "native-bird-group": 0.91,
                    "insect-group": 0.05,
                    "unknown": 0.04,
                },
            )
        )

        self.assertFalse(summary.retained)
        self.assertIsNone(summary.species_group)

    def test_low_confidence_ecological_audio_is_unknown_not_forced(self) -> None:
        summary = summarize_acoustic_frame(
            AcousticFrameAssessment(
                speech_likelihood=0.01,
                ecological_signal_quality=0.90,
                species_group_probabilities={
                    "native-bird-group": 0.42,
                    "insect-group": 0.36,
                    "bat-group": 0.22,
                },
            )
        )

        self.assertTrue(summary.retained)
        self.assertEqual(summary.species_group, "unknown-ecological-event")

    def test_clear_high_quality_reflectance_yields_indices(self) -> None:
        summary = summarize_reflectance_sample(
            ReflectanceSample(
                near_infrared=0.72,
                red=0.18,
                blue=0.09,
                image_quality=0.93,
                privacy_clear=True,
            )
        )

        self.assertTrue(summary.retained)
        self.assertIsNotNone(summary.ndvi)
        self.assertIsNotNone(summary.evi)
        self.assertIsNotNone(summary.evi2)
        assert summary.ndvi is not None
        self.assertGreater(summary.ndvi, 0.0)

    def test_privacy_uncertain_imagery_yields_no_indices(self) -> None:
        summary = summarize_reflectance_sample(
            ReflectanceSample(
                near_infrared=0.72,
                red=0.18,
                image_quality=0.95,
                privacy_clear=False,
            )
        )

        self.assertFalse(summary.retained)
        self.assertIsNone(summary.ndvi)
        self.assertIsNone(summary.evi)
        self.assertIsNone(summary.evi2)

    def test_spectral_index_formulas(self) -> None:
        sample = ReflectanceSample(
            near_infrared=0.80,
            red=0.20,
            blue=0.10,
            privacy_clear=True,
        )

        self.assertAlmostEqual(ndvi(sample), 0.60)
        self.assertGreater(evi(sample), 0.0)

    def test_shannon_entropy_and_evenness(self) -> None:
        counts = {
            "native-bird-group": 10,
            "insect-group": 10,
            "bat-group": 10,
        }

        self.assertAlmostEqual(
            shannon_entropy(counts),
            1.0986122886681098,
        )
        self.assertAlmostEqual(normalized_evenness(counts), 1.0)

    def test_cwsi(self) -> None:
        value = cwsi(
            CwsiInput(
                canopy_temperature_c=34.0,
                dry_reference_temperature_c=40.0,
                wet_reference_temperature_c=28.0,
            )
        )

        self.assertAlmostEqual(value, 0.50)

    def test_invalid_cwsi_references_are_rejected(self) -> None:
        with self.assertRaises(ValueError):
            CwsiInput(
                canopy_temperature_c=34.0,
                dry_reference_temperature_c=28.0,
                wet_reference_temperature_c=28.0,
            )


if __name__ == "__main__":
    unittest.main()
