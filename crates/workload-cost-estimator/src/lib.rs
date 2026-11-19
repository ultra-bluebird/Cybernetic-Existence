#![forbid(unsafe_code)]

//! Online estimation of a non-clinical workload-cost index.
//!
//! This crate integrates unitless workload observations. It does not estimate
//! calories, metabolic rate, oxygen consumption, medical status, or any
//! physiological property of a person.

#[derive(Debug, Clone, Copy)]
pub struct Coefficients {
    pub graph_load: f64,
    pub power_budget: f64,
    pub operator_burden: f64,
}

#[derive(Debug, Clone, Copy)]
pub struct WorkloadObservation {
    pub timestamp_seconds: f64,
    pub graph_load: f64,
    pub power_budget: f64,
    pub operator_burden: f64,
}

#[derive(Debug, Clone, Copy, Default)]
pub struct WorkloadCostEstimator {
    previous: Option<WorkloadObservation>,
    accumulated_cost_index_seconds: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WorkloadCostError {
    InvalidCoefficient,
    InvalidObservation,
    NonMonotonicTimestamp,
}

impl Coefficients {
    pub fn validate(&self) -> Result<(), WorkloadCostError> {
        let values = [self.graph_load, self.power_budget, self.operator_burden];

        if values.iter().any(|value| !value.is_finite() || *value < 0.0) {
            return Err(WorkloadCostError::InvalidCoefficient);
        }

        let sum = self.graph_load + self.power_budget + self.operator_burden;

        if (sum - 1.0).abs() > 0.000_001 {
            return Err(WorkloadCostError::InvalidCoefficient);
        }

        Ok(())
    }

    pub fn weighted_value(
        &self,
        observation: WorkloadObservation,
    ) -> Result<f64, WorkloadCostError> {
        self.validate()?;
        observation.validate()?;

        Ok(
            self.graph_load * observation.graph_load
                + self.power_budget * observation.power_budget
                + self.operator_burden * observation.operator_burden,
        )
    }
}

impl WorkloadObservation {
    pub fn validate(&self) -> Result<(), WorkloadCostError> {
        let values = [
            self.timestamp_seconds,
            self.graph_load,
            self.power_budget,
            self.operator_burden,
        ];

        if values.iter().any(|value| !value.is_finite()) {
            return Err(WorkloadCostError::InvalidObservation);
        }

        if self.timestamp_seconds < 0.0
            || !(0.0..=1.0).contains(&self.graph_load)
            || !(0.0..=1.0).contains(&self.power_budget)
            || !(0.0..=1.0).contains(&self.operator_burden)
        {
            return Err(WorkloadCostError::InvalidObservation);
        }

        Ok(())
    }
}

impl WorkloadCostEstimator {
    pub fn push(
        &mut self,
        coefficients: Coefficients,
        observation: WorkloadObservation,
    ) -> Result<f64, WorkloadCostError> {
        coefficients.validate()?;
        observation.validate()?;

        if let Some(previous) = self.previous {
            if observation.timestamp_seconds <= previous.timestamp_seconds {
                return Err(WorkloadCostError::NonMonotonicTimestamp);
            }

            let previous_value = coefficients.weighted_value(previous)?;
            let current_value = coefficients.weighted_value(observation)?;
            let elapsed_seconds = observation.timestamp_seconds - previous.timestamp_seconds;

            self.accumulated_cost_index_seconds +=
                ((previous_value + current_value) / 2.0) * elapsed_seconds;
        }

        self.previous = Some(observation);

        Ok(self.accumulated_cost_index_seconds)
    }

    pub fn accumulated_cost_index_seconds(&self) -> f64 {
        self.accumulated_cost_index_seconds
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn integrates_unitless_cost_with_trapezoidal_rule() {
        let coefficients = Coefficients {
            graph_load: 0.50,
            power_budget: 0.30,
            operator_burden: 0.20,
        };

        let mut estimator = WorkloadCostEstimator::default();

        estimator
            .push(
                coefficients,
                WorkloadObservation {
                    timestamp_seconds: 0.0,
                    graph_load: 1.0,
                    power_budget: 0.0,
                    operator_burden: 0.0,
                },
            )
            .expect("first valid sample");

        let result = estimator
            .push(
                coefficients,
                WorkloadObservation {
                    timestamp_seconds: 2.0,
                    graph_load: 1.0,
                    power_budget: 0.0,
                    operator_burden: 0.0,
                },
            )
            .expect("second valid sample");

        assert!((result - 1.0).abs() < f64::EPSILON);
    }

    #[test]
    fn rejects_non_normalized_coefficients() {
        let coefficients = Coefficients {
            graph_load: 0.50,
            power_budget: 0.30,
            operator_burden: 0.30,
        };

        assert_eq!(
            coefficients.validate(),
            Err(WorkloadCostError::InvalidCoefficient)
        );
    }
}
