// mk-bluebird/nanorobotics/crates/nanoswarm-shared-control/src/lyapunov.rs
use crate::types::UnifiedSafetyAxes7Plus1;
use nalgebra::VectorN;
use nalgebra::U8;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LyapunovConfig {
    pub weights: [f32; 8],
    pub vmax: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Lyapunov7Plus1 {
    pub cfg: LyapunovConfig,
}

impl Lyapunov7Plus1 {
    pub fn new(cfg: LyapunovConfig) -> Self {
        Self { cfg }
    }

    pub fn v(&self, axes: &UnifiedSafetyAxes7Plus1) -> f32 {
        let x: VectorN<f32, U8> = axes.as_vector();
        let mut value = 0.0_f32;
        for i in 0..8 {
            let w = self.cfg.weights[i];
            let xi = x[i];
            value += w * xi * xi;
        }
        value
    }

    pub fn is_within_level_set(&self, axes: &UnifiedSafetyAxes7Plus1) -> bool {
        self.v(axes) <= self.cfg.vmax
    }
}
