use crate::bounds::{NonNegativeF64, UnitInterval};
use crate::continuity::{CapabilityKind, CapabilityWindow, EvidenceStatus};
use crate::error::PopmathError;
use crate::time::TimeWindow;

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct ElectricFieldStrengthVoltsPerMeter {
    value: NonNegativeF64,
}

impl ElectricFieldStrengthVoltsPerMeter {
    pub fn new(value: NonNegativeF64) -> Self {
        Self { value }
    }

    pub fn value(self) -> NonNegativeF64 {
        self.value
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct EmiSensitivityThreshold {
    pub maximum_field_strength: ElectricFieldStrengthVoltsPerMeter,
    pub required_confidence: UnitInterval,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct EmiMeasurement {
    pub corridor_window: TimeWindow,
    pub electric_field_strength: ElectricFieldStrengthVoltsPerMeter,
    pub confidence: UnitInterval,
    pub evidence: EvidenceStatus,
}

pub fn is_emi_compatible(
    measurement: EmiMeasurement,
    threshold: EmiSensitivityThreshold,
) -> bool {
    measurement.electric_field_strength.value().value()
        <= threshold.maximum_field_strength.value().value()
        && measurement.confidence.value() >= threshold.required_confidence.value()
        && measurement.evidence == EvidenceStatus::Verified
}

pub fn as_capability_window(
    measurement: EmiMeasurement,
    threshold: EmiSensitivityThreshold,
) -> CapabilityWindow {
    CapabilityWindow::new(
        CapabilityKind::ElectromagneticInterferenceLow,
        measurement.corridor_window,
        measurement.evidence,
        is_emi_compatible(measurement, threshold),
    )
}

pub fn dbuv_per_meter_to_volts_per_meter(
    dbuv_per_meter: f64,
) -> Result<ElectricFieldStrengthVoltsPerMeter, PopmathError> {
    if !dbuv_per_meter.is_finite() {
        return Err(PopmathError::NonFiniteValue);
    }

    let volts_per_meter = 10_f64.powf((dbuv_per_meter - 120.0) / 20.0);

    Ok(ElectricFieldStrengthVoltsPerMeter::new(
        NonNegativeF64::new(volts_per_meter)?,
    ))
}
