#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum InflammationSensingMode {
    FullySensed,
    Degraded,
}

#[derive(Clone, Copy, Debug)]
pub struct InflammationSafeLimits {
    /// Max tolerated fused inflammatory scalar under full sensing (0..=1).
    pub r_inflam_ceiling_full: f32,
    /// Max conservative scalar assumed under degraded mode (0..=1).
    pub r_inflam_ceiling_degraded: f32,
    /// Max cognitive demand allowed in degraded mode (0..=1).
    pub cognitive_demand_ceiling_degraded: f32,
}
