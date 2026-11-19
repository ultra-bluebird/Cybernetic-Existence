#![forbid(unsafe_code)]

//! Environmental EMC monitoring primitives.
//!
//! This crate classifies measured environmental RF observations against
//! device-specific, externally established operational limits. It does not
//! determine human exposure safety, medical safety, or biological effects.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EmcAction {
    Observe,
    DeferNoncriticalWork,
    RequestOperatorReview,
}

#[derive(Debug, Clone, Copy)]
pub struct FrequencyBandLimit {
    pub start_hz: f64,
    pub end_hz: f64,
    pub operational_limit_watts: f64,
    pub measurement_uncertainty_watts: f64,
}

#[derive(Debug, Clone, Copy)]
pub struct AmbientMeasurement {
    pub frequency_hz: f64,
    pub received_power_watts: f64,
    pub measured_at_unix_seconds: u64,
}

#[derive(Debug, Clone, Copy)]
pub struct EmcAssessment {
    pub environmental_ratio: f64,
    pub margin: f64,
    pub action: EmcAction,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum EmcError {
    InvalidFrequencyBand,
    InvalidMeasurement,
    NoApplicableBand,
}

impl FrequencyBandLimit {
    pub fn validate(&self) -> Result<(), EmcError> {
        if !self.start_hz.is_finite()
            || !self.end_hz.is_finite()
            || !self.operational_limit_watts.is_finite()
            || !self.measurement_uncertainty_watts.is_finite()
            || self.start_hz < 0.0
            || self.end_hz <= self.start_hz
            || self.operational_limit_watts <= 0.0
            || self.measurement_uncertainty_watts < 0.0
        {
            return Err(EmcError::InvalidFrequencyBand);
        }

        Ok(())
    }

    pub fn contains(&self, frequency_hz: f64) -> bool {
        frequency_hz >= self.start_hz && frequency_hz <= self.end_hz
    }
}

pub fn assess_measurement(
    bands: &[FrequencyBandLimit],
    measurement: AmbientMeasurement,
) -> Result<EmcAssessment, EmcError> {
    if !measurement.frequency_hz.is_finite()
        || !measurement.received_power_watts.is_finite()
        || measurement.frequency_hz < 0.0
        || measurement.received_power_watts < 0.0
    {
        return Err(EmcError::InvalidMeasurement);
    }

    let band = bands
        .iter()
        .find(|candidate| candidate.contains(measurement.frequency_hz))
        .ok_or(EmcError::NoApplicableBand)?;

    band.validate()?;

    let adjusted_observed_power =
        measurement.received_power_watts + band.measurement_uncertainty_watts;

    let environmental_ratio = adjusted_observed_power / band.operational_limit_watts;
    let margin = band.operational_limit_watts / adjusted_observed_power.max(f64::MIN_POSITIVE);

    let action = if environmental_ratio < 0.50 {
        EmcAction::Observe
    } else if environmental_ratio < 1.00 {
        EmcAction::DeferNoncriticalWork
    } else {
        EmcAction::RequestOperatorReview
    };

    Ok(EmcAssessment {
        environmental_ratio,
        margin,
        action,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn high_environmental_ratio_requests_review() {
        let bands = [FrequencyBandLimit {
            start_hz: 100_000.0,
            end_hz: 1_000_000.0,
            operational_limit_watts: 0.010,
            measurement_uncertainty_watts: 0.001,
        }];

        let result = assess_measurement(
            &bands,
            AmbientMeasurement {
                frequency_hz: 500_000.0,
                received_power_watts: 0.010,
                measured_at_unix_seconds: 1_726_000_000,
            },
        )
        .expect("measurement should be valid");

        assert_eq!(result.action, EmcAction::RequestOperatorReview);
    }

    #[test]
    fn unmatched_band_is_rejected() {
        let bands = [FrequencyBandLimit {
            start_hz: 100_000.0,
            end_hz: 1_000_000.0,
            operational_limit_watts: 0.010,
            measurement_uncertainty_watts: 0.001,
        }];

        let result = assess_measurement(
            &bands,
            AmbientMeasurement {
                frequency_hz: 5_000_000.0,
                received_power_watts: 0.001,
                measured_at_unix_seconds: 1_726_000_000,
            },
        );

        assert_eq!(result, Err(EmcError::NoApplicableBand));
    }
}
