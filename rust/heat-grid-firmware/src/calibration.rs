#![forbid(unsafe_code)]

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct CalibrationCoefficients {
    pub alpha: f32,
    pub beta: f32,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct CalibrationBounds {
    pub minimum_temperature_c: f32,
    pub maximum_temperature_c: f32,
    pub maximum_absolute_offset_c: f32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CalibrationError {
    NonFiniteInput,
    TemperatureOutsideSupportedRange,
    OffsetOutsideAllowedRange,
}

impl CalibrationCoefficients {
    pub fn corrected_temperature_c(
        self,
        raw_temperature_c: f32,
        bounds: CalibrationBounds,
    ) -> Result<f32, CalibrationError> {
        if !self.alpha.is_finite()
            || !self.beta.is_finite()
            || !raw_temperature_c.is_finite()
        {
            return Err(CalibrationError::NonFiniteInput);
        }

        if raw_temperature_c < bounds.minimum_temperature_c
            || raw_temperature_c > bounds.maximum_temperature_c
        {
            return Err(CalibrationError::TemperatureOutsideSupportedRange);
        }

        if self.beta.abs() > bounds.maximum_absolute_offset_c {
            return Err(CalibrationError::OffsetOutsideAllowedRange);
        }

        let corrected = self.alpha * raw_temperature_c + self.beta;

        if !corrected.is_finite() {
            return Err(CalibrationError::NonFiniteInput);
        }

        Ok(corrected)
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct TemperatureObservation {
    pub raw_temperature_c: f32,
    pub corrected_temperature_c: f32,
    pub relative_humidity_percent: f32,
    pub uncertainty_c: f32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ObservationQuality {
    Accepted,
    TemperatureOutOfRange,
    HumidityOutOfRange,
    CalibrationReview,
    OfflineBuffered,
}

pub fn assess_observation(
    raw_temperature_c: f32,
    relative_humidity_percent: f32,
    bounds: CalibrationBounds,
) -> ObservationQuality {
    if !raw_temperature_c.is_finite()
        || raw_temperature_c < bounds.minimum_temperature_c
        || raw_temperature_c > bounds.maximum_temperature_c
    {
        return ObservationQuality::TemperatureOutOfRange;
    }

    if !relative_humidity_percent.is_finite()
        || !(0.0..=100.0).contains(&relative_humidity_percent)
    {
        return ObservationQuality::HumidityOutOfRange;
    }

    ObservationQuality::Accepted
}
