// nanorobotics/crates/capillary-density-guard/src/lib.rs
// edition: 2024, rust-version: 1.85

#![forbid(unsafe_code)]
#![cfg_attr(not(test), no_std)]

extern crate alloc;
use alloc::vec::Vec;

use hematocrit_swarm_fraction::{
    CapillaryGeometry, BloodProperties, SwarmProperties, VolumeFractions,
    CapillaryDensityCorridorConfig, compute_volume_fractions,
};
use nanorobotics_fp::{
    CapillaryFpParams, DensityProfile1D, DensityRiskLocal,
    step_capillary_fp, capillary_density_risk,
};

/// Nano-position representation for TDA/clogging proxy (3D positions in m).[file:27]
#[derive(Clone, Copy, Debug)]
pub struct NanoPosition3 {
    pub x_m: f32,
    pub y_m: f32,
    pub z_m: f32,
}

/// Config for the guard, typically loaded from ALN corridor shard.[file:27]
#[derive(Clone, Copy, Debug)]
pub struct CapillaryDensityGuardConfig {
    pub corridor_config: CapillaryDensityCorridorConfig,
    pub fp_params: CapillaryFpParams,
    pub clog_soft_threshold: f32,
    pub clog_hard_threshold: f32,
    pub roh_weight_density: f32,
    pub roh_weight_clogging: f32,
    pub roh_slice_max: f32, // ≤ 0.30
}

/// Guard inputs summarizing the current state.[file:27]
#[derive(Clone, Debug)]
pub struct CapillaryDensityGuardInputs {
    pub geometry: CapillaryGeometry,
    pub blood: BloodProperties,
    pub swarm: SwarmProperties,
    pub initial_profile: DensityProfile1D,
    pub nano_positions: Vec<NanoPosition3>,
}

/// Verdicts: Allow, Clamp (shrink swarm density/duty), Deny.[file:27]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CapillaryDensityVerdict {
    Allow,
    ClampAndRetry,
    Deny,
}

/// Simple clogging score proxy based on local density and connectivity.[file:27]
pub fn compute_clogging_score(
    positions: &[NanoPosition3],
    scale_r0_m: f32,
) -> f32 {
    // Very conservative proxy: high score if many positions within r0 of each other.
    let n = positions.len();
    if n == 0 {
        return 0.0;
    }

    let mut cluster_counts = 0_u32;

    for i in 0..n {
        let mut local_neighbors = 0_u32;
        let p_i = positions[i];
        for j in 0..n {
            if i == j {
                continue;
            }
            let p_j = positions[j];
            let dx = p_i.x_m - p_j.x_m;
            let dy = p_i.y_m - p_j.y_m;
            let dz = p_i.z_m - p_j.z_m;
            let dist2 = dx * dx + dy * dy + dz * dz;
            if dist2 <= scale_r0_m * scale_r0_m {
                local_neighbors += 1;
            }
        }
        if local_neighbors > 0 {
            cluster_counts += 1;
        }
    }

    let density_factor = n as f32;
    let connectivity_factor =
        (cluster_counts as f32 / n as f32).clamp(0.0, 1.0);

    density_factor * connectivity_factor
}

