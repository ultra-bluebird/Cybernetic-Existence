#![forbid(unsafe_code)]
use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, Serialize, Deserialize)]
pub struct AliasParams {
    pub y_safe: f32,
    pub y_hard: f32,
    pub lipschitz_l: f32,
    pub dt: f32,
}

pub fn next_state(y_k: f32, delta: f32) -> f32 {
    y_k + delta
}
