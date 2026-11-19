#![feature(rust_2024_preview)]
#![forbid(unsafe_code)]

#![cfg(kani)]

use kani::any;
use neuro_ad_guard::{check_ad_step, compute_v_ad, AdInvariants, AdSample, AdSafetyVerdict};

/// Kani harness:
///
/// Prove that for any step where:
///   - invariants are well-formed,
///   - CSI, sigma, and xbar_tau stay within [0,1],
///   - RoH <= roh_max,
/// the guard will not allow an increase in V_AD.
///
/// This is a reduced-order proof: we assume that any accepted
/// "improved" state does not violate domain bounds and focus on
/// the Lyapunov monotonicity enforced by check_ad_step.
#[kani::proof]
fn kani_ad_lyapunov_nonincrease() {
    let a1: f64 = any();
    let a2: f64 = any();
    let a3: f64 = any();
    let v_ad_max: f64 = any();
    let roh_max: f64 = any();
    let csi_min: f64 = any();
    let sigma_min: f64 = any();
    let xbar_max: f64 = any();

    kani::assume(a1 > 0.0);
    kani::assume(a2 > 0.0);
    kani::assume(a3 > 0.0);
    kani::assume(v_ad_max > 0.0);
    kani::assume(roh_max > 0.0 && roh_max <= 0.30);
    kani::assume(csi_min >= 0.0 && csi_min <= 1.0);
    kani::assume(sigma_min >= 0.0 && sigma_min <= 1.0);
    kani::assume(xbar_max >= 0.0 && xbar_max <= 1.0);

    let inv = AdInvariants {
        a1,
        a2,
        a3,
        v_ad_max,
        roh_max,
        csi_min,
        sigma_min,
        xbar_max,
    };

    // Previous sample
    let mut prev = AdSample {
        csi: any(),
        sigma_sw: any(),
        xbar_tau: any(),
        roh: any(),
    };

    kani::assume(prev.csi >= csi_min && prev.csi <= 1.0);
    kani::assume(prev.sigma_sw >= sigma_min && prev.sigma_sw <= 1.0);
    kani::assume(prev.xbar_tau >= 0.0 && prev.xbar_tau <= xbar_max);
    kani::assume(prev.roh >= 0.0 && prev.roh <= roh_max);

    let prev_v = compute_v_ad(&inv, prev);
    kani::assume(prev_v <= v_ad_max);

    // Candidate next sample
    let mut next = AdSample {
        csi: any(),
        sigma_sw: any(),
        xbar_tau: any(),
        roh: any(),
    };

    kani::assume(next.csi >= csi_min && next.csi <= 1.0);
    kani::assume(next.sigma_sw >= sigma_min && next.sigma_sw <= 1.0);
    kani::assume(next.xbar_tau >= 0.0 && next.xbar_tau <= xbar_max);
    kani::assume(next.roh >= 0.0 && next.roh <= roh_max);

    let verdict = check_ad_step(&inv, prev_v, next);

    match verdict {
        AdSafetyVerdict::Allow { v_ad_next } => {
            // If the guard allows the step, it must not increase V_AD.
            assert!(v_ad_next <= prev_v);
            assert!(v_ad_next <= v_ad_max);
        }
        _ => {
            // On any denial verdict, we impose no additional constraint.
        }
    }
}
