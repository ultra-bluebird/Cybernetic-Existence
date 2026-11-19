// filename: crates/advanced-safety-maths/tests/kani_gsp_fractional_compat.rs
#![cfg(kani)]
#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]

use kani::any;

use advanced_safety_maths::{
    GraphSignalRiskInput,
    GraphSignalRiskOutput,
    FractionalDiffusionInput,
    FractionalDiffusionOutput,
    compute_gsp_permeability_risk,
    compute_fractional_density_multiplier,
};

/// Kani proof sketch: graph-spectral permeability risk must never underestimate
/// the baseline ratio-based density risk for any admissible state.
#[kani::proof]
fn gsp_risk_is_conservative() {
    let input: GraphSignalRiskInput = any();

    // Constrain input to the admissible state space (non-negative densities,
    // finite degrees, normalized risk scalars).
    kani::assume(input.baseline_density_risk >= 0.0);
    kani::assume(input.baseline_density_risk <= 1.0);
    kani::assume(input.max_local_density >= 0.0);
    kani::assume(input.max_local_density <= input.density_ceiling + 1e-6);

    let out: GraphSignalRiskOutput = compute_gsp_permeability_risk(&input);

    // GSP risk scalar must be >= baseline risk for all admissible states.
    kani::assert!(
        out.graph_permeability_risk + 1e-6 >= input.baseline_density_risk,
        "Graph spectral permeability risk underestimated baseline density risk"
    );

    // GSP risk must remain within normalized [0, 1] bounds for stability.
    kani::assert!(
        out.graph_permeability_risk >= 0.0 && out.graph_permeability_risk <= 1.0 + 1e-6,
        "Graph spectral permeability risk fell outside [0, 1] bounds"
    );
}

/// Kani proof sketch: fractional diffusion density multiplier must be >= 1.0,
/// so that fractional density predictions are never lower than classical ones.
#[kani::proof]
fn fractional_density_is_conservative() {
    let input: FractionalDiffusionInput = any();

    // Constrain to admissible tissue parameters.
    kani::assume(input.alpha >= 0.0 && input.alpha <= 1.0);
    kani::assume(input.time_h > 0.0);
    kani::assume(input.classical_density >= 0.0);

    let out: FractionalDiffusionOutput = compute_fractional_density_multiplier(&input);

    // Multiplier >= 1.0 ensures fractional density is conservative.
    kani::assert!(
        out.density_multiplier + 1e-6 >= 1.0,
        "Fractional density multiplier fell below 1.0, weakening density risk"
    );

    // Normalization bounds to keep the scalar well-behaved.
    kani::assert!(
        out.density_multiplier >= 1.0 && out.density_multiplier <= input.max_multiplier_bound,
        "Fractional density multiplier exceeded configured bounds"
    );

    // Derived fractional density is always >= classical density.
    let rho_fractional = out.density_multiplier * input.classical_density;
    kani::assert!(
        rho_fractional + 1e-6 >= input.classical_density,
        "Fractional density prediction fell below classical density"
    );
}
