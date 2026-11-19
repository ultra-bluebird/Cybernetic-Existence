use alloc::vec::Vec;

use crate::bounds::{NonNegativeF64, PositiveF64, UnitInterval};
use crate::error::{PopmathError, PopmathResult};
use crate::synthetic_demand::AggregateDemandRow;
use crate::units::{EnergyKwh, PopulationCount, PopulationWeight};

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct PopulationProjectionInput {
    pub starting_population: PopulationCount,
    pub annual_growth_rate: UnitInterval,
    pub years: u32,
    pub annual_net_adjustment: i64,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct PopulationProjectionResult {
    pub projected_population: PopulationCount,
    pub net_change: i64,
}

pub fn project_population(
    input: PopulationProjectionInput,
) -> PopmathResult<PopulationProjectionResult> {
    let mut population = input.starting_population.get() as f64;
    let annual_growth_factor = 1.0 + input.annual_growth_rate.get();

    for _ in 0..input.years {
        population = population.mul_add(
            annual_growth_factor,
            input.annual_net_adjustment as f64,
        );

        if !population.is_finite() || population < 0.0 || population > u64::MAX as f64 {
            return Err(PopmathError::NumericalInstability {
                component: "population_projection",
            });
        }
    }

    let projected_population = PopulationCount::new(population.round() as u64);
    let net_change = calculate_net_change(
        input.starting_population,
        projected_population,
    )?;

    Ok(PopulationProjectionResult {
        projected_population,
        net_change,
    })
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct ServiceDemandInput {
    pub population_weight: PopulationWeight,
    pub demand_per_population_weight: PositiveF64,
    pub peak_multiplier: PositiveF64,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct ServiceDemandResult {
    pub baseline_demand: f64,
    pub peak_demand: f64,
}

pub fn calculate_service_demand(
    input: ServiceDemandInput,
) -> PopmathResult<ServiceDemandResult> {
    let baseline_demand =
        input.population_weight.get() * input.demand_per_population_weight.get();

    let peak_demand = baseline_demand * input.peak_multiplier.get();

    if !baseline_demand.is_finite() || !peak_demand.is_finite() {
        return Err(PopmathError::NumericalInstability {
            component: "service_demand",
        });
    }

    Ok(ServiceDemandResult {
        baseline_demand,
        peak_demand,
    })
}

#[derive(Clone, Debug, PartialEq)]
pub struct AggregateServiceDemandProfile {
    pub peak_operating_load_kw: NonNegativeF64,
    pub total_recharge_energy_kwh: EnergyKwh,
    pub active_synthetic_count: PopulationCount,
    pub contributing_rows: u64,
}

pub fn aggregate_synthetic_service_demand(
    rows: &[AggregateDemandRow],
) -> PopmathResult<AggregateServiceDemandProfile> {
    if rows.is_empty() {
        return Err(PopmathError::InvalidInput(
            "at least one aggregate demand row is required",
        ));
    }

    let mut peak_operating_load_kw = 0.0_f64;
    let mut total_recharge_energy_kwh = 0.0_f64;
    let mut active_synthetic_count = 0_u64;

    for row in rows {
        let operating_load_kw = row.operating_load_kw.value();
        let recharge_energy_kwh = row.recharge_energy_kwh.value().value();
        let active_count = row.active_synthetic_count.value();

        if !operating_load_kw.is_finite() || !recharge_energy_kwh.is_finite() {
            return Err(PopmathError::NumericalInstability {
                component: "aggregate_synthetic_service_demand",
            });
        }

        peak_operating_load_kw = peak_operating_load_kw.max(operating_load_kw);

        total_recharge_energy_kwh += recharge_energy_kwh;

        if !total_recharge_energy_kwh.is_finite() {
            return Err(PopmathError::NumericalInstability {
                component: "aggregate_synthetic_service_demand",
            });
        }

        active_synthetic_count = active_synthetic_count
            .checked_add(active_count)
            .ok_or(PopmathError::ArithmeticOverflow)?;
    }

    let contributing_rows = u64::try_from(rows.len())
        .map_err(|_| PopmathError::ArithmeticOverflow)?;

    Ok(AggregateServiceDemandProfile {
        peak_operating_load_kw: NonNegativeF64::new(peak_operating_load_kw)?,
        total_recharge_energy_kwh: EnergyKwh::new(
            NonNegativeF64::new(total_recharge_energy_kwh)?,
        ),
        active_synthetic_count: PopulationCount::new(active_synthetic_count),
        contributing_rows,
    })
}

pub fn aggregate_synthetic_demand_rows_by_time_bin(
    rows: &[AggregateDemandRow],
    time_bin_index: u32,
) -> PopmathResult<AggregateServiceDemandProfile> {
    let selected_rows = rows
        .iter()
        .filter(|row| row.time_bin_index == time_bin_index)
        .cloned()
        .collect::<Vec<_>>();

    aggregate_synthetic_service_demand(&selected_rows)
}

fn calculate_net_change(
    starting_population: PopulationCount,
    projected_population: PopulationCount,
) -> PopmathResult<i64> {
    let net_change = projected_population.get() as i128
        - starting_population.get() as i128;

    if net_change > i64::MAX as i128 || net_change < i64::MIN as i128 {
        return Err(PopmathError::NumericalInstability {
            component: "population_net_change",
        });
    }

    Ok(net_change as i64)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::synthetic_demand::AggregateDemandRow;

    fn demand_row(
        zone_index: u32,
        time_bin_index: u32,
        active_synthetic_count: u64,
        operating_load_kw: f64,
        recharge_energy_kwh: f64,
    ) -> AggregateDemandRow {
        AggregateDemandRow {
            zone_index,
            time_bin_index,
            active_synthetic_count: PopulationCount::new(active_synthetic_count),
            operating_load_kw: NonNegativeF64::new(operating_load_kw)
                .expect("operating load is non-negative"),
            recharge_energy_kwh: EnergyKwh::new(
                NonNegativeF64::new(recharge_energy_kwh)
                    .expect("recharge energy is non-negative"),
            ),
        }
    }

    #[test]
    fn aggregate_population_projection_is_reproducible() {
        let result = project_population(PopulationProjectionInput {
            starting_population: PopulationCount::new(100_000),
            annual_growth_rate: UnitInterval::new(
                0.02,
                "annual_growth_rate",
            )
            .expect("annual growth rate is valid"),
            years: 2,
            annual_net_adjustment: 100,
        })
        .expect("population projection succeeds");

        assert_eq!(result.projected_population.get(), 104_240);
        assert_eq!(result.net_change, 4_240);
    }

    #[test]
    fn aggregate_population_projection_supports_negative_adjustments() {
        let result = project_population(PopulationProjectionInput {
            starting_population: PopulationCount::new(1_000),
            annual_growth_rate: UnitInterval::new(
                0.0,
                "annual_growth_rate",
            )
            .expect("zero growth rate is valid"),
            years: 2,
            annual_net_adjustment: -100,
        })
        .expect("population projection succeeds");

        assert_eq!(result.projected_population.get(), 800);
        assert_eq!(result.net_change, -200);
    }

    #[test]
    fn aggregate_population_projection_rejects_negative_population() {
        let error = project_population(PopulationProjectionInput {
            starting_population: PopulationCount::new(100),
            annual_growth_rate: UnitInterval::new(
                0.0,
                "annual_growth_rate",
            )
            .expect("zero growth rate is valid"),
            years: 1,
            annual_net_adjustment: -101,
        })
        .expect_err("projection below zero must fail");

        assert_eq!(
            error,
            PopmathError::NumericalInstability {
                component: "population_projection",
            }
        );
    }

    #[test]
    fn aggregate_service_demand_models_peak_conditions() {
        let result = calculate_service_demand(ServiceDemandInput {
            population_weight: PopulationWeight::new(1_000.0)
                .expect("population weight is valid"),
            demand_per_population_weight: PositiveF64::new(
                1.5,
                "demand_per_population_weight",
            )
            .expect("demand factor is valid"),
            peak_multiplier: PositiveF64::new(1.25, "peak_multiplier")
                .expect("peak multiplier is valid"),
        })
        .expect("service demand succeeds");

        assert_eq!(result.baseline_demand, 1_500.0);
        assert_eq!(result.peak_demand, 1_875.0);
    }

    #[test]
    fn synthetic_demand_aggregation_tracks_peak_load_and_total_energy() {
        let result = aggregate_synthetic_service_demand(&[
            demand_row(1, 0, 15, 2.5, 1.25),
            demand_row(1, 1, 20, 3.75, 1.50),
            demand_row(2, 1, 10, 3.25, 0.75),
        ])
        .expect("aggregate demand succeeds");

        assert_eq!(result.peak_operating_load_kw.value(), 3.75);
        assert_eq!(result.total_recharge_energy_kwh.value().value(), 3.50);
        assert_eq!(result.active_synthetic_count.get(), 45);
        assert_eq!(result.contributing_rows, 3);
    }

    #[test]
    fn synthetic_demand_aggregation_can_select_one_time_bin() {
        let rows = [
            demand_row(1, 0, 15, 2.5, 1.25),
            demand_row(1, 1, 20, 3.75, 1.50),
            demand_row(2, 1, 10, 3.25, 0.75),
        ];

        let result = aggregate_synthetic_demand_rows_by_time_bin(&rows, 1)
            .expect("time-bin aggregation succeeds");

        assert_eq!(result.peak_operating_load_kw.value(), 3.75);
        assert_eq!(result.total_recharge_energy_kwh.value().value(), 2.25);
        assert_eq!(result.active_synthetic_count.get(), 30);
        assert_eq!(result.contributing_rows, 2);
    }

    #[test]
    fn synthetic_demand_aggregation_rejects_empty_input() {
        let error = aggregate_synthetic_service_demand(&[])
            .expect_err("empty demand rows must fail");

        assert_eq!(
            error,
            PopmathError::InvalidInput(
                "at least one aggregate demand row is required"
            )
        );
    }
}
