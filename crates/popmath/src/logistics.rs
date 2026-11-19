use crate::bounds::PositiveF64;
use crate::error::{PopmathError, PopmathResult};
use crate::units::{DistanceM, EmissionsKgCo2e, MassKg, VolumeM3};

/// Input for a deterministic construction or freight delivery capacity screen.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct DeliveryCapacityInput {
    /// Total mass to transport.
    pub total_mass: MassKg,
    /// Total volume to transport.
    pub total_volume: VolumeM3,
    /// Maximum safe mass per vehicle load.
    pub vehicle_mass_capacity: MassKg,
    /// Maximum usable volume per vehicle load.
    pub vehicle_volume_capacity: VolumeM3,
    /// Available vehicle count.
    pub vehicle_count: u32,
    /// Total available crew-hours across the modeled delivery window.
    pub available_crew_hours: PositiveF64,
    /// Total required crew-hours for loading, travel support, unloading, and site service.
    pub required_crew_hours: PositiveF64,
    /// Aggregate route distance per vehicle in meters.
    pub route_distance_per_vehicle: DistanceM,
    /// Fuel use in liters per kilometer.
    pub fuel_liters_per_kilometer: PositiveF64,
    /// Emissions factor in kilograms carbon-dioxide-equivalent per liter.
    pub emissions_kg_co2e_per_liter: PositiveF64,
}

/// Result of a deterministic delivery capacity screen.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct DeliveryCapacityResult {
    /// Minimum loads required under mass and volume limits.
    pub minimum_loads: u32,
    /// Whether mass capacity determines the minimum load count.
    pub mass_is_limiting: bool,
    /// Whether volume capacity determines the minimum load count.
    pub volume_is_limiting: bool,
    /// Whether declared vehicles and crew-hours can satisfy the capacity screen.
    pub feasible: bool,
    /// Estimated total fuel use in liters.
    pub estimated_fuel_liters: f64,
    /// Estimated transport emissions.
    pub estimated_emissions: EmissionsKgCo2e,
}

/// Calculates a capacity screen without selecting routes or controlling vehicles.
pub fn calculate_delivery_capacity(
    input: DeliveryCapacityInput,
) -> PopmathResult<DeliveryCapacityResult> {
    if input.vehicle_count == 0 {
        return Err(PopmathError::ZeroNotAllowed {
            field: "vehicle_count",
        });
    }

    let mass_loads = (input.total_mass.get() / input.vehicle_mass_capacity.get()).ceil();
    let volume_loads = (input.total_volume.get() / input.vehicle_volume_capacity.get()).ceil();
    let required_loads = mass_loads.max(volume_loads);

    if required_loads > f64::from(u32::MAX) {
        return Err(PopmathError::NumericalInstability {
            component: "delivery_load_count",
        });
    }

    let minimum_loads = required_loads as u32;
    let vehicle_capacity_sufficient = minimum_loads <= input.vehicle_count;
    let crew_capacity_sufficient =
        input.required_crew_hours.get() <= input.available_crew_hours.get();

    let route_kilometers = input.route_distance_per_vehicle.get() / 1_000.0;
    let estimated_fuel_liters =
        f64::from(input.vehicle_count) * route_kilometers * input.fuel_liters_per_kilometer.get();
    let estimated_emissions =
        estimated_fuel_liters * input.emissions_kg_co2e_per_liter.get();

    Ok(DeliveryCapacityResult {
        minimum_loads,
        mass_is_limiting: mass_loads >= volume_loads,
        volume_is_limiting: volume_loads >= mass_loads,
        feasible: vehicle_capacity_sufficient && crew_capacity_sufficient,
        estimated_fuel_liters,
        estimated_emissions: EmissionsKgCo2e::new(estimated_emissions)?,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn delivery_capacity_reports_feasibility() {
        let result = calculate_delivery_capacity(DeliveryCapacityInput {
            total_mass: MassKg::new(9_000.0).expect("valid"),
            total_volume: VolumeM3::new(25.0).expect("valid"),
            vehicle_mass_capacity: MassKg::new(6_000.0).expect("valid"),
            vehicle_volume_capacity: VolumeM3::new(20.0).expect("valid"),
            vehicle_count: 2,
            available_crew_hours: PositiveF64::new(16.0, "crew_hours").expect("valid"),
            required_crew_hours: PositiveF64::new(8.0, "crew_hours").expect("valid"),
            route_distance_per_vehicle: DistanceM::new(80_000.0).expect("valid"),
            fuel_liters_per_kilometer: PositiveF64::new(0.25, "fuel_rate").expect("valid"),
            emissions_kg_co2e_per_liter: PositiveF64::new(2.68, "emissions_factor")
                .expect("valid"),
        })
        .expect("valid calculation");

        assert!(result.feasible);
        assert_eq!(result.minimum_loads, 2);
        assert!(result.estimated_emissions.get() > 0.0);
    }
}
