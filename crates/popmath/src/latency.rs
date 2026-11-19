use alloc::vec::Vec;

use crate::bounds::{NonNegativeF64, UnitInterval};
use crate::continuity::{
    CapabilityKind, CapabilityRequirement, CapabilityWindow, EvidenceStatus,
};
use crate::error::PopmathError;
use crate::time::TimeWindow;

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct LatencyMilliseconds {
    value: NonNegativeF64,
}

impl LatencyMilliseconds {
    pub fn new(value: NonNegativeF64) -> Self {
        Self { value }
    }

    pub fn value(self) -> f64 {
        self.value.value()
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct LatencyRequirement {
    pub maximum_latency: LatencyMilliseconds,
    pub percentile: UnitInterval,
    pub minimum_sample_count: u32,
    pub required_evidence: EvidenceStatus,
}

#[derive(Debug, Clone, PartialEq)]
pub struct LatencyMeasurementWindow {
    pub window: TimeWindow,
    pub samples_milliseconds: Vec<LatencyMilliseconds>,
    pub evidence: EvidenceStatus,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct LatencyWindowAssessment {
    pub percentile_latency: LatencyMilliseconds,
    pub sample_count: u32,
    pub available: bool,
}

pub fn assess_latency_window(
    measurement: &LatencyMeasurementWindow,
    requirement: LatencyRequirement,
) -> Result<LatencyWindowAssessment, PopmathError> {
    let sample_count = u32::try_from(measurement.samples_milliseconds.len())
        .map_err(|_| PopmathError::ArithmeticOverflow)?;

    if sample_count < requirement.minimum_sample_count {
        return Ok(LatencyWindowAssessment {
            percentile_latency: LatencyMilliseconds::new(
                NonNegativeF64::new(0.0)?,
            ),
            sample_count,
            available: false,
        });
    }

    if measurement.evidence < requirement.required_evidence {
        return Ok(LatencyWindowAssessment {
            percentile_latency: LatencyMilliseconds::new(
                NonNegativeF64::new(0.0)?,
            ),
            sample_count,
            available: false,
        });
    }

    let percentile_latency = calculate_percentile(
        &measurement.samples_milliseconds,
        requirement.percentile,
    )?;

    let available =
        percentile_latency.value() <= requirement.maximum_latency.value();

    Ok(LatencyWindowAssessment {
        percentile_latency,
        sample_count,
        available,
    })
}

pub fn latency_measurement_to_capability_window(
    measurement: &LatencyMeasurementWindow,
    requirement: LatencyRequirement,
) -> Result<CapabilityWindow, PopmathError> {
    let assessment = assess_latency_window(measurement, requirement)?;

    Ok(CapabilityWindow::new(
        CapabilityKind::LowLatencyConnectivity,
        measurement.window,
        measurement.evidence,
        assessment.available,
    ))
}

pub fn latency_requirement_to_capability_requirement(
    requirement: LatencyRequirement,
    minimum_availability: UnitInterval,
    maximum_gap_seconds: NonNegativeF64,
) -> CapabilityRequirement {
    CapabilityRequirement::new(
        CapabilityKind::LowLatencyConnectivity,
        minimum_availability,
        maximum_gap_seconds,
        requirement.required_evidence,
    )
}

fn calculate_percentile(
    samples: &[LatencyMilliseconds],
    percentile: UnitInterval,
) -> Result<LatencyMilliseconds, PopmathError> {
    if samples.is_empty() {
        return Err(PopmathError::InvalidInput(
            "at least one latency sample is required",
        ));
    }

    let mut values = samples
        .iter()
        .map(|sample| sample.value())
        .collect::<Vec<_>>();

    values.sort_by(f64::total_cmp);

    let position = percentile.value() * (values.len() - 1) as f64;
    let lower_index = position.floor() as usize;
    let upper_index = position.ceil() as usize;
    let fraction = position - lower_index as f64;

    let lower_value = values[lower_index];
    let upper_value = values[upper_index];
    let interpolated = lower_value + ((upper_value - lower_value) * fraction);

    Ok(LatencyMilliseconds::new(
        NonNegativeF64::new(interpolated)?,
    ))
}
