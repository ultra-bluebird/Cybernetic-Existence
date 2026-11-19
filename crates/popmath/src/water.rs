use crate::error::PopmathResult;
use crate::units::VolumeM3;

/// Input for one explicit water-balance interval.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct WaterBalanceInput {
    /// Storage at the start of the interval.
    pub starting_storage: VolumeM3,
    /// Inflow during the interval.
    pub inflow: VolumeM3,
    /// Service demand during the interval.
    pub demand: VolumeM3,
    /// Measured or modeled loss during the interval.
    pub losses: VolumeM3,
    /// Evaporation or defined environmental loss during the interval.
    pub evaporation: VolumeM3,
    /// Recovered, reclaimed, or transferred supply during the interval.
    pub recovered_supply: VolumeM3,
    /// Maximum usable storage capacity.
    pub maximum_storage: VolumeM3,
}

/// Result of a constrained water balance.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct WaterBalanceResult {
    /// Storage at the end of the interval.
    pub ending_storage: VolumeM3,
    /// Demand that could not be served within the modeled balance.
    pub unmet_demand: VolumeM3,
    /// Volume above maximum storage.
    pub spill: VolumeM3,
    /// Unconstrained storage before physical storage bounds were applied.
    pub unconstrained_storage: f64,
}

/// Calculates one water-storage accounting interval.
pub fn calculate_water_balance(input: WaterBalanceInput) -> PopmathResult<WaterBalanceResult> {
    let unconstrained_storage = input.starting_storage.get() + input.inflow.get()
        - input.demand.get()
        - input.losses.get()
        - input.evaporation.get()
        + input.recovered_supply.get();

    let ending_storage = unconstrained_storage.clamp(0.0, input.maximum_storage.get());
    let unmet_demand = (-unconstrained_storage).max(0.0);
    let spill = (unconstrained_storage - input.maximum_storage.get()).max(0.0);

    Ok(WaterBalanceResult {
        ending_storage: VolumeM3::new(ending_storage)?,
        unmet_demand: VolumeM3::new(unmet_demand)?,
        spill: VolumeM3::new(spill)?,
        unconstrained_storage,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn shortage_is_reported_separately_from_storage() {
        let result = calculate_water_balance(WaterBalanceInput {
            starting_storage: VolumeM3::new(100.0).expect("valid"),
            inflow: VolumeM3::new(10.0).expect("valid"),
            demand: VolumeM3::new(120.0).expect("valid"),
            losses: VolumeM3::new(5.0).expect("valid"),
            evaporation: VolumeM3::new(3.0).expect("valid"),
            recovered_supply: VolumeM3::new(0.0).expect("valid"),
            maximum_storage: VolumeM3::new(200.0).expect("valid"),
        })
        .expect("valid calculation");

        assert_eq!(result.ending_storage.get(), 0.0);
        assert_eq!(result.unmet_demand.get(), 18.0);
        assert_eq!(result.spill.get(), 0.0);
    }

    #[test]
    fn overflow_is_reported_separately_from_storage() {
        let result = calculate_water_balance(WaterBalanceInput {
            starting_storage: VolumeM3::new(90.0).expect("valid"),
            inflow: VolumeM3::new(80.0).expect("valid"),
            demand: VolumeM3::new(0.0).expect("valid"),
            losses: VolumeM3::new(0.0).expect("valid"),
            evaporation: VolumeM3::new(0.0).expect("valid"),
            recovered_supply: VolumeM3::new(0.0).expect("valid"),
            maximum_storage: VolumeM3::new(100.0).expect("valid"),
        })
        .expect("valid calculation");

        assert_eq!(result.ending_storage.get(), 100.0);
        assert_eq!(result.spill.get(), 70.0);
    }
}
