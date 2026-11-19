from __future__ import annotations

from dataclasses import dataclass
from math import cos, exp, isfinite, pi, sin, sqrt
from random import Random
from typing import Sequence


@dataclass(frozen=True)
class MonthlyClimateParameters:
    precipitation_occurrence_probability: float
    precipitation_shape: float
    precipitation_scale_mm: float
    temperature_mean_c: float
    temperature_standard_deviation_c: float
    humidity_mean_fraction: float
    humidity_standard_deviation_fraction: float
    reservoir_inflow_mean_m3_per_s: float
    reservoir_inflow_log_standard_deviation: float

    def validate(self) -> None:
        values = (
            self.precipitation_occurrence_probability,
            self.precipitation_shape,
            self.precipitation_scale_mm,
            self.temperature_mean_c,
            self.temperature_standard_deviation_c,
            self.humidity_mean_fraction,
            self.humidity_standard_deviation_fraction,
            self.reservoir_inflow_mean_m3_per_s,
            self.reservoir_inflow_log_standard_deviation,
        )

        if any(not isfinite(value) for value in values):
            raise ValueError("monthly climate parameters must be finite")

        if not 0.0 <= self.precipitation_occurrence_probability <= 1.0:
            raise ValueError("precipitation occurrence probability must be within [0, 1]")
        if self.precipitation_shape <= 0.0 or self.precipitation_scale_mm <= 0.0:
            raise ValueError("precipitation gamma parameters must be positive")
        if self.temperature_standard_deviation_c <= 0.0:
            raise ValueError("temperature standard deviation must be positive")
        if not 0.0 <= self.humidity_mean_fraction <= 1.0:
            raise ValueError("humidity mean fraction must be within [0, 1]")
        if self.humidity_standard_deviation_fraction <= 0.0:
            raise ValueError("humidity standard deviation must be positive")
        if self.reservoir_inflow_mean_m3_per_s <= 0.0:
            raise ValueError("reservoir inflow mean must be positive")
        if self.reservoir_inflow_log_standard_deviation <= 0.0:
            raise ValueError("reservoir inflow log standard deviation must be positive")


@dataclass(frozen=True)
class DroughtGeneratorParameters:
    monthly: tuple[MonthlyClimateParameters, ...]
    drought_state_persistence: float
    drought_state_precipitation_effect: float
    drought_state_temperature_effect_c: float
    drought_state_humidity_effect: float
    drought_state_inflow_effect: float
    long_memory_fraction: float
    long_memory_decay: float
    extreme_event_probability: float
    extreme_precipitation_multiplier: float
    extreme_temperature_increment_c: float
    extreme_inflow_multiplier: float

    def validate(self) -> None:
        if len(self.monthly) != 12:
            raise ValueError("exactly 12 monthly parameter sets are required")

        for item in self.monthly:
            item.validate()

        bounded = (
            self.drought_state_persistence,
            self.long_memory_fraction,
            self.extreme_event_probability,
        )

        if any(not isfinite(value) or not 0.0 <= value < 1.0 for value in bounded):
            raise ValueError("bounded generator parameters must be finite and within [0, 1)")

        values = (
            self.drought_state_precipitation_effect,
            self.drought_state_temperature_effect_c,
            self.drought_state_humidity_effect,
            self.drought_state_inflow_effect,
            self.long_memory_decay,
            self.extreme_precipitation_multiplier,
            self.extreme_temperature_increment_c,
            self.extreme_inflow_multiplier,
        )

        if any(not isfinite(value) for value in values):
            raise ValueError("generator parameters must be finite")

        if self.long_memory_decay <= 0.0:
            raise ValueError("long_memory_decay must be positive")
        if self.extreme_precipitation_multiplier <= 0.0:
            raise ValueError("extreme_precipitation_multiplier must be positive")
        if self.extreme_inflow_multiplier <= 0.0:
            raise ValueError("extreme_inflow_multiplier must be positive")


@dataclass(frozen=True)
class SyntheticDay:
    day_index: int
    month_index: int
    drought_state: float
    precipitation_mm: float
    air_temperature_c: float
    relative_humidity_fraction: float
    reservoir_inflow_m3_per_s: float
    extreme_event: bool


def clamp(value: float, minimum: float, maximum: float) -> float:
    return max(minimum, min(maximum, value))


def month_index_for_day(day_index: int) -> int:
    day_of_year = day_index % 365
    approximate_month = int(day_of_year * 12 / 365)
    return clamp(approximate_month, 0, 11)


