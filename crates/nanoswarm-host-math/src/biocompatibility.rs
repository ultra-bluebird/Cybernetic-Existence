// mk-bluebird/nanorobotics/crates/nanoswarm-host-math/src/biocompatibility.rs

#![forbid(unsafe_code)]
#![deny(warnings)]

use serde::{Deserialize, Serialize};

/// Biocompatibility parameters used for nanoswarm simulations.
///
/// All values must be interpreted in SI units.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BiocompatibilityProfile {
    pub region: BiocompatRegion,
    pub hydro_radius_m_raw: f64,
    pub surface_charge_mV_raw: f64,
    pub coating_thickness_m_raw: f64,
    pub max_density_particles_per_mm3_raw: f64,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum BiocompatRegion {
    CnsCortex,
    RenalMicrovasc,
    CardiacMyocardium,
}

/// Evidence-backed corridor for a given region.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub struct BiocompatCorridor {
    pub hydro_radius_m_min: f64,
    pub hydro_radius_m_max: f64,
    pub surface_charge_mV_min: f64,
    pub surface_charge_mV_max: f64,
    pub coating_thickness_m_min: f64,
    pub coating_thickness_m_max: f64,
    pub max_density_particles_per_mm3_min: f64,
    pub max_density_particles_per_mm3_max: f64,
    /// Padding factor applied to risk-raising parameters.
    pub padding_risk_raising: f64,
    /// Padding factor applied to risk-lowering parameters.
    pub padding_risk_lowering: f64,
}

impl BiocompatCorridor {
    pub fn for_region(region: BiocompatRegion) -> Self {
        match region {
            BiocompatRegion::CnsCortex => Self {
                hydro_radius_m_min: 1e-9,
                hydro_radius_m_max: 1e-8,
                surface_charge_mV_min: -20.0,
                surface_charge_mV_max: 5.0,
                coating_thickness_m_min: 5e-9,
                coating_thickness_m_max: 5e-8,
                max_density_particles_per_mm3_min: 1e3,
                max_density_particles_per_mm3_max: 1e5,
                padding_risk_raising: 1.10,
                padding_risk_lowering: 1.00,
            },
            BiocompatRegion::RenalMicrovasc => Self {
                hydro_radius_m_min: 5e-10,
                hydro_radius_m_max: 5e-9,
                surface_charge_mV_min: -15.0,
                surface_charge_mV_max: 10.0,
                coating_thickness_m_min: 2e-9,
                coating_thickness_m_max: 3e-8,
                max_density_particles_per_mm3_min: 1e2,
                max_density_particles_per_mm3_max: 5e4,
                padding_risk_raising: 1.15,
                padding_risk_lowering: 1.00,
            },
            BiocompatRegion::CardiacMyocardium => Self {
                hydro_radius_m_min: 8e-10,
                hydro_radius_m_max: 8e-9,
                surface_charge_mV_min: -25.0,
                surface_charge_mV_max: 5.0,
                coating_thickness_m_min: 3e-9,
                coating_thickness_m_max: 4e-8,
                max_density_particles_per_mm3_min: 5e2,
                max_density_particles_per_mm3_max: 8e4,
                padding_risk_raising: 1.12,
                padding_risk_lowering: 1.00,
            },
        }
    }
}

/// Effective, padded parameters that must be used for simulation.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub struct BiocompatEffective {
    pub hydro_radius_m: f64,
    pub surface_charge_mV: f64,
    pub coating_thickness_m: f64,
    pub max_density_particles_per_mm3: f64,
}

#[derive(Debug, thiserror::Error)]
pub enum BiocompatValidationError {
    #[error("parameter {name} = {value} is outside evidence-backed range [{min}, {max}]")]
    OutOfRange {
        name: &'static str,
        value: f64,
        min: f64,
        max: f64,
    },
    #[error("invalid padding factor {name} = {value}, must be >= 1.0")]
    InvalidPadding { name: &'static str, value: f64 },
}

impl BiocompatProfileExt for BiocompatibilityProfile {}

/// Extension trait providing validated, padded parameters.
pub trait BiocompatProfileExt {
    fn validate_and_pad(&self) -> Result<BiocompatEffective, BiocompatValidationError>;
}

impl BiocompatProfileExt for BiocompatibilityProfile {
    fn validate_and_pad(&self) -> Result<BiocompatEffective, BiocompatValidationError> {
        let corridor = BiocompatCorridor::for_region(self.region);

        if corridor.padding_risk_raising < 1.0 {
            return Err(BiocompatValidationError::InvalidPadding {
                name: "padding_risk_raising",
                value: corridor.padding_risk_raising,
            });
        }
        if corridor.padding_risk_lowering < 1.0 {
            return Err(BiocompatValidationError::InvalidPadding {
                name: "padding_risk_lowering",
                value: corridor.padding_risk_lowering,
            });
        }

        // Risk-raising parameters: hydro radius, density.
        let hydro_radius_m = self.hydro_radius_m_raw * corridor.padding_risk_raising;
        let max_density_particles_per_mm3 =
            self.max_density_particles_per_mm3_raw * corridor.padding_risk_raising;

        // Risk-lowering parameters: surface charge closer to zero is risk-raising;
        // we use the raw value and rely on range checks.
        let surface_charge_mV = self.surface_charge_mV_raw * corridor.padding_risk_lowering;
        let coating_thickness_m = self.coating_thickness_m_raw * corridor.padding_risk_raising;

        fn check_range(
            name: &'static str,
            value: f64,
            min: f64,
            max: f64,
        ) -> Result<(), BiocompatValidationError> {
            if value < min || value > max {
                return Err(BiocompatValidationError::OutOfRange {
                    name,
                    value,
                    min,
                    max,
                });
            }
            Ok(())
        }

        check_range(
            "hydro_radius_m",
            hydro_radius_m,
            corridor.hydro_radius_m_min,
            corridor.hydro_radius_m_max,
        )?;
        check_range(
            "surface_charge_mV",
            surface_charge_mV,
            corridor.surface_charge_mV_min,
            corridor.surface_charge_mV_max,
        )?;
        check_range(
            "coating_thickness_m",
            coating_thickness_m,
            corridor.coating_thickness_m_min,
            corridor.coating_thickness_m_max,
        )?;
        check_range(
            "max_density_particles_per_mm3",
            max_density_particles_per_mm3,
            corridor.max_density_particles_per_mm3_min,
            corridor.max_density_particles_per_mm3_max,
        )?;

        Ok(BiocompatEffective {
            hydro_radius_m,
            surface_charge_mV,
            coating_thickness_m,
            max_density_particles_per_mm3,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn cns_profile_in_range_validates() {
        let profile = BiocompatibilityProfile {
            region: BiocompatRegion::CnsCortex,
            hydro_radius_m_raw: 5e-9,
            surface_charge_mV_raw: -10.0,
            coating_thickness_m_raw: 2e-8,
            max_density_particles_per_mm3_raw: 5e4,
        };

        let eff = profile.validate_and_pad().expect("valid CNS profile");
        assert!(eff.hydro_radius_m > 0.0);
    }

    #[test]
    fn out_of_range_is_rejected() {
        let profile = BiocompatibilityProfile {
            region: BiocompatRegion::RenalMicrovasc,
            hydro_radius_m_raw: 1e-6,
            surface_charge_mV_raw: 0.0,
            coating_thickness_m_raw: 1e-8,
            max_density_particles_per_mm3_raw: 1e3,
        };

        let res = profile.validate_and_pad();
        assert!(res.is_err());
    }
}
