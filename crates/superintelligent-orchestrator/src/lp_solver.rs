// File: crates/superintelligent-orchestrator/src/lp_solver.rs

#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

use crate::types::{NanoswarmMission, OrchestratorInput, OrchestratorConfig};

/// Result of a linear-programming solve.
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct LpSolveResult {
    /// Missions produced by the LP optimizer.
    pub missions: Vec<NanoswarmMission>,
    /// Forecasted peak RoH over the schedule in [0.0, 0.3].
    pub forecasted_roh_peak: f32,
    /// Aggregate capability score in [0.0, 1.0].
    pub capability_score: f32,
}

/// Abstract LP solver. Implementations may delegate to a virtual
/// supercomputer-backed engine that solves the LP on a GPU cluster.
/// All implementations MUST respect the min-preserving lexicographic
/// ordering specified by the Orchestrator.
pub trait LinearProgrammingSolver {
    /// Solve the safety-constrained mission allocation LP.
    ///
    /// Primary objective:
    ///   minimize max_t RoH(t) subject to RoH(t) <= config.roh_ceiling - config.roh_margin.
    ///
    /// Secondary objective:
    ///   maximize capability_score (e.g., weighted sum of mission coverage) while
    ///   never violating the primary objective.
    fn solve(
        &self,
        input: &OrchestratorInput,
        config: &OrchestratorConfig,
    ) -> LpSolveResult;
}
