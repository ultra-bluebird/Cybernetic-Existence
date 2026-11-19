// crates/cybernano-physio/src/kani/corridor_subset_phx6d.rs
#![forbid(unsafe_code)]
#![cfg(feature = "kani")]

extern crate alloc;

use alloc::vec::Vec;
use kani::any;
use kani::assume;
use kani::proof;

use crate::risk_of_harm_kernel::{CorridorPolytope, SixDState};

/// Canonical Cybercore migration authority.
pub const ALN_MIGRATION_CYBERCORE_AUTHORITY_V1: &str =
    "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";

/// Host DID and Bostrom address bound to this proof-only harness.
pub const HOST_DID: &str = "did:aln:organic-host";
pub const BOSTROM_ADDRESS: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

/// Helper: construct a Phoenix 6D corridor polytope used as the global hull.
///
/// This should mirror the ALN shard `phoenix.6d.corridor.v1.aln`, but for the
/// proof we only need a representative matrix that satisfies:
/// - RoH ceiling <= 0.30 enforced elsewhere,
/// - Thermal axis rows x3 clamped to a conservative corridor (e.g. ±2.0 C),
/// - All axes bounded to finite, physiologically plausible intervals.
///
/// In the live codebase, wire this to the ALN loader that parses the actual
/// Phoenix 6D coefficients and builds a CorridorPolytope from them.
fn kani_phx6d_corridor() -> CorridorPolytope<6> {
    // For the harness, we keep M small but structurally correct:
    // - HRV lower bound:      x1 >= 20.0  ->  -x1 <= -20.0
    // - EEG ratio upper:      x2 <= 2.0   ->   x2 <= 2.0
    // - core temp delta:      |x3| <= 2.0 ->   x3 <= 2.0, -x3 <= 2.0
    // - IL-6 upper:           x4 <= 50.0
    // - fatigue upper:        x5 <= 1.0
    // - ecoimpact lower:      x6 >= 0.0   ->  -x6 <= 0.0
    //
    // A is M x 6, b is length M.
    let mut a_rows: Vec<[f32; 6]> = Vec::new();
    let mut b: Vec<f32> = Vec::new();

    // -x1 <= -20.0  (HRV floor)
    a_rows.push([-1.0, 0.0, 0.0, 0.0, 0.0, 0.0]);
    b.push(-20.0);

    //  x2 <= 2.0    (EEG theta/beta ceiling)
    a_rows.push([0.0, 1.0, 0.0, 0.0, 0.0, 0.0]);
    b.push(2.0);

    //  x3 <= 2.0    (thermal upper)
    a_rows.push([0.0, 0.0, 1.0, 0.0, 0.0, 0.0]);
    b.push(2.0);

    // -x3 <= 2.0    (thermal lower)
    a_rows.push([0.0, 0.0, -1.0, 0.0, 0.0, 0.0]);
    b.push(2.0);

    //  x4 <= 50.0   (IL-6 ceiling)
    a_rows.push([0.0, 0.0, 0.0, 1.0, 0.0, 0.0]);
    b.push(50.0);

    //  x5 <= 1.0    (fatigue ceiling)
    a_rows.push([0.0, 0.0, 0.0, 0.0, 1.0, 0.0]);
    b.push(1.0);

    // -x6 <= 0.0    (ecoimpact floor)
    a_rows.push([0.0, 0.0, 0.0, 0.0, 0.0, -1.0]);
    b.push(0.0);

    CorridorPolytope::new(a_rows, b)
}

