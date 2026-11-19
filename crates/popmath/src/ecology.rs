use crate::bounds::{PositiveF64, UnitInterval};
use crate::error::{PopmathError, PopmathResult};
use crate::units::{
    DurationSeconds, EmissionsKgCo2e, EnergyKwh, FlowRateM3PerSecond, MassKg, PowerKw,
};

/// A named contaminant or ecological measurement target.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Contaminant {
    name: String,
}

impl Contaminant {
    /// Creates a contaminant identifier.
    pub fn new(name: impl Into<String>) -> PopmathResult<Self> {
        let name = name.into();
        if name.trim().is_empty() {
            return Err(PopmathError::InvalidScenario {
                field: "contaminant_name",
            });
        }

        Ok(Self { name })
    }

    /// Returns the contaminant name.
    #[must_use]
    pub fn name(&self) -> &str {
        &self.name
    }
}

/// A concentration expressed in kilograms per cubic meter.
#[derive(Clone, Copy, Debug, PartialEq, PartialOrd)]
pub struct ConcentrationKgPerM3(PositiveF64);

impl ConcentrationKgPerM3 {
    /// Creates a positive concentration.
    pub fn new(value: f64) -> PopmathResult<Self> {
        PositiveF64::new(value, "concentration_kg_per_m3").map(Self)
    }

    /// Returns concentration in kilograms per cubic meter.
    #[must_use]
    pub const fn get(self) -> f64 {
        self.0.get()
    }
}

/// Input for one discrete pollutant mass-balance interval.
#[derive(Clone, Debug, PartialEq)]
pub struct PollutantMassBalanceInput {
    /// Identity of the measured pollutant or constituent.
    pub contaminant: Contaminant,
    /// Inlet concentration.
    pub inlet_concentration: ConcentrationKgPerM3,
    /// Outlet concentration.
    pub outlet_concentration: ConcentrationKgPerM3,
    /// Volumetric flow through the system.
    pub flow_rate: FlowRateM3PerSecond,
    /// Explicit observation interval.
    pub duration: DurationSeconds,
}

/// Result of a discrete pollutant mass-balance calculation.
#[derive(Clone, Debug, PartialEq)]
pub struct PollutantMassBalanceResult {
    /// Identity preserved from the input.
    pub contaminant: Contaminant,
    /// Mass removed from the measured flow.
    pub removed_mass: MassKg,
    /// Mass entering during the interval.
    pub inlet_mass: MassKg,
    /// Mass leaving during the interval.
    pub outlet_mass: MassKg,
    /// Whether the output concentration exceeded the input concentration.
    pub net_release_detected: bool,
}

/// Calculates pollutant mass balance for a constant flow and concentration interval.
pub fn calculate_pollutant_mass_balance(
    input: PollutantMassBalanceInput,
) -> PopmathResult<PollutantMassBalanceResult> {
    let volume_m3 = input.flow_rate.get() * input.duration.get();
    let inlet_mass_kg = input.inlet_concentration.get() * volume_m3;
    let outlet_mass_kg = input.outlet_concentration.get() * volume_m3;
    let signed_removed_mass_kg = inlet_mass_kg - outlet_mass_kg;

    Ok(PollutantMassBalanceResult {
        contaminant: input.contaminant,
        removed_mass: MassKg::new(signed_removed_mass_kg.max(0.0))?,
        inlet_mass: MassKg::new(inlet_mass_kg)?,
        outlet_mass: MassKg::new(outlet_mass_kg)?,
        net_release_detected: signed_removed_mass_kg < 0.0,
    })
}

/// Input for an attributable operational-emissions estimate.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct OperationalEmissionsInput {
    /// Electrical energy consumed during the stated interval.
    pub energy_consumed: EnergyKwh,
    /// Fraction of supply modeled as renewable.
    pub renewable_fraction: UnitInterval,
    /// Attributable grid emissions in kilograms carbon-dioxide-equivalent per kilowatt-hour.
    pub grid_emissions_kg_co2e_per_kwh: PositiveF64,
}

/// Result of an attributable operational-emissions estimate.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct OperationalEmissionsResult {
    /// Attributable grid-supplied energy.
    pub grid_supplied_energy: EnergyKwh,
    /// Attributable operational emissions.
    pub emissions: EmissionsKgCo2e,
}

