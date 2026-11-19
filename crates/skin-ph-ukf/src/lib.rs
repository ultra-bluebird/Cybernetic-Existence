#![cfg_attr(not(test), deny(warnings))]
use serde::{Deserialize, Serialize};

pub const ALN_MIGRATION_CYBERCORE_AUTHORITY_V1: &str =
    "ALN.MIGRATION.CYBERCORE_AUTHORITY.v1";
pub const HOST_DID: &str = "did.aln.bostrom-organic-host";
pub const BOSTROM_ADDRESS: &str = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PhUkfConfig {
    pub n_layers: usize,
    pub process_noise: f32,
    pub meas_noise: f32,
    pub smoothness_lambda: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PhUkfState {
    pub mean: Vec<f32>,      // length n_layers
    pub cov: Vec<f32>,       // row-major n_layers x n_layers
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SprMeasurement {
    pub values: Vec<f32>,    // per sensor
}

pub fn ukf_predict(state: &mut PhUkfState, cfg: &PhUkfConfig, dt: f32) {
    // Implement shallow random-walk or AR(1) prediction over depth layers,
    // updating `state.mean` and `state.cov` with process noise.
}

pub fn ukf_update(
    state: &mut PhUkfState,
    cfg: &PhUkfConfig,
    meas: &SprMeasurement,
) {
    // Implement unscented update:
    // - generate sigma points,
    // - propagate through SPR forward model,
    // - compute Kalman gain,
    // - update mean and covariance.
}

/// Helper: estimated pH at epidermal layer (z1).
pub fn epidermal_ph_mean(state: &PhUkfState) -> f32 {
    state.mean.get(0).copied().unwrap_or(7.0)
}

/// Helper: posterior variance at epidermal layer.
pub fn epidermal_ph_var(state: &PhUkfState) -> f32 {
    if state.mean.is_empty() {
        return 1.0;
    }
    let n = state.mean.len();
    state.cov[0 * n + 0]
}
