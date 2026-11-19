// Path: crates/nanorobotics-guards/src/kani/metabolic_power_corridor.rs
// Edition: 2024

#![cfg(kani)]
#![forbid(unsafe_code)]

use kani::any;

use nanorobotics_core::metabolic_power::{
    MetabolicPowerEnvelope, MetabolicSnapshot, compute_atp_norm,
};
use nanorobotics_core::rohfromstatevectorbiohost::{
    StateVectorNBiohost, RoHWeights, computeroh,
};

const ROH_SAFE_MAX: f64 = 0.3;
const ROH_CRITICAL_MIN: f64 = 0.7;

/// Helper clamp into [0,1] for symbolic values.
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

/// Harness 1: If ATPnorm >= 0.8 and other axes are kept in a conservative band,
/// then RoH <= 0.3 under conservative RoH weights.
///
/// This encodes the "safe metabolic corridor" invariant.
#[kani::proof]
fn roh_bounded_in_safe_metabolic_corridor() {
    let env = MetabolicPowerEnvelope::default();
    kani::assume(env.validate());

    // Symbolic ATP snapshot constrained to high reserves and modest device use.
    let b_global = any::<f64>();
    let b_brain = any::<f64>();
    let b_liver = any::<f64>();
    let b_muscle = any::<f64>();
    let b_gut = any::<f64>();
    let b_other = any::<f64>();
    let b_mt = any::<f64>();
    let b_nano = any::<f64>();
    let b_biofilm = any::<f64>();

    // Conservative assumptions: global ATP near top of envelope, device usage small.
    kani::assume(b_global.is_finite());
    kani::assume(b_global >= env.b_global_max_mmol * 0.9);
    kani::assume(b_global <= env.b_global_max_mmol * 1.05);

    for v in [
        b_brain, b_liver, b_muscle, b_gut, b_other, b_mt, b_nano, b_biofilm,
    ] {
        kani::assume(v.is_finite());
        kani::assume(v >= 0.0);
    }

    let snap = MetabolicSnapshot::new(
        b_global, b_brain, b_liver, b_muscle, b_gut, b_other, b_mt, b_nano, b_biofilm,
    );

    let atp_norm = compute_atp_norm(&env, &snap).unwrap();

    // Safe metabolic corridor: ATPnorm >= 0.8
    kani::assume(atp_norm >= 0.8);

    // Other axes constrained to conservative band <= 0.8.
    let tnorm = clamp01(any::<f64>()).min(0.8);
    let psychnorm = clamp01(any::<f64>()).min(0.8);
    let biofilmnorm = clamp01(any::<f64>()).min(0.8);
    let motionnorm = clamp01(any::<f64>()).min(0.8);

    let sv = StateVectorNBiohost {
        tnorm,
        atpnorm: atp_norm,
        psychnorm,
        biofilmnorm,
        motionnorm,
    };

    let w = RoHWeights::default_conservative();
    let roh = computeroh(sv, w).unwrap();

    // Invariant: RoH must remain inside the 0.3 safety corridor.
    assert!(roh <= ROH_SAFE_MAX + 1e-6);
}

/// Harness 2: If ATPnorm <= 0.3, then RoH must sit in a critical band >= 0.7,
/// even when other axes are nominal.
///
/// This ensures ATP crisis alone can trigger hard clamps.
#[kani::proof]
fn roh_critical_in_metabolic_crisis() {
    let env = MetabolicPowerEnvelope::default();
    kani::assume(env.validate());

    // Symbolic ATP snapshot with low reserves, potentially high device consumption.
    let b_global = any::<f64>();
    let b_brain = any::<f64>();
    let b_liver = any::<f64>();
    let b_muscle = any::<f64>();
    let b_gut = any::<f64>();
    let b_other = any::<f64>();
    let b_mt = any::<f64>();
    let b_nano = any::<f64>();
    let b_biofilm = any::<f64>();

    kani::assume(b_global.is_finite());
    kani::assume(b_global >= env.b_global_min_mmol * 0.5);
    kani::assume(b_global <= env.b_global_min_mmol * 1.1);

    for v in [
        b_brain, b_liver, b_muscle, b_gut, b_other, b_mt, b_nano, b_biofilm,
    ] {
        kani::assume(v.is_finite());
        kani::assume(v >= 0.0);
    }

    let snap = MetabolicSnapshot::new(
        b_global, b_brain, b_liver, b_muscle, b_gut, b_other, b_mt, b_nano, b_biofilm,
    );

    let atp_norm = compute_atp_norm(&env, &snap).unwrap();

    // Crisis corridor: ATPnorm <= 0.3
    kani::assume(atp_norm <= 0.3);

    // Other axes can be relatively benign.
    let tnorm = clamp01(any::<f64>()).min(0.5);
    let psychnorm = clamp01(any::<f64>()).min(0.5);
    let biofilmnorm = clamp01(any::<f64>()).min(0.5);
    let motionnorm = clamp01(any::<f64>()).min(0.5);

    let sv = StateVectorNBiohost {
        tnorm,
        atpnorm: atp_norm,
        psychnorm,
        biofilmnorm,
        motionnorm,
    };

    let w = RoHWeights::default_conservative();
    let roh = computeroh(sv, w).unwrap();

    // Invariant: metabolic crisis must push RoH into critical band.
    assert!(roh >= ROH_CRITICAL_MIN - 1e-6);
}