/// Helper: construct an organ-refined corridor that is guaranteed to be a
/// tightening (subset) of the Phoenix 6D corridor along one or more axes.
///
/// The key invariants:
/// - No new axes are introduced: refinement is still 6D in pure biophysical
///   coordinates (HRV, EEG, core temp delta, IL-6, fatigue, ecoimpact).
/// - No corridor widening is allowed: every refined row is at least as
///   restrictive as some Phoenix row, or adds a stricter constraint.
/// - No hardware-governed or virtual-hardware corridors are encoded here.
///
/// We model this by:
/// - Starting from the Phoenix A,b rows.
/// - Optionally tightening selected bounds symbolically.
fn kani_organ_refined_corridor(global: &CorridorPolytope<6>) -> CorridorPolytope<6> {
    let (global_a, global_b) = global.matrix();

    let m = global_a.len();
    let mut refined_a: Vec<[f32; 6]> = Vec::with_capacity(m);
    let mut refined_b: Vec<f32> = Vec::with_capacity(m);

    for i in 0..m {
        let row = global_a[i];
        let bound = global_b[i];

        // For each global row, choose a refined bound b_refined such that
        // 0 <= tighten_factor <= 1, and:
        //
        // - If the row encodes an upper bound  (a · x <= b, with a nonnegative
        //   scalar axis), then:
        //     b_refined = bound * tighten_factor,
        //   so b_refined <= bound and the constraint is tighter or equal.
        //
        // - If the row encodes a lower bound via -axis <= -L, we interpret
        //   "tightening" as raising the minimum L (more restrictive). Because
        //   we store -axis on the left and -L on the right, tightening moves
        //   b toward zero (e.g. -20 -> -10).
        //
        // To keep the harness generic, we treat any row with negative bound
        // as a lower-bound form and tighten toward 0.0.
        let tighten_factor: f32 = any();

        // Keep tighten_factor within [0, 1].
        assume(tighten_factor >= 0.0);
        assume(tighten_factor <= 1.0);

        let refined_bound = if bound >= 0.0 {
            // Upper-bound style: 0 <= b_refined <= b.
            bound * tighten_factor
        } else {
            // Lower-bound style: bound <= b_refined <= 0.0, so that
            // -axis <= b_refined is at least as restrictive as -axis <= bound.
            // Interpolate linearly toward 0.0.
            bound * (1.0 - tighten_factor)
        };

        refined_a.push(row);
        refined_b.push(refined_bound);
    }

    CorridorPolytope::new(refined_a, refined_b)
}

/// Helper: sample a 6D BioState inside the organ-refined corridor.
///
/// We let Kani choose an arbitrary SixDState, then constrain it to satisfy
/// all linear inequalities of the refined corridor. This models any pure
/// biophysical organ corridor that lives inside the Phoenix hull.
fn kani_biostate_inside_refined(refined: &CorridorPolytope<6>) -> SixDState {
    let mut state: SixDState = any();

    // Constrain state coordinates to broad, physiologic ranges so that
    // Kani does not diverge into nonphysical extremes.
    assume(state.hrv_sdnn_ms.is_finite());
    assume(state.hrv_sdnn_ms >= 0.0);
    assume(state.hrv_sdnn_ms <= 300.0);

    assume(state.eeg_theta_beta_ratio.is_finite());
    assume(state.eeg_theta_beta_ratio >= 0.0);
    assume(state.eeg_theta_beta_ratio <= 5.0);

    assume(state.core_temp_delta_c.is_finite());
    assume(state.core_temp_delta_c >= -3.0);
    assume(state.core_temp_delta_c <= 3.0);

    assume(state.il6_pg_ml.is_finite());
    assume(state.il6_pg_ml >= 0.0);
    assume(state.il6_pg_ml <= 200.0);

    assume(state.fatigue_index_01.is_finite());
    assume(state.fatigue_index_01 >= 0.0);
    assume(state.fatigue_index_01 <= 1.0);

    assume(state.eco_impact_score_01.is_finite());
    assume(state.eco_impact_score_01 >= 0.0);
    assume(state.eco_impact_score_01 <= 1.0);

    // Enforce that this state lies inside the refined corridor.
    assume(refined.contains(&state));

    state
}

/// Proof: any organ-refined corridor that is obtained by tightening the
/// Phoenix 6D corridor along biophysical axes only is a subset of the
/// Phoenix 6D corridor.
///
/// Formally:
///   Let C_phx = { x | A_phx x <= b_phx }
///   Let C_org = { x | A_org x <= b_org },
///   where A_org = A_phx and b_org is componentwise tighter as constructed
///   in `kani_organ_refined_corridor`.
///
/// The property:
///   For all x, if x ∈ C_org then x ∈ C_phx.
///
/// This encodes that:
/// - No organ corridor may widen Phoenix.
/// - No hardware-governed or virtual-hardware axes are introduced.
/// - Any sovereign host corridor specialization remains a subset of the
///   Phoenix environment hull and cannot relax global safety.
#[proof]
fn proof_organ_corridor_is_subset_of_phx6d() {
    // Global Phoenix corridor (host-sovereign, environment-calibrated).
    let global = kani_phx6d_corridor();

    // Organ-refined corridor built by tightening global bounds only.
    let refined = kani_organ_refined_corridor(&global);

    // Sample any state inside the refined corridor.
    let state = kani_biostate_inside_refined(&refined);

    // Subset property: membership in refined implies membership in global.
    assert!(
        global.contains(&state),
        "organ-refined corridor admitted a state outside Phoenix 6D corridor"
    );
}