def gamma_sample(random: Random, shape: float, scale: float) -> float:
    if shape <= 0.0 or scale <= 0.0:
        raise ValueError("gamma parameters must be positive")

    if shape < 1.0:
        u = random.random()
        return gamma_sample(random, shape + 1.0, scale) * u ** (1.0 / shape)

    d = shape - 1.0 / 3.0
    c = 1.0 / sqrt(9.0 * d)

    while True:
        normal = random.gauss(0.0, 1.0)
        candidate = 1.0 + c * normal

        if candidate <= 0.0:
            continue

        v = candidate**3
        u = random.random()

        if u < 1.0 - 0.0331 * normal**4:
            return scale * d * v

        if log_safe(u) < 0.5 * normal**2 + d * (1.0 - v + log_safe(v)):
            return scale * d * v


def log_safe(value: float) -> float:
    return __import__("math").log(max(value, 1e-15))


def long_memory_signal(
    innovations: Sequence[float],
    fraction: float,
    decay: float,
) -> list[float]:
    if not 0.0 <= fraction < 1.0:
        raise ValueError("fraction must be within [0, 1)")
    if decay <= 0.0:
        raise ValueError("decay must be positive")

    values: list[float] = []

    for time_index in range(len(innovations)):
        memory = 0.0

        for lag in range(1, time_index + 1):
            weight = fraction * (lag + 1.0) ** (-decay)
            memory += weight * innovations[time_index - lag]

        values.append(innovations[time_index] + memory)

    return values


def generate_synthetic_drought_sequence(
    parameters: DroughtGeneratorParameters,
    days: int,
    seed: int,
) -> list[SyntheticDay]:
    parameters.validate()

    if days <= 0:
        raise ValueError("days must be positive")

    random = Random(seed)
    innovations = [random.gauss(0.0, 1.0) for _ in range(days)]
    memory_signal = long_memory_signal(
        innovations=innovations,
        fraction=parameters.long_memory_fraction,
        decay=parameters.long_memory_decay,
    )

    sequence: list[SyntheticDay] = []
    drought_state = 0.0

    for day_index in range(days):
        month_index = int(month_index_for_day(day_index))
        monthly = parameters.monthly[month_index]

        seasonal_phase = 2.0 * pi * (day_index % 365) / 365.0
        seasonal_anomaly = 0.20 * sin(seasonal_phase) - 0.10 * cos(seasonal_phase)

        drought_innovation = 0.25 * innovations[day_index] + 0.15 * memory_signal[day_index]
        drought_state = clamp(
            parameters.drought_state_persistence * drought_state
            + drought_innovation
            + seasonal_anomaly,
            -3.0,
            3.0,
        )

        extreme_event = random.random() < parameters.extreme_event_probability

        precipitation_probability = clamp(
            monthly.precipitation_occurrence_probability
            * exp(-parameters.drought_state_precipitation_effect * drought_state),
            0.0,
            1.0,
        )

        precipitation_mm = 0.0
        if random.random() < precipitation_probability:
            precipitation_mm = gamma_sample(
                random,
                monthly.precipitation_shape,
                monthly.precipitation_scale_mm,
            )

        if extreme_event:
            precipitation_mm *= parameters.extreme_precipitation_multiplier

        temperature_c = (
            monthly.temperature_mean_c
            + random.gauss(0.0, monthly.temperature_standard_deviation_c)
            + parameters.drought_state_temperature_effect_c * drought_state
        )

        if extreme_event:
            temperature_c += parameters.extreme_temperature_increment_c

        humidity_fraction = clamp(
            monthly.humidity_mean_fraction
            + random.gauss(0.0, monthly.humidity_standard_deviation_fraction)
            - parameters.drought_state_humidity_effect * drought_state
            - 0.003 * (temperature_c - monthly.temperature_mean_c),
            0.01,
            0.99,
        )

        log_inflow = (
            log_safe(monthly.reservoir_inflow_mean_m3_per_s)
            + random.gauss(0.0, monthly.reservoir_inflow_log_standard_deviation)
            - parameters.drought_state_inflow_effect * drought_state
            + 0.02 * memory_signal[day_index]
        )

        reservoir_inflow_m3_per_s = exp(log_inflow)

        if extreme_event:
            reservoir_inflow_m3_per_s *= parameters.extreme_inflow_multiplier

        sequence.append(
            SyntheticDay(
                day_index=day_index,
                month_index=month_index,
                drought_state=drought_state,
                precipitation_mm=max(0.0, precipitation_mm),
                air_temperature_c=temperature_c,
                relative_humidity_fraction=humidity_fraction,
                reservoir_inflow_m3_per_s=max(0.0, reservoir_inflow_m3_per_s),
                extreme_event=extreme_event,
            )
        )

    return sequence
