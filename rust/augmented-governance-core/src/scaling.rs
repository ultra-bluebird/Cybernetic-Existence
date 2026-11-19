use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum EvoMode {
    Conservative,
    Copilot,
    Custom,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct EvoModeScaling {
    pub conservative_scale: f32,
    pub copilot_scale: f32,
    pub custom_scale: f32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ScalingError {
    NonFiniteScale,
    ScaleOutsideInclusiveRange,
}

impl EvoModeScaling {
    pub const MIN_FACTOR: f32 = 0.0;
    pub const MAX_FACTOR: f32 = 1.0;

    pub fn new(
        conservative_scale: f32,
        copilot_scale: f32,
        custom_scale: f32,
    ) -> Result<Self, ScalingError> {
        let scaling = Self {
            conservative_scale,
            copilot_scale,
            custom_scale,
        };

        scaling.validate()?;
        Ok(scaling)
    }

    pub fn validate(self) -> Result<(), ScalingError> {
        for factor in [
            self.conservative_scale,
            self.copilot_scale,
            self.custom_scale,
        ] {
            if !factor.is_finite() {
                return Err(ScalingError::NonFiniteScale);
            }

            if !(Self::MIN_FACTOR..=Self::MAX_FACTOR).contains(&factor) {
                return Err(ScalingError::ScaleOutsideInclusiveRange);
            }
        }

        Ok(())
    }

    pub fn factor_for(self, mode: EvoMode) -> f32 {
        match mode {
            EvoMode::Conservative => self.conservative_scale,
            EvoMode::Copilot => self.copilot_scale,
            EvoMode::Custom => self.custom_scale,
        }
    }
}
