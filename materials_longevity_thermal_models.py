# mk-bluebird/Cybercore/research/materials_longevity_thermal_models.py
from __future__ import annotations

from dataclasses import asdict, dataclass
from enum import StrEnum
from math import exp, log
from statistics import mean
from typing import Sequence


class EvidenceDisposition(StrEnum):
    EVIDENCE_MAPPED = "evidence-mapped"
    RESEARCH_PRIORITY_CANDIDATE = "research-priority-candidate"
    TRANSLATION_GAP_IDENTIFIED = "translation-gap-identified"
    INSUFFICIENT_RECORD = "insufficient-record"


class LongevityDisposition(StrEnum):
    STABLE = "stable"
    MONITOR = "monitor"
    INVESTIGATE = "investigate"
    INSUFFICIENT_SERIES = "insufficient-series"


class ThermalDisposition(StrEnum):
    WITHIN_RESEARCH_BUDGET = "within-research-budget"
    REDUCE_DUTY_CYCLE = "reduce-duty-cycle"
    INCREASE_SPARSITY = "increase-sparsity"
    REQUIRES_THERMAL_REVIEW = "requires-thermal-review"


@dataclass(frozen=True)
class MaterialEvidenceScores:
    mechanical: float
    electrical: float
    chemical: float
    biological: float
    evidence_quality: float

    def validate(self) -> None:
        values = (
            self.mechanical,
            self.electrical,
            self.chemical,
            self.biological,
            self.evidence_quality,
        )
        if any(not 0.0 <= value <= 1.0 for value in values):
            raise ValueError("all material evidence dimensions must be within [0, 1]")

    def priority(self) -> float:
        self.validate()
        return (
            0.25 * self.mechanical
            + 0.25 * self.electrical
            + 0.20 * self.chemical
            + 0.20 * self.biological
            + 0.10 * self.evidence_quality
        )

    def eligible(self) -> bool:
        self.validate()
        return (
            self.mechanical >= 0.57
            and self.electrical >= 0.57
            and self.chemical >= 0.50
            and self.biological >= 0.57
            and self.evidence_quality >= 0.57
        )

    def disposition(self) -> EvidenceDisposition:
        if self == MaterialEvidenceScores(0.0, 0.0, 0.0, 0.0, 0.0):
            return EvidenceDisposition.INSUFFICIENT_RECORD
        if self.eligible():
            return EvidenceDisposition.RESEARCH_PRIORITY_CANDIDATE
        if self.priority() >= 0.50:
            return EvidenceDisposition.TRANSLATION_GAP_IDENTIFIED
        return EvidenceDisposition.EVIDENCE_MAPPED


@dataclass(frozen=True)
class ImpedanceObservation:
    elapsed_days: float
    impedance_ohms: float
    snr_proxy: float


@dataclass(frozen=True)
class LongevityFit:
    initial_signal: float
    degradation_rate_per_day: float
    residual_variance: float
    r_squared: float

    def predict_snr(self, elapsed_days: float) -> float:
        if elapsed_days < 0.0:
            raise ValueError("elapsed days must be non-negative")
        return self.initial_signal * exp(-self.degradation_rate_per_day * elapsed_days)


@dataclass(frozen=True)
class LongevityThresholds:
    max_daily_degradation_rate: float = 0.005
    minimum_snr_retention: float = 0.80
    minimum_r_squared: float = 0.60


@dataclass(frozen=True)
class LongevityAssessment:
    fit: LongevityFit
    snr_retention: float
    impedance_change_fraction: float
    disposition: LongevityDisposition


@dataclass(frozen=True)
class ThermalPolicy:
    peak_power_milliwatts: float
    duty_cycle: float
    sparsity_fraction: float
    thermal_resistance_celsius_per_milliwatt: float
    thermal_cap_celsius: float = 1.0


@dataclass(frozen=True)
class ThermalAssessment:
    average_power_milliwatts: float
    estimated_delta_celsius: float
    maximum_duty_cycle: float
    minimum_sparsity_fraction: float
    disposition: ThermalDisposition


def fit_exponential_snr_decay(observations: Sequence[ImpedanceObservation]) -> LongevityFit:
    if len(observations) < 3:
        raise ValueError("at least three observations are required")
    if any(
        observation.elapsed_days < 0.0
        or observation.impedance_ohms <= 0.0
        or observation.snr_proxy <= 0.0
        for observation in observations
    ):
        raise ValueError("observations require non-negative time and positive impedance/SNR")

    x_values = [observation.elapsed_days for observation in observations]
    y_values = [log(observation.snr_proxy) for observation in observations]
    x_mean = mean(x_values)
    y_mean = mean(y_values)

    denominator = sum((x - x_mean) ** 2 for x in x_values)
    if denominator == 0.0:
        raise ValueError("time observations must not all be identical")

    slope = sum(
        (x - x_mean) * (y - y_mean)
        for x, y in zip(x_values, y_values, strict=True)
    ) / denominator
    intercept = y_mean - slope * x_mean
    predictions = [intercept + slope * x for x in x_values]
    residual_sum_squares = sum(
        (actual - predicted) ** 2
        for actual, predicted in zip(y_values, predictions, strict=True)
    )
    total_sum_squares = sum((value - y_mean) ** 2 for value in y_values)
    r_squared = 1.0 if total_sum_squares == 0.0 else 1.0 - residual_sum_squares / total_sum_squares

    return LongevityFit(
        initial_signal=exp(intercept),
        degradation_rate_per_day=-slope,
        residual_variance=residual_sum_squares / len(observations),
        r_squared=r_squared,
    )


