#![forbid(unsafe_code)]
#![feature(rust_2024_preview)]

use kani::any;

use crate::metrics::HazardMetrics;

/// Helper: construct arbitrary but finite metrics in [0, 1].
fn any_metrics() -> HazardMetrics {
    let total_load: f32 = any();
    let peak_concentration: f32 = any();
    let swarm_duty_fraction: f32 = any();
    let material_risk_proxy: f32 = any();
    let near_roh_events: f32 = any();

    fn clamp01(x: f32) -> f32 {
        if !x.is_finite() {
            0.0
        } else {
            x.clamp(0.0, 1.0)
        }
    }

    HazardMetrics {
        total_load: clamp01(total_load),
        peak_concentration: clamp01(peak_concentration),
        swarm_duty_fraction: clamp01(swarm_duty_fraction),
        material_risk_proxy: clamp01(material_risk_proxy),
        near_roh_events: clamp01(near_roh_events),
    }
}

/// Proof 1: materialrisk_contribution is bounded in [0, 1].
#[proof]
fn proof_materialrisk_contribution_bounded() {
    let m = any_metrics();
    let r = m.materialrisk_contribution();

    // Monotone-tightening requirement: risk contribution must be a valid normalized scalar.
    assert!(r.is_finite());
    assert!(r >= 0.0);
    assert!(r <= 1.0 + 1.0e-5);
}

/// Proof 2: materialrisk_contribution is monotone in each metric.
///
/// For each axis, increasing that axis while holding others fixed
/// must not decrease the resulting contribution.
#[proof]
fn proof_materialrisk_contribution_monotone_axes() {
    let base = any_metrics();

    // For each axis, construct a variant with that axis >= base.
    // 1. total_load axis.
    let mut m1 = base.clone();
    let delta_total: f32 = any();
    let new_total = (base.total_load + delta_total.abs()).clamp(0.0, 1.0);
    m1.total_load = new_total;

    // 2. peak_concentration axis.
    let mut m2 = base.clone();
    let delta_peak: f32 = any();
    let new_peak = (base.peak_concentration + delta_peak.abs()).clamp(0.0, 1.0);
    m2.peak_concentration = new_peak;

    // 3. swarm_duty_fraction axis.
    let mut m3 = base.clone();
    let delta_duty: f32 = any();
    let new_duty = (base.swarm_duty_fraction + delta_duty.abs()).clamp(0.0, 1.0);
    m3.swarm_duty_fraction = new_duty;

    // 4. material_risk_proxy axis.
    let mut m4 = base.clone();
    let delta_mrisk: f32 = any();
    let new_mrisk = (base.material_risk_proxy + delta_mrisk.abs()).clamp(0.0, 1.0);
    m4.material_risk_proxy = new_mrisk;

    // 5. near_roh_events axis.
    let mut m5 = base.clone();
    let delta_roh_events: f32 = any();
    let new_roh_events = (base.near_roh_events + delta_roh_events.abs()).clamp(0.0, 1.0);
    m5.near_roh_events = new_roh_events;

    let r_base = base.materialrisk_contribution();
    let r1 = m1.materialrisk_contribution();
    let r2 = m2.materialrisk_contribution();
    let r3 = m3.materialrisk_contribution();
    let r4 = m4.materialrisk_contribution();
    let r5 = m5.materialrisk_contribution();

    // Conservative monotonicity: increasing any axis cannot lower the contribution.
    assert!(r1 + 1.0e-5 >= r_base);
    assert!(r2 + 1.0e-5 >= r_base);
    assert!(r3 + 1.0e-5 >= r_base);
    assert!(r4 + 1.0e-5 >= r_base);
    assert!(r5 + 1.0e-5 >= r_base);
}
