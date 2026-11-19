// crates/afm-control/src/hardware/dummy_impl.rs

use crate::hardware::afm::{AfmController, AfmHeightSample, AfmScanParams};
use crate::hardware::motion_stage::{AxisConfig, MotionStage, MotionTarget};
use anyhow::{anyhow, Result};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Default)]
pub struct DummyStage {
    axes: Vec<AxisConfig>,
    last_target: Option<MotionTarget>,
}

impl MotionStage for DummyStage {
    fn configure_axis(&mut self, cfg: AxisConfig) -> Result<()> {
        self.axes.push(cfg);
        Ok(())
    }

    fn move_to(&mut self, target: MotionTarget) -> Result<()> {
        self.last_target = Some(target);
        Ok(())
    }

    fn stop(&mut self, axis_id: u8) -> Result<()> {
        if self.axes.iter().any(|a| a.id == axis_id) {
            Ok(())
        } else {
            Err(anyhow!("axis {} not configured", axis_id))
        }
    }
}

#[derive(Debug, Default)]
pub struct DummyAfm {
    params: Option<AfmScanParams>,
    scanning: bool,
    sample_index: u64,
}

impl AfmController for DummyAfm {
    fn configure_scan(&mut self, params: AfmScanParams) -> Result<()> {
        self.params = Some(params);
        Ok(())
    }

    fn start_scan(&mut self) -> Result<()> {
        if self.params.is_some() {
            self.scanning = true;
            self.sample_index = 0;
            Ok(())
        } else {
            Err(anyhow!("AFM scan not configured"))
        }
    }

    fn stop_scan(&mut self) -> Result<()> {
        self.scanning = false;
        Ok(())
    }

    fn next_height_sample(&mut self) -> Result<Option<AfmHeightSample>> {
        if !self.scanning {
            return Ok(None);
        }

        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos() as u64;

        let x = (self.sample_index % 256) as f64;
        let y = ((self.sample_index / 256) % 256) as f64;
        let z = (self.sample_index % 32) as f64;

        self.sample_index += 1;

        Ok(Some(AfmHeightSample {
            x_nm: x,
            y_nm: y,
            z_nm: z,
            timestamp_ns: now,
        }))
    }
}
