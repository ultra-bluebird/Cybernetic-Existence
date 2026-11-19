// mk-bluebird/nanorobotics/crates/nanoswarm-shared-control/src/barrier.rs
use crate::types::SwarmState;
use nalgebra::Vector3;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum BarrierOutcome {
    Safe,
    Adjusted,
    Frozen,
}

pub trait ControlBarrierFunction {
    fn project(
        &self,
        state: &SwarmState,
        desired: &Vector3<f32>,
    ) -> (Vector3<f32>, BarrierOutcome);

    fn name(&self) -> &'static str;
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OrganCorridorBarrier {
    pub d_min: f32,
    pub alpha_org: f32,
}

impl OrganCorridorBarrier {
    fn h(&self, d_current: f32) -> f32 {
        d_current - self.d_min
    }
}

impl ControlBarrierFunction for OrganCorridorBarrier {
    fn project(
        &self,
        state: &SwarmState,
        desired: &Vector3<f32>,
    ) -> (Vector3<f32>, BarrierOutcome) {
        let h = self.h(state.distance_to_no_fly);
        if h <= 0.0 {
            return (Vector3::zeros(), BarrierOutcome::Frozen);
        }
        let alpha_h = self.alpha_org * h;
        let v_norm = desired.norm();
        if v_norm <= alpha_h {
            (*desired, BarrierOutcome::Safe)
        } else if alpha_h <= 0.0 {
            (Vector3::zeros(), BarrierOutcome::Frozen)
        } else {
            let scaled = desired * (alpha_h / v_norm);
            (scaled, BarrierOutcome::Adjusted)
        }
    }

    fn name(&self) -> &'static str {
        "organ_corridor_barrier"
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ThermalBarrier {
    pub t_max: f32,
    pub alpha_th: f32,
}

impl ThermalBarrier {
    fn h(&self, t_local: f32) -> f32 {
        self.t_max - t_local
    }
}

impl ControlBarrierFunction for ThermalBarrier {
    fn project(
        &self,
        state: &SwarmState,
        desired: &Vector3<f32>,
    ) -> (Vector3<f32>, BarrierOutcome) {
        let h = self.h(state.local_temperature);
        if h <= 0.0 {
            return (Vector3::zeros(), BarrierOutcome::Frozen);
        }
        let alpha_h = self.alpha_th * h;
        let v_norm = desired.norm();
        if v_norm <= alpha_h {
            (*desired, BarrierOutcome::Safe)
        } else if alpha_h <= 0.0 {
            (Vector3::zeros(), BarrierOutcome::Frozen)
        } else {
            let scaled = desired * (alpha_h / v_norm);
            (scaled, BarrierOutcome::Adjusted)
        }
    }

    fn name(&self) -> &'static str {
        "thermal_barrier"
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DensityBarrier {
    pub r_max: f32,
    pub alpha_dens: f32,
}

impl DensityBarrier {
    fn h(&self, r_local: f32) -> f32 {
        self.r_max - r_local
    }
}

impl ControlBarrierFunction for DensityBarrier {
    fn project(
        &self,
        state: &SwarmState,
        desired: &Vector3<f32>,
    ) -> (Vector3<f32>, BarrierOutcome) {
        let h = self.h(state.local_density);
        if h <= 0.0 {
            return (Vector3::zeros(), BarrierOutcome::Frozen);
        }
        let alpha_h = self.alpha_dens * h;
        let v_norm = desired.norm();
        if v_norm <= alpha_h {
            (*desired, BarrierOutcome::Safe)
        } else if alpha_h <= 0.0 {
            (Vector3::zeros(), BarrierOutcome::Frozen)
        } else {
            let scaled = desired * (alpha_h / v_norm);
            (scaled, BarrierOutcome::Adjusted)
        }
    }

    fn name(&self) -> &'static str {
        "density_barrier"
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RiskOfHarmBarrier {
    pub roh_max: f32,
    pub alpha_roh: f32,
}

impl RiskOfHarmBarrier {
    fn h(&self, roh: f32) -> f32 {
        self.roh_max - roh
    }
}

impl ControlBarrierFunction for RiskOfHarmBarrier {
    fn project(
        &self,
        state: &SwarmState,
        desired: &Vector3<f32>,
    ) -> (Vector3<f32>, BarrierOutcome) {
        let h = self.h(state.biomarkers.roh_scalar);
        if h <= 0.0 {
            return (Vector3::zeros(), BarrierOutcome::Frozen);
        }
        let alpha_h = self.alpha_roh * h;
        let v_norm = desired.norm();
        if v_norm <= alpha_h {
            (*desired, BarrierOutcome::Safe)
        } else if alpha_h <= 0.0 {
            (Vector3::zeros(), BarrierOutcome::Frozen)
        } else {
            let scaled = desired * (alpha_h / v_norm);
            (scaled, BarrierOutcome::Adjusted)
        }
    }

    fn name(&self) -> &'static str {
        "roh_barrier"
    }
}
