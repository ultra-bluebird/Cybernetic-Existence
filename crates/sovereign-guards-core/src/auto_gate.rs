// path: crates/sovereign-guards-core/src/auto_gate.rs
#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(clippy::all, clippy::pedantic))]

use serde::{Deserialize, Serialize};

use crate::sovereign_verdict::SovereignVerdict;

/// Variables for gate.auto_allowed_predicate evaluation
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct AutoGateVars {
    pub roh: f32,
    pub eco_non_regression: bool,
    pub neurorights_ok: bool,
}

/// Auto-allowed predicate for CONSERVATIVE mode:
/// gate.auto_allowed_predicate = "RoH<=0.25 && EcoNonRegression && NeurorightsOK"
pub fn conservative_auto_allowed(vars: &AutoGateVars) -> bool {
    vars.roh <= 0.25 && vars.eco_non_regression && vars.neurorights_ok
}

/// Atomic evaluation wrapper: EcoNonRegression and NeurorightsOK must be
/// evaluated together and committed before any upgrade.
pub fn conservative_auto_allowed_atomic<F>(
    mut eval_guard: F,
    roh: f32,
) -> (SovereignVerdict, AutoGateVars)
where
    F: FnMut() -> (bool, bool),
{
    let (eco_non_regression, neurorights_ok) = eval_guard();
    let vars = AutoGateVars {
        roh,
        eco_non_regression,
        neurorights_ok,
    };
    if conservative_auto_allowed(&vars) {
        (SovereignVerdict::AutoAllowed, vars)
    } else {
        (SovereignVerdict::AutoDenied, vars)
    }
}