/// Calculates attributable grid emissions from declared energy and supply fraction.
pub fn calculate_operational_emissions(
    input: OperationalEmissionsInput,
) -> PopmathResult<OperationalEmissionsResult> {
    let grid_fraction = 1.0 - input.renewable_fraction.get();
    let grid_supplied_energy_kwh = input.energy_consumed.get() * grid_fraction;
    let emissions_kg_co2e =
        grid_supplied_energy_kwh * input.grid_emissions_kg_co2e_per_kwh.get();

    Ok(OperationalEmissionsResult {
        grid_supplied_energy: EnergyKwh::new(grid_supplied_energy_kwh)?,
        emissions: EmissionsKgCo2e::new(emissions_kg_co2e)?,
    })
}

/// Input for a transparent KER-style ecological evidence calculation.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct EcoEvidenceInput {
    /// Confidence in the calculation and evidence chain.
    pub knowledge_factor: UnitInterval,
    /// Normalized verified ecological evidence.
    pub ecological_evidence: UnitInterval,
    /// Maximum applicable risk coordinate.
    pub combined_risk: UnitInterval,
}

/// Result of a transparent ecological evidence calculation.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct EcoEvidenceResult {
    /// Composite evidence score bounded from zero to one.
    pub eco_impact_value: UnitInterval,
}

/// Calculates \(E = K \cdot V \cdot (1 - R)\).
pub fn calculate_eco_evidence(input: EcoEvidenceInput) -> PopmathResult<EcoEvidenceResult> {
    let value = input.knowledge_factor.get()
        * input.ecological_evidence.get()
        * (1.0 - input.combined_risk.get());

    Ok(EcoEvidenceResult {
        eco_impact_value: UnitInterval::new(value, "eco_impact_value")?,
    })
}

/// Input for comparing hydraulic energy use with useful hydraulic power.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct HydraulicEfficiencyInput {
    /// Useful hydraulic output power.
    pub hydraulic_power: PowerKw,
    /// Electrical or mechanical input power.
    pub input_power: PowerKw,
}

/// Result of a hydraulic-efficiency calculation.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct HydraulicEfficiencyResult {
    /// Useful output divided by input power.
    pub coupling_efficiency: UnitInterval,
}

/// Calculates useful hydraulic power divided by input power.
pub fn calculate_hydraulic_efficiency(
    input: HydraulicEfficiencyInput,
) -> PopmathResult<HydraulicEfficiencyResult> {
    if input.input_power.get() == 0.0 {
        return Err(PopmathError::DivisionByZero {
            field: "input_power",
        });
    }

    let ratio = input.hydraulic_power.get() / input.input_power.get();
    Ok(HydraulicEfficiencyResult {
        coupling_efficiency: UnitInterval::new(ratio, "coupling_efficiency")?,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pollutant_mass_balance_preserves_contaminant_and_mass() {
        let result = calculate_pollutant_mass_balance(PollutantMassBalanceInput {
            contaminant: Contaminant::new("nitrate").expect("valid contaminant"),
            inlet_concentration: ConcentrationKgPerM3::new(0.010).expect("valid inlet"),
            outlet_concentration: ConcentrationKgPerM3::new(0.004).expect("valid outlet"),
            flow_rate: FlowRateM3PerSecond::new(2.0).expect("valid flow"),
            duration: DurationSeconds::new(60.0).expect("valid duration"),
        })
        .expect("valid mass balance");

        assert_eq!(result.contaminant.name(), "nitrate");
        assert!((result.removed_mass.get() - 0.72).abs() < 1e-12);
        assert!(!result.net_release_detected);
    }

    #[test]
    fn operational_emissions_respect_renewable_fraction() {
        let result = calculate_operational_emissions(OperationalEmissionsInput {
            energy_consumed: EnergyKwh::new(100.0).expect("valid energy"),
            renewable_fraction: UnitInterval::new(0.75, "renewable_fraction").expect("valid"),
            grid_emissions_kg_co2e_per_kwh: PositiveF64::new(
                0.4,
                "grid_emissions_kg_co2e_per_kwh",
            )
            .expect("valid factor"),
        })
        .expect("valid emissions calculation");

        assert_eq!(result.grid_supplied_energy.get(), 25.0);
        assert_eq!(result.emissions.get(), 10.0);
    }

    #[test]
    fn ecological_evidence_is_bounded() {
        let result = calculate_eco_evidence(EcoEvidenceInput {
            knowledge_factor: UnitInterval::new(0.9, "knowledge_factor").expect("valid"),
            ecological_evidence: UnitInterval::new(0.8, "ecological_evidence").expect("valid"),
            combined_risk: UnitInterval::new(0.25, "combined_risk").expect("valid"),
        })
        .expect("valid evidence result");

        assert_eq!(result.eco_impact_value.get(), 0.54);
    }
}
