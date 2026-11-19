// Path: crates/psychcaps-core/src/kani_psychosis_risk.rs
//
// Kani proof harnesses for psychosis_risk.rs. [file:3]

#![cfg(kani)]

use super::psychosis_risk::{
    compute_psychosis_risk_default, PsychosisInputsNorm, PsychosisRiskParams,
};

/// Helper: clamp to [0,1] for symbolic values.
fn clamp01(x: f64) -> f64 {
    if !x.is_finite() {
        0.0
    } else if x < 0.0 {
        0.0
    } else if x > 1.0 {
        1.0
    } else {
        x
    }
}

/// Monotonicity: if inputs2 >= inputs1 componentwise, risk2 >= risk1. [file:3]
#[kani::proof]
fn prove_psychosis_risk_monotone() {
    let a_pain: f64 = kani::any();
    let a_anx: f64 = kani::any();
    let a_cog: f64 = kani::any();
    let a_id: f64 = kani::any();
    let a_hall: f64 = kani::any();
    let a_del: f64 = kani::any();
    let a_sleep: f64 = kani::any();
    let a_stress: f64 = kani::any();
    let a_mania: f64 = kani::any();

    let b_pain: f64 = kani::any();
    let b_anx: f64 = kani::any();
    let b_cog: f64 = kani::any();
    let b_id: f64 = kani::any();
    let b_hall: f64 = kani::any();
    let b_del: f64 = kani::any();
    let b_sleep: f64 = kani::any();
    let b_stress: f64 = kani::any();
    let b_mania: f64 = kani::any();

    let a = PsychosisInputsNorm::new(
        clamp01(a_pain),
        clamp01(a_anx),
        clamp01(a_cog),
        clamp01(a_id),
        clamp01(a_hall),
        clamp01(a_del),
        clamp01(a_sleep),
        clamp01(a_stress),
        clamp01(a_mania),
    )
    .unwrap();

    let b = PsychosisInputsNorm::new(
        clamp01(b_pain.max(a_pain)),
        clamp01(b_anx.max(a_anx)),
        clamp01(b_cog.max(a_cog)),
        clamp01(b_id.max(a_id)),
        clamp01(b_hall.max(a_hall)),
        clamp01(b_del.max(a_del)),
        clamp01(b_sleep.max(a_sleep)),
        clamp01(b_stress.max(a_stress)),
        clamp01(b_mania.max(a_mania)),
    )
    .unwrap();

    let ra = compute_psychosis_risk_default(a).unwrap();
    let rb = compute_psychosis_risk_default(b).unwrap();

    // Monotonicity: worsening symptoms cannot lower risk.
    assert!(rb.r_psychosis + 1e-9 >= ra.r_psychosis);
}

/// Safety corridor: if all dimensions <= 0.8, R_psychosis <= 0.3. [file:1][file:3]
#[kani::proof]
fn prove_psychosis_roh_corridor() {
    let p: f64 = kani::any();
    let anx: f64 = kani::any();
    let cog: f64 = kani::any();
    let id: f64 = kani::any();
    let hall: f64 = kani::any();
    let del: f64 = kani::any();
    let sleep: f64 = kani::any();
    let stress: f64 = kani::any();
    let mania: f64 = kani::any();

    // Constrain to conservative psych corridor <= 0.8.
    let max_val = 0.8_f64;
    let inputs = PsychosisInputsNorm::new(
        clamp01(p).min(max_val),
        clamp01(anx).min(max_val),
        clamp01(cog).min(max_val),
        clamp01(id).min(max_val),
        clamp01(hall).min(max_val),
        clamp01(del).min(max_val),
        clamp01(sleep).min(max_val),
        clamp01(stress).min(max_val),
        clamp01(mania).min(max_val),
    )
    .unwrap();

    let r = compute_psychosis_risk_default(inputs).unwrap();

    // RoH corridor: for psych components in safe band, risk remains <= 0.3.
    assert!(r.r_psychosis <= 0.3 + 1e-9);
}
