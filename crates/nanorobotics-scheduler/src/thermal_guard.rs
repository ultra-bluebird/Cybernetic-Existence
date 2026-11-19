use serde::{Deserialize, Serialize};
use thiserror::Error;

/// ThermalEnvelope: Temperature constraints for nanoswarm operations.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ThermalEnvelope {
    /// Maximum allowable brain temperature delta in Celsius.
    pub max_brain_delta_c: f32,
    /// Maximum allowable core temperature delta in Celsius.
    pub max_core_delta_c: f32,
    /// Maximum allowable skin temperature delta in Celsius.
    pub max_skin_delta_c: f32,
    /// Rate of temperature change limit in Celsius per second.
    pub max_rate_of_change_c_per_sec: f32,
}

/// TemperatureReading: A single temperature measurement with metadata.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TemperatureReading {
    /// Timestamp of the reading.
    pub timestamp: i64,
    /// Brain temperature delta in Celsius.
    pub brain_delta_c: f32,
    /// Core temperature delta in Celsius.
    pub core_delta_c: f32,
    /// Skin temperature delta in Celsius.
    pub skin_delta_c: f32,
    /// Rate of temperature change in Celsius per second.
    pub rate_of_change_c_per_sec: f32,
}

#[derive(Error, Debug)]
pub enum ThermalGuardError {
    #[error("brain temperature delta {0} exceeds envelope limit {1}")]
    BrainTempExceeded(f32, f32),
    #[error("core temperature delta {0} exceeds envelope limit {1}")]
    CoreTempExceeded(f32, f32),
    #[error("skin temperature delta {0} exceeds envelope limit {1}")]
    SkinTempExceeded(f32, f32),
    #[error("rate of temperature change {0} exceeds limit {1}")]
    RateOfChangeExceeded(f32, f32),
}

/// ThermalGuard: Enforces thermal safety constraints for nanoswarm operations.
pub struct ThermalGuard {
    envelope: ThermalEnvelope,
    last_reading: Option<TemperatureReading>,
}

impl ThermalGuard {
    /// Create a new thermal guard with the given envelope.
    pub fn new(envelope: ThermalEnvelope) -> Self {
        Self {
            envelope,
            last_reading: None,
        }
    }

    /// Validate a temperature reading against the thermal envelope.
    pub fn validate(&self, reading: &TemperatureReading) -> Result<(), ThermalGuardError> {
        if reading.brain_delta_c > self.envelope.max_brain_delta_c {
            return Err(ThermalGuardError::BrainTempExceeded(
                reading.brain_delta_c,
                self.envelope.max_brain_delta_c,
            ));
        }
        if reading.core_delta_c > self.envelope.max_core_delta_c {
            return Err(ThermalGuardError::CoreTempExceeded(
                reading.core_delta_c,
                self.envelope.max_core_delta_c,
            ));
        }
        if reading.skin_delta_c > self.envelope.max_skin_delta_c {
            return Err(ThermalGuardError::SkinTempExceeded(
                reading.skin_delta_c,
                self.envelope.max_skin_delta_c,
            ));
        }
        if reading.rate_of_change_c_per_sec.abs() > self.envelope.max_rate_of_change_c_per_sec {
            return Err(ThermalGuardError::RateOfChangeExceeded(
                reading.rate_of_change_c_per_sec,
                self.envelope.max_rate_of_change_c_per_sec,
            ));
        }
        Ok(())
    }

    /// Check if a proposed temperature change would violate the envelope.
    pub fn would_violate(&self, current: &TemperatureReading, proposed: &TemperatureReading) -> bool {
        self.validate(proposed).is_err()
    }

    /// Update the guard with a new reading and return validation result.
    pub fn update(&mut self, reading: TemperatureReading) -> Result<(), ThermalGuardError> {
        self.validate(&reading)?;
        self.last_reading = Some(reading);
        Ok(())
    }

    /// Get the last validated temperature reading.
    pub fn last_reading(&self) -> Option<&TemperatureReading> {
        self.last_reading.as_ref()
    }

    /// Get the thermal envelope.
    pub fn envelope(&self) -> &ThermalEnvelope {
        &self.envelope
    }
}
