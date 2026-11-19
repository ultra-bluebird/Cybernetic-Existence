use crate::bounds::{NonNegativeF64, UnitInterval};
use crate::error::PopmathError;
use crate::units::EnergyKwh;

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct GreenRoofEnergyInput {
    pub roof_area_square_meters: NonNegativeF64,
    pub baseline_cooling_energy_kwh_per_square_meter: NonNegativeF64,
    pub cooling_reduction_factor: UnitInterval,
    pub irrigation_pump_power_kw: NonNegativeF64,
    pub irrigation_runtime_hours: NonNegativeF64,
    pub irrigation_pump_efficiency: UnitInterval,
    pub baseline_critical_energy_kwh: EnergyKwh,
    pub available_storage_energy_kwh: EnergyKwh,
    pub critical_load_duration_hours: NonNegativeF64,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct GreenRoofEnergyResult {
    pub gross_cooling_energy_saved_kwh: EnergyKwh,
    pub irrigation_energy_kwh: EnergyKwh,
    pub net_energy_saved_kwh: EnergyKwh,
    pub adjusted_critical_energy_kwh: EnergyKwh,
    pub baseline_critical_load_kw: NonNegativeF64,
    pub adjusted_critical_load_kw: NonNegativeF64,
    pub baseline_support_hours: NonNegativeF64,
    pub adjusted_support_hours: NonNegativeF64,
}

pub fn calculate_green_roof_energy_balance(
    input: GreenRoofEnergyInput,
) -> Result<GreenRoofEnergyResult, PopmathError> {
    if input.roof_area_square_meters.value() <= 0.0 {
        return Err(PopmathError::InvalidInput(
            "green roof area must be greater than zero",
        ));
    }

    if input.irrigation_pump_efficiency.value() <= 0.0 {
        return Err(PopmathError::InvalidInput(
            "irrigation pump efficiency must be greater than zero",
        ));
    }

    if input.critical_load_duration_hours.value() <= 0.0 {
        return Err(PopmathError::InvalidInput(
            "critical-load duration must be greater than zero",
        ));
    }

    let gross_cooling_energy_saved_kwh = input.roof_area_square_meters.value()
        * input.baseline_cooling_energy_kwh_per_square_meter.value()
        * input.cooling_reduction_factor.value();

    let irrigation_energy_kwh = (
        input.irrigation_pump_power_kw.value()
            * input.irrigation_runtime_hours.value()
    ) / input.irrigation_pump_efficiency.value();

    let net_energy_saved_kwh = (
        gross_cooling_energy_saved_kwh - irrigation_energy_kwh
    )
    .max(0.0);

    let adjusted_critical_energy_kwh = (
        input.baseline_critical_energy_kwh.value().value()
            - net_energy_saved_kwh
    )
    .max(0.0);

    let baseline_critical_load_kw = input.baseline_critical_energy_kwh.value().value()
        / input.critical_load_duration_hours.value();

    let adjusted_critical_load_kw = adjusted_critical_energy_kwh
        / input.critical_load_duration_hours.value();

    let baseline_support_hours = if baseline_critical_load_kw > 0.0 {
        input.available_storage_energy_kwh.value().value()
            / baseline_critical_load_kw
    } else {
        f64::MAX
    };

    let adjusted_support_hours = if adjusted_critical_load_kw > 0.0 {
        input.available_storage_energy_kwh.value().value()
            / adjusted_critical_load_kw
    } else {
        f64::MAX
    };

    Ok(GreenRoofEnergyResult {
        gross_cooling_energy_saved_kwh: EnergyKwh::new(
            NonNegativeF64::new(gross_cooling_energy_saved_kwh)?,
        ),
        irrigation_energy_kwh: EnergyKwh::new(
            NonNegativeF64::new(irrigation_energy_kwh)?,
        ),
        net_energy_saved_kwh: EnergyKwh::new(
            NonNegativeF64::new(net_energy_saved_kwh)?,
        ),
        adjusted_critical_energy_kwh: EnergyKwh::new(
            NonNegativeF64::new(adjusted_critical_energy_kwh)?,
        ),
        baseline_critical_load_kw: NonNegativeF64::new(
            baseline_critical_load_kw,
        )?,
        adjusted_critical_load_kw: NonNegativeF64::new(
            adjusted_critical_load_kw,
        )?,
        baseline_support_hours: NonNegativeF64::new(
            baseline_support_hours,
        )?,
        adjusted_support_hours: NonNegativeF64::new(
            adjusted_support_hours,
        )?,
    })
}
