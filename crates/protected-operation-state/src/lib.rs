#![forbid(unsafe_code)]

//! Protected operating-mode state machine.
//!
//! This module controls software workload behavior only. It does not command
//! physical movement, enter restricted areas, actuate equipment, or assess
//! human health or radiation exposure.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OperatingMode {
    Normal,
    Protected,
    ReviewRequired,
}

#[derive(Debug, Clone, Copy)]
pub struct EnvironmentalState {
    pub emc_margin: f64,
    pub thermal_margin: f64,
    pub sensor_integrity: f64,
    pub environment_known: bool,
}

#[derive(Debug, Clone, Copy)]
pub struct ModePolicy {
    pub minimum_emc_margin: f64,
    pub minimum_thermal_margin: f64,
    pub minimum_sensor_integrity: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ModeError {
    InvalidPolicy,
    InvalidState,
}

impl Default for ModePolicy {
    fn default() -> Self {
        Self {
            minimum_emc_margin: 1.0,
            minimum_thermal_margin: 1.0,
            minimum_sensor_integrity: 0.80,
        }
    }
}

impl ModePolicy {
    pub fn validate(&self) -> Result<(), ModeError> {
        if !self.minimum_emc_margin.is_finite()
            || !self.minimum_thermal_margin.is_finite()
            || !self.minimum_sensor_integrity.is_finite()
            || self.minimum_emc_margin <= 0.0
            || self.minimum_thermal_margin <= 0.0
            || !(0.0..=1.0).contains(&self.minimum_sensor_integrity)
        {
            return Err(ModeError::InvalidPolicy);
        }

        Ok(())
    }
}

pub fn determine_mode(
    policy: ModePolicy,
    state: EnvironmentalState,
) -> Result<OperatingMode, ModeError> {
    policy.validate()?;

    if !state.emc_margin.is_finite()
        || !state.thermal_margin.is_finite()
        || !state.sensor_integrity.is_finite()
        || state.emc_margin < 0.0
        || state.thermal_margin < 0.0
        || !(0.0..=1.0).contains(&state.sensor_integrity)
    {
        return Err(ModeError::InvalidState);
    }

    if !state.environment_known {
        return Ok(OperatingMode::ReviewRequired);
    }

    let below_operating_profile = state.emc_margin < policy.minimum_emc_margin
        || state.thermal_margin < policy.minimum_thermal_margin
        || state.sensor_integrity < policy.minimum_sensor_integrity;

    if below_operating_profile {
        Ok(OperatingMode::Protected)
    } else {
        Ok(OperatingMode::Normal)
    }
}

pub fn user_message(mode: OperatingMode) -> &'static str {
    match mode {
        OperatingMode::Normal => "Operating within the configured environmental profile.",
        OperatingMode::Protected => {
            "Environmental conditions are outside the configured operating profile. Noncritical tasks are paused."
        }
        OperatingMode::ReviewRequired => {
            "Environmental status requires review before noncritical tasks resume."
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn low_sensor_integrity_enters_protected_mode() {
        let mode = determine_mode(
            ModePolicy::default(),
            EnvironmentalState {
                emc_margin: 2.0,
                thermal_margin: 2.0,
                sensor_integrity: 0.50,
                environment_known: true,
            },
        )
        .expect("state should be valid");

        assert_eq!(mode, OperatingMode::Protected);
    }

    #[test]
    fn unknown_environment_requires_review() {
        let mode = determine_mode(
            ModePolicy::default(),
            EnvironmentalState {
                emc_margin: 2.0,
                thermal_margin: 2.0,
                sensor_integrity: 1.0,
                environment_known: false,
            },
        )
        .expect("state should be valid");

        assert_eq!(mode, OperatingMode::ReviewRequired);
    }
}
