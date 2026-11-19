// crates/nanoswarm-execution-particles/src/kani_dental_stimulation_guard.rs
//
// Kani harness stubs for DentalCranialStimulationGuard invariants.
// Compile only under the `kani` feature.
//
// These harnesses are designed to prove that:
// - If all normalized axes (thermal, ATP, psych, motion) are in conservative
//   corridors, RoH <= 0.30 for any Allow verdict.
// - Increasing dental hazard or psych risk cannot reduce the likelihood of
//   ClampAndRetry or Deny (monotone tightening semantics).
#![forbid(unsafe_code)]

#![cfg(feature = "kani")]

use kani::any;

use crate::dental_stimulation_guard::{
    evaluate_dental_stim_guard, DentalStimGuardConfig, DentalStimGuardInputs, DentalStimVerdict,
};
use cybernano_physio::lifeforce::LifeforceInputs;
use nanorobotics_core::telemetry_dental::DentalCranialTelemetry;
use nanorobotics_core::roh_state::{RohWeights, StateVectorBiohost, compute_roh};

const MAX_ROH_SAFE: f64 = 0.30;
const ROH_CRITICAL: f64 = 0.70;

/// Harness 1: conservative corridors imply RoH <= 0.30 for any Allow verdict.
#[kani::proof]
fn dental_guard_allow_implies_roh_bounded() {
    // Conservative guard config.
    let mut cfg = DentalStimGuardConfig::default_conservative();
    kani::assume(cfg.validate());

    // Symbolic, conservative lifeforce inputs: all axes in [0, 0.8].
    let mut lf = LifeforceInputs {
        hrvnorm: any(),
        tempnorm: any(),
        perfusionnorm: any(),
        lactatenorm: any(),
        atpnorm: any(),
    };
    kani::assume(lf.hrvnorm.is_finite() && 0.0 <= lf.hrvnorm && lf.hrvnorm <= 0.8);
    kani::assume(lf.tempnorm.is_finite() && 0.0 <= lf.tempnorm && lf.tempnorm <= 0.8);
    kani::assume(lf.perfusionnorm.is_finite() && 0.0 <= lf.perfusionnorm && lf.perfusionnorm <= 0.8);
    kani::assume(lf.lactatenorm.is_finite() && 0.0 <= lf.lactatenorm && lf.lactatenorm <= 0.8);
    kani::assume(lf.atpnorm.is_finite() && 0.0 <= lf.atpnorm && lf.atpnorm <= 0.8);

    // Conservative psych risk and motion norms.
    let psych_risk: f32 = any();
    let motion_norm: f32 = any();
    kani::assume(psych_risk.is_finite() && 0.0 <= psych_risk && psych_risk <= 0.8);
    kani::assume(motion_norm.is_finite() && 0.0 <= motion_norm && motion_norm <= 0.8);

    // Symbolic dental telemetry within conservative corridors.
    let tissue_temp_c: f32 = any();
    let pressure_kpa: f32 = any();
    let duty_cycle: f32 = any();
    kani::assume(tissue_temp_c.is_finite() && 36.5 <= tissue_temp_c && tissue_temp_c <= 37.5);
    kani::assume(pressure_kpa.is_finite() && 0.0 <= pressure_kpa && pressure_kpa <= 20.0);
    kani::assume(duty_cycle.is_finite() && 0.0 <= duty_cycle && duty_cycle <= cfg.dutycycle_soft_max);

    let tel = DentalCranialTelemetry::new(tissue_temp_c, pressure_kpa, duty_cycle);

    let inputs = DentalStimGuardInputs {
        dental_telemetry: tel,
        psych_risk_norm: psych_risk,
        lifeforce_inputs: lf,
        motion_norm,
    };

    let verdict = evaluate_dental_stim_guard(&cfg, &inputs)
        .expect("guard evaluation must not fail under conservative assumptions");

    // If the guard returns Allow, RoH must be <= MAX_ROH_SAFE.
    if verdict == DentalStimVerdict::Allow {
        let dental_norm = nanorobotics_core::telemetry_dental::dental_hazard_score(
            cfg.dental_envelope,
            tel,
        )
        .unwrap_or(0.0_f32)
        .clamp(0.0, 1.0);

        let sv = StateVectorBiohost {
            tnorm: lf.tempnorm as f64,
            atpnorm: lf.atpnorm as f64,
            psychnorm: psych_risk as f64,
            biofilmnorm: lf.biofilmnorm as f64,
            motionnorm: (motion_norm.max(dental_norm)) as f64,
        };

        let w: RohWeights = cfg.roh_weights;
        let roh = compute_roh(sv, w);
        assert!(roh <= MAX_ROH_SAFE + 1e-9);
    }
}

