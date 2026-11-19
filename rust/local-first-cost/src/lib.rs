#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct ResourceWeights {
    pub energy: f64,
    pub latency: f64,
    pub storage: f64,
    pub communications: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct ResourceBudget {
    pub max_energy_joules: f64,
    pub max_latency_millis: f64,
    pub max_storage_byte_hours: f64,
    pub max_communications_bytes: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct ResourceUsage {
    pub energy_joules: f64,
    pub latency_millis: f64,
    pub storage_byte_hours: f64,
    pub communications_bytes: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct CostReport {
    pub normalized_energy: f64,
    pub normalized_latency: f64,
    pub normalized_storage: f64,
    pub normalized_communications: f64,
    pub weighted_cost: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CostModelError {
    NonFiniteValue,
    NegativeValue,
    InvalidBudget,
    InvalidWeights,
}

pub fn calculate_cost(
    weights: ResourceWeights,
    budget: ResourceBudget,
    usage: ResourceUsage,
) -> Result<CostReport, CostModelError> {
    validate_weights(weights)?;
    validate_budget(budget)?;
    validate_usage(usage)?;

    let normalized_energy = normalized(usage.energy_joules, budget.max_energy_joules);
    let normalized_latency = normalized(usage.latency_millis, budget.max_latency_millis);
    let normalized_storage =
        normalized(usage.storage_byte_hours, budget.max_storage_byte_hours);
    let normalized_communications =
        normalized(usage.communications_bytes, budget.max_communications_bytes);

    let weighted_cost = weights.energy * normalized_energy
        + weights.latency * normalized_latency
        + weights.storage * normalized_storage
        + weights.communications * normalized_communications;

    Ok(CostReport {
        normalized_energy,
        normalized_latency,
        normalized_storage,
        normalized_communications,
        weighted_cost,
    })
}

fn normalized(value: f64, limit: f64) -> f64 {
    (value / limit).clamp(0.0, 1.0)
}

fn validate_weights(weights: ResourceWeights) -> Result<(), CostModelError> {
    for value in [
        weights.energy,
        weights.latency,
        weights.storage,
        weights.communications,
    ] {
        if !value.is_finite() {
            return Err(CostModelError::NonFiniteValue);
        }

        if value < 0.0 {
            return Err(CostModelError::NegativeValue);
        }
    }

    let sum =
        weights.energy + weights.latency + weights.storage + weights.communications;

    if (sum - 1.0).abs() > 1e-12 {
        return Err(CostModelError::InvalidWeights);
    }

    Ok(())
}

fn validate_budget(budget: ResourceBudget) -> Result<(), CostModelError> {
    for value in [
        budget.max_energy_joules,
        budget.max_latency_millis,
        budget.max_storage_byte_hours,
        budget.max_communications_bytes,
    ] {
        if !value.is_finite() {
            return Err(CostModelError::NonFiniteValue);
        }

        if value <= 0.0 {
            return Err(CostModelError::InvalidBudget);
        }
    }

    Ok(())
}

fn validate_usage(usage: ResourceUsage) -> Result<(), CostModelError> {
    for value in [
        usage.energy_joules,
        usage.latency_millis,
        usage.storage_byte_hours,
        usage.communications_bytes,
    ] {
        if !value.is_finite() {
            return Err(CostModelError::NonFiniteValue);
        }

        if value < 0.0 {
            return Err(CostModelError::NegativeValue);
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn calculates_a_bounded_weighted_resource_cost() {
        let report = calculate_cost(
            ResourceWeights {
                energy: 0.40,
                latency: 0.25,
                storage: 0.20,
                communications: 0.15,
            },
            ResourceBudget {
                max_energy_joules: 1_000.0,
                max_latency_millis: 500.0,
                max_storage_byte_hours: 1_000_000.0,
                max_communications_bytes: 500_000.0,
            },
            ResourceUsage {
                energy_joules: 400.0,
                latency_millis: 100.0,
                storage_byte_hours: 500_000.0,
                communications_bytes: 100_000.0,
            },
        )
        .expect("valid resource cost inputs");

        assert_eq!(report.normalized_energy, 0.4);
        assert_eq!(report.normalized_latency, 0.2);
        assert_eq!(report.normalized_storage, 0.5);
        assert_eq!(report.normalized_communications, 0.2);
        assert!((report.weighted_cost - 0.36).abs() < 1e-12);
    }

    #[test]
    fn rejects_weights_that_do_not_sum_to_one() {
        let result = calculate_cost(
            ResourceWeights {
                energy: 0.50,
                latency: 0.50,
                storage: 0.50,
                communications: 0.50,
            },
            ResourceBudget {
                max_energy_joules: 1.0,
                max_latency_millis: 1.0,
                max_storage_byte_hours: 1.0,
                max_communications_bytes: 1.0,
            },
            ResourceUsage {
                energy_joules: 0.0,
                latency_millis: 0.0,
                storage_byte_hours: 0.0,
                communications_bytes: 0.0,
            },
        );

        assert_eq!(result, Err(CostModelError::InvalidWeights));
    }

    #[test]
    fn caps_each_normalized_resource_component_at_one() {
        let report = calculate_cost(
            ResourceWeights {
                energy: 0.25,
                latency: 0.25,
                storage: 0.25,
                communications: 0.25,
            },
            ResourceBudget {
                max_energy_joules: 1.0,
                max_latency_millis: 1.0,
                max_storage_byte_hours: 1.0,
                max_communications_bytes: 1.0,
            },
            ResourceUsage {
                energy_joules: 20.0,
                latency_millis: 10.0,
                storage_byte_hours: 2.0,
                communications_bytes: 3.0,
            },
        )
        .expect("valid usage");

        assert_eq!(report.weighted_cost, 1.0);
    }
}
