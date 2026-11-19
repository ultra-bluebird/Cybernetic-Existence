// Filename: mk-bluebird/nanorobotics/crates/nanorobotics-guards/src/corridor_traits.rs
// Destination: github.com/mk-bluebird/nanorobotics

#![forbid(unsafe_code)]

use crate::verdict::Verdict;

/// Shared guard input state for hemodynamic, thermal, immune, and density corridors.
/// Additional axes can be added as needed (e.g., lymphatic, biocompatibility index).
#[derive(Clone, Copy, Debug)]
pub struct GuardState {
    pub wss: f32,
    pub density: f32,
    pub thermal: f32,
    pub immune: f32,
}

pub trait CorridorGuard {
    fn evaluate(&self, state: &GuardState) -> Verdict;
}