/// Harness 2: increasing dental hazard or psych risk cannot make the guard "more permissive".
///
/// Specifically, if a given set of inputs is denied, then increasing dental temperature,
/// pressure, duty, or psych_risk must not result in an Allow verdict.
#[kani::proof]
fn dental_guard_monotone_in_hazard() {
    let cfg = DentalStimGuardConfig::default_conservative();
    kani::assume(cfg.validate());

    // Base lifeforce inputs and motion.
    let lf = LifeforceInputs {
        hrvnorm: any(),
        tempnorm: any(),
        perfusionnorm: any(),
        lactatenorm: any(),
        atpnorm: any(),
    };
    kani::assume(lf.hrvnorm.is_finite());
    kani::assume(lf.tempnorm.is_finite());
    kani::assume(lf.perfusionnorm.is_finite());
    kani::assume(lf.lactatenorm.is_finite());
    kani::assume(lf.atpnorm.is_finite());

    let motion_base: f32 = any();
    kani::assume(motion_base.is_finite() && 0.0 <= motion_base && motion_base <= 1.0);

    // Base telemetry and psych risk.
    let t_base: f32 = any();
    let p_base: f32 = any();
    let d_base: f32 = any();
    let psych_base: f32 = any();

    kani::assume(t_base.is_finite());
    kani::assume(p_base.is_finite() && 0.0 <= p_base && p_base <= 40.0);
    kani::assume(d_base.is_finite() && 0.0 <= d_base && d_base <= 1.0);
    kani::assume(psych_base.is_finite() && 0.0 <= psych_base && psych_base <= 1.0);

    let tel_base = DentalCranialTelemetry::new(t_base, p_base, d_base);
    let inputs_base = DentalStimGuardInputs {
        dental_telemetry: tel_base,
        psych_risk_norm: psych_base,
        lifeforce_inputs: lf,
        motion_norm: motion_base,
    };

    let verdict_base = evaluate_dental_stim_guard(&cfg, &inputs_base)
        .expect("base evaluation must not error");

    // Construct a "worse" scenario: higher thermal, pressure, duty, and psych.
    let t_worse: f32 = t_base + any::<f32>().abs();
    let p_worse: f32 = p_base + any::<f32>().abs();
    let d_worse: f32 = (d_base + any::<f32>().abs()).min(1.0);
    let psych_worse: f32 = (psych_base + any::<f32>().abs()).min(1.0);
    let motion_worse: f32 = (motion_base + any::<f32>().abs()).min(1.0);

    let tel_worse = DentalCranialTelemetry::new(t_worse, p_worse, d_worse);
    let inputs_worse = DentalStimGuardInputs {
        dental_telemetry: tel_worse,
        psych_risk_norm: psych_worse,
        lifeforce_inputs: lf,
        motion_norm: motion_worse,
    };

    let verdict_worse = evaluate_dental_stim_guard(&cfg, &inputs_worse)
        .expect("worse evaluation must not error");

    // Monotonic tightening: once Deny, never become Allow at worse conditions.
    if verdict_base == DentalStimVerdict::Deny {
        assert!(verdict_worse != DentalStimVerdict::Allow);
    }
}

/// Harness 3: if any axis saturates (psych or dental), RoH can enter a critical band.
///
/// This is a sanity check rather than a hard invariant, but it encodes the intent
/// that extreme conditions map to high RoH.
#[kani::proof]
fn dental_guard_roh_critical_when_axes_saturate() {
    let cfg = DentalStimGuardConfig::default_conservative();
    kani::assume(cfg.validate());

    let mut sv = StateVectorBiohost {
        tnorm: any(),
        atpnorm: any(),
        psychnorm: any(),
        biofilmnorm: any(),
        motionnorm: any(),
    };

    kani::assume(sv.tnorm.is_finite() && 0.0 <= sv.tnorm && sv.tnorm <= 1.0);
    kani::assume(sv.atpnorm.is_finite() && 0.0 <= sv.atpnorm && sv.atpnorm <= 1.0);
    kani::assume(sv.psychnorm.is_finite() && 0.0 <= sv.psychnorm && sv.psychnorm <= 1.0);
    kani::assume(sv.biofilmnorm.is_finite() && 0.0 <= sv.biofilmnorm && sv.biofilmnorm <= 1.0);
    kani::assume(sv.motionnorm.is_finite() && 0.0 <= sv.motionnorm && sv.motionnorm <= 1.0);

    // Force at least one axis into worst case.
    let choice: u8 = any();
    match choice % 3 {
        0 => sv.psychnorm = 1.0,
        1 => sv.motionnorm = 1.0,
        _ => sv.tnorm = 1.0,
    }

    let w = cfg.roh_weights;
    let roh = compute_roh(sv, w);

    // When any axis is saturated, RoH must be in or above the critical band.
    assert!(roh >= ROH_CRITICAL - 1e-6);
}
