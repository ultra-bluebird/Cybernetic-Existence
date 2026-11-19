// Path: crates/neurorights-microshield/src/psychosis_clamp.rs
//
// Extend NeurorightsMicroshield to use PsychosisRisk axes for clamp. [file:3]

#![forbid(unsafe_code)]
#![cfg_attr(not(test), deny(warnings))]

use psychcaps_core::psychosis_risk::{PsychosisRisk, PsychosisRiskParams};

pub struct ClampThresholds {
    pub floor: f32,
    pub ceiling: f32,
}

impl ClampThresholds {
    pub fn new(floor: f32, ceiling: f32) -> Option<Self> {
        if !floor.is_finite() || !ceiling.is_finite() {
            return None;
        }
        if floor < 0.0 || floor > 1.0 || ceiling < 0.0 || ceiling > 1.0 {
            return None;
        }
        if floor > ceiling {
            return None;
        }
        Some(Self { floor, ceiling })
    }

    #[inline]
    pub fn phi(&self, x: f32) -> f32 {
        let x = x.clamp(0.0, 1.0);
        if x <= self.floor {
            1.0
        } else if x >= self.ceiling {
            0.0
        } else {
            let span = self.ceiling - self.floor;
            let delta = x - self.floor;
            1.0 - (delta / span)
        }
    }
}

/// Microshield variant that clamps based on PsychosisRisk 3-axis projection. [file:3]
pub struct PsychosisMicroshield {
    pub thr_thought: ClampThresholds,
    pub thr_aff: ClampThresholds,
    pub thr_id: ClampThresholds,
    pub params: PsychosisRiskParams,
}

impl PsychosisMicroshield {
    pub fn conservative_default() -> Self {
        Self {
            thr_thought: ClampThresholds::new(0.2, 0.6).unwrap(),
            thr_aff: ClampThresholds::new(0.2, 0.6).unwrap(),
            thr_id: ClampThresholds::new(0.2, 0.5).unwrap(),
            params: PsychosisRiskParams::conservative_default(),
        }
    }

    /// Global clamp factor c ∈ [0,1] from psych risk axes. [file:3]
    pub fn clamp(&self, risk: &PsychosisRisk) -> f32 {
        let r_thought = risk.r_thought as f32;
        let r_aff = risk.r_affective as f32;
        let r_id = risk.r_identity_axis as f32;

        let c_thought = self.thr_thought.phi(r_thought);
        let c_aff = self.thr_aff.phi(r_aff);
        let c_id = self.thr_id.phi(r_id);

        (c_thought * c_aff * c_id).clamp(0.0, 1.0)
    }

    /// Tightening-only threshold updates. [file:3]
    pub fn update_thresholds(
        &mut self,
        new_thought: ClampThresholds,
        new_aff: ClampThresholds,
        new_id: ClampThresholds,
    ) -> bool {
        let ok =
            new_thought.floor >= self.thr_thought.floor
                && new_thought.ceiling <= self.thr_thought.ceiling
                && new_aff.floor >= self.thr_aff.floor
                && new_aff.ceiling <= self.thr_aff.ceiling
                && new_id.floor >= self.thr_id.floor
                && new_id.ceiling <= self.thr_id.ceiling;

        if ok {
            self.thr_thought = new_thought;
            self.thr_aff = new_aff;
            self.thr_id = new_id;
        }
        ok
    }
}