/// Evaluate guard and compute RoH contribution; pure function suitable for Kani.[file:27][file:25]
pub fn evaluate_capillary_density_guard(
    cfg: CapillaryDensityGuardConfig,
    inputs: CapillaryDensityGuardInputs,
    scale_r0_m: f32,
) -> (CapillaryDensityVerdict, f32) {
    assert!(cfg.corridor_config.is_valid());
    assert!(cfg.roh_slice_max <= 0.30);
    assert!(cfg.roh_slice_max > 0.0);

    // 1. Volume fractions and φ_tot corridor check.
    let vf: VolumeFractions = compute_volume_fractions(
        inputs.geometry,
        inputs.blood,
        inputs.swarm,
    );

    if vf.phi_tot > cfg.corridor_config.phi_tot_maxsafe {
        // Hard violation of total volume fraction corridor.
        return (CapillaryDensityVerdict::Deny, cfg.roh_slice_max);
    }

    // 2. FP evolution and density risk.
    let mut profile = inputs.initial_profile.clone();
    let mut t: f32 = 0.0;

    // Simple loop up to max_horizon_s (clamped by FP params).
    while t < cfg.fp_params.max_horizon_s {
        profile = step_capillary_fp(cfg.fp_params, &profile);
        t += cfg.fp_params.dt_s;
    }

    let density_risk: DensityRiskLocal =
        capillary_density_risk(&profile, cfg.corridor_config.rho_ceiling_per_m3);

    // 3. Clogging score via proxy.
    let clog_score =
        compute_clogging_score(&inputs.nano_positions, scale_r0_m);

    // 4. Map to RoH density + clog components.
    let roh_density = cfg.roh_weight_density
        * (density_risk.rho_max / cfg.corridor_config.rho_ceiling_per_m3)
            .clamp(0.0, 1.0);

    let roh_clogging = cfg.roh_weight_clogging
        * (clog_score / cfg.clog_hard_threshold).clamp(0.0, 1.0);

    let roh_local = (roh_density + roh_clogging).clamp(0.0, cfg.roh_slice_max);

    // 5. Verdict logic: monotone in risk metrics.[file:27]
    if density_risk.exceed_fraction
        > cfg.corridor_config.max_exceed_fraction
        || clog_score >= cfg.clog_hard_threshold
    {
        // Hard limits violated.
        (CapillaryDensityVerdict::Deny, roh_local)
    } else if vf.phi_tot >= 0.9 * cfg.corridor_config.phi_tot_maxsafe
        || density_risk.exceed_fraction
            >= 0.7 * cfg.corridor_config.max_exceed_fraction
        || clog_score >= cfg.clog_soft_threshold
    {
        // Near limits: clamp and retry with lower swarm density/duty.
        (CapillaryDensityVerdict::ClampAndRetry, roh_local)
    } else {
        // Safe: Allow.
        (CapillaryDensityVerdict::Allow, roh_local)
    }
}

#[cfg(kani)]
mod kani_harnesses {
    use super::*;
    use kani::proof;

    #[proof]
    fn monotone_risk_never_relaxes_verdict() {
        // For simplicity, test that increasing rho_max or clog_score
        // cannot change a stricter verdict (Deny) into a more lenient (Allow).
        let cfg = CapillaryDensityGuardConfig {
            corridor_config: CapillaryDensityCorridorConfig {
                phi_tot_maxsafe: 0.45,
                rho_ceiling_per_m3: 1.0e12,
                max_exceed_fraction: 0.10,
            },
            fp_params: CapillaryFpParams {
                dx_m: 1.0e-5,
                dt_s: 0.01,
                diffusion_m2_per_s: 1.0e-10,
                velocity_m_per_s: 0.01,
                max_horizon_s: 1.0,
            },
            clog_soft_threshold: 2.5,
            clog_hard_threshold: 5.0,
            roh_weight_density: 0.15,
            roh_weight_clogging: 0.15,
            roh_slice_max: 0.30,
        };

        // Base inputs with low risk.
        let geom = CapillaryGeometry {
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
        let initial_rho = vec![1.0e11; 8];
        let profile = DensityProfile1D {
            rho: initial_rho,
            dx_m: cfg.fp_params.dx_m,
        };
        let positions = vec![
            NanoPosition3 {
                x_m: 0.0,
                y_m: 0.0,
                z_m: 0.0,
            };
            8
        ];

        let base_inputs = CapillaryDensityGuardInputs {
            geometry: geom,
            blood,
            swarm,
            initial_profile: profile,
            nano_positions: positions.clone(),
        };

        let (verdict_base, roh_base) =
            evaluate_capillary_density_guard(cfg, base_inputs, 2.5e-6);

        // Construct a "worse" scenario: higher swarm density and closer positions.
        let swarm_worse = SwarmProperties {
            particle_diameter_nm: 100.0,
            number_density_per_m3: 1.0e13, // higher density
        };
        let worse_rho = vec![1.0e13; 8];
        let profile_worse = DensityProfile1D {
            rho: worse_rho,
            dx_m: cfg.fp_params.dx_m,
        };
        let mut positions_worse = positions.clone();
        // Pack positions closer to increase clogging score.
        for p in &mut positions_worse {
            p.x_m *= 0.1;
            p.y_m *= 0.1;
            p.z_m *= 0.1;
        }

        let worse_inputs = CapillaryDensityGuardInputs {
            geometry: geom,
            blood,
            swarm: swarm_worse,
            initial_profile: profile_worse,
            nano_positions: positions_worse,
        };

        let (verdict_worse, roh_worse) =
            evaluate_capillary_density_guard(cfg, worse_inputs, 2.5e-6);

        // If base scenario is Deny, worse must be Deny as well.
        if verdict_base == CapillaryDensityVerdict::Deny {
            assert_eq!(verdict_worse, CapillaryDensityVerdict::Deny);
        }

        // RoH should not decrease in worse scenario.
        assert!(roh_worse >= roh_base - f32::EPSILON);
    }
}
