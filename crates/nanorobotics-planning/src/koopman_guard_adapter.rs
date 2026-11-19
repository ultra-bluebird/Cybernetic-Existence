// File: mk-bluebird/nanorobotics/crates/nanorobotics-planning/src/koopman_guard_adapter.rs
// Edition: 2024
// License: MIT OR Apache-2.0

#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

use cybercore_safety_kernel::StaticGuardVerdict;
use cybercore_state::UnifiedSafetyState7Plus1;
use virtual_supercomputer_sim::koopman_reach_envelope::{
    koopman_reachability, KoopmanModel, KoopmanReachabilityResult,
};

/// Abstract mission template seen by planner; concrete type should already
/// be constrained to actions that individually pass static guards.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MissionTemplate {
    /// Pre-validated sequence of duty / control envelopes.
    pub controls: Vec<PlannerControl>,
}

/// Planner-side control representation that can be projected
/// into Koopman ControlVector.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlannerControl {
    pub components: Vec<f32>,
}

impl PlannerControl {
    pub fn as_koopman(&self) -> virtual_supercomputer_sim::koopman_reach_envelope::ControlVector {
        virtual_supercomputer_sim::koopman_reach_envelope::ControlVector {
            components: self.components.clone(),
        }
    }
}

/// Verdict exposed to the planner; this layer can only veto or request ClampAndRetry,
/// never override a static HardStop or allow a mission that static guards rejected.
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum KoopmanPlannerVerdict {
    Accept,
    ClampAndRetry,
    Reject,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KoopmanPlannerConfig {
    /// Maximum allowed horizon steps for envelope computation.
    pub max_horizon: u32,
}

/// Entry point used by the planner after static guards have accepted the mission.
pub fn vet_mission_with_koopman(
    cfg: &KoopmanPlannerConfig,
    model: &KoopmanModel,
    static_guard_verdict: StaticGuardVerdict,
    initial_state: &UnifiedSafetyState7Plus1,
    mission: &MissionTemplate,
) -> (KoopmanPlannerVerdict, KoopmanReachabilityResult) {
    // Static guards are the primary authority.
    match static_guard_verdict {
        StaticGuardVerdict::HardStop | StaticGuardVerdict::Veto => {
            // Koopman layer cannot soften this.
            return (
                KoopmanPlannerVerdict::Reject,
                KoopmanReachabilityResult {
                    max_roh_over_horizon: initial_state.roh_scalar,
                    min_margin_to_ceiling: model.roh_ceiling_hard - initial_state.roh_scalar,
                    exceeds_warning_line: initial_state.roh_scalar >= model.roh_warning_line,
                    exceeds_hard_ceiling: initial_state.roh_scalar > model.roh_ceiling_hard,
                },
            );
        }
        StaticGuardVerdict::Allow => {
            // Continue to Koopman envelope check.
        }
        StaticGuardVerdict::Brake => {
            // Optional: treat Brake as a pre-filtered state where Koopman may still veto
            // but may not upgrade it to full Allow.
        }
    }

    let horizon = mission.controls.len().min(cfg.max_horizon as usize);
    let controls: Vec<_> = mission.controls[..horizon]
        .iter()
        .map(|c| c.as_koopman())
        .collect();

    let reach = koopman_reachability(model, initial_state, &controls);

    let planner_verdict = if reach.exceeds_hard_ceiling {
        KoopmanPlannerVerdict::Reject
    } else if reach.exceeds_warning_line {
        KoopmanPlannerVerdict::ClampAndRetry
    } else {
        KoopmanPlannerVerdict::Accept
    };

    (planner_verdict, reach)
}
