// nanorobotics/afm-control/src/telemetry.rs

use serde::{Deserialize, Serialize};
use crate::hardware::afm::AfmHeightSample;
use crate::hardware::motion_stage::MotionTarget;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NanoSnapshot {
    pub host_did: String,
    pub bostrom_address: String,
    pub timestamp_ns: u64,
    pub afm_sample: Option<AfmHeightSample>,
    pub motion_target: Option<MotionTarget>,
    pub cybercore_authority: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NanoEnvelope {
    pub snapshot: NanoSnapshot,
    pub cybermode: String,
    pub nanoswarm_compliance: String,
}
