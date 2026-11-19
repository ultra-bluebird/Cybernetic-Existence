// File: crates/bioscale-formal/src/probabilistic_roh.rs
// edition: 2024, rust-version: 1.85

#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

/// Deterministic upper-bound model for RoH evolution, used for Kani proofs.
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct RohEnvelopeDet {
    pub roh_before: f32,
    pub roh_after_nominal: f32,
    pub roh_noise_bound: f32,
}

impl RohEnvelopeDet {
    /// Compute a worst-case upper bound on RoH after noise and latency.
    /// The guard condition is roh_worst <= 0.30, making proofs robust to noise.
    pub fn roh_worst_case(&self) -> f32 {
        let candidate = self.roh_after_nominal + self.roh_noise_bound;
        candidate.clamp(0.0, 1.0)
    }

    pub fn respects_ceiling(&self, ceiling: f32) -> bool {
        self.roh_worst_case() <= ceiling
    }
}

/// Lightweight stochastic metadata for offline analysis (not used in Kani).
#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct RohStochasticMeta {
    pub mean: f32,
    pub variance: f32,
}

/// Example adapter: derive a deterministic noise bound from a variance estimate.
/// This is used to parameterise RohEnvelopeDet without embedding probability
/// into sovereignty-critical guard proofs.
pub fn variance_to_noise_bound(variance: f32, sigma_factor: f32) -> f32 {
    if variance <= 0.0 {
        return 0.0;
    }
    let sigma = variance.sqrt();
    sigma_factor * sigma
}
