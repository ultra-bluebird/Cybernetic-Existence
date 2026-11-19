// File: crates/superintelligent-orchestrator/src/orchestrator.rs

#![forbid(unsafe_code)]

use crate::lp_solver::{LinearProgrammingSolver, LpSolveResult};
use crate::types::{
    NanoswarmMissionSchedule, OrchestratorConfig, OrchestratorInput,
};

/// Orchestrator wiring LP solver and virtual supercomputer constraints.
///
/// The algorithm is lexicographic:
/// 1. Minimize forecasted peak RoH under clinical constraints.
/// 2. Subject to 1, maximize capability_score while keeping
///    capability_score >= capability_floor.
///
/// The concrete LP is delegated to a virtual-supercomputer-backed solver
/// that uses corridor polytopes and SimulationCoefficients derived from
/// MaterialLibrary to ensure conservatism.
pub struct SuperintelligentOrchestrator<S: LinearProgrammingSolver> {
    solver: S,
}

impl<S: LinearProgrammingSolver> SuperintelligentOrchestrator<S> {
    /// Construct a new orchestrator instance.
    pub fn new(solver: S) -> Self {
        Self { solver }
    }

    /// Produce a RoH-bounded, host-sovereign mission schedule that respects
    /// corridor polytopes, material safety, and neurorights.
    pub fn orchestrate(
        &self,
        input: &OrchestratorInput,
        config: &OrchestratorConfig,
    ) -> NanoswarmMissionSchedule {
        // Step 1: run LP solve under hard RoH ceiling with safety margin.
        let lp_result = self.solver.solve(input, config);

        // Lexicographic min-preserving checks:
        // - RoH must be <= roh_ceiling - roh_margin.
        // - Capability must be >= capability_floor.
        let roh_ok = lp_result.forecasted_roh_peak
            <= (config.roh_ceiling - config.roh_margin);
        let capability_ok = lp_result.capability_score >= config.capability_floor;

        if !roh_ok || !capability_ok {
            // No admissible schedule exists under current constraints;
            // return an empty schedule with forecasted_roh_peak at baseline.
            return NanoswarmMissionSchedule {
                schedule_id: "infeasible".to_owned(),
                missions: Vec::new(),
                forecasted_roh_peak: 0.0,
            };
        }

        NanoswarmMissionSchedule {
            schedule_id: "schedule-01".to_owned(),
            missions: lp_result.missions,
            forecasted_roh_peak: lp_result.forecasted_roh_peak,
        }
    }
}
