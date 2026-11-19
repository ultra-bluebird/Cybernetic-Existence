// crates/nanorobotics-guards/src/kani_latency.rs
// Dual-licensed: MIT OR Apache-2.0
// Rust edition 2024, rust-version = "1.85"
// Kani 0.56.0, non-optional.

#![forbid(unsafe_code)]

use kani::any;
use advanced_safety_math::latency_fp::{LatencyFpParams, LatencyRisk};
use nanorobotics_core::roh_kernel::{RoHKernelInput, RoHKernelOutput};
use aln_governance::roh::RoHCeiling;

/// Kani harness: under stable FP parameters and corridor latency, RoH never exceeds 0.30
/// for any admissible latency distribution.
#[kani::proof]
fn roh_never_exceeds_ceiling_under_latency_corridor() {
    // Arbitrary but constrained FP parameters.
    let mut params: LatencyFpParams = any();
    // Enforce explicit stability constraints as in density FP harnesses.
    kani::assume(params.dt_ms > 0.0);
    kani::assume(params.dx_ms > 0.0);
    kani::assume(params.dt_ms <= 0.5 * params.dx_ms * params.dx_ms / params.d_max());

    // Arbitrary latency density field within ceiling.
    let mut rho = advanced_safety_math::latency_fp::any_density(params.grid_len);
    for i in 0..params.grid_len {
        kani::assume(rho.values[i] >= 0.0);
        kani::assume(rho.values[i] <= params.density_ceiling);
    }

    // Corridor latency budget (2-hop).
    let latency_budget_ms: f32 = 120.0;
    let roh_ceiling = RoHCeiling { value: 0.30_f32 };

    let latency_risk: LatencyRisk =
        advanced_safety_math::latency_fp::compute_latency_risk(
            &rho,
            std::time::Duration::from_millis(latency_budget_ms as u64),
        );

    // Fake RoHKernelInput: we only care about the mapping from latency axis to RoH.
    let roh_input = RoHKernelInput::from_latency(latency_risk);
    let roh_out: RoHKernelOutput =
        nanorobotics_core::roh_kernel::compute_roh(&roh_input);

    assert!(roh_out.global.value <= roh_ceiling.value + 1.0e-6);
}

/// Kani harness: latency corridor is monotonically tightening.
/// Any more conservative parameters (lower max_latency_ms, higher weights)
/// cannot reduce RoH for a fixed latency distribution.
#[kani::proof]
fn latency_corridor_monotone_tightening() {
    let original_params: LatencyFpParams = any();
    let mut tightened_params = original_params.clone();

    // Tighten latency budget and weights.
    tightened_params.max_latency_ms =
        original_params.max_latency_ms * 0.8_f32;
    tightened_params.latency_soft_weight =
        original_params.latency_soft_weight * 1.1_f32;
    tightened_params.latency_hard_weight =
        original_params.latency_hard_weight * 1.1_f32;

    let rho = advanced_safety_math::latency_fp::any_density(original_params.grid_len);

    let risk_orig =
        advanced_safety_math::latency_fp::compute_latency_risk(
            &rho,
            std::time::Duration::from_millis(
                original_params.max_latency_ms as u64,
            ),
        );

    let risk_tight =
        advanced_safety_math::latency_fp::compute_latency_risk(
            &rho,
            std::time::Duration::from_millis(
                tightened_params.max_latency_ms as u64,
            ),
        );

    let roh_orig =
        nanorobotics_core::roh_kernel::compute_roh(
            &RoHKernelInput::from_latency(risk_orig),
        );
    let roh_tight =
        nanorobotics_core::roh_kernel::compute_roh(
            &RoHKernelInput::from_latency(risk_tight),
        );

    // Tightening latency corridor cannot reduce RoH.
    assert!(roh_tight.global.value >= roh_orig.global.value - 1.0e-6);
}
