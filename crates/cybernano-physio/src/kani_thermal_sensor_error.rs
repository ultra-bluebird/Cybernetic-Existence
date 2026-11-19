// destination: crates/cybernano-physio/src/kani_thermal_sensor_error.rs
#![forbid(unsafe_code)]

use kani::any;
use crate::thermal_sensor_error::{SensorErrorConfig, SensorKind};

#[kani::proof]
fn error_bound_monotone_in_r_and_q() {
    let cfg = SensorErrorConfig {
        sensor_kind: SensorKind::SkinThermistor,
        bias_min_c: -0.5,
        bias_max_c: 0.5,
        noise_bound_c: 0.3,
        gamma_radiant_c_per_unit: any(),
        gamma_aq_c_per_unit: any(),
        gamma_radiant_aq_c_per_unit: any(),
        r_min: 0.0,
        r_max: 1.0,
        q_min: 0.0,
        q_max: 1.0,
    };

    let r1: f32 = any();
    let r2: f32 = any();
    let q1: f32 = any();
    let q2: f32 = any();

    kani::assume(r1 >= 0.0 && r1 <= 1.0);
    kani::assume(r2 >= 0.0 && r2 <= 1.0);
    kani::assume(q1 >= 0.0 && q1 <= 1.0);
    kani::assume(q2 >= 0.0 && q2 <= 1.0);
    kani::assume(r1 <= r2);
    kani::assume(q1 <= q2);

    let e1 = cfg.error_bound(r1, q1);
    let e2 = cfg.error_bound(r2, q2);

    assert!(e1 <= e2 + 1e-3);
}

#[kani::proof]
fn risk_upper_covers_true_interval() {
    let cfg = SensorErrorConfig {
        sensor_kind: SensorKind::AmbientShielded,
        bias_min_c: -0.5,
        bias_max_c: 0.5,
        noise_bound_c: 0.3,
        gamma_radiant_c_per_unit: 1.0,
        gamma_aq_c_per_unit: 1.0,
        gamma_radiant_aq_c_per_unit: 1.0,
        r_min: 0.0,
        r_max: 1.0,
        q_min: 0.0,
        q_max: 1.0,
    };

    let measured: f32 = any();
    let radiant: f32 = any();
    let aq: f32 = any();

    kani::assume(radiant >= 0.0 && radiant <= 1.0);
    kani::assume(aq >= 0.0 && aq <= 1.0);

    let e = cfg.error_bound(radiant, aq);
    let t_min = measured - e;
    let t_max = measured + e;

    let t_true: f32 = any();
    kani::assume(t_true >= t_min && t_true <= t_max);

    let t_risk = cfg.risk_upper(measured, radiant, aq);
    assert!(t_risk >= t_true - 1e-3);
}
