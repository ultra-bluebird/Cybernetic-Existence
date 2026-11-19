// mk-bluebird/nanorobotics/crates/bci-teleop-filter/src/kani_harness.rs
#![cfg(kani)]
#![forbid(unsafe_code)]

use bci_teleop_filter::{
    BciControlSignal, BciTeleopFilter, BciTeleopFilterConfig, MotionScalingProfile,
};
use kani::any;
use nalgebra::Vector3;

#[kani::proof]
fn motion_scaling_monotone_in_roh() {
    let base_scale = 0.2_f32;
    let profile = MotionScalingProfile {
        base_scale,
        min_scale: 0.05,
        max_scale: 1.0,
        roh_tightening_start: 0.1,
        roh_tightening_end: 0.3,
    };

    let cfg = BciTeleopFilterConfig { motion_profile: profile };

    let roh_low = any::<f32>().max(0.0).min(0.25);
    let roh_high = (roh_low + 0.01).min(0.3);
    let cog_load = any::<f32>().max(0.0).min(1.0);

    let s_low = cfg
        .motion_profile
        .effective_scale(cog_load, roh_low);
    let s_high = cfg
        .motion_profile
        .effective_scale(cog_load, roh_high);

    assert!(s_high <= s_low + 1.0e-6);
}

#[kani::proof]
fn teleop_filter_does_not_amplify_velocity_norm() {
    let profile = MotionScalingProfile {
        base_scale: 0.2,
        min_scale: 0.05,
        max_scale: 1.0,
        roh_tightening_start: 0.1,
        roh_tightening_end: 0.3,
    };
    let cfg = BciTeleopFilterConfig { motion_profile: profile };
    let mut filter = BciTeleopFilter::new(cfg);

    let raw_v = Vector3::new(any::<f32>(), any::<f32>(), any::<f32>());
    let roh = any::<f32>().max(0.0).min(0.3);
    let load = any::<f32>().max(0.0).min(1.0);

    let signal = BciControlSignal {
        intent_velocity: raw_v,
        cognitive_load: load,
        roh_scalar: roh,
    };

    let out = filter.process(signal);

    assert!(out.norm() <= raw_v.norm() + 1.0e-6);
}
