// destination-path: crates/biophysical-ledger/src/lib.rs
// edition: 2024
// rust-version: 1.85
#![forbid(unsafe_code)]

use serde::{Deserialize, Serialize};

pub const PRIMARY_BOSTROM_ADDRESS: &str =
    "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7";

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum BiophysicalTokenType {
    Blood,
    Protein,
    Lifeforce,
    Sugar,
    Oxygen,
    Pain,
    Fear,
}

impl BiophysicalTokenType {
    pub fn is_positive(self) -> bool {
        matches!(
            self,
            BiophysicalTokenType::Blood
                | BiophysicalTokenType::Protein
                | BiophysicalTokenType::Lifeforce
                | BiophysicalTokenType::Sugar
                | BiophysicalTokenType::Oxygen
        )
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BiophysicalTokenFloorV2 {
    pub region_id: String,
    pub token_type: BiophysicalTokenType,
    pub floor: f32,
    pub consciousness_threshold: f32,
    pub evidence_tags: [String; 10],
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ChannelBudget {
    pub channel_id: String,
    pub token_type: BiophysicalTokenType,
    pub window_seconds: u64,
    pub max_budget: f32,
    pub used_budget: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BiophysicalBalance {
    pub region_id: String,
    pub token_type: BiophysicalTokenType,
    pub balance: f32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LedgerError {
    NegativeFloor,
    InvalidThreshold,
    SovereignBostromMismatch,
    BalanceBelowFloor,
    BalanceOutsideConsciousBand,
    BudgetExceeded,
}

#[derive(Debug, Default)]
pub struct BiophysicalLedger {
    floors: Vec<BiophysicalTokenFloorV2>,
    channels: Vec<ChannelBudget>,
}

impl BiophysicalLedger {
    pub fn with_floors_and_channels(
        floors: Vec<BiophysicalTokenFloorV2>,
        channels: Vec<ChannelBudget>,
        bostrom_address: &str,
    ) -> Result<Self, LedgerError> {
        if bostrom_address != PRIMARY_BOSTROM_ADDRESS {
            return Err(LedgerError::SovereignBostromMismatch);
        }
        for f in &floors {
            if f.floor < 0.0 {
                return Err(LedgerError::NegativeFloor);
            }
            if f.consciousness_threshold < f.floor {
                return Err(LedgerError::InvalidThreshold);
            }
        }
        Ok(Self { floors, channels })
    }

    pub fn floor_for(
        &self,
        region_id: &str,
        token_type: BiophysicalTokenType,
    ) -> Option<(f32, f32)> {
        self.floors
            .iter()
            .find(|f| f.region_id == region_id && f.token_type == token_type)
            .map(|f| (f.floor, f.consciousness_threshold))
    }

    pub fn channel_for_mut(
        &mut self,
        channel_id: &str,
        token_type: BiophysicalTokenType,
    ) -> Option<&mut ChannelBudget> {
        self.channels
            .iter_mut()
            .find(|c| c.channel_id == channel_id && c.token_type == token_type)
    }

    pub fn apply_transition(
        &self,
        current: &BiophysicalBalance,
        next_balance: f32,
    ) -> Result<BiophysicalBalance, LedgerError> {
        let (floor, c_thresh) = self
            .floor_for(&current.region_id, current.token_type)
            .unwrap_or((0.0, f32::MAX));
        if current.token_type.is_positive() {
            if next_balance < floor {
                return Err(LedgerError::BalanceBelowFloor);
            }
            if next_balance > c_thresh {
                return Err(LedgerError::BalanceOutsideConsciousBand);
            }
        } else {
            if next_balance > c_thresh {
                return Err(LedgerError::BalanceOutsideConsciousBand);
            }
        }
        Ok(BiophysicalBalance {
            region_id: current.region_id.clone(),
            token_type: current.token_type,
            balance: next_balance,
        })
    }

    pub fn apply_channel_cost(
        &mut self,
        channel_id: &str,
        token_type: BiophysicalTokenType,
        cost: f32,
    ) -> Result<(), LedgerError> {
        if cost < 0.0 {
            return Err(LedgerError::BudgetExceeded);
        }
        let Some(ch) = self.channel_for_mut(channel_id, token_type) else {
            return Ok(());
        };
        let next_used = ch.used_budget + cost;
        if next_used > ch.max_budget {
            return Err(LedgerError::BudgetExceeded);
        }
        ch.used_budget = next_used;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn positive_tokens_respect_floors_and_thresholds() {
        let floor = BiophysicalTokenFloorV2 {
            region_id: "cns".to_string(),
            token_type: BiophysicalTokenType::Blood,
            floor: 5.0,
            consciousness_threshold: 10.0,
            evidence_tags: Default::default(),
        };
        let ledger = BiophysicalLedger::with_floors_and_channels(
            vec![floor],
            Vec::new(),
            PRIMARY_BOSTROM_ADDRESS,
        )
        .unwrap();
        let current = BiophysicalBalance {
            region_id: "cns".to_string(),
            token_type: BiophysicalTokenType::Blood,
            balance: 7.0,
        };
        let ok = ledger.apply_transition(&current, 6.0).unwrap();
        assert!(ok.balance >= 5.0);
        assert!(ok.balance <= 10.0);
        assert!(ledger.apply_transition(&current, 4.0).is_err());
        assert!(ledger.apply_transition(&current, 11.0).is_err());
    }

    #[test]
    fn pain_fear_respect_ceiling_only() {
        let floor = BiophysicalTokenFloorV2 {
            region_id: "cns".to_string(),
            token_type: BiophysicalTokenType::Pain,
            floor: 0.0,
            consciousness_threshold: 3.0,
            evidence_tags: Default::default(),
        };
        let ledger = BiophysicalLedger::with_floors_and_channels(
            vec![floor],
            Vec::new(),
            PRIMARY_BOSTROM_ADDRESS,
        )
        .unwrap();
        let current = BiophysicalBalance {
            region_id: "cns".to_string(),
            token_type: BiophysicalTokenType::Pain,
            balance: 1.0,
        };
        let ok = ledger.apply_transition(&current, 2.0).unwrap();
        assert!(ok.balance <= 3.0);
        assert!(ledger.apply_transition(&current, 4.0).is_err());
    }

    #[test]
    fn channel_budget_enforced() {
        let floor = BiophysicalTokenFloorV2 {
            region_id: "cns".to_string(),
            token_type: BiophysicalTokenType::Sugar,
            floor: 3.0,
            consciousness_threshold: 8.0,
            evidence_tags: Default::default(),
        };
        let channel = ChannelBudget {
            channel_id: "rope-01".to_string(),
            token_type: BiophysicalTokenType::Sugar,
            window_seconds: 60,
            max_budget: 5.0,
            used_budget: 0.0,
        };
        let mut ledger = BiophysicalLedger::with_floors_and_channels(
            vec![floor],
            vec![channel],
            PRIMARY_BOSTROM_ADDRESS,
        )
        .unwrap();
        assert!(ledger
            .apply_channel_cost("rope-01", BiophysicalTokenType::Sugar, 3.0)
            .is_ok());
        assert!(ledger
            .apply_channel_cost("rope-01", BiophysicalTokenType::Sugar, 3.0)
            .is_err());
    }
}
