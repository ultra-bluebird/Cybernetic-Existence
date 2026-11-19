// crates/reality_os_core/src/neurorights.rs
#![forbid(unsafe_code)]
#![deny(warnings)]

use serde::{Deserialize, Serialize};

use crate::sovereignty::HostSovereigntyBinding;

/// Machine-readable neurorights bitmask loaded from ALN shard.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct NeurorightsShard {
    pub sovereignty: HostSovereigntyBinding,
    /// Bitmask for active rights; bits 0..6 as enumerated below.
    pub bits: u32,
}

#[repr(u8)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Neuroright {
    MentalPrivacy = 0,
    CognitiveLiberty = 1,
    MentalIntegrity = 2,
    NonPunitiveXR = 3,
    SoulNonAddressability = 4,
    NonCommercialNeuralData = 5,
    FairBenefit = 6,
}

impl NeurorightsShard {
    pub fn validate(&self) -> Result<(), String> {
        if !self.sovereignty.is_primary_and_compliant() {
            return Err("NeurorightsShard sovereignty mismatch".into());
        }
        // Reserved upper bits must be zero for forward-compatible proof harnesses.
        let reserved_mask: u32 = !0u32 << 7;
        if self.bits & reserved_mask != 0 {
            return Err("NeurorightsShard reserved bits must be zero".into());
        }
        Ok(())
    }

    pub fn is_active(&self, right: Neuroright) -> bool {
        let bit = right as u8;
        (self.bits & (1u32 << bit)) != 0
    }
}
