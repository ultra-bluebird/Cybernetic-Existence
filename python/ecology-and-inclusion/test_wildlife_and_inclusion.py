import unittest

from digital_inclusion.index import (
    InclusionComponents,
    evaluate_digital_inclusion,
)
from wildlife_monitoring.chao1 import (
    AcousticEvent,
    chao1,
    filter_events,
)


class WildlifeMonitoringTests(unittest.TestCase):
    def test_discards_probable_human_speech_and_retains_no_raw_audio(self) -> None:
        summary = filter_events(
            [
                AcousticEvent(
                    taxon_label="bird_group_a",
                    confidence=0.95,
                    audio_quality=0.90,
                    probable_human_speech=False,
                    raw_audio_retained=False,
                    human_identity_data_present=False,
                    device_identifier_present=False,
                ),
                AcousticEvent(
                    taxon_label="unknown",
                    confidence=0.99,
                    audio_quality=0.99,
                    probable_human_speech=True,
                    raw_audio_retained=False,
                    human_identity_data_present=False,
                    device_identifier_present=False,
                ),
            ]
        )

        self.assertEqual(summary.accepted_taxa_counts, {"bird_group_a": 1})
        self.assertEqual(summary.discarded_probable_speech_frames, 1)
        self.assertFalse(summary.raw_audio_retained)
        self.assertFalse(summary.human_identity_data_present)

    def test_chao1_uses_singleton_and_doubleton_counts(self) -> None:
        result = chao1(
            {
                "taxon_a": 1,
                "taxon_b": 1,
                "taxon_c": 2,
                "taxon_d": 4,
            }
        )

        self.assertEqual(result.observed_taxa, 4)
        self.assertEqual(result.singleton_taxa, 2)
        self.assertEqual(result.doubleton_taxa, 1)
        self.assertEqual(result.estimated_richness, 6.0)


class DigitalInclusionTests(unittest.TestCase):
    def test_equal_weight_index_with_accessibility_floor(self) -> None:
        result = evaluate_digital_inclusion(
            InclusionComponents(
                internet_access=0.8,
                device_access=0.7,
                digital_support=0.6,
                accessibility=0.9,
            )
        )

        self.assertTrue(result.privacy_compliant)
        self.assertFalse(result.essential_access_gap_review_required)
        self.assertEqual(result.index, 0.75)

    def test_low_accessibility_requires_review_even_if_index_is_acceptable(self) -> None:
        result = evaluate_digital_inclusion(
            InclusionComponents(
                internet_access=0.9,
                device_access=0.9,
                digital_support=0.9,
                accessibility=0.2,
            )
        )

        self.assertTrue(result.privacy_compliant)
        self.assertTrue(result.essential_access_gap_review_required)
        self.assertIsNotNone(result.index)

    def test_tracking_data_blocks_index_calculation(self) -> None:
        result = evaluate_digital_inclusion(
            InclusionComponents(
                internet_access=0.8,
                device_access=0.8,
                digital_support=0.8,
                accessibility=0.8,
                public_wifi_mac_addresses_retained=True,
            )
        )

        self.assertFalse(result.privacy_compliant)
        self.assertIsNone(result.index)


if __name__ == "__main__":
    unittest.main()
