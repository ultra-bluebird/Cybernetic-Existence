#![forbid(unsafe_code)]

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HexDecision {
    Proceed,
    Derate,
    Halt,
    Indeterminate,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum HexError {
    NonFiniteInput,
    InvalidRange,
    InvalidCapacity,
    InvalidMassBalance,
    InvalidDissipation,
    InvalidCarbonEnergy,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct CanopyEtInput {
    pub canopy_fraction: f64,
    pub root_zone_water_fraction: f64,
    pub vapor_pressure_deficit_kpa: f64,
    pub air_temperature_c: f64,
    pub et_max_mm_per_day: f64,
    pub vpd_half_response_kpa: f64,
    pub vpd_shape: f64,
    pub temperature_optimum_c: f64,
    pub temperature_width_c: f64,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct AlbedoState {
    pub current_albedo: f64,
    pub initial_albedo: f64,
    pub aged_equilibrium_albedo: f64,
    pub aging_rate_per_day: f64,
    pub dust_sensitivity_per_loading_day: f64,
    pub shear_sensitivity_per_unit_day: f64,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct HteGains {
    pub values: [[f64; 3]; 3],
    pub hydraulic_dissipation: f64,
    pub thermal_dissipation: f64,
    pub ecological_dissipation: f64,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct NexusFloors {
    pub carbon_gco2e: f64,
    pub energy_kwh: f64,
    pub carbon_limit_gco2e_per_kwh: f64,
    pub water_available_m3: f64,
    pub water_used_m3: f64,
    pub water_reserve_m3: f64,
    pub energy_budget_kwh: f64,
    pub ecological_floor_met: bool,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct HexMassBalance {
    pub storage_change_m3: f64,
    pub imported_m3: f64,
    pub precipitation_capture_m3: f64,
    pub reclaimed_m3: f64,
    pub condensate_m3: f64,
    pub beneficial_use_m3: f64,
    pub evapotranspiration_m3: f64,
    pub loss_m3: f64,
    pub net_boundary_flux_m3: f64,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct TreeStressState {
    pub canopy_deficit: f64,
    pub soil_water_deficit: f64,
    pub hydraulic_stress_excess: f64,
    pub crown_damage_excess: f64,
    pub canopy_weight: f64,
    pub soil_water_weight: f64,
    pub hydraulic_weight: f64,
    pub crown_damage_weight: f64,
    pub critical_stress_value: f64,
}

pub fn canopy_et_modifier(input: CanopyEtInput) -> Result<f64, HexError> {
    let values = [
        input.canopy_fraction,
        input.root_zone_water_fraction,
        input.vapor_pressure_deficit_kpa,
        input.air_temperature_c,
        input.et_max_mm_per_day,
        input.vpd_half_response_kpa,
        input.vpd_shape,
        input.temperature_optimum_c,
        input.temperature_width_c,
    ];

    if values.iter().any(|value| !value.is_finite()) {
        return Err(HexError::NonFiniteInput);
    }

    if !(0.0..=1.0).contains(&input.canopy_fraction)
        || !(0.0..=1.0).contains(&input.root_zone_water_fraction)
        || input.vapor_pressure_deficit_kpa < 0.0
        || input.et_max_mm_per_day < 0.0
        || input.vpd_half_response_kpa <= 0.0
        || input.vpd_shape <= 0.0
        || input.temperature_width_c <= 0.0
    {
        return Err(HexError::InvalidRange);
    }

    let water_response = input.root_zone_water_fraction;
    let vpd_ratio = input.vapor_pressure_deficit_kpa / input.vpd_half_response_kpa;
    let vpd_response = 1.0 / (1.0 + vpd_ratio.powf(input.vpd_shape));
    let temperature_offset =
        input.air_temperature_c - input.temperature_optimum_c;
    let temperature_response = (-(temperature_offset * temperature_offset)
        / (2.0 * input.temperature_width_c * input.temperature_width_c))
        .exp();

    Ok(
        input.canopy_fraction
            * input.et_max_mm_per_day
            * water_response
            * vpd_response
            * temperature_response,
    )
}

pub fn advance_albedo(
    state: AlbedoState,
    dust_loading: f64,
    traffic_shear: f64,
    maintenance_fraction: f64,
    duration_days: f64,
) -> Result<f64, HexError> {
    let values = [
        state.current_albedo,
        state.initial_albedo,
        state.aged_equilibrium_albedo,
        state.aging_rate_per_day,
        state.dust_sensitivity_per_loading_day,
        state.shear_sensitivity_per_unit_day,
        dust_loading,
        traffic_shear,
        maintenance_fraction,
        duration_days,
    ];

    if values.iter().any(|value| !value.is_finite()) {
        return Err(HexError::NonFiniteInput);
    }

    if !(0.0..=1.0).contains(&state.current_albedo)
        || !(0.0..=1.0).contains(&state.initial_albedo)
        || !(0.0..=1.0).contains(&state.aged_equilibrium_albedo)
        || state.aging_rate_per_day < 0.0
        || state.dust_sensitivity_per_loading_day < 0.0
        || state.shear_sensitivity_per_unit_day < 0.0
        || dust_loading < 0.0
        || traffic_shear < 0.0
        || !(0.0..=1.0).contains(&maintenance_fraction)
        || duration_days < 0.0
    {
        return Err(HexError::InvalidRange);
    }

    let degradation_rate = state.aging_rate_per_day
        + state.dust_sensitivity_per_loading_day * dust_loading
        + state.shear_sensitivity_per_unit_day * traffic_shear;

    let degraded = state.aged_equilibrium_albedo
        + (state.current_albedo - state.aged_equilibrium_albedo)
            * (-degradation_rate * duration_days).exp();

    let maintained = degraded
        + maintenance_fraction * (state.initial_albedo - degraded);

    Ok(maintained.clamp(
        state.aged_equilibrium_albedo.min(state.initial_albedo),
        state.aged_equilibrium_albedo.max(state.initial_albedo),
    ))
}

pub fn normalized_hte_row_sum_bound(
    gains: HteGains,
) -> Result<f64, HexError> {
    let dissipation = [
        gains.hydraulic_dissipation,
        gains.thermal_dissipation,
        gains.ecological_dissipation,
    ];

    if dissipation.iter().any(|value| !value.is_finite() || *value <= 0.0) {
        return Err(HexError::InvalidDissipation);
    }

    let mut maximum_row_sum = 0.0_f64;

    for (row_index, row) in gains.values.iter().enumerate() {
        let mut row_sum = 0.0_f64;

        for gain in row {
            if !gain.is_finite() || *gain < 0.0 {
                return Err(HexError::InvalidRange);
            }

            row_sum += *gain / dissipation[row_index];
        }

        maximum_row_sum = maximum_row_sum.max(row_sum);
    }

    Ok(maximum_row_sum)
}

pub fn nexus_floors_met(
    floors: NexusFloors,
) -> Result<bool, HexError> {
    let values = [
        floors.carbon_gco2e,
        floors.energy_kwh,
        floors.carbon_limit_gco2e_per_kwh,
        floors.water_available_m3,
        floors.water_used_m3,
        floors.water_reserve_m3,
        floors.energy_budget_kwh,
    ];

    if values.iter().any(|value| !value.is_finite()) {
        return Err(HexError::NonFiniteInput);
    }

    if floors.carbon_gco2e < 0.0
        || floors.energy_kwh <= 0.0
        || floors.carbon_limit_gco2e_per_kwh <= 0.0
        || floors.water_available_m3 < 0.0
        || floors.water_used_m3 < 0.0
        || floors.water_reserve_m3 < 0.0
        || floors.energy_budget_kwh < 0.0
    {
        return Err(HexError::InvalidCarbonEnergy);
    }

    let carbon_ok =
        floors.carbon_gco2e / floors.energy_kwh
            <= floors.carbon_limit_gco2e_per_kwh;

    let water_ok =
        floors.water_available_m3 - floors.water_used_m3
            >= floors.water_reserve_m3;

    let energy_ok = floors.energy_kwh <= floors.energy_budget_kwh;

    Ok(carbon_ok && water_ok && energy_ok && floors.ecological_floor_met)
}

pub fn mass_balance_residual(
    balance: HexMassBalance,
) -> Result<f64, HexError> {
    let values = [
        balance.storage_change_m3,
        balance.imported_m3,
        balance.precipitation_capture_m3,
        balance.reclaimed_m3,
        balance.condensate_m3,
        balance.beneficial_use_m3,
        balance.evapotranspiration_m3,
        balance.loss_m3,
        balance.net_boundary_flux_m3,
    ];

    if values.iter().any(|value| !value.is_finite()) {
        return Err(HexError::NonFiniteInput);
    }

    if balance.imported_m3 < 0.0
        || balance.precipitation_capture_m3 < 0.0
        || balance.reclaimed_m3 < 0.0
        || balance.condensate_m3 < 0.0
        || balance.beneficial_use_m3 < 0.0
        || balance.evapotranspiration_m3 < 0.0
        || balance.loss_m3 < 0.0
    {
        return Err(HexError::InvalidMassBalance);
    }

    Ok(
        balance.storage_change_m3
            - balance.imported_m3
            - balance.precipitation_capture_m3
            - balance.reclaimed_m3
            - balance.condensate_m3
            - balance.net_boundary_flux_m3
            + balance.beneficial_use_m3
            + balance.evapotranspiration_m3
            + balance.loss_m3,
    )
}

pub fn tree_stress_value(
    state: TreeStressState,
) -> Result<f64, HexError> {
    let values = [
        state.canopy_deficit,
        state.soil_water_deficit,
        state.hydraulic_stress_excess,
        state.crown_damage_excess,
        state.canopy_weight,
        state.soil_water_weight,
        state.hydraulic_weight,
        state.crown_damage_weight,
        state.critical_stress_value,
    ];

    if values.iter().any(|value| !value.is_finite()) {
        return Err(HexError::NonFiniteInput);
    }

    if state.canopy_deficit < 0.0
        || state.soil_water_deficit < 0.0
        || state.hydraulic_stress_excess < 0.0
        || state.crown_damage_excess < 0.0
        || state.canopy_weight < 0.0
        || state.soil_water_weight < 0.0
        || state.hydraulic_weight < 0.0
        || state.crown_damage_weight < 0.0
        || state.critical_stress_value < 0.0
    {
        return Err(HexError::InvalidRange);
    }

    Ok(
        state.canopy_weight * state.canopy_deficit.powi(2)
            + state.soil_water_weight * state.soil_water_deficit.powi(2)
            + state.hydraulic_weight * state.hydraulic_stress_excess.powi(2)
            + state.crown_damage_weight * state.crown_damage_excess.powi(2),
    )
}

pub fn evaluate_hex(
    gains: HteGains,
    required_small_gain_margin: f64,
    floors: NexusFloors,
    balance_residual_m3: f64,
    mass_balance_tolerance_m3: f64,
    tree_stress: TreeStressState,
) -> Result<HexDecision, HexError> {
    if !required_small_gain_margin.is_finite()
        || !mass_balance_tolerance_m3.is_finite()
        || required_small_gain_margin <= 0.0
        || required_small_gain_margin >= 1.0
        || mass_balance_tolerance_m3 < 0.0
    {
        return Err(HexError::InvalidRange);
    }

    if !nexus_floors_met(floors)? {
        return Ok(HexDecision::Halt);
    }

    let gain_bound = normalized_hte_row_sum_bound(gains)?;

    if gain_bound > 1.0 - required_small_gain_margin {
        return Ok(HexDecision::Indeterminate);
    }

    if !balance_residual_m3.is_finite()
        || balance_residual_m3.abs() > mass_balance_tolerance_m3
    {
        return Ok(HexDecision::Indeterminate);
    }

    let stress_value = tree_stress_value(tree_stress)?;

    if stress_value > tree_stress.critical_stress_value {
        return Ok(HexDecision::Derate);
    }

    Ok(HexDecision::Proceed)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn high_vpd_reduces_canopy_et_modifier() {
        let common = CanopyEtInput {
            canopy_fraction: 0.5,
            root_zone_water_fraction: 0.8,
            vapor_pressure_deficit_kpa: 1.0,
            air_temperature_c: 35.0,
            et_max_mm_per_day: 6.0,
            vpd_half_response_kpa: 2.0,
            vpd_shape: 2.0,
            temperature_optimum_c: 30.0,
            temperature_width_c: 10.0,
        };

        let low_vpd = canopy_et_modifier(common).expect("valid input");
        let high_vpd = canopy_et_modifier(CanopyEtInput {
            vapor_pressure_deficit_kpa: 5.0,
            ..common
        })
        .expect("valid input");

        assert!(high_vpd < low_vpd);
    }

    #[test]
    fn dust_and_shear_degrade_albedo_without_maintenance() {
        let state = AlbedoState {
            current_albedo: 0.35,
            initial_albedo: 0.35,
            aged_equilibrium_albedo: 0.12,
            aging_rate_per_day: 0.001,
            dust_sensitivity_per_loading_day: 0.002,
            shear_sensitivity_per_unit_day: 0.002,
        };

        let next = advance_albedo(state, 2.0, 2.0, 0.0, 30.0)
            .expect("valid albedo input");

        assert!(next < state.current_albedo);
    }

    #[test]
    fn high_normalized_gain_returns_indeterminate() {
        let decision = evaluate_hex(
            HteGains {
                values: [
                    [0.8, 0.2, 0.2],
                    [0.2, 0.8, 0.2],
                    [0.2, 0.2, 0.8],
                ],
                hydraulic_dissipation: 1.0,
                thermal_dissipation: 1.0,
                ecological_dissipation: 1.0,
            },
            0.1,
            NexusFloors {
                carbon_gco2e: 40.0,
                energy_kwh: 1.0,
                carbon_limit_gco2e_per_kwh: 50.0,
                water_available_m3: 100.0,
                water_used_m3: 10.0,
                water_reserve_m3: 50.0,
                energy_budget_kwh: 2.0,
                ecological_floor_met: true,
            },
            0.0,
            0.01,
            TreeStressState {
                canopy_deficit: 0.0,
                soil_water_deficit: 0.0,
                hydraulic_stress_excess: 0.0,
                crown_damage_excess: 0.0,
                canopy_weight: 1.0,
                soil_water_weight: 1.0,
                hydraulic_weight: 1.0,
                crown_damage_weight: 1.0,
                critical_stress_value: 1.0,
            },
        )
        .expect("valid hex state");

        assert_eq!(decision, HexDecision::Indeterminate);
    }

    #[test]
    fn mass_balance_residual_closes_for_balanced_hex() {
        let residual = mass_balance_residual(HexMassBalance {
            storage_change_m3: 5.0,
            imported_m3: 10.0,
            precipitation_capture_m3: 3.0,
            reclaimed_m3: 2.0,
            condensate_m3: 1.0,
            beneficial_use_m3: 8.0,
            evapotranspiration_m3: 2.0,
            loss_m3: 1.0,
            net_boundary_flux_m3: 2.0,
        })
        .expect("valid mass balance");

        assert!(residual.abs() < 1e-12);
    }

    #[test]
    fn tree_stress_above_calibrated_boundary_derates() {
        let decision = evaluate_hex(
            HteGains {
                values: [
                    [0.1, 0.0, 0.0],
                    [0.0, 0.1, 0.0],
                    [0.0, 0.0, 0.1],
                ],
                hydraulic_dissipation: 1.0,
                thermal_dissipation: 1.0,
                ecological_dissipation: 1.0,
            },
            0.1,
            NexusFloors {
                carbon_gco2e: 40.0,
                energy_kwh: 1.0,
                carbon_limit_gco2e_per_kwh: 50.0,
                water_available_m3: 100.0,
                water_used_m3: 10.0,
                water_reserve_m3: 50.0,
                energy_budget_kwh: 2.0,
                ecological_floor_met: true,
            },
            0.0,
            0.01,
            TreeStressState {
                canopy_deficit: 0.8,
                soil_water_deficit: 0.8,
                hydraulic_stress_excess: 0.8,
                crown_damage_excess: 0.8,
                canopy_weight: 1.0,
                soil_water_weight: 1.0,
                hydraulic_weight: 1.0,
                crown_damage_weight: 1.0,
                critical_stress_value: 1.0,
            },
        )
        .expect("valid hex state");

        assert_eq!(decision, HexDecision::Derate);
    }
}
