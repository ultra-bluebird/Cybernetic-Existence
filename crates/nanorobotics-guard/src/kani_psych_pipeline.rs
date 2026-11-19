// Path: crates/nanorobotics-guard/src/kani_psych_pipeline.rs
//
// Kani harnesses for full psych pipeline:
// PsychosisInputsNorm → PsychosisRisk → PsychosisMicroshield.clamp
// → StateVectorN → RoH ≤ 0.3 in corridor, and monotonicity. [file:1][file:3]

#![cfg(kani)]

use psychcaps_core::psychosis_risk::{
    compute_psychosis_risk_default, PsychosisInputsNorm,
};
use neurorights_microshield::psychosis_clamp::{PsychosisMicroshield, ClampThresholds};
use nanorobotics_core::state_vector_biohost::{
    StateVectorNBiohost, RoHWeights, roh_from_statevector,
};

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

/// Monotonicity: worsening psych inputs can only increase psych RoH component
/// and reduce clamp (or keep it same), never the opposite. [file:3]
#[kani::proof]
fn prove_full_psych_pipeline_monotone() {
    let a = PsychosisInputsNorm::new(
        clamp01(kani::any()),
        clamp01(kani::any()),
        clamp01(kani::any()),
        clamp01(kani::any()),
        clamp01(kani::any()),
        clamp01(kani::any()),
        clamp01(kani::any()),
        clamp01(kani::any()),
        clamp01(kani::any()),
    )
    .unwrap();

    // b is componentwise >= a.
    let b = PsychosisInputsNorm::new(
        clamp01(kani::any::<f64>().max(a.pain)),
        clamp01(kani::any::<f64>().max(a.anxiety)),
        clamp01(kani::any::<f64>().max(a.cog_load)),
        clamp01(kani::any::<f64>().max(a.identity_disr)),
        clamp01(kani::any::<f64>().max(a.halluc)),
        clamp01(kani::any::<f64>().max(a.delusion)),
        clamp01(kani::any::<f64>().max(a.sleep_depr)),
        clamp01(kani::any::<f64>().max(a.stress)),
        clamp01(kani::any::<f64>().max(a.mania)),
    )
    .unwrap();

    let ra = compute_psychosis_risk_default(a).unwrap();
    let rb = compute_psychosis_risk_default(b).unwrap();

    let micro = PsychosisMicroshield::conservative_default();
    let ca = micro.clamp(&ra);
    let cb = micro.clamp(&rb);

    // Worse symptoms → higher or equal r_psychosis.
    assert!(rb.r_psychosis + 1e-9 >= ra.r_psychosis);
    // Worse symptoms → clamp no larger.
    assert!(cb <= ca + 1e-9);
}

/// Safe corridor: if thermal, ATP, psych, biofilm, motion all ≤ 0.8,
/// then RoH(StateVectorN) ≤ 0.3 (with conservative weights). [file:1][file:3]
#[kani::proof]
fn prove_statevector_roh_corridor_with_psych() {
    let t: f64 = clamp01(kani::any()).min(0.8);
    let atp: f64 = clamp01(kani::any()).min(0.8);
    let bio: f64 = clamp01(kani::any()).min(0.8);
    let mot: f64 = clamp01(kani::any()).min(0.8);

    let inputs = PsychosisInputsNorm::new(
        clamp01(kani::any()).min(0.8),
        clamp01(kani::any()).min(0.8),
        clamp01(kani::any()).min(0.8),
        clamp01(kani::any()).min(0.8),
        clamp01(kani::any()).min(0.8),
        clamp01(kani::any()).min(0.8),
        clamp01(kani::any()).min(0.8),
        clamp01(kani::any()).min(0.8),
        clamp01(kani::any()).min(0.8),
    )
    .unwrap();

    let risk = compute_psychosis_risk_default(inputs).unwrap();
    let psych_norm = risk.r_psychosis.min(0.8);

    let sv = StateVectorNBiohost::new(t, atp, psych_norm, bio, mot).unwrap();
    let w = RoHWeights::conservative_default();

    let roh = roh_from_statevector(sv, w);
    assert!(roh <= 0.3 + 1e-9);
}
