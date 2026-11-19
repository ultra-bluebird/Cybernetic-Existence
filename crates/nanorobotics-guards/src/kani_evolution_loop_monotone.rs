// filename: crates/nanorobotics-guards/src/kani_evolution_loop_monotone.rs
#![cfg(kani)]
#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]

use kani::any;

use nanorobotics_guards_core::{
    EvolutionWindowState,
    ManifestUpgradeGift,
    NonDegradationInvariants,
    run_evolution_window,
};

/// Kani proof: one full evolution window cannot weaken any core safety invariant.
/// This harness assumes the guard and threshold kernels already implement local
/// monotone-tightening semantics and composes them at the window level.
#[kani::proof]
fn evolution_window_is_globally_monotone() {
    // Symbolic initial state, assumed to satisfy the global invariants.
    let state_before: EvolutionWindowState = any();
    let invariants: NonDegradationInvariants = any();

    // Constrain the initial state to be admissible under the invariants.
    kani::assume(state_before.satisfies_invariants(&invariants));

    // Bounded number of manifest rows per window; adjust as needed but keep
    // small enough for Kani’s state-space exploration.
    const MAX_ROWS: usize = 8;

    // Symbolic manifest rows; each may be accepted or rejected by the guards.
    let mut gifts: [ManifestUpgradeGift; MAX_ROWS] = [any(); MAX_ROWS];

    // Optional: sanitize symbolic gifts to avoid degenerate values that violate
    // basic schema constraints before guard evaluation.
    for gift in gifts.iter_mut() {
        gift.sanitize_for_kani();
    }

    // Run the evolution window.
    let state_after = run_evolution_window(&state_before, &gifts, &invariants);

    // Global RoH ceiling preservation: ceiling never increases and never exceeds hard cap.
    kani::assert!(
        state_after.roh_ceiling <= invariants.roh_ceiling_hard,
        "RoH ceiling exceeded hard cap after evolution window"
    );
    kani::assert!(
        state_after.roh_ceiling <= state_before.roh_ceiling + invariants.float_tol,
        "RoH ceiling increased across evolution window"
    );

    // Observed RoH scalar must not exceed hard ceiling.
    kani::assert!(
        state_after.roh_max_observed <= invariants.roh_ceiling_hard + invariants.float_tol,
        "Observed RoH exceeded hard ceiling"
    );

    // Neurorights floors: cannot be weakened.
    kani::assert!(
        state_after.rights_state.dominates(&state_before.rights_state),
        "Neurorights floors weakened across evolution window"
    );

    // Vampiric healthcare envelopes: ceilings can only tighten (non-increasing),
    // floors can only tighten (non-decreasing).
    kani::assert!(
        state_after.vampiric_envelope.dominates_or_equal(&state_before.vampiric_envelope),
        "Vampiric healthcare envelope was relaxed across evolution window"
    );

    // Responsibility axis: rdelta is non-negative for accepted rows, and
    // cumulative responsibility scalar is non-decreasing.
    kani::assert!(
        state_after.responsibility_scalar + invariants.float_tol
            >= state_before.responsibility_scalar,
        "Responsibility scalar decreased across evolution window"
    );

    // Capability floor preservation: cannot drop below configured floor unless
    // explicitly host-authorized downgrade is present.
    if !state_after.has_host_authorized_downgrade {
        kani::assert!(
            state_after.capability_floor + invariants.float_tol
                >= state_before.capability_floor,
            "Capability floor decreased without host-authorized downgrade"
        );
        kani::assert!(
            state_after.capability_floor + invariants.float_tol
                >= invariants.capability_floor_hard,
            "Capability floor fell below hard minimum"
        );
    } else {
        // Even with an explicit downgrade, we must not violate hard limits.
        kani::assert!(
            state_after.capability_floor + invariants.float_tol
                >= invariants.capability_floor_hard,
            "Host-authorized downgrade violated minimum capability floor"
        );
        kani::assert!(
            state_after.roh_ceiling <= invariants.roh_ceiling_hard + invariants.float_tol,
            "Host-authorized downgrade violated RoH ceiling"
        );
        kani::assert!(
            state_after.rights_state.dominates(&invariants.rights_minima),
            "Host-authorized downgrade violated neurorights minima"
        );
    }

    // No implicit rollback / downgrade semantics: if the initial state respects
    // invariants, the post-window state must also respect them, without relying
    // on external reset or rollback mechanisms.
    kani::assert!(
        state_after.satisfies_invariants(&invariants),
        "Evolution window produced a state that violates non-degradation invariants"
    );
}

/// Kani proof: adversarial or malformed manifest rows cannot silently weaken
/// invariants; either they are rejected by guards or the resulting state still
/// satisfies the same invariants as the baseline state.
#[kani::proof]
fn adversarial_manifest_cannot_weaken_invariants() {
    let baseline_state: EvolutionWindowState = any();
    let invariants: NonDegradationInvariants = any();

    kani::assume(baseline_state.satisfies_invariants(&invariants));

    const MAX_ROWS: usize = 8;
    let gifts: [ManifestUpgradeGift; MAX_ROWS] = [any(); MAX_ROWS];

    // Run with potentially adversarial gifts.
    let state_after = run_evolution_window(&baseline_state, &gifts, &invariants);

    // Either nothing changed, or the invariants are still satisfied.
    // This matches the update-from-evidence adversarial harness pattern.
    if state_after != baseline_state {
        kani::assert!(
            state_after.satisfies_invariants(&invariants),
            "Adversarial manifest weakened non-degradation invariants"
        );
    }
}
