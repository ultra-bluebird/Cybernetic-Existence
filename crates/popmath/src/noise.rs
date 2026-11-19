use crate::bounds::{NonNegativeF64, UnitInterval};
use crate::continuity::{CapabilityKind, CapabilityWindow, EvidenceStatus};
use crate::error::PopmathError;
use crate::time::TimeWindow;

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct AWeightedDecibels {
    value: NonNegativeF64,
}

impl AWeightedDecibels {
    pub fn new(value: NonNegativeF64) -> Self {
        Self { value }
    }

    pub fn value(self) -> f64 {
        self.value.value()
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct CorridorPositionMeters {
    value: NonNegativeF64,
}

impl CorridorPositionMeters {
    pub fn new(value: NonNegativeF64) -> Self {
        Self { value }
    }

    pub fn value(self) -> f64 {
        self.value.value()
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct NoiseRequirement {
    pub maximum_laeq_one_hour: AWeightedDecibels,
    pub minimum_confidence: UnitInterval,
    pub required_evidence: EvidenceStatus,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct NoiseMeasurementWindow {
    pub window: TimeWindow,
    pub laeq_one_hour: AWeightedDecibels,
    pub confidence: UnitInterval,
    pub evidence: EvidenceStatus,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct CorridorNoisePoint {
    pub position: CorridorPositionMeters,
    pub laeq_one_hour: AWeightedDecibels,
}

pub fn is_low_noise_compatible(
    measurement: NoiseMeasurementWindow,
    requirement: NoiseRequirement,
) -> bool {
    measurement.laeq_one_hour.value()
        <= requirement.maximum_laeq_one_hour.value()
        && measurement.confidence.value()
            >= requirement.minimum_confidence.value()
        && measurement.evidence >= requirement.required_evidence
}

pub fn noise_measurement_to_capability_window(
    measurement: NoiseMeasurementWindow,
    requirement: NoiseRequirement,
) -> CapabilityWindow {
    CapabilityWindow::new(
        CapabilityKind::LowNoiseEnvironment,
        measurement.window,
        measurement.evidence,
        is_low_noise_compatible(measurement, requirement),
    )
}

pub fn interpolate_corridor_noise(
    left: CorridorNoisePoint,
    right: CorridorNoisePoint,
    target_position: CorridorPositionMeters,
) -> Result<AWeightedDecibels, PopmathError> {
    let left_position = left.position.value();
    let right_position = right.position.value();
    let target = target_position.value();

    if right_position <= left_position {
        return Err(PopmathError::InvalidInput(
            "right sensor position must be greater than left sensor position",
        ));
    }

    if target < left_position || target > right_position {
        return Err(PopmathError::InvalidInput(
            "target position must lie between the two corridor sensor positions",
        ));
    }

    let interpolation_ratio =
        (target - left_position) / (right_position - left_position);

    let left_energy = 10_f64.powf(left.laeq_one_hour.value() / 10.0);
    let right_energy = 10_f64.powf(right.laeq_one_hour.value() / 10.0);

    let interpolated_energy = (
        (1.0 - interpolation_ratio) * left_energy
    )
    + (
        interpolation_ratio * right_energy
    );

    let interpolated_decibels = 10.0 * interpolated_energy.log10();

    Ok(AWeightedDecibels::new(
        NonNegativeF64::new(interpolated_decibels)?,
    ))
}
