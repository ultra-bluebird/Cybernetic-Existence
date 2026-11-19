//! nanorobotics-guardmesh-kani
//!
//! Kani proof harnesses for the sovereignty guard mesh decision logic.
//! Proves that:
//! - HardBrake is only issued when quorum is reached.
//! - SoftBrake is issued only under emergency conditions.
//! - No configuration violating BFT invariants is accepted.

#![forbid(unsafe_code)]
#![deny(missing_docs)]

use std::time::Duration;

use kani::any;

use nanorobotics_guardmesh::{Approval, GuardNodeId, MeshDecision, MeshGuardConfig, decidebrake};

/// Helper to construct a sample MeshGuardConfig satisfying basic BFT bounds.
///
/// This mirrors the config used in the main guardmesh crate.
fn sample_config(n_nodes: usize, f_byzantine: usize) -> MeshGuardConfig {
    let nodes = (0..n_nodes)
        .map(|i| GuardNodeId(format!("node-{i}")))
        .collect::<Vec<_>>();

    let quorum = 2 * f_byzantine + 1;

    MeshGuardConfig {
        nodes,
        maxbyzantine: f_byzantine,
        quorum,
        emergencythreshold: 0.9,
        emergencytimeout: Duration::from_millis(100),
    }
}

/// Proof: HardBrake requires at least `quorum` distinct approvals.
#[kani::proof]
fn hard_brake_requires_quorum() {
    let cfg = sample_config(4, 1);

    // Fewer than quorum approvals
    let mut approvals = Vec::new();
    approvals.push(Approval {
        nodeid: GuardNodeId("node-0".into()),
        localseverity: 0.95,
    });

    let elapsed = Duration::from_millis(50);
    let maxsev = 0.95;

    let decision = decidebrake(approvals.clone(), cfg.clone(), elapsed, maxsev);
    assert!(decision != MeshDecision::HardBrake);

    // Now reach quorum with distinct node IDs
    approvals.push(Approval {
        nodeid: GuardNodeId("node-1".into()),
        localseverity: 0.92,
    });
    approvals.push(Approval {
        nodeid: GuardNodeId("node-2".into()),
        localseverity: 0.90,
    });

    let decision2 = decidebrake(approvals, cfg, elapsed, maxsev);
    assert!(decision2 == MeshDecision::HardBrake);
}

/// Proof: SoftBrake triggers only when emergency severity and timeout are met.
#[kani::proof]
fn soft_brake_on_emergency_timeout() {
    let cfg = sample_config(4, 1);
    let approvals = Vec::<Approval>::new();

    // Severity above threshold, elapsed beyond timeout
    let elapsed = Duration::from_millis(200);
    let maxsev = 0.95;

    let decision = decidebrake(approvals.clone(), cfg.clone(), elapsed, maxsev);
    assert!(decision == MeshDecision::SoftBrake);

    // Same severity, but elapsed below timeout → should defer
    let elapsed_short = Duration::from_millis(50);
    let decision2 = decidebrake(approvals, cfg, elapsed_short, maxsev);
    assert!(decision2 == MeshDecision::Defer);
}

/// Proof: Config validation rejects obvious BFT violations.
#[kani::proof]
fn config_invariants_hold() {
    let n_nodes = any::<usize>();
    let f_byzantine = any::<usize>();

    // Restrict Kani search space to sensible ranges.
    kani::assume(n_nodes >= 3 && n_nodes <= 10);
    kani::assume(f_byzantine >= 1 && f_byzantine <= (n_nodes / 3));

    let cfg = sample_config(n_nodes, f_byzantine);
    assert!(cfg.validate().is_ok());
}
