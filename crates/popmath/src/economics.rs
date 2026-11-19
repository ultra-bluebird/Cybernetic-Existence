use crate::bounds::UnitInterval;
use crate::error::{PopmathError, PopmathResult};
use crate::units::{CurrencyAmount, CurrencyCode};

/// One future annual cost record for lifecycle-cost calculation.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct AnnualCost {
    /// Year index beginning at one.
    pub year: u32,
    /// Operations cost in the declared currency.
    pub operations: CurrencyAmount,
    /// Maintenance cost in the declared currency.
    pub maintenance: CurrencyAmount,
    /// Replacement cost in the declared currency.
    pub replacement: CurrencyAmount,
    /// Declared externality cost in the declared currency.
    pub externality: CurrencyAmount,
}

/// Lifecycle-cost model input.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct LifecycleCostInput {
    /// Initial capital cost at the base period.
    pub initial_cost: CurrencyAmount,
    /// Discount rate for annual discounting.
    pub discount_rate: UnitInterval,
    /// Expected annual costs.
    pub annual_costs: Vec<AnnualCost>,
}

/// Lifecycle-cost output.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct LifecycleCostResult {
    /// Discounted lifecycle cost in the base currency.
    pub present_value: CurrencyAmount,
    /// Number of years included.
    pub horizon_years: u32,
}

/// Calculates lifecycle cost using integer minor units rounded to nearest minor unit.
pub fn calculate_lifecycle_cost(input: &LifecycleCostInput) -> PopmathResult<LifecycleCostResult> {
    let currency = input.initial_cost.currency();
    let mut total = input.initial_cost.minor_units() as f64;
    let mut horizon_years = 0_u32;

    for annual in &input.annual_costs {
        if annual.year == 0 {
            return Err(PopmathError::InvalidScenario {
                field: "annual_cost_year",
            });
        }

        let annual_values = [
            annual.operations,
            annual.maintenance,
            annual.replacement,
            annual.externality,
        ];

        if annual_values.iter().any(|value| value.currency() != currency) {
            return Err(PopmathError::CurrencyMismatch);
        }

        let year_cost: i128 = annual_values.iter().map(|value| value.minor_units()).sum();
        let divisor = (1.0 + input.discount_rate.get()).powf(f64::from(annual.year));
        total += year_cost as f64 / divisor;
        horizon_years = horizon_years.max(annual.year);
    }

    if !total.is_finite() || total > i128::MAX as f64 || total < i128::MIN as f64 {
        return Err(PopmathError::NumericalInstability {
            component: "lifecycle_cost",
        });
    }

    Ok(LifecycleCostResult {
        present_value: CurrencyAmount::new(total.round() as i128, currency),
        horizon_years,
    })
}

/// Creates a currency amount with an explicit three-letter code.
pub fn amount(minor_units: i128, code: &str) -> PopmathResult<CurrencyAmount> {
    Ok(CurrencyAmount::new(minor_units, CurrencyCode::new(code)?))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn lifecycle_cost_uses_minor_units() {
        let usd = CurrencyCode::new("USD").expect("valid currency");
        let input = LifecycleCostInput {
            initial_cost: CurrencyAmount::new(10_000, usd),
            discount_rate: UnitInterval::new(0.10, "discount_rate").expect("valid rate"),
            annual_costs: vec![AnnualCost {
                year: 1,
                operations: CurrencyAmount::new(1_100, usd),
                maintenance: CurrencyAmount::new(0, usd),
                replacement: CurrencyAmount::new(0, usd),
                externality: CurrencyAmount::new(0, usd),
            }],
        };

        let result = calculate_lifecycle_cost(&input).expect("valid lifecycle cost");
        assert_eq!(result.present_value.minor_units(), 11_000);
    }
}
