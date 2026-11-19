// Filename: mk-bluebird/nanorobotics/crates/nanorobotics-guards/src/hierarchical_composer_kani.rs
// Destination: github.com/mk-bluebird/nanorobotics

#![forbid(unsafe_code)]

use kani::proof;
use crate::{
    hierarchical_composer::HierarchicalGuardComposer,
    guards_impl::{DensityGuard, ImmuneGuard, ThermalGuard, WssGuard},
    corridor_traits::GuardState,
    verdict::Verdict,
};

#[proof]
fn wss_deny_dominates_all_other_corridors() {
    let composer = HierarchicalGuardComposer {
        wss_guard: WssGuard,
        density_guard: DensityGuard,
        thermal_guard: ThermalGuard,
        immune_guard: ImmuneGuard,
    };

    let state = GuardState {
        wss: 2.0,
        density: kani::any(),
        thermal: kani::any(),
        immune: kani::any(),
    };

    let wss_v = composer.wss_guard.evaluate(&state);
    assert!(wss_v == Verdict::Deny);

    let global_v = composer.evaluate(&state);
    assert!(global_v == Verdict::Deny);
}
