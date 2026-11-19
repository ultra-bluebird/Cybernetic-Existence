// crates/afm-control/src/hardware/motion_stage.rs

use serde::{Deserialize, Serialize};
use anyhow::Result;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AxisConfig {
    pub id: u8,
    pub max_velocity_mm_s: f32,
    pub max_acc_mm_s2: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MotionTarget {
    pub axis_id: u8,
    pub position_mm: f64,
    pub velocity_mm_s: f32,
}

pub trait MotionStage {
    fn configure_axis(&mut self, cfg: AxisConfig) -> Result<()>;
    fn move_to(&mut self, target: MotionTarget) -> Result<()>;
    fn stop(&mut self, axis_id: u8) -> Result<()>;
}
