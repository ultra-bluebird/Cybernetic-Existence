from __future__ import annotations

from dataclasses import dataclass
from math import log
from typing import Mapping


@dataclass(frozen=True)
class AcousticFrameAssessment:
    speech_likelihood: float
    ecological_signal_quality: float
    species_group_probabilities: Mapping[str, float]

    def __post_init__(self) -> None:
        _validate_probability(self.speech_likelihood, "speech_likelihood")
        _validate_probability(self.ecological_signal_quality, "ecological_signal_quality")

        if not self.species_group_probabilities:
            raise ValueError("species_group_probabilities must not be empty.")

        for group, probability in self.species_group_probabilities.items():
            if not group.strip():
                raise ValueError("Species-group names must not be empty.")
            _validate_probability(probability, f"probability for {group}")


@dataclass(frozen=True)
class AcousticSummary:
    retained: bool
    species_group: str | None
    classification_confidence: float
    signal_quality: float
    speech_likelihood: float


@dataclass(frozen=True)
class ReflectanceSample:
    near_infrared: float
    red: float
    blue: float | None = None
    image_quality: float = 1.0
    privacy_clear: bool = False

    def __post_init__(self) -> None:
        for name, value in (
            ("near_infrared", self.near_infrared),
            ("red", self.red),
            ("image_quality", self.image_quality),
        ):
            _validate_probability(value, name)

        if self.blue is not None:
            _validate_probability(self.blue, "blue")

        if self.near_infrared + self.red == 0.0:
            raise ValueError("near_infrared + red must be greater than zero.")


@dataclass(frozen=True)
class SpectralSummary:
    retained: bool
    ndvi: float | None
    evi: float | None
    evi2: float | None
    image_quality: float


@dataclass(frozen=True)
class CwsiInput:
    canopy_temperature_c: float
    dry_reference_temperature_c: float
    wet_reference_temperature_c: float

    def __post_init__(self) -> None:
        if self.dry_reference_temperature_c <= self.wet_reference_temperature_c:
            raise ValueError(
                "dry_reference_temperature_c must exceed wet_reference_temperature_c."
            )


def summarize_acoustic_frame(
    assessment: AcousticFrameAssessment,
    speech_threshold: float = 0.10,
    quality_threshold: float = 0.60,
    confidence_threshold: float = 0.65,
) -> AcousticSummary:
    _validate_probability(speech_threshold, "speech_threshold")
    _validate_probability(quality_threshold, "quality_threshold")
    _validate_probability(confidence_threshold, "confidence_threshold")

    if assessment.speech_likelihood >= speech_threshold:
        return AcousticSummary(
            retained=False,
            species_group=None,
            classification_confidence=0.0,
            signal_quality=assessment.ecological_signal_quality,
            speech_likelihood=assessment.speech_likelihood,
        )

    if assessment.ecological_signal_quality < quality_threshold:
        return AcousticSummary(
            retained=False,
            species_group=None,
            classification_confidence=0.0,
            signal_quality=assessment.ecological_signal_quality,
            speech_likelihood=assessment.speech_likelihood,
        )

    group, confidence = max(
        assessment.species_group_probabilities.items(),
        key=lambda item: item[1],
    )

    if confidence < confidence_threshold:
        return AcousticSummary(
            retained=True,
            species_group="unknown-ecological-event",
            classification_confidence=confidence,
            signal_quality=assessment.ecological_signal_quality,
            speech_likelihood=assessment.speech_likelihood,
        )

    return AcousticSummary(
        retained=True,
        species_group=group,
        classification_confidence=confidence,
        signal_quality=assessment.ecological_signal_quality,
        speech_likelihood=assessment.speech_likelihood,
    )


def ndvi(sample: ReflectanceSample) -> float:
    return (sample.near_infrared - sample.red) / (
        sample.near_infrared + sample.red
    )


def evi(sample: ReflectanceSample) -> float:
    if sample.blue is None:
        raise ValueError("EVI requires a calibrated blue reflectance band.")

    denominator = (
        sample.near_infrared
        + 6.0 * sample.red
        - 7.5 * sample.blue
        + 1.0
    )

    if denominator == 0.0:
        raise ValueError("EVI denominator must not be zero.")

    return 2.5 * (sample.near_infrared - sample.red) / denominator


def evi2(sample: ReflectanceSample) -> float:
    denominator = sample.near_infrared + 2.4 * sample.red + 1.0

    if denominator == 0.0:
        raise ValueError("EVI2 denominator must not be zero.")

    return 2.5 * (sample.near_infrared - sample.red) / denominator


def summarize_reflectance_sample(
    sample: ReflectanceSample,
    image_quality_threshold: float = 0.75,
) -> SpectralSummary:
    _validate_probability(image_quality_threshold, "image_quality_threshold")

    if not sample.privacy_clear or sample.image_quality < image_quality_threshold:
        return SpectralSummary(
            retained=False,
            ndvi=None,
            evi=None,
            evi2=None,
            image_quality=sample.image_quality,
        )

    index_ndvi = ndvi(sample)
    index_evi = evi(sample) if sample.blue is not None else None
    index_evi2 = evi2(sample)

    return SpectralSummary(
        retained=True,
        ndvi=index_ndvi,
        evi=index_evi,
        evi2=index_evi2,
        image_quality=sample.image_quality,
    )


def shannon_entropy(counts: Mapping[str, int]) -> float:
    if not counts:
        raise ValueError("counts must not be empty.")

    if any(count < 0 for count in counts.values()):
        raise ValueError("counts must not contain negative values.")

    total = sum(counts.values())

    if total == 0:
        return 0.0

    entropy = 0.0

    for count in counts.values():
        if count == 0:
            continue
        probability = count / total
        entropy -= probability * log(probability)

    return entropy


def normalized_evenness(counts: Mapping[str, int]) -> float:
    positive_groups = sum(1 for count in counts.values() if count > 0)

    if positive_groups <= 1:
        return 0.0

    return shannon_entropy(counts) / log(positive_groups)


def cwsi(value: CwsiInput) -> float:
    return (
        value.canopy_temperature_c - value.wet_reference_temperature_c
    ) / (
        value.dry_reference_temperature_c - value.wet_reference_temperature_c
    )


def _validate_probability(value: float, name: str) -> None:
    if not 0.0 <= value <= 1.0:
        raise ValueError(f"{name} must be within 0.0..=1.0.")
