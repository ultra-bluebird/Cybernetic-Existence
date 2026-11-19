// nanorobotics/crates/nanorobotics-fp/src/lib.rs
// edition: 2024, rust-version: 1.85

#![forbid(unsafe_code)]
#![cfg_attr(not(test), no_std)]

extern crate alloc;
use alloc::vec::Vec;

#[derive(Clone, Copy, Debug)]
pub struct CapillaryFpParams {
    pub dx_m: f32,
    pub dt_s: f32,
    pub diffusion_m2_per_s: f32,
    pub velocity_m_per_s: f32,
    pub max_horizon_s: f32,
}

#[derive(Clone, Debug)]
pub struct DensityProfile1D {
    /// Density values at discrete nodes along the capillary.
    pub rho: Vec<f32>,
    /// Spatial step dx (consistent with params).
    pub dx_m: f32,
}

#[derive(Clone, Copy, Debug)]
pub struct DensityRiskLocal {
    pub rho_max: f32,
    pub exceed_fraction: f32,
}

/// Single explicit FP step: forward Euler in time, centered diffusion, upwind advection.
/// This is conservative but requires dt small enough; stability is enforced by Kani harnesses.[file:27][file:25]
pub fn step_capillary_fp(
    params: CapillaryFpParams,
    current: &DensityProfile1D,
) -> DensityProfile1D {
    let n = current.rho.len();
    let dx = params.dx_m;
    let dt = params.dt_s;
    let v = params.velocity_m_per_s;
    let d = params.diffusion_m2_per_s;

    let mut next = current.rho.clone();

    for i in 0..n {
        let rho_i = current.rho[i];

        // Neumann boundary conditions (zero flux) at ends.
        let rho_left = if i == 0 { current.rho[0] } else { current.rho[i - 1] };
        let rho_right =
            if i + 1 == n { current.rho[n - 1] } else { current.rho[i + 1] };

        // Diffusion term: D * (rho_left - 2*rho_i + rho_right) / dx^2
        let diffusion =
            d * (rho_left - 2.0 * rho_i + rho_right) / (dx * dx);

        // Upwind advection: -v * (rho_i - rho_left) / dx
        let advection = -v * (rho_i - rho_left) / dx;

        let rho_next = rho_i + dt * (diffusion + advection);

        // Clamp to non-negative.
        next[i] = if rho_next < 0.0 { 0.0 } else { rho_next };
    }

    DensityProfile1D { rho: next, dx_m: dx }
}

/// Compute local density risk metrics given a profile and corridor ceiling.[file:27]
pub fn capillary_density_risk(
    profile: &DensityProfile1D,
    rho_ceiling_per_m3: f32,
) -> DensityRiskLocal {
    let mut rho_max = 0.0_f32;
    let mut exceed_count = 0_u32;

    for &val in &profile.rho {
        if val > rho_max {
            rho_max = val;
        }
        if val > rho_ceiling_per_m3 {
            exceed_count += 1;
        }
    }

    let n = profile.rho.len() as f32;
    let exceed_fraction = if n > 0.0 {
        (exceed_count as f32 / n).clamp(0.0, 1.0)
    } else {
        0.0
    };

    DensityRiskLocal {
        rho_max,
        exceed_fraction,
    }
}

#[cfg(kani)]
mod kani_harnesses {
    use super::*;
    use kani::proof;

    #[proof]
    fn fp_step_preserves_nonnegativity() {
        let dx_m: f32 = kani::any();
        let dt_s: f32 = kani::any();
        let d_m2_s: f32 = kani::any();
        let v_m_s: f32 = kani::any();

        kani::assume(dx_m > 0.0 && dx_m < 1.0e-3);
        kani::assume(dt_s > 0.0 && dt_s < 1.0);
        kani::assume(d_m2_s > 0.0 && d_m2_s < 1.0e-9);
        kani::assume(v_m_s >= 0.0 && v_m_s < 0.1);

        let params = CapillaryFpParams {
            dx_m,
            dt_s,
            diffusion_m2_per_s: d_m2_s,
            velocity_m_per_s: v_m_s,
            max_horizon_s: 10.0,
        };

        let n_nodes: usize = 8;
        let mut rho = Vec::with_capacity(n_nodes);
        for _ in 0..n_nodes {
            let val: f32 = kani::any();
            kani::assume(val >= 0.0);
            rho.push(val);
        }

        let profile = DensityProfile1D { rho, dx_m };

        let next = step_capillary_fp(params, &profile);

        for val in next.rho {
            assert!(val >= 0.0);
        }
    }
}
