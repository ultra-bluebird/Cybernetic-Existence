// Path: crates/nanorobotics-guards/src/kani/state_vector_roh.rs
// Edition: 2024
// Compile only with `--cfg kani`

#![cfg(kani)]
#![forbid(unsafe_code)]

use kani::any;
use nanorobotics_core::rohfromstatevectorbiohost::{StateVectorNBiohost, RoHWeights, computeroh};
use nanorobotics_core::telemetry_dental::{DentalCranialEnvelope, DentalCranialTelemetry, dental_hazard_score};

const MAX_ROH_SAFE: f64 = 0.3;
const ROH_CRITICAL: f64 = 0.7;

/// Conservative harness: all axes (including dental) in [0, 0.8] imply RoH <= 0.3.
#[kani::proof]
fn roh_bounded_when_axes_conservative() {
    let mut sv = StateVectorNBiohost {
        tnorm: any(),
        atpnorm: any(),
        psychnorm: any(),
        biofilmnorm: any(),
        motionnorm: any(),
    };

    // Constrain all components to [0, 0.8]
    kani::assume(sv.tnorm.is_finite() && sv.tnorm >= 0.0 && sv.tnorm <= 0.8);
    kani::assume(sv.atpnorm.is_finite() && sv.atpnorm >= 0.0 && sv.atpnorm <= 0.8);
    kani::assume(sv.psychnorm.is_finite() && sv.psychnorm >= 0.0 && sv.psychnorm <= 0.8);
    kani::assume(sv.biofilmnorm.is_finite() && sv.biofilmnorm >= 0.0 && sv.biofilmnorm <= 0.8);
    kani::assume(sv.motionnorm.is_finite() && sv.motionnorm >= 0.0 && sv.motionnorm <= 0.8);

    let w = RoHWeights::default_conservative();
    let roh = computeroh(sv, w).unwrap();

    assert!(roh <= MAX_ROH_SAFE + 1e-6);
}

/// Critical harness: an axis saturating at 1.0 can drive RoH into critical band.
#[kani::proof]
fn roh_critical_when_any_axis_saturates() {
    let mut sv = StateVectorNBiohost {
        tnorm: any(),
        atpnorm: any(),
        psychnorm: any(),
        biofilmnorm: any(),
        motionnorm: any(),
    };

    // Conservative lower bounds (not all zero)
    kani::assume(sv.tnorm.is_finite() && sv.tnorm >= 0.0 && sv.tnorm <= 1.0);
    kani::assume(sv.atpnorm.is_finite() && sv.atpnorm >= 0.0 && sv.atpnorm <= 1.0);
    kani::assume(sv.psychnorm.is_finite() && sv.psychnorm >= 0.0 && sv.psychnorm <= 1.0);
    kani::assume(sv.biofilmnorm.is_finite() && sv.biofilmnorm >= 0.0 && sv.biofilmnorm <= 1.0);
    kani::assume(sv.motionnorm.is_finite() && sv.motionnorm >= 0.0 && sv.motionnorm <= 1.0);

    // At least one axis saturates
    let choice: u8 = any();
    match choice % 5 {
        0 => { sv.tnorm = 1.0; }
        1 => { sv.atpnorm = 0.0; } // worst ATP (1-ATPnorm)^2
        2 => { sv.psychnorm = 1.0; }
        3 => { sv.biofilmnorm = 1.0; }
        _ => { sv.motionnorm = 1.0; }
    }

    let w = RoHWeights::default_conservative();
    let roh = computeroh(sv, w).unwrap();

    // We want RoH to reflect critical status when any axis is at its worst.
    assert!(roh >= ROH_CRITICAL - 1e-6);
}

/// Optional: link dental hazard score into Tnorm for sanity.
#[kani::proof]
fn dental_hazard_does_not_break_roh_bound() {
    let env = DentalCranialEnvelope::default();
    kani::assume(env.validate());

    let tel = DentalCranialTelemetry::new(any(), any(), any());
    // Reasonable ranges for telemetry
    kani::assume(tel.t_tissue_c >= 35.0 && tel.t_tissue_c <= 39.0);
    kani::assume(tel.pressure_kpa >= 0.0 && tel.pressure_kpa <= 40.0);
    kani::assume(tel.duty_cycle >= 0.0 && tel.duty_cycle <= 1.0);

    let score = dental_hazard_score(&env, &tel).unwrap();

    let sv = StateVectorNBiohost {
        tnorm: score as f64,      // conservative mapping for harness
        atpnorm: 0.8,
        psychnorm: 0.2,
        biofilmnorm: 0.2,
        motionnorm: 0.2,
    };

    let w = RoHWeights::default_conservative();
    let roh = computeroh(sv, w).unwrap();

    assert!(roh <= 1.0 + 1e-6);
}
