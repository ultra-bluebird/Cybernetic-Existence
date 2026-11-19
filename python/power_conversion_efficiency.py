from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Iterable


@dataclass(frozen=True)
class ConverterParameters:
    output_power_w: float
    switching_frequency_hz: float
    input_capacitance_f: float
    gate_drive_voltage_v: float
    rms_current_a: float
    rds_on_ohm: float
    dead_time_loss_w: float
    reverse_recovery_loss_w: float
    core_loss_w: float
    leakage_loss_w: float
    gate_drive_loss_w: float
    estimated_junction_temperature_c: float
    maximum_junction_temperature_c: float

    def validate(self) -> None:
        values = (
            self.output_power_w,
            self.switching_frequency_hz,
            self.input_capacitance_f,
            self.gate_drive_voltage_v,
            self.rms_current_a,
            self.rds_on_ohm,
            self.dead_time_loss_w,
            self.reverse_recovery_loss_w,
            self.core_loss_w,
            self.leakage_loss_w,
            self.gate_drive_loss_w,
            self.estimated_junction_temperature_c,
            self.maximum_junction_temperature_c,
        )

        if not all(isfinite(value) for value in values):
            raise ValueError("all parameters must be finite")

        if self.output_power_w <= 0:
            raise ValueError("output_power_w must be greater than zero")

        if self.switching_frequency_hz <= 0:
            raise ValueError("switching_frequency_hz must be greater than zero")

        if self.input_capacitance_f < 0:
            raise ValueError("input_capacitance_f must not be negative")

        if self.gate_drive_voltage_v < 0:
            raise ValueError("gate_drive_voltage_v must not be negative")

        if self.rms_current_a < 0:
            raise ValueError("rms_current_a must not be negative")

        if self.rds_on_ohm < 0:
            raise ValueError("rds_on_ohm must not be negative")

        for value in (
            self.dead_time_loss_w,
            self.reverse_recovery_loss_w,
            self.core_loss_w,
            self.leakage_loss_w,
            self.gate_drive_loss_w,
        ):
            if value < 0:
                raise ValueError("loss values must not be negative")

        if self.maximum_junction_temperature_c <= 0:
            raise ValueError("maximum_junction_temperature_c must be greater than zero")


@dataclass(frozen=True)
class EfficiencyResult:
    switching_loss_w: float
    conduction_loss_w: float
    parasitic_loss_w: float
    total_loss_w: float
    input_power_w: float
    efficiency_fraction: float
    thermal_constraint_satisfied: bool

    @property
    def efficiency_percent(self) -> float:
        return self.efficiency_fraction * 100.0


def switching_loss_w(parameters: ConverterParameters) -> float:
    return (
        parameters.switching_frequency_hz
        * parameters.input_capacitance_f
        * parameters.gate_drive_voltage_v**2
    )


def conduction_loss_w(parameters: ConverterParameters) -> float:
    return parameters.rms_current_a**2 * parameters.rds_on_ohm


def evaluate_efficiency(parameters: ConverterParameters) -> EfficiencyResult:
    parameters.validate()

    switching = switching_loss_w(parameters)
    conduction = conduction_loss_w(parameters)

    parasitic = (
        parameters.dead_time_loss_w
        + parameters.reverse_recovery_loss_w
        + parameters.core_loss_w
        + parameters.leakage_loss_w
        + parameters.gate_drive_loss_w
    )

    total_loss = switching + conduction + parasitic
    input_power = parameters.output_power_w + total_loss
    efficiency = parameters.output_power_w / input_power

    return EfficiencyResult(
        switching_loss_w=switching,
        conduction_loss_w=conduction,
        parasitic_loss_w=parasitic,
        total_loss_w=total_loss,
        input_power_w=input_power,
        efficiency_fraction=efficiency,
        thermal_constraint_satisfied=(
            parameters.estimated_junction_temperature_c
            <= parameters.maximum_junction_temperature_c
        ),
    )


def select_best_modeled_candidate(
    candidates: Iterable[ConverterParameters],
) -> tuple[ConverterParameters, EfficiencyResult]:
    evaluated: list[tuple[ConverterParameters, EfficiencyResult]] = []

    for candidate in candidates:
        result = evaluate_efficiency(candidate)
        if result.thermal_constraint_satisfied:
            evaluated.append((candidate, result))

    if not evaluated:
        raise ValueError(
            "no candidate satisfies the modeled thermal constraint; "
            "this is an advisory result and does not control hardware"
        )

    return max(evaluated, key=lambda item: item[1].efficiency_fraction)


if __name__ == "__main__":
    modeled_candidates = [
        ConverterParameters(
            output_power_w=1_000.0,
            switching_frequency_hz=100_000.0,
            input_capacitance_f=4.0e-9,
            gate_drive_voltage_v=8.0,
            rms_current_a=30.0,
            rds_on_ohm=0.004,
            dead_time_loss_w=2.4,
            reverse_recovery_loss_w=1.8,
            core_loss_w=3.1,
            leakage_loss_w=0.7,
            gate_drive_loss_w=0.9,
            estimated_junction_temperature_c=82.0,
            maximum_junction_temperature_c=110.0,
        ),
        ConverterParameters(
            output_power_w=1_000.0,
            switching_frequency_hz=250_000.0,
            input_capacitance_f=4.0e-9,
            gate_drive_voltage_v=7.0,
            rms_current_a=30.0,
            rds_on_ohm=0.004,
            dead_time_loss_w=1.6,
            reverse_recovery_loss_w=1.2,
            core_loss_w=4.9,
            leakage_loss_w=0.9,
            gate_drive_loss_w=1.4,
            estimated_junction_temperature_c=94.0,
            maximum_junction_temperature_c=110.0,
        ),
    ]

    selected, result = select_best_modeled_candidate(modeled_candidates)

    print(
        {
            "modeled_switching_frequency_hz": selected.switching_frequency_hz,
            "modeled_efficiency_percent": round(result.efficiency_percent, 4),
            "modeled_total_loss_w": round(result.total_loss_w, 4),
            "thermal_constraint_satisfied": result.thermal_constraint_satisfied,
            "output_type": "simulation_advisory_only",
        }
    )
