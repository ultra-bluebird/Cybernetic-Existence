// mk-bluebird/nanorobotics/crates/bci-teleop-filter/src/lib.rs
#![forbid(unsafe_code)]

use nalgebra::Vector3;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct BciControlSignal {
    pub intent_velocity: Vector3<f32>,
    pub cognitive_load: f32,
    pub roh_scalar: f32,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct MotionScalingProfile {
    pub base_scale: f32,
    pub min_scale: f32,
    pub max_scale: f32,
    pub roh_tightening_start: f32,
    pub roh_tightening_end: f32,
}

impl MotionScalingProfile {
    pub fn effective_scale(&self, cognitive_load: f32, roh: f32) -> f32 {
        let mut scale = self.base_scale;

        if cognitive_load > 0.5 {
            let excess = (cognitive_load - 0.5).min(0.5);
            scale *= 1.0 - 0.8 * excess;
        }

        if roh >= self.roh_tightening_start {
            let span = (self.roh_tightening_end - self.roh_tightening_start).max(1.0e-3);
            let clamped_roh = roh.min(self.roh_tightening_end);
            let frac = ((clamped_roh - self.roh_tightening_start) / span).max(0.0);
            scale *= 1.0 - 0.9 * frac;
        }

        scale.clamp(self.min_scale, self.max_scale)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct TremorFilterState {
    pub prev_velocity: Vector3<f32>,
}

impl TremorFilterState {
    pub fn new() -> Self {
        Self {
            prev_velocity: Vector3::zeros(),
        }
    }

    pub fn filter_tremor(&mut self, raw_velocity: Vector3<f32>) -> Vector3<f32> {
        let alpha: f32 = 0.2;
        let filtered = alpha * raw_velocity + (1.0 - alpha) * self.prev_velocity;
        self.prev_velocity = filtered;
        filtered
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct BciTeleopFilterConfig {
    pub motion_profile: MotionScalingProfile,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct BciTeleopFilter {
    pub cfg: BciTeleopFilterConfig,
    pub tremor_state: TremorFilterState,
}

impl BciTeleopFilter {
    pub fn new(cfg: BciTeleopFilterConfig) -> Self {
        Self {
            cfg,
            tremor_state: TremorFilterState::new(),
        }
    }

    pub fn process(&mut self, signal: BciControlSignal) -> Vector3<f32> {
        let scaled = self.apply_motion_scaling(signal);
        self.tremor_state.filter_tremor(scaled)
    }

    fn apply_motion_scaling(&self, signal: BciControlSignal) -> Vector3<f32> {
        let scale = self
            .cfg
            .motion_profile
            .effective_scale(signal.cognitive_load, signal.roh_scalar);
        signal.intent_velocity * scale
    }
}
