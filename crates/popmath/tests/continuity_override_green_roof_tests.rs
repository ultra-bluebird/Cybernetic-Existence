use popmath::bounds::{NonNegativeF64, UnitInterval};
use popmath::green_roof::{
    calculate_green_roof_energy_balance,
    GreenRoofEnergyInput,
};
use popmath::units::EnergyKwh;

#[test]
fn green_roof_reduces_adjusted_critical_load_in_synthetic_scenario() {
    let result = calculate_green_roof_energy_balance(
        GreenRoofEnergyInput {
            roof_area_square_meters: NonNegativeF64::new(500.0)
                .expect("roof area"),
            baseline_cooling_energy_kwh_per_square_meter:
                NonNegativeF64::new(0.80).expect("cooling energy"),
            cooling_reduction_factor: UnitInterval::new(0.30)
                .expect("reduction"),
            irrigation_pump_power_kw: NonNegativeF64::new(0.50)
                .expect("pump power"),
            irrigation_runtime_hours: NonNegativeF64::new(2.0)
                .expect("runtime"),
            irrigation_pump_efficiency: UnitInterval::new(0.80)
                .expect("pump efficiency"),
            baseline_critical_energy_kwh: EnergyKwh::new(
                NonNegativeF64::new(100.0).expect("baseline energy"),
            ),
            available_storage_energy_kwh: EnergyKwh::new(
                NonNegativeF64::new(80.0).expect("storage energy"),
            ),
            critical_load_duration_hours: NonNegativeF64::new(10.0)
                .expect("duration"),
        },
    )
    .expect("green roof balance");

    assert!(
        (result.gross_cooling_energy_saved_kwh.value().value() - 120.0)
            .abs()
            < 1e-9
    );

    assert!(
        (result.irrigation_energy_kwh.value().value() - 1.25).abs()
            < 1e-9
    );

    assert!(
        (result.net_energy_saved_kwh.value().value() - 118.75).abs()
            < 1e-9
    );

    assert_eq!(result.adjusted_critical_energy_kwh.value().value(), 0.0);

    assert!(
        result.adjusted_critical_load_kw.value()
            <= result.baseline_critical_load_kw.value()
    );
}

#[test]
fn green_roof_calculation_never_returns_negative_energy() {
    let result = calculate_green_roof_energy_balance(
        GreenRoofEnergyInput {
            roof_area_square_meters: NonNegativeF64::new(500.0)
                .expect("roof area"),
            baseline_cooling_energy_kwh_per_square_meter:
                NonNegativeF64::new(0.01).expect("cooling energy"),
            cooling_reduction_factor: UnitInterval::new(0.10)
                .expect("reduction"),
            irrigation_pump_power_kw: NonNegativeF64::new(10.0)
                .expect("pump power"),
            irrigation_runtime_hours: NonNegativeF64::new(8.0)
                .expect("runtime"),
            irrigation_pump_efficiency: UnitInterval::new(0.80)
                .expect("pump efficiency"),
            baseline_critical_energy_kwh: EnergyKwh::new(
                NonNegativeF64::new(100.0).expect("baseline energy"),
            ),
            available_storage_energy_kwh: EnergyKwh::new(
                NonNegativeF64::new(80.0).expect("storage energy"),
            ),
            critical_load_duration_hours: NonNegativeF64::new(10.0)
                .expect("duration"),
        },
    )
    .expect("green roof balance");

    assert_eq!(result.net_energy_saved_kwh.value().value(), 0.0);
    assert_eq!(
        result.adjusted_critical_energy_kwh.value().value(),
        100.0
    );
}
