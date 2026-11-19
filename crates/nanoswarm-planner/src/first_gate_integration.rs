// filename: mk-bluebird/nanorobotics/crates/nanoswarm-planner/src/first_gate_integration.rs
// edition: 2024
// rust-version: 1.85
// Purpose: Wire NeurorightsClauseRegistry + EmergencyShutdownProtocol as
// unconditional first gate for nanoswarm plans.

#![forbid(unsafe_code)]
#![deny(warnings)]

use serde::{Deserialize, Serialize};

use neurorights_gate::gate::{evaluate_first_gate, FirstGateDecisionKind};
use neurorights_gate::types::{NeurorightsFloors, RiskSnapshot, SovereignIdentity};

/// Minimal nanoswarm plan header viewed by the first gate.
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct NanoswarmPlanHeader {
    pub host_did: String,
    pub bostrom_address: String,
    pub roh_before: f32,
    pub rod_before: f32,
    pub neurorights_floors: NeurorightsFloors,
}

/// Evaluate whether a nanoswarm plan may proceed to downstream planning.
pub fn first_gate_for_plan(header: &NanoswarmPlanHeader) -> FirstGateDecisionKind {
    let identity = SovereignIdentity::new();
    if header.host_did != identity.host_did || header.bostrom_address != identity.bostrom_address {
        return FirstGateDecisionKind::HardStop;
    }

    let config = neurorights_gate::gate::FirstGateConfig::new_default();
    let risk = RiskSnapshot {
        roh: header.roh_before,
        rod: header.rod_before,
    };

    let decision = evaluate_first_gate(&config, &header.neurorights_floors, risk);
    decision.kind
}
