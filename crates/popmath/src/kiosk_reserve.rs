use crate::bounds::{NonNegativeF64, UnitInterval};
use crate::error::PopmathError;
use crate::units::EnergyKwh;

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct KioskReserveSizingInput {
    pub critical_load_kw: NonNegativeF64,
    pub mean_outage_hours: NonNegativeF64,
    pub outage_variance_hours_squared: NonNegativeF64,
    pub confidence_level: UnitInterval,
    pub continuity_ratio: UnitInterval,
    pub service_window_hours: NonNegativeF64,
    pub discharge_efficiency: UnitInterval,
    pub usable_depth_of_discharge: UnitInterval,
    pub reserve_margin: UnitInterval,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct KioskReserveSizingResult {
    pub conservative_outage_hours: NonNegativeF64,
    pub required_support_hours: NonNegativeF64,
    pub maximum_allowed_gap_hours: NonNegativeF64,
    pub minimum_nominal_capacity_kwh: EnergyKwh,
}

pub fn calculate_public_charging_kiosk_reserve(
    input: KioskReserveSizingInput,
) -> Result<KioskReserveSizingResult, PopmathError> {
    if input.critical_load_kw.value() <= 0.0 {
        return Err(PopmathError::InvalidInput(
            "critical load must be greater than zero",
        ));
    }

    if input.service_window_hours.value() <= 0.0 {
        return Err(PopmathError::InvalidInput(
            "service window must be greater than zero",
        ));
    }

    if input.confidence_level.value() <= 0.0 || input.confidence_level.value() >= 1.0 {
        return Err(PopmathError::InvalidInput(
            "confidence level must be greater than zero and less than one",
        ));
    }

    if input.discharge_efficiency.value() <= 0.0 {
        return Err(PopmathError::InvalidInput(
            "discharge efficiency must be greater than zero",
        ));
    }

    if input.usable_depth_of_discharge.value() <= 0.0 {
        return Err(PopmathError::InvalidInput(
            "usable depth of discharge must be greater than zero",
        ));
    }

    let standard_deviation = input.outage_variance_hours_squared.value().sqrt();

    let confidence_multiplier = (
        input.confidence_level.value()
            / (1.0 - input.confidence_level.value())
    )
    .sqrt();

    let conservative_outage_hours = input.mean_outage_hours.value()
        + standard_deviation * confidence_multiplier;

    let required_support_hours = conservative_outage_hours
        .min(input.service_window_hours.value());

    let maximum_allowed_gap_hours = (
        1.0 - input.continuity_ratio.value()
    )
    * input.service_window_hours.value();

    let capacity_kwh = (
        input.critical_load_kw.value()
            * required_support_hours
            * (1.0 + input.reserve_margin.value())
    )
    / (
        input.discharge_efficiency.value()
            * input.usable_depth_of_discharge.value()
    );

    Ok(KioskReserveSizingResult {
        conservative_outage_hours: NonNegativeF64::new(
            conservative_outage_hours,
        )?,
        required_support_hours: NonNegativeF64::new(required_support_hours)?,
        maximum_allowed_gap_hours: NonNegativeF64::new(
            maximum_allowed_gap_hours,
        )?,
        minimum_nominal_capacity_kwh: EnergyKwh::new(
            NonNegativeF64::new(capacity_kwh)?,
        ),
    })
}
