// File: mk-bluebird/nanorobotics/crates/nanorobotics-planning/tests/kanikoopman_subset.rs
// Edition: 2024
// License: MIT OR Apache-2.0

#![cfg(kani)]
#![forbid(unsafe_code)]

use kani::any;

use cybercore_safety_kernel::StaticGuardVerdict;
use cybercore_state::UnifiedSafetyState7Plus1;
use virtual_supercomputer_sim::koopman_reach_envelope::{
    koopman_reachability, KoopmanFeatureConfig, KoopmanModel,
};
use nanorobotics_planning::{
    koopman_guard_adapter::{
        vet_mission_with_koopman, KoopmanPlannerConfig, KoopmanPlannerVerdict, MissionTemplate,
        PlannerControl,
    },
};

/// Kani harness: prove that Koopman veto cannot enlarge the set of accepted missions.
/// Formally: if vet_mission_with_koopman returns Accept, then static_guard_verdict was not a HardStop/Veto.
#[kani::proof]
fn kanikoopman_accept_subset_of_static_allow() {
    // Bounded dimensions for symbolic exploration.
    let dim_z: usize = 8;
    let dim_u: usize = 3;
    let roh_ceiling_hard: f32 = 0.30;
    let roh_warning_line: f32 = 0.27;

    let feature = KoopmanFeatureConfig { dim_z };

    // Arbitrary but bounded K and B entries.
    let mut k = vec![0.0_f32; dim_z * dim_z];
    let mut b = vec![0.0_f32; dim_z * dim_u];
    for v in k.iter_mut() {
        let val: f32 = any();
        // Keep matrix entries in a small range to avoid overflow in symbolic exec.
        kani::assume(val.is_finite());
        kani::assume(val >= -1.0 && val <= 1.0);
        *v = val;
    }
    for v in b.iter_mut() {
        let val: f32 = any();
        kani::assume(val.is_finite());
        kani::assume(val >= -1.0 && val <= 1.0);
        *v = val;
    }

    let mut roh_weights = vec![0.0_f32; dim_z];
    for w in roh_weights.iter_mut() {
        let val: f32 = any();
        kani::assume(val.is_finite());
        kani::assume(val >= -1.0 && val <= 1.0);
        *w = val;
    }
    let roh_offset: f32 = any();
    kani::assume(roh_offset.is_finite());
    kani::assume(roh_offset >= 0.0);
    kani::assume(roh_offset <= roh_ceiling_hard);

    let model = KoopmanModel {
        dim_z,
        dim_u,
        k,
        b,
        feature,
        roh_weights,
        roh_offset,
        roh_ceiling_hard,
        roh_warning_line,
    };

    // Initial state inside RoH ceiling.
    let mut x0 = UnifiedSafetyState7Plus1 {
        roh_scalar: any(),
        density_risk: any(),
        thermal_risk: any(),
        immune_risk: any(),
        microvascular_risk: any(),
        lifeforce_chi: any(),
        eco_risk: any(),
        spare_axis: any(),
    };
    kani::assume(x0.roh_scalar.is_finite());
    kani::assume(x0.roh_scalar >= 0.0 && x0.roh_scalar <= roh_ceiling_hard);

    // Static guard verdict is symbolic.
    let static_guard_verdict: u8 = any();
    let static_guard_verdict = match static_guard_verdict % 3 {
        0 => StaticGuardVerdict::Allow,
        1 => StaticGuardVerdict::Brake,
        _ => StaticGuardVerdict::HardStop,
    };

    // Small mission length for symbolic exploration.
    let len: usize = 3;
    let mut controls = Vec::with_capacity(len);
    for _ in 0..len {
        let mut c = PlannerControl { components: Vec::with_capacity(dim_u) };
        for _ in 0..dim_u {
            let v: f32 = any();
            kani::assume(v.is_finite());
            kani::assume(v >= -1.0 && v <= 1.0);
            c.components.push(v);
        }
        controls.push(c);
    }
    let mission = MissionTemplate { controls };

    let cfg = KoopmanPlannerConfig { max_horizon: len as u32 };

    let (koopman_verdict, _) =
        vet_mission_with_koopman(&cfg, &model, static_guard_verdict, &x0, &mission);

    // Invariant: Koopman Accept implies static guard was not HardStop.
    if koopman_verdict == KoopmanPlannerVerdict::Accept {
        kani::assert_ne!(
            static_guard_verdict,
            StaticGuardVerdict::HardStop,
            "Koopman layer must not accept missions that static guards HardStop"
        );
    }
}

/// Kani harness: Koopman is monotone-tightening relative to a simple baseline
/// that uses only initial RoH over the same horizon.
#[kani::proof]
fn kanikoopman_monotone_tightening() {
    let dim_z: usize = 8;
    let dim_u: usize = 2;
    let roh_ceiling_hard: f32 = 0.30;
    let roh_warning_line: f32 = 0.27;

    let feature = KoopmanFeatureConfig { dim_z };

    let mut k = vec![0.0_f32; dim_z * dim_z];
    let mut b = vec![0.0_f32; dim_z * dim_u];
    for v in k.iter_mut() {
        let val: f32 = any();
        kani::assume(val.is_finite());
        kani::assume(val >= -0.5 && val <= 0.5);
        *v = val;
    }
    for v in b.iter_mut() {
        let val: f32 = any();
        kani::assume(val.is_finite());
        kani::assume(val >= -0.5 && val <= 0.5);
        *v = val;
    }

    let mut roh_weights = vec![0.0_f32; dim_z];
    for w in roh_weights.iter_mut() {
        let val: f32 = any();
        kani::assume(val.is_finite());
        kani::assume(val >= -1.0 && val <= 1.0);
        *w = val;
    }
    let roh_offset: f32 = any();
    kani::assume(roh_offset.is_finite());
    kani::assume(roh_offset >= 0.0);
    kani::assume(roh_offset <= roh_ceiling_hard);

    let model = KoopmanModel {
        dim_z,
        dim_u,
        k,
        b,
        feature,
        roh_weights,
        roh_offset,
        roh_ceiling_hard,
        roh_warning_line,
    };

    let x0 = UnifiedSafetyState7Plus1 {
        roh_scalar: {
            let v: f32 = any();
            kani::assume(v.is_finite());
            kani::assume(v >= 0.0 && v <= roh_ceiling_hard);
            v
        },
        density_risk: 0.0,
        thermal_risk: 0.0,
        immune_risk: 0.0,
        microvascular_risk: 0.0,
        lifeforce_chi: 0.0,
        eco_risk: 0.0,
        spare_axis: 0.0,
    };

    let horizon: usize = 3;
    let mut controls = Vec::with_capacity(horizon);
    for _ in 0..horizon {
        let mut c = super::PlannerControl { components: Vec::with_capacity(dim_u) };
        for _ in 0..dim_u {
            let v: f32 = any();
            kani::assume(v.is_finite());
            kani::assume(v >= -1.0 && v <= 1.0);
            c.components.push(v);
        }
        controls.push(c);
    }

    let controls_vec: Vec<_> = controls
        .iter()
        .map(|c| c.as_koopman())
        .collect();

    let reach = koopman_reachability(&model, &x0, &controls_vec);

    // Baseline risk: max RoH is at least the initial RoH.
    let baseline_max = x0.roh_scalar;

    kani::assert!(
        reach.max_roh_over_horizon >= baseline_max - 1e-6,
        "Koopman envelope must be a conservative refinement of baseline RoH"
    );
}
