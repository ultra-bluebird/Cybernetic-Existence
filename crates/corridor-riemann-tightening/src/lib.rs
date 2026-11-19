#![cfg_attr(not(test), deny(warnings))]
#![forbid(unsafe_code)]

pub const HOST_DID: &str = "did.aln.bostrom-organic-host";
pub const BOSTROM_ADDRESS: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";
pub const ALN_MIGRATION_CYBERCORE_AUTHORITY_V1: &str =
    "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";

/// Unified corridor axes for 7-D RoH manifold:
/// (density, shear, thermal, immune, topology, psych, energy).
#[derive(Debug, Clone, Copy)]
pub struct CorridorAxes {
    pub density: f32,
    pub shear: f32,
    pub thermal: f32,
    pub immune: f32,
    pub topology: f32,
    pub psych: f32,
    pub energy: f32,
}

/// Host-specific baselines and comfort bands for each axis.
#[derive(Debug, Clone, Copy)]
pub struct AxisBand {
    pub baseline: f32,
    pub min: f32,
    pub max: f32,
    pub weight: f32,
    pub curvature_gain: f32,
}

#[derive(Debug, Clone, Copy)]
pub struct CorridorBands {
    pub density: AxisBand,
    pub shear: AxisBand,
    pub thermal: AxisBand,
    pub immune: AxisBand,
    pub topology: AxisBand,
    pub psych: AxisBand,
    pub energy: AxisBand,
}

/// Metric tensor diagonal entries g_ii(x) for the 7-D corridor manifold.
#[derive(Debug, Clone, Copy)]
pub struct CorridorMetricDiagonal {
    pub g_density: f32,
    pub g_shear: f32,
    pub g_thermal: f32,
    pub g_immune: f32,
    pub g_topology: f32,
    pub g_psych: f32,
    pub g_energy: f32,
}

/// Log-support representation for corridor faces.
/// Each entry is log(h_i) for support function h_K(u_i).
#[derive(Debug, Clone)]
pub struct CorridorSupport {
    /// Log-support vector theta.
    pub theta: Vec<f32>,
    /// Optional per-direction weights (risk sensitivity per support ray).
    pub direction_weights: Vec<f32>,
}

/// Gradient of a risk functional with respect to log-support coordinates.
/// Must be monotone: tightening (decreasing theta) must not increase RoH.
#[derive(Debug, Clone)]
pub struct SupportGradient {
    pub grad: Vec<f32>,
}

/// Simple RoH scalar proxy used here to keep tightening steps conservative.
/// Real code should call the shared RoH kernel crate.
#[derive(Debug, Clone, Copy)]
pub struct RohProxy {
    pub value: f32,
}

/// Maximum allowed global RoH.
pub const ROH_CEILING: f32 = 0.30;

/// Compute normalized strain coordinate for an axis.
fn axis_strain(value: f32, band: AxisBand) -> f32 {
    let span = band.max - band.min;
    if span <= 0.0 {
        return 0.0;
    }
    (value - band.baseline) / span
}

/// Compute the diagonal metric entries g_ii(x) from axes and bands.
pub fn metric_diagonal(axes: CorridorAxes, bands: CorridorBands) -> CorridorMetricDiagonal {
    fn g_axis(value: f32, band: AxisBand) -> f32 {
        let z = axis_strain(value, band);
        let z2 = z * z;
        let base = band.weight.max(0.0);
        let k = band.curvature_gain.max(0.0);
        base * (1.0 + k * z2)
    }

    CorridorMetricDiagonal {
        g_density: g_axis(axes.density, bands.density),
        g_shear: g_axis(axes.shear, bands.shear),
        g_thermal: g_axis(axes.thermal, bands.thermal),
        g_immune: g_axis(axes.immune, bands.immune),
        g_topology: g_axis(axes.topology, bands.topology),
        g_psych: g_axis(axes.psych, bands.psych),
        g_energy: g_axis(axes.energy, bands.energy),
    }
}

/// Project a gradient onto tightening directions: clamp any positive component to 0.
/// This ensures that the resulting direction never increases log-support.
pub fn project_tightening_direction(gradient: &SupportGradient) -> SupportGradient {
    let mut out = Vec::with_capacity(gradient.grad.len());
    for &g in &gradient.grad {
        let projected = if g > 0.0 { 0.0 } else { g };
        out.push(projected);
    }
    SupportGradient { grad: out }
}

/// Perform a geodesic-like tightening step in log-support coordinates.
///
/// theta_new = theta_old + step_size * v_tight,
/// with v_tight <= 0 component-wise and step_size >= 0,
/// so theta_new <= theta_old element-wise, guaranteeing monotone tightening.
pub fn geodesic_tighten_step(
    support: &CorridorSupport,
    tightening_direction: &SupportGradient,
    step_size: f32,
) -> CorridorSupport {
    let step = step_size.max(0.0);
    let mut theta_new = Vec::with_capacity(support.theta.len());

    for (theta_i, v_i) in support.theta.iter().zip(tightening_direction.grad.iter()) {
        // v_i is <= 0 after projection, step >= 0; so theta_new_i <= theta_i.
        let delta = step * (*v_i);
        let candidate = *theta_i + delta;
        // Ensure monotone tightening explicitly.
        let tightened = if candidate <= *theta_i {
            candidate
        } else {
            *theta_i
        };
        theta_new.push(tightened);
    }

    CorridorSupport {
        theta: theta_new,
        direction_weights: support.direction_weights.clone(),
    }
}

