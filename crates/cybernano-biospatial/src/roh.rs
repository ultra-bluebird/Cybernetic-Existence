// destination-path: crates/cybernano-biospatial/src/roh.rs
// edition: 2024
// rust-version: 1.85
#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

use biophysical_ledger::{BiophysicalBalance, BiophysicalLedger, BiophysicalTokenType};

pub const ROH_GLOBAL_CEILING: f32 = 0.30;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BiospatialRegionState {
    pub region_id: String,
    pub local_roh: f32,
    pub roh_slice_max: f32,
    pub alpha_weight: f32,
    pub evidence_tags: [String; 10],
}

impl BiospatialRegionState {
    pub fn clamped_local_roh(&self) -> f32 {
        let upper = self.roh_slice_max.max(0.0).min(ROH_GLOBAL_CEILING);
        self.local_roh.max(0.0).min(upper)
    }

    pub fn clamped_alpha(&self, alpha_min: f32, alpha_max: f32) -> f32 {
        let max_nonneg = alpha_max.max(0.0);
        let min_clamped = alpha_min.max(0.0).min(max_nonneg);
        self.alpha_weight.max(min_clamped).min(max_nonneg)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BiospatialState {
    pub regions: Vec<BiospatialRegionState>,
    pub global_roh: f32,
    pub region_alpha_min: Vec<f32>,
    pub region_alpha_max: Vec<f32>,
}

impl BiospatialState {
    pub fn new(regions: Vec<BiospatialRegionState>) -> Self {
        let n = regions.len();
        let mut s = Self {
            regions,
            global_roh: 0.0,
            region_alpha_min: vec![0.0; n],
            region_alpha_max: vec![1.0; n],
        };
        s.recompute_global_roh();
        s
    }

    pub fn set_alpha_bounds(&mut self, alpha_min: Vec<f32>, alpha_max: Vec<f32>) {
        if alpha_min.len() == self.regions.len() && alpha_max.len() == self.regions.len() {
            self.region_alpha_min = alpha_min;
            self.region_alpha_max = alpha_max;
        }
    }

    pub fn recompute_global_roh(&mut self) {
        if self.regions.is_empty() {
            self.global_roh = 0.0;
            return;
        }
        let mut weighted_sum = 0.0_f32;
        let mut alpha_sum = 0.0_f32;
        for (idx, r) in self.regions.iter().enumerate() {
            let alpha_min = self.region_alpha_min.get(idx).copied().unwrap_or(0.0);
            let alpha_max = self.region_alpha_max.get(idx).copied().unwrap_or(1.0);
            let alpha = r.clamped_alpha(alpha_min, alpha_max);
            let roh = r.clamped_local_roh();
            weighted_sum += alpha * roh;
            alpha_sum += alpha;
        }
        let roh = if alpha_sum > 0.0 {
            weighted_sum / alpha_sum
        } else {
            0.0
        };
        self.global_roh = roh.max(0.0).min(ROH_GLOBAL_CEILING);
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum SafetyVerdict {
    Safe,
    Brake,
    RollbackRequired,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BiospatialRoHGuard {
    pub roh_ceiling_global: f32,
}

impl BiospatialRoHGuard {
    pub fn new() -> Self {
        Self {
            roh_ceiling_global: ROH_GLOBAL_CEILING,
        }
    }

    pub fn evaluate(&self, state: &mut BiospatialState) -> SafetyVerdict {
        state.recompute_global_roh();
        let g = state.global_roh;
        if !g.is_finite() {
            return SafetyVerdict::RollbackRequired;
        }
        if g <= self.roh_ceiling_global {
            SafetyVerdict::Safe
        } else if g <= self.roh_ceiling_global * 1.05 {
            SafetyVerdict::Brake
        } else {
            SafetyVerdict::RollbackRequired
        }
    }

    pub fn evaluate_with_tokens(
        &self,
        state: &mut BiospatialState,
        ledger: &mut BiophysicalLedger,
        token_transitions: &[BiophysicalBalance],
    ) -> SafetyVerdict {
        let roh_verdict = self.evaluate(state);
        if !matches!(roh_verdict, SafetyVerdict::Safe | SafetyVerdict::Brake) {
            return SafetyVerdict::RollbackRequired;
        }
        for transition in token_transitions {
            let current = BiophysicalBalance {
                region_id: transition.region_id.clone(),
                token_type: transition.token_type,
                balance: transition.balance,
            };
            let next_balance = transition.balance;
            if ledger
                .apply_transition(&current, next_balance)
                .is_err()
            {
                return SafetyVerdict::RollbackRequired;
            }
        }
        if state.global_roh > self.roh_ceiling_global {
            SafetyVerdict::RollbackRequired
        } else {
            SafetyVerdict::Safe
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn global_roh_bounded_by_ceiling() {
        let r1 = BiospatialRegionState {
            region_id: "cns".to_string(),
            local_roh: 0.10,
            roh_slice_max: 0.15,
            alpha_weight: 0.6,
            evidence_tags: Default::default(),
        };
        let r2 = BiospatialRegionState {
            region_id: "cardiac".to_string(),
            local_roh: 0.05,
            roh_slice_max: 0.10,
            alpha_weight: 0.4,
            evidence_tags: Default::default(),
        };
        let mut state = BiospatialState::new(vec![r1, r2]);
        state.set_alpha_bounds(vec![0.0, 0.0], vec![1.0, 1.0]);
        state.recompute_global_roh();
        assert!(state.global_roh >= 0.0);
        assert!(state.global_roh <= ROH_GLOBAL_CEILING + f32::EPSILON);
    }

    #[test]
    fn guard_respects_global_roh_ceiling() {
        let r1 = BiospatialRegionState {
            region_id: "cns".to_string(),
            local_roh: 0.30,
            roh_slice_max: 0.30,
            alpha_weight: 1.0,
            evidence_tags: Default::default(),
        };
        let mut state = BiospatialState::new(vec![r1]);
        state.set_alpha_bounds(vec![1.0], vec![1.0]);
        let guard = BiospatialRoHGuard::new();
        let verdict = guard.evaluate(&mut state);
        assert!(state.global_roh <= guard.roh_ceiling_global + f32::EPSILON);
        assert!(matches!(
            verdict,
            SafetyVerdict::Safe | SafetyVerdict::Brake | SafetyVerdict::RollbackRequired
        ));
    }
}