def assess_longevity(
    observations: Sequence[ImpedanceObservation],
    thresholds: LongevityThresholds = LongevityThresholds(),
) -> LongevityAssessment:
    if (
        thresholds.max_daily_degradation_rate < 0.0
        or not 0.0 <= thresholds.minimum_snr_retention <= 1.0
        or not 0.0 <= thresholds.minimum_r_squared <= 1.0
    ):
        raise ValueError("longevity thresholds are outside their valid bounds")

    fit = fit_exponential_snr_decay(observations)
    first = observations[0]
    last = observations[-1]
    snr_retention = last.snr_proxy / first.snr_proxy
    impedance_change_fraction = (last.impedance_ohms - first.impedance_ohms) / first.impedance_ohms

    if fit.r_squared < thresholds.minimum_r_squared:
        disposition = LongevityDisposition.INSUFFICIENT_SERIES
    elif (
        fit.degradation_rate_per_day > thresholds.max_daily_degradation_rate
        or snr_retention < thresholds.minimum_snr_retention
    ):
        disposition = LongevityDisposition.INVESTIGATE
    elif fit.degradation_rate_per_day > 0.0 or impedance_change_fraction > 0.0:
        disposition = LongevityDisposition.MONITOR
    else:
        disposition = LongevityDisposition.STABLE

    return LongevityAssessment(
        fit=fit,
        snr_retention=snr_retention,
        impedance_change_fraction=impedance_change_fraction,
        disposition=disposition,
    )


def assess_thermal_budget(policy: ThermalPolicy) -> ThermalAssessment:
    if (
        policy.peak_power_milliwatts < 0.0
        or not 0.0 <= policy.duty_cycle <= 1.0
        or not 0.0 <= policy.sparsity_fraction <= 1.0
        or policy.thermal_resistance_celsius_per_milliwatt < 0.0
        or policy.thermal_cap_celsius < 0.0
    ):
        raise ValueError("thermal-policy inputs are outside valid bounds")

    average_power = (
        policy.duty_cycle
        * policy.peak_power_milliwatts
        * (1.0 - policy.sparsity_fraction)
    )
    estimated_delta = average_power * policy.thermal_resistance_celsius_per_milliwatt

    duty_denominator = (
        policy.peak_power_milliwatts
        * (1.0 - policy.sparsity_fraction)
        * policy.thermal_resistance_celsius_per_milliwatt
    )
    maximum_duty_cycle = 1.0 if duty_denominator == 0.0 else min(
        policy.thermal_cap_celsius / duty_denominator,
        1.0,
    )

    sparsity_denominator = (
        policy.duty_cycle
        * policy.peak_power_milliwatts
        * policy.thermal_resistance_celsius_per_milliwatt
    )
    minimum_sparsity = 0.0 if sparsity_denominator == 0.0 else max(
        0.0,
        min(1.0, 1.0 - policy.thermal_cap_celsius / sparsity_denominator),
    )

    if estimated_delta <= policy.thermal_cap_celsius:
        disposition = ThermalDisposition.WITHIN_RESEARCH_BUDGET
    elif 0.0 < maximum_duty_cycle < policy.duty_cycle:
        disposition = ThermalDisposition.REDUCE_DUTY_CYCLE
    elif policy.sparsity_fraction < minimum_sparsity < 1.0:
        disposition = ThermalDisposition.INCREASE_SPARSITY
    else:
        disposition = ThermalDisposition.REQUIRES_THERMAL_REVIEW

    return ThermalAssessment(
        average_power_milliwatts=average_power,
        estimated_delta_celsius=estimated_delta,
        maximum_duty_cycle=maximum_duty_cycle,
        minimum_sparsity_fraction=minimum_sparsity,
        disposition=disposition,
    )


def entropy_budget(event_count: int, entropy_bits_per_event: int) -> int:
    if event_count < 0 or entropy_bits_per_event < 0:
        raise ValueError("entropy budget inputs must be non-negative")
    return event_count * entropy_bits_per_event


def research_object_example() -> dict[str, object]:
    evidence = MaterialEvidenceScores(
        mechanical=0.80,
        electrical=0.75,
        chemical=0.70,
        biological=0.85,
        evidence_quality=0.90,
    )
    longevity = assess_longevity(
        (
            ImpedanceObservation(0.0, 100_000.0, 1.00),
            ImpedanceObservation(10.0, 105_000.0, 0.95),
            ImpedanceObservation(20.0, 110_000.0, 0.90),
        )
    )
    thermal = assess_thermal_budget(
        ThermalPolicy(
            peak_power_milliwatts=10.0,
            duty_cycle=0.50,
            sparsity_fraction=0.60,
            thermal_resistance_celsius_per_milliwatt=0.25,
        )
    )
    return {
        "material_evidence": {
            "priority": evidence.priority(),
            "eligible": evidence.eligible(),
            "disposition": evidence.disposition(),
        },
        "longevity": {
            "fit": asdict(longevity.fit),
            "snr_retention": longevity.snr_retention,
            "impedance_change_fraction": longevity.impedance_change_fraction,
            "disposition": longevity.disposition,
        },
        "thermal": asdict(thermal),
        "entropy_budget_bits": entropy_budget(1_000_000_000, 128),
    }