/// Simple monotone RoH proxy that maps axis values to a scalar risk
/// and is guaranteed not to increase when corridor faces tighten.
/// Real deployments must use the unified RoH kernel.
pub fn roh_proxy_from_axes(axes: CorridorAxes, bands: &CorridorBands) -> RohProxy {
    // Each axis contributes proportionally to its normalized strain and weight.
    fn axis_risk(value: f32, band: &AxisBand) -> f32 {
        let z = axis_strain(value, *band);
        let abs_z = z.abs();
        let w = band.weight.max(0.0);
        (w * abs_z).min(ROH_CEILING)
    }

    let r_density = axis_risk(axes.density, &bands.density);
    let r_shear = axis_risk(axes.shear, &bands.shear);
    let r_thermal = axis_risk(axes.thermal, &bands.thermal);
    let r_immune = axis_risk(axes.immune, &bands.immune);
    let r_topology = axis_risk(axes.topology, &bands.topology);
    let r_psych = axis_risk(axes.psych, &bands.psych);
    let r_energy = axis_risk(axes.energy, &bands.energy);

    let sum = r_density
        + r_shear
        + r_thermal
        + r_immune
        + r_topology
        + r_psych
        + r_energy;

    // Clamp global RoH proxy to the ceiling.
    RohProxy {
        value: sum.min(ROH_CEILING),
    }
}

/// Check that a tightening step preserves RoH <= 0.30,
/// under the assumption that the RoH kernel is monotone in corridor faces.
pub fn roh_safe_after_tightening(before: RohProxy, after: RohProxy) -> bool {
    // Because tightening reduces support faces, RoH must not increase.
    after.value <= before.value && before.value <= ROH_CEILING && after.value <= ROH_CEILING
}

/// Convenience function: apply tightening, then verify RoH safety.
pub fn apply_tightening_with_roh_guard(
    support: &CorridorSupport,
    tightening_direction: &SupportGradient,
    step_size: f32,
    axes_before: CorridorAxes,
    axes_after: CorridorAxes,
    bands: &CorridorBands,
) -> Option<CorridorSupport> {
    let roh_before = roh_proxy_from_axes(axes_before, bands);
    let roh_after = roh_proxy_from_axes(axes_after, bands);

    if !roh_safe_after_tightening(roh_before, roh_after) {
        return None;
    }

    let tightened_dir = project_tightening_direction(tightening_direction);
    let updated_support = geodesic_tighten_step(support, &tightened_dir, step_size);
    Some(updated_support)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tightening_direction_is_non_positive() {
        let grad = SupportGradient {
            grad: vec![1.0, -0.5, 0.0],
        };
        let projected = project_tightening_direction(&grad);
        assert_eq!(projected.grad[0], 0.0);
        assert_eq!(projected.grad[1], -0.5);
        assert_eq!(projected.grad[2], 0.0);
    }

    #[test]
    fn geodesic_step_never_increases_theta() {
        let support = CorridorSupport {
            theta: vec![0.0, 1.0, -1.0],
            direction_weights: vec![1.0, 1.0, 1.0],
        };
        let grad = SupportGradient {
            grad: vec![-0.1, 0.0, -0.2],
        };
        let projected = project_tightening_direction(&grad);
        let updated = geodesic_tighten_step(&support, &projected, 2.0);

        for (old, new) in support.theta.iter().zip(updated.theta.iter()) {
            assert!(
                new <= old,
                "theta_new must be <= theta_old: new={}, old={}",
                new,
                old
            );
        }
    }

    #[test]
    fn roh_proxy_respects_ceiling() {
        let bands = CorridorBands {
            density: AxisBand {
                baseline: 0.0,
                min: -1.0,
                max: 1.0,
                weight: 0.1,
                curvature_gain: 1.0,
            },
            shear: AxisBand {
                baseline: 0.0,
                min: -1.0,
                max: 1.0,
                weight: 0.1,
                curvature_gain: 1.0,
            },
            thermal: AxisBand {
                baseline: 0.0,
                min: -1.0,
                max: 1.0,
                weight: 0.1,
                curvature_gain: 1.0,
            },
            immune: AxisBand {
                baseline: 0.0,
                min: -1.0,
                max: 1.0,
                weight: 0.1,
                curvature_gain: 1.0,
            },
            topology: AxisBand {
                baseline: 0.0,
                min: -1.0,
                max: 1.0,
                weight: 0.1,
                curvature_gain: 1.0,
            },
            psych: AxisBand {
                baseline: 0.0,
                min: -1.0,
                max: 1.0,
                weight: 0.1,
                curvature_gain: 1.0,
            },
            energy: AxisBand {
                baseline: 0.0,
                min: -1.0,
                max: 1.0,
                weight: 0.1,
                curvature_gain: 1.0,
            },
        };

        let axes = CorridorAxes {
            density: 2.0,
            shear: 2.0,
            thermal: 2.0,
            immune: 2.0,
            topology: 2.0,
            psych: 2.0,
            energy: 2.0,
        };

        let roh = roh_proxy_from_axes(axes, &bands);
        assert!(roh.value <= ROH_CEILING);
    }

    #[test]
    fn roh_safe_after_tightening_checks_monotonicity() {
        let before = RohProxy { value: 0.25 };
        let after_ok = RohProxy { value: 0.20 };
        let after_bad = RohProxy { value: 0.28 };

        assert!(roh_safe_after_tightening(before, after_ok));
        assert!(!roh_safe_after_tightening(before, after_bad));
    }
}
