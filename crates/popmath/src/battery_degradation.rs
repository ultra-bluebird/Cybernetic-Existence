use crate::bounds::{NonNegativeF64, UnitInterval};
use crate::error::PopmathError;
use crate::units::EnergyKwh;

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct BatteryDegradationInput {
    pub nominal_capacity_kwh: EnergyKwh,
    pub cycle_count: NonNegativeF64,
    pub depth_of_discharge: UnitInterval,
    pub reference_depth_of_discharge: UnitInterval,
    pub cycle_fade_per_reference_cycle: UnitInterval,
    pub depth_of_discharge_exponent: NonNegativeF64,
    pub calendar_years: NonNegativeF64,
    pub calendar_fade_per_year: UnitInterval,
    pub capacity_floor: UnitInterval,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct BatteryDegradationResult {
    pub cycle_capacity_factor: UnitInterval,
    pub calendar_capacity_factor: UnitInterval,
    pub retained_capacity_factor: UnitInterval,
    pub available_capacity_kwh: EnergyKwh,
}

pub fn calculate_battery_degradation(
    input: BatteryDegradationInput,
) -> Result<BatteryDegradationResult, PopmathError> {
    if input.nominal_capacity_kwh.value().value() <= 0.0 {
        return Err(PopmathError::InvalidInput(
            "nominal battery capacity must be greater than zero",
        ));
    }

    if input.reference_depth_of_discharge.value() <= 0.0 {
        return Err(PopmathError::InvalidInput(
            "reference depth of discharge must be greater than zero",
        ));
    }

    let depth_ratio = input.depth_of_discharge.value()
        / input.reference_depth_of_discharge.value();

    let cycle_fade = input.cycle_fade_per_reference_cycle.value()
        * input.cycle_count.value()
        * depth_ratio.powf(input.depth_of_discharge_exponent.value());

    let calendar_fade =
        input.calendar_fade_per_year.value() * input.calendar_years.value();

    let cycle_capacity_factor = (
        1.0 - cycle_fade
    )
    .max(input.capacity_floor.value())
    .clamp(0.0, 1.0);

    let calendar_capacity_factor = (
        1.0 - calendar_fade
    )
    .max(input.capacity_floor.value())
    .clamp(0.0, 1.0);

    let retained_capacity_factor = (
        cycle_capacity_factor * calendar_capacity_factor
    )
    .max(input.capacity_floor.value())
    .clamp(0.0, 1.0);

    let available_capacity_kwh = input.nominal_capacity_kwh.value().value()
        * retained_capacity_factor;

    Ok(BatteryDegradationResult {
        cycle_capacity_factor: UnitInterval::new(cycle_capacity_factor)?,
        calendar_capacity_factor: UnitInterval::new(calendar_capacity_factor)?,
        retained_capacity_factor: UnitInterval::new(retained_capacity_factor)?,
        available_capacity_kwh: EnergyKwh::new(
            NonNegativeF64::new(available_capacity_kwh)?,
        ),
    })
}
