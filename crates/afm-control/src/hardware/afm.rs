// nanorobotics/afm-control/src/hardware/afm.rs

use serde::{Deserialize, Serialize};
use anyhow::Result;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AfmMode {
    Contact,
    Tapping,
    NonContact,
    Electrochemical,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AfmScanParams {
    pub mode: AfmMode,
    pub size_nm: f64,
    pub resolution_px: u32,
    pub line_rate_hz: f32,
    pub setpoint_n: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AfmHeightSample {
    pub x_nm: f64,
    pub y_nm: f64,
    pub z_nm: f64,
    pub timestamp_ns: u64,
}

pub trait AfmController {
    fn configure_scan(&mut self, params: AfmScanParams) -> Result<()>;
    fn start_scan(&mut self) -> Result<()>;
    fn stop_scan(&mut self) -> Result<()>;
    fn next_height_sample(&mut self) -> Result<Option<AfmHeightSample>>;
}
