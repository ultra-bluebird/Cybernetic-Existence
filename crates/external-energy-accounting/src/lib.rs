#![forbid(unsafe_code)]

//! Online accounting for externally characterized energy-harvesting experiments.
//!
//! The crate measures and integrates supplied power samples. It does not
//! authorize wireless-power operation near people or make safety claims.

#[derive(Debug, Clone, Copy)]
pub struct PowerSample {
    pub timestamp_seconds: f64,
    pub input_power_watts: f64,
    pub conversion_efficiency: f64,
}

#[derive(Debug, Clone, Copy, Default)]
pub struct EnergyAccumulator {
    previous: Option<PowerSample>,
    harvested_energy_joules: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EnergyError {
    InvalidSample,
    NonMonotonicTimestamp,
}

impl PowerSample {
    pub fn validate(&self) -> Result<(), EnergyError> {
        if !self.timestamp_seconds.is_finite()
            || !self.input_power_watts.is_finite()
            || !self.conversion_efficiency.is_finite()
            || self.input_power_watts < 0.0
            || !(0.0..=1.0).contains(&self.conversion_efficiency)
        {
            return Err(EnergyError::InvalidSample);
        }

        Ok(())
    }

    pub fn harvested_power_watts(&self) -> f64 {
        self.input_power_watts * self.conversion_efficiency
    }
}

impl EnergyAccumulator {
    pub fn push(&mut self, sample: PowerSample) -> Result<f64, EnergyError> {
        sample.validate()?;

        if let Some(previous) = self.previous {
            if sample.timestamp_seconds <= previous.timestamp_seconds {
                return Err(EnergyError::NonMonotonicTimestamp);
            }

            let elapsed_seconds = sample.timestamp_seconds - previous.timestamp_seconds;
            let average_harvested_power =
                (previous.harvested_power_watts() + sample.harvested_power_watts()) / 2.0;

            self.harvested_energy_joules += average_harvested_power * elapsed_seconds;
        }

        self.previous = Some(sample);

        Ok(self.harvested_energy_joules)
    }

    pub fn harvested_energy_joules(&self) -> f64 {
        self.harvested_energy_joules
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn integrates_harvested_energy_with_trapezoidal_rule() {
        let mut accumulator = EnergyAccumulator::default();

        accumulator
            .push(PowerSample {
                timestamp_seconds: 0.0,
                input_power_watts: 10.0,
                conversion_efficiency: 0.50,
            })
            .expect("first sample should be accepted");

        let energy = accumulator
            .push(PowerSample {
                timestamp_seconds: 2.0,
                input_power_watts: 10.0,
                conversion_efficiency: 0.50,
            })
            .expect("second sample should be accepted");

        assert!((energy - 10.0).abs() < f64::EPSILON);
    }

    #[test]
    fn rejects_non_monotonic_sample_time() {
        let mut accumulator = EnergyAccumulator::default();

        accumulator
            .push(PowerSample {
                timestamp_seconds: 10.0,
                input_power_watts: 1.0,
                conversion_efficiency: 0.50,
            })
            .expect("first sample should be accepted");

        let result = accumulator.push(PowerSample {
            timestamp_seconds: 10.0,
            input_power_watts: 1.0,
            conversion_efficiency: 0.50,
        });

        assert_eq!(result, Err(EnergyError::NonMonotonicTimestamp));
    }
}
