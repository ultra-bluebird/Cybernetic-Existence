// destination-path: crates/envelopes-core/src/lib.rs
#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]

use serde::{Deserialize, Serialize};

use evo_consents::EvoMode; // from cratesevo-consents
use crate::state::EnvelopeState;
use crate::scaling::EvoModeScaling;

/// Common interface for all physiological envelopes.
pub trait Envelope: Sized + Clone + Serialize + for<'de> Deserialize<'de> {
    /// Check whether the given state lies within this envelope.
    fn is_within(&self, state: &dyn EnvelopeState) -> bool;

    /// Apply mode-dependent scaling, returning a new envelope that is
    /// component-wise no wider than the original and respects EvoModeScaling.
    fn apply_scale(&self, scale: &EvoModeScaling, mode: EvoMode) -> Self;
}

/// Abstract view of a host state used by envelopes.
pub trait EnvelopeState {
    fn roh_scalar(&self) -> f32;
    fn thermo_delta_c(&self) -> f32;
    fn cognitive_load(&self) -> f32;
    fn rope_plasticity(&self) -> f32;
    // extend with organ-specific accessors as needed
}

/// Mode-dependent scaling factors, normalized to [0,1].
#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq)]
pub struct EvoModeScaling {
    pub conservative_scale: f32,
    pub copilot_scale: f32,
    pub custom_scale: f32,
}

impl EvoModeScaling {
    pub fn clamped(self) -> Self {
        Self {
            conservative_scale: self.conservative_scale.clamp(0.0, 1.0),
            copilot_scale: self.copilot_scale.clamp(0.0, 1.0),
            custom_scale: self.custom_scale.clamp(0.0, 1.0),
        }
    }

    pub fn factor_for(self, mode: EvoMode) -> f32 {
        let s = self.clamped();
        match mode {
            EvoMode::Conservative => s.conservative_scale,
            EvoMode::Copilot => s.copilot_scale,
            EvoMode::Custom => s.custom_scale,
        }
    }
}
