// nanorobotics/crates/hematocrit-swarm-fraction/src/lib.rs
// edition: 2024, rust-version: 1.85

#![forbid(unsafe_code)]
#![cfg_attr(not(test), no_std)]

extern crate alloc;
use alloc::string::String;
use alloc::vec::Vec;

/// Host authority constants (bound to ALN and Organichain).[file:25][file:23]
pub const HOST_DID: &str = "did.aln.organic-host";
pub const BOSTROM_ADDRESS: &str =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

/// Capillary geometry (cerebral microvessels).[file:27]
#[derive(Clone, Copy, Debug)]
pub struct CapillaryGeometry {
    /// Radius in micrometers.
    pub radius_um: f32,
    /// Length in micrometers.
    pub length_um: f32,
}

/// Blood properties relevant for hematocrit and viscosity.[file:27]
#[derive(Clone, Copy, Debug)]
pub struct BloodProperties {
    /// Plasma viscosity in Pa·s.
    pub plasma_viscosity_pas: f32,
    /// Systemic hematocrit (fraction in [0,1]).
    pub systemic_hematocrit: f32,
}

/// Swarm properties (effective sphere approximation).[file:27]
#[derive(Clone, Copy, Debug)]
pub struct SwarmProperties {
    /// Effective particle diameter in nanometers.
    pub particle_diameter_nm: f32,
    /// Number density per m^3.
    pub number_density_per_m3: f32,
}

/// Volume fractions: RBC, swarm, total φ_tot.[file:27]
#[derive(Clone, Copy, Debug)]
pub struct VolumeFractions {
    pub phi_rbc: f32,
    pub phi_swarm: f32,
    pub phi_tot: f32,
}

/// Corridor parameters (subset of ALN fields).[file:27]
#[derive(Clone, Copy, Debug)]
pub struct CapillaryDensityCorridorConfig {
    pub phi_tot_maxsafe: f32,
    pub rho_ceiling_per_m3: f32,
    pub max_exceed_fraction: f32,
}

impl CapillaryDensityCorridorConfig {
    pub fn is_valid(&self) -> bool {
        self.phi_tot_maxsafe > 0.0
            && self.phi_tot_maxsafe < 1.0
            && self.rho_ceiling_per_m3 > 0.0
            && self.max_exceed_fraction >= 0.0
            && self.max_exceed_fraction <= 1.0
    }
}

/// Compute tube hematocrit as a function of systemic hematocrit and vessel radius.
/// This is a placeholder monotone mapping consistent with plasma skimming effect.
/// In practice, calibration comes from microvascular data and ALN evidence.[file:27]
pub fn tube_hematocrit(systemic_hct: f32, radius_um: f32) -> f32 {
    // Clamp systemic hematocrit.
    let h = systemic_hct.clamp(0.0, 1.0);
    // Simple radius-dependent adjustment: smaller vessels get slightly lower Hct.
    // h_tube = h * (1.0 - k / (radius_um + k)), with k > 0.
    let k: f32 = 4.0;
    let adj = 1.0 - k / (radius_um + k);
    (h * adj).clamp(0.0, 1.0)
}

/// Compute RBC, swarm, and total volume fractions.[file:27]
pub fn compute_volume_fractions(
    geom: CapillaryGeometry,
    blood: BloodProperties,
    swarm: SwarmProperties,
) -> VolumeFractions {
    let h_tube = tube_hematocrit(blood.systemic_hematocrit, geom.radius_um);

    // Capillary cross-section area in m^2.
    let radius_m = geom.radius_um * 1.0e-6;
    let area_m2 = core::f32::consts::PI * radius_m * radius_m;

    // Effective swarm volume per particle (sphere).
    let d_m = swarm.particle_diameter_nm * 1.0e-9;
    let r_particle = 0.5 * d_m;
    let v_particle = (4.0 / 3.0) * core::f32::consts::PI * r_particle.powi(3);

    // Swarm volume fraction φ_swarm = N * v_particle / unit volume.
    let phi_swarm = (swarm.number_density_per_m3 * v_particle)
        .clamp(0.0, 1.0);

    // RBC volume fraction = tube hematocrit.
    let phi_rbc = h_tube;

    let phi_tot = (phi_rbc + phi_swarm).clamp(0.0, 1.0);

    VolumeFractions {
        phi_rbc,
        phi_swarm,
        phi_tot,
    }
}

/// Effective viscosity model placeholder based on Fahraeus–Lindqvist effect.
/// In practice, parameters must be fitted to cerebral microvascular data.[file:27]
pub fn effective_viscosity_pas(
    geom: CapillaryGeometry,
    blood: BloodProperties,
    vf: VolumeFractions,
) -> f32 {
    let r_m = geom.radius_um * 1.0e-6;
    let h = vf.phi_rbc;

    // Simple phenomenological form: μ_eff = μ_plasma * (1 + a*h + b*h^2) * f(radius).
    let a: f32 = 2.0;
    let b: f32 = 1.0;
    let radius_factor = (1.0 + 0.5 / (r_m + 1.0e-6)).clamp(1.0, 3.0);

    let mu_eff =
        blood.plasma_viscosity_pas * (1.0 + a * h + b * h * h) * radius_factor;

    mu_eff
}

#[cfg(kani)]
mod kani_harnesses {
    use super::*;
    use kani::proof;

    #[proof]
    fn volume_fractions_are_bounded() {
        let radius_um: f32 = kani::any();
        let length_um: f32 = kani::any();
        let systemic_hct: f32 = kani::any();
        let plasma_mu: f32 = kani::any();
        let particle_diameter_nm: f32 = kani::any();
        let number_density_per_m3: f32 = kani::any();

        kani::assume(radius_um > 1.0 && radius_um < 20.0);
        kani::assume(length_um > 100.0 && length_um < 5_000.0);
        kani::assume(systemic_hct > 0.2 && systemic_hct < 0.6);
        kani::assume(plasma_mu > 0.001 && plasma_mu < 0.01);
        kani::assume(particle_diameter_nm > 10.0 && particle_diameter_nm < 500.0);
        kani::assume(number_density_per_m3 >= 0.0 && number_density_per_m3 < 1.0e15);

        let geom = CapillaryGeometry {
            radius_um,
            length_um,
        };
        let blood = BloodProperties {
            plasma_viscosity_pas: plasma_mu,
            systemic_hematocrit: systemic_hct,
        };
        let swarm = SwarmProperties {
            particle_diameter_nm,
            number_density_per_m3,
        };

        let vf = compute_volume_fractions(geom, blood, swarm);

        assert!(vf.phi_rbc >= 0.0 && vf.phi_rbc <= 1.0);
        assert!(vf.phi_swarm >= 0.0 && vf.phi_swarm <= 1.0);
        assert!(vf.phi_tot >= 0.0 && vf.phi_tot <= 1.0);
    }
}
