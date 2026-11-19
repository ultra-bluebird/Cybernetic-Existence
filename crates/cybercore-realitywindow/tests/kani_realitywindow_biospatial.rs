// destination-path: crates/cybercore-realitywindow/tests/kani_realitywindow_biospatial.rs
// edition: 2024
// rust-version: 1.85
#![forbid(unsafe_code)]

use kani::any;

use cybernano_biospatial::{BiospatialRegionState, BiospatialRoHGuard, BiospatialState, SafetyVerdict};

#[kani::proof]
fn kani_realitywindow_never_allows_rollback_required() {
    let r1 = BiospatialRegionState {
        region_id: String::from("cns"),
        local_roh: any(),
        roh_slice_max: 0.20,
        alpha_weight: 0.5,
        evidence_tags: Default::default(),
    };
    let r2 = BiospatialRegionState {
        region_id: String::from("cardiac"),
        local_roh: any(),
        roh_slice_max: 0.20,
        alpha_weight: 0.5,
        evidence_tags: Default::default(),
    };
    let mut state = BiospatialState::new(vec![r1, r2]);
    state.set_alpha_bounds(vec![0.0, 0.0], vec![1.0, 1.0]);
    let guard = BiospatialRoHGuard::new();
    let verdict = guard.evaluate(&mut state);
    assert!(!matches!(verdict, SafetyVerdict::RollbackRequired));
}
