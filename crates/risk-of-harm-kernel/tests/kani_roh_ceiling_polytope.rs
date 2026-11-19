// crates/risk-of-harm-kernel/tests/kani_roh_ceiling_polytope.rs
#![cfg(kani)]

use kani::any;
use risk_of_harm_kernel::polytope::{BioState, CorridorPolytope};
use risk_of_harm_kernel::roh::compute_roh;
use risk_of_harm_kernel::constants::ROH_CEILING;

/// Kani proof: any finite sequence of in-corridor states respects RoH <= 0.3.
#[kani::proof]
fn roh_never_exceeds_ceiling_given_corridor() {
    // Arbitrary initial state and corridor.
    let mut state: BioState = any();
    let mut corridor: CorridorPolytope<8> = CorridorPolytope::empty();

    // Constrain corridor to the calibrated envelope (host-specific bounds).
    // These assumptions encode A x <= b as ranges over axes.
    kani::assume(state.hrv_sdnn_ms >= 40.0 && state.hrv_sdnn_ms <= 120.0);
    kani::assume(state.eeg_theta_beta_ratio >= 0.3 && state.eeg_theta_beta_ratio <= 1.0);
    kani::assume(state.core_temp_delta_c >= -0.3 && state.core_temp_delta_c <= 0.5);
    kani::assume(state.il6_pg_ml >= 0.0 && state.il6_pg_ml <= 2.4);
    kani::assume(state.fatigue_index >= 0.0 && state.fatigue_index <= 1.0);
    kani::assume(state.ecoimpact_score >= 0.0 && state.ecoimpact_score <= 1.0);

    // Invariant before the loop: initial state satisfies corridor assumptions.
    let roh0 = compute_roh(&state);
    assert!(roh0 <= ROH_CEILING + 1e-6);

    // Number of steps to explore.
    let steps: u8 = any();
    kani::assume(steps <= 8);

    let mut k = 0u8;
    while k < steps {
        // Arbitrary delta, but constrained so we remain in corridor bounds.
        let delta_hrv: f32 = any();
        let delta_tbr: f32 = any();
        let delta_temp: f32 = any();
        let delta_il6: f32 = any();
        let delta_fatigue: f32 = any();
        let delta_eco: f32 = any();

        // Apply bounded transition keeping state inside corridor ranges.
        state.hrv_sdnn_ms += delta_hrv;
        state.eeg_theta_beta_ratio += delta_tbr;
        state.core_temp_delta_c += delta_temp;
        state.il6_pg_ml += delta_il6;
        state.fatigue_index += delta_fatigue;
        state.ecoimpact_score += delta_eco;

        // Re‑enforce corridor polytope bounds as assumptions.
        kani::assume(state.hrv_sdnn_ms >= 40.0 && state.hrv_sdnn_ms <= 120.0);
        kani::assume(state.eeg_theta_beta_ratio >= 0.3 && state.eeg_theta_beta_ratio <= 1.0);
        kani::assume(state.core_temp_delta_c >= -0.3 && state.core_temp_delta_c <= 0.5);
        kani::assume(state.il6_pg_ml >= 0.0 && state.il6_pg_ml <= 2.4);
        kani::assume(state.fatigue_index >= 0.0 && state.fatigue_index <= 1.0);
        kani::assume(state.ecoimpact_score >= 0.0 && state.ecoimpact_score <= 1.0);

        // Loop invariant: RoH must remain under the ceiling at every step.
        let roh_k = compute_roh(&state);
        assert!(roh_k <= ROH_CEILING + 1e-6);

        k += 1;
    }
}
