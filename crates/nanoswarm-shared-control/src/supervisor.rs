// mk-bluebird/nanorobotics/crates/nanoswarm-shared-control/src/supervisor.rs
use crate::barrier::{BarrierOutcome, ControlBarrierFunction};
use crate::lyapunov::Lyapunov7Plus1;
use crate::types::{HostBinding, SwarmCommand, SwarmState};
use nalgebra::Vector3;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum FuseDecision {
    Applied,
    AdjustedByBarrier,
    FrozenForSafety,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SwarmSupervisoryController {
    pub host_binding: HostBinding,
    pub lyapunov: Lyapunov7Plus1,
    pub roh_barrier_active: bool,
    pub organ_barrier: crate::barrier::OrganCorridorBarrier,
    pub thermal_barrier: crate::barrier::ThermalBarrier,
    pub density_barrier: crate::barrier::DensityBarrier,
    pub roh_barrier: crate::barrier::RiskOfHarmBarrier,
}

impl SwarmSupervisoryController {
    pub fn fuse(
        &self,
        state: &SwarmState,
        host_cmd: &SwarmCommand,
    ) -> (SwarmCommand, FuseDecision) {
        if !self.lyapunov.is_within_level_set(&state.unified_axes_7p1) {
            let frozen = SwarmCommand {
                velocity: Vector3::zeros(),
                formation: host_cmd.formation,
                actuation_intensity: 0.0,
            };
            return (frozen, FuseDecision::FrozenForSafety);
        }

        if self.roh_barrier_active && state.biomarkers.roh_scalar >= self.roh_barrier.roh_max {
            let frozen = SwarmCommand {
                velocity: Vector3::zeros(),
                formation: host_cmd.formation,
                actuation_intensity: 0.0,
            };
            return (frozen, FuseDecision::FrozenForSafety);
        }

        let mut v = host_cmd.velocity;
        let mut decision = FuseDecision::Applied;

        let barriers: [&dyn ControlBarrierFunction; 4] = [
            &self.organ_barrier,
            &self.thermal_barrier,
            &self.density_barrier,
            &self.roh_barrier,
        ];

        for b in barriers.iter() {
            let (v_projected, outcome) = b.project(state, &v);
            match outcome {
                BarrierOutcome::Safe => {}
                BarrierOutcome::Adjusted => {
                    v = v_projected;
                    if decision == FuseDecision::Applied {
                        decision = FuseDecision::AdjustedByBarrier;
                    }
                }
                BarrierOutcome::Frozen => {
                    let frozen = SwarmCommand {
                        velocity: Vector3::zeros(),
                        formation: host_cmd.formation,
                        actuation_intensity: 0.0,
                    };
                    return (frozen, FuseDecision::FrozenForSafety);
                }
            }
        }

        let fused = SwarmCommand {
            velocity: v,
            formation: host_cmd.formation,
            actuation_intensity: host_cmd.actuation_intensity,
        };

        (fused, decision)
    }
}
