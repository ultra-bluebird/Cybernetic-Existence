// mk-bluebird/nanorobotics/crates/vascular-corridor-guards/src/lib.rs
// edition: 2024, rust-version: 1.85

#![forbid(unsafe_code)]
#![cfg_attr(not(test), no_std)]

extern crate alloc;

use alloc::vec::Vec;

pub use capillary_density_guard::{
    CapillaryDensityGuardConfig,
    CapillaryDensityGuardInputs,
    CapillaryDensityVerdict,
    NanoPosition3,
};
pub use hematocrit_swarm_fraction::{
    CapillaryGeometry,
    BloodProperties,
    SwarmProperties,
    CapillaryDensityCorridorConfig,
};
pub use nanorobotics_fp::{
    CapillaryFpParams,
    DensityProfile1D,
    DensityRiskLocal,
};

mod cerebral_arterial_loader;

use cerebral_arterial_loader::{
    load_cerebral_arterial_corridor_calibration,
    build_cerebral_capillary_corridor,
};

/// Vascular corridor identifier.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum VascularCorridorKind {
    CerebralArterialCapillary,
}

/// Wrapper for a specific corridor instance.
#[derive(Clone, Debug)]
pub struct CerebralCapillaryCorridor {
    pub kind: VascularCorridorKind,
    pub guard_config: CapillaryDensityGuardConfig,
}

impl CerebralCapillaryCorridor {
    pub fn new(
        corridor_cfg: CapillaryDensityCorridorConfig,
        fp_params: CapillaryFpParams,
        clog_soft_threshold: f32,
        clog_hard_threshold: f32,
        roh_weight_density: f32,
        roh_weight_clogging: f32,
        roh_slice_max: f32,
    ) -> Self {
        let guard_config = CapillaryDensityGuardConfig {
            corridor_config: corridor_cfg,
            fp_params,
            clog_soft_threshold,
            clog_hard_threshold,
            roh_weight_density,
            roh_weight_clogging,
            roh_slice_max,
        };

        Self {
            kind: VascularCorridorKind::CerebralArterialCapillary,
            guard_config,
        }
    }

    pub fn evaluate(
        &self,
        geometry: CapillaryGeometry,
        blood: BloodProperties,
        swarm: SwarmProperties,
        initial_profile: DensityProfile1D,
        nano_positions: Vec<NanoPosition3>,
        scale_r0_m: f32,
    ) -> (CapillaryDensityVerdict, f32) {
        let inputs = CapillaryDensityGuardInputs {
            geometry,
            blood,
            swarm,
            initial_profile,
            nano_positions,
        };

        capillary_density_guard::evaluate_capillary_density_guard(
            self.guard_config,
            inputs,
            scale_r0_m,
        )
    }
}

/// Stateless helper to evaluate a cerebral corridor in one call.
pub fn evaluate_cerebral_capillary_corridor(
    corridor_cfg: CapillaryDensityCorridorConfig,
    fp_params: CapillaryFpParams,
    clog_soft_threshold: f32,
    clog_hard_threshold: f32,
    roh_weight_density: f32,
    roh_weight_clogging: f32,
    roh_slice_max: f32,
    geometry: CapillaryGeometry,
    blood: BloodProperties,
    swarm: SwarmProperties,
    initial_profile: DensityProfile1D,
    nano_positions: Vec<NanoPosition3>,
    scale_r0_m: f32,
) -> (CapillaryDensityVerdict, f32) {
    let corridor = CerebralCapillaryCorridor::new(
        corridor_cfg,
        fp_params,
        clog_soft_threshold,
        clog_hard_threshold,
        roh_weight_density,
        roh_weight_clogging,
        roh_slice_max,
    );

    corridor.evaluate(
        geometry,
        blood,
        swarm,
        initial_profile,
        nano_positions,
        scale_r0_m,
    )
}

/// High-level async API: load corridor config from an ALN shard and evaluate.
pub async fn evaluate_cerebral_capillary_corridor_from_aln(
    aln_path: &str,
    geometry: CapillaryGeometry,
    blood: BloodProperties,
    swarm: SwarmProperties,
    initial_profile: DensityProfile1D,
    nano_positions: Vec<NanoPosition3>,
    scale_r0_m: f32,
) -> Result<(CapillaryDensityVerdict, f32), cybercore_aln_loader::AlnError> {
    let calib =
        load_cerebral_arterial_corridor_calibration(aln_path).await?;
    let corridor = build_cerebral_capillary_corridor(calib);

    Ok(corridor.evaluate(
        geometry,
        blood,
        swarm,
        initial_profile,
        nano_positions,
        scale_r0_m,
    ))
}

#[cfg(kani)]
mod kani_harnesses {
    use super::*;
    use kani::proof;

    #[proof]
    fn cerebral_corridor_roh_bounded() {
        let corridor_cfg = CapillaryDensityCorridorConfig {
            phi_tot_maxsafe: 0.45,
            rho_ceiling_per_m3: 1.0e12,
            max_exceed_fraction: 0.10,
        };

        let fp_params = CapillaryFpParams {
            dx_m: 1.0e-5,
            dt_s: 0.01,
            diffusion_m2_per_s: 1.0e-10,
            velocity_m_per_s: 0.01,
            max_horizon_s: 1.0,
        };

        let roh_slice_max: f32 = 0.30;
        let clog_soft_threshold: f32 = 2.5;
        let clog_hard_threshold: f32 = 5.0;
        let roh_weight_density: f32 = 0.15;
        let roh_weight_clogging: f32 = 0.15;

        let corridor = CerebralCapillaryCorridor::new(
            corridor_cfg,
            fp_params,
            clog_soft_threshold,
            clog_hard_threshold,
            roh_weight_density,
            roh_weight_clogging,
            roh_slice_max,
        );

        let geometry = CapillaryGeometry {
            radius_um: 5.0,
            length_um: 1000.0,
        };
        let blood = BloodProperties {
            plasma_viscosity_pas: 0.003,
            systemic_hematocrit: 0.40,
        };
        let swarm = SwarmProperties {
            particle_diameter_nm: 100.0,
            number_density_per_m3: 1.0e11,
        };

        let initial_profile = DensityProfile1D {
            rho: vec![1.0e11; 8],
            dx_m: fp_params.dx_m,
        };

        let nano_positions = vec![
            NanoPosition3 {
                x_m: 0.0,
                y_m: 0.0,
                z_m: 0.0,
            };
            8
        ];

        let (_verdict, roh_local) = corridor.evaluate(
            geometry,
            blood,
            swarm,
            initial_profile,
            nano_positions,
            2.5e-6,
        );

        assert!(roh_local >= 0.0 && roh_local <= roh_slice_max + f32::EPSILON);
    }
}
