from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Iterable, Mapping


class WildlifeMonitoringValidationError(ValueError):
    pass


@dataclass(frozen=True)
class AcousticEvent:
    taxon_label: str
    confidence: float
    audio_quality: float
    probable_human_speech: bool
    raw_audio_retained: bool
    human_identity_data_present: bool
    device_identifier_present: bool

    def __post_init__(self) -> None:
        if not self.taxon_label.strip():
            raise WildlifeMonitoringValidationError("taxon_label must be non-empty.")

        for field_name, value in (
            ("confidence", self.confidence),
            ("audio_quality", self.audio_quality),
        ):
            if not isfinite(value) or not 0.0 <= value <= 1.0:
                raise WildlifeMonitoringValidationError(
                    f"{field_name} must be a finite value from zero through one."
                )


@dataclass(frozen=True)
class PrivacyFilteredSummary:
    accepted_taxa_counts: Mapping[str, int]
    discarded_probable_speech_frames: int
    discarded_unsafe_events: int
    raw_audio_retained: bool
    human_identity_data_present: bool
    device_identifier_present: bool


def filter_events(
    events: Iterable[AcousticEvent],
    minimum_confidence: float = 0.80,
    minimum_audio_quality: float = 0.70,
) -> PrivacyFilteredSummary:
    if (
        not isfinite(minimum_confidence)
        or not isfinite(minimum_audio_quality)
        or not 0.0 <= minimum_confidence <= 1.0
        or not 0.0 <= minimum_audio_quality <= 1.0
    ):
        raise WildlifeMonitoringValidationError(
            "Confidence and quality thresholds must be finite values from zero through one."
        )

    accepted: dict[str, int] = {}
    discarded_speech = 0
    discarded_unsafe = 0

    for event in events:
        if event.probable_human_speech:
            discarded_speech += 1
            continue

        if (
            event.raw_audio_retained
            or event.human_identity_data_present
            or event.device_identifier_present
        ):
            discarded_unsafe += 1
            continue

        if event.confidence < minimum_confidence or event.audio_quality < minimum_audio_quality:
            continue

        accepted[event.taxon_label] = accepted.get(event.taxon_label, 0) + 1

    return PrivacyFilteredSummary(
        accepted_taxa_counts=accepted,
        discarded_probable_speech_frames=discarded_speech,
        discarded_unsafe_events=discarded_unsafe,
        raw_audio_retained=False,
        human_identity_data_present=False,
        device_identifier_present=False,
    )


@dataclass(frozen=True)
class Chao1Result:
    observed_taxa: int
    singleton_taxa: int
    doubleton_taxa: int
    estimated_richness: float


def chao1(counts: Mapping[str, int]) -> Chao1Result:
    if not counts:
        raise WildlifeMonitoringValidationError(
            "At least one accepted taxon count is required."
        )

    if any(
        not isinstance(label, str)
        or not label.strip()
        or not isinstance(count, int)
        or count <= 0
        for label, count in counts.items()
    ):
        raise WildlifeMonitoringValidationError(
            "Taxon labels must be non-empty and counts must be positive integers."
        )

    observed = len(counts)
    singleton_taxa = sum(count == 1 for count in counts.values())
    doubleton_taxa = sum(count == 2 for count in counts.values())

    if doubleton_taxa > 0:
        estimated = observed + (singleton_taxa**2) / (2.0 * doubleton_taxa)
    else:
        estimated = observed + singleton_taxa * (singleton_taxa - 1) / 2.0

    return Chao1Result(
        observed_taxa=observed,
        singleton_taxa=singleton_taxa,
        doubleton_taxa=doubleton_taxa,
        estimated_richness=estimated,
    )
