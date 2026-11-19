// File: mk-bluebird/nanorobotics/crates/nanoswarm-gas-core/src/lib.rs
#![forbid(unsafe_code)]
#![deny(warnings)]

use std::collections::HashMap;
use std::time::{SystemTime, Duration};

use serde::{Deserialize, Serialize};
use thiserror::Error;

// These constants and types are defined in Cybercore's energy objects crate.
use cybernetic_energy_objects::{
    HOSTDID,
    BOSTROMADDRESSPRIMARY,
    ALNMIGRATIONCYBERCOREAUTHORITYV1,
    TokenKind,
    BiophysicalEnergyLedger,
    LedgerError,
};

/// Per-token gas coefficients (α_X, β_X) for phys_cost and risk_scalar.
/// Host-specific, corridor-calibrated, and ALN-governed.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GasCoeffs {
    pub alpha: HashMap<TokenKind, f32>,
    pub beta: HashMap<TokenKind, f32>,
}

impl GasCoeffs {
    pub fn alpha_for(&self, kind: TokenKind) -> f32 {
        self.alpha.get(&kind).copied().unwrap_or(0.0).max(0.0)
    }

    pub fn beta_for(&self, kind: TokenKind) -> f32 {
        self.beta.get(&kind).copied().unwrap_or(0.0).max(0.0)
    }
}

/// Host-bound gas budget for 2026, with daily, mission, and lifetime ceilings.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NanoswarmGasBudget2026v1 {
    pub hostdid: String,
    pub bostrom_address: String,
    pub aln_clause: String,
    pub date: chrono::NaiveDate,
    pub daily_ceilings: HashMap<TokenKind, f32>,
    pub mission_ceilings: HashMap<TokenKind, f32>,
    pub lifetime_ceilings: HashMap<TokenKind, f64>,
}

impl NanoswarmGasBudget2026v1 {
    pub fn validate_binding(&self) -> Result<(), GasError> {
        if self.hostdid != HOSTDID || self.bostrom_address != BOSTROMADDRESSPRIMARY {
            return Err(GasError::HostBindingMismatch);
        }
        if self.aln_clause != ALNMIGRATIONCYBERCOREAUTHORITYV1 {
            return Err(GasError::AlnClauseMismatch);
        }
        Ok(())
    }

    pub fn ceiling_for_daily(&self, kind: TokenKind) -> f32 {
        self.daily_ceilings.get(&kind).copied().unwrap_or(0.0).max(0.0)
    }

    pub fn ceiling_for_mission(&self, kind: TokenKind) -> f32 {
        self.mission_ceilings.get(&kind).copied().unwrap_or(0.0).max(0.0)
    }

    pub fn ceiling_for_lifetime(&self, kind: TokenKind) -> f64 {
        self.lifetime_ceilings.get(&kind).copied().unwrap_or(0.0).max(0.0)
    }
}

/// Per-operation gas burn vector, tied to a mission id and timestamp.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NanoswarmGasBurn2026v1 {
    pub timestamp: SystemTime,
    pub mission_id: String,
    pub burns: HashMap<TokenKind, f32>,
}

impl NanoswarmGasBurn2026v1 {
    pub fn new(mission_id: impl Into<String>, burns: HashMap<TokenKind, f32>) -> Result<Self, GasError> {
        for (_, v) in burns.iter() {
            if *v < 0.0 {
                return Err(GasError::NegativeBurn);
            }
        }
        Ok(Self {
            timestamp: SystemTime::now(),
            mission_id: mission_id.into(),
            burns,
        })
    }
}

/// Daily summary of gas usage per token.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GasDailySummary2026v1 {
    pub date: chrono::NaiveDate,
    pub total_burns: HashMap<TokenKind, f32>,
    pub within_budget: bool,
    pub roh_after: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GasBurnVector {
    pub blood: f32,
    pub protein: f32,
    pub sugar: f32,
    pub lifeforce: f32,
    pub oxygen: f32,
}

impl GasBurnVector {
    pub fn to_map(&self) -> HashMap<TokenKind, f32> {
        let mut m = HashMap::new();
        m.insert(TokenKind::Blood, self.blood.max(0.0));
        m.insert(TokenKind::Protein, self.protein.max(0.0));
        m.insert(TokenKind::Lifeforce, self.lifeforce.max(0.0));
        m.insert(TokenKind::NeuromodEnergy, self.sugar.max(0.0)); // if you keep SUGAR separate, adjust TokenKind.
        m.insert(TokenKind::Oxygen, self.oxygen.max(0.0));
        m
    }
}

/// Minimal PDE dose state exported from your controller.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PdeDoseState {
    pub blood_phys_cost: f32,
    pub protein_phys_cost: f32,
    pub sugar_phys_cost: f32,
    pub lifeforce_phys_cost: f32,
    pub oxygen_phys_cost: f32,
}

/// Risk scalars for the mission (RoH slices, latency penalties, etc.).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RiskScalars {
    pub blood_risk: f32,
    pub protein_risk: f32,
    pub sugar_risk: f32,
    pub lifeforce_risk: f32,
    pub oxygen_risk: f32,
}

#[derive(Debug, Error)]
pub enum GasError {
    #[error("host binding mismatch between budget and sovereign identity")]
    HostBindingMismatch,
    #[error("ALN clause mismatch, expected Cybercore authority")]
    AlnClauseMismatch,
    #[error("daily ceiling exceeded for token {kind:?}, total={total}, ceiling={ceiling}")]
    DailyCeilingExceeded {
        kind: TokenKind,
        total: f32,
        ceiling: f32,
    },
    #[error("lifetime ceiling exceeded for token {kind:?}, total={total}, ceiling={ceiling}")]
    LifetimeCeilingExceeded {
        kind: TokenKind,
        total: f64,
        ceiling: f64,
    },
    #[error("token ledger error: {0}")]
    Ledger(#[from] LedgerError),
    #[error("negative gas burn encountered")]
    NegativeBurn,
}

/// Check that per-day burns respect gas budget and ledger balances (no debt).
pub fn check_daily_budget(
    budget: &NanoswarmGasBudget2026v1,
    burns: &[NanoswarmGasBurn2026v1],
    ledger: &BiophysicalEnergyLedger,
) -> Result<bool, GasError> {
    budget.validate_binding()?;
    ledger.validate_binding()?;

    let mut totals: HashMap<TokenKind, f32> = HashMap::new();

    for burn in burns {
        for (kind, amount) in burn.burns.iter() {
            if *amount < 0.0 {
                return Err(GasError::NegativeBurn);
            }
            let entry = totals.entry(*kind).or_insert(0.0);
            *entry += *amount;
        }
    }

    for (kind, total) in totals.iter() {
        let ceiling = budget.ceiling_for_daily(*kind);
        if *total > ceiling {
            return Err(GasError::DailyCeilingExceeded {
                kind: *kind,
                total: *total,
                ceiling,
            });
        }
        let remaining = ledger.remaining(*kind, None)?;
        if *total > remaining {
            // ledger would go negative if burns were applied
            return Ok(false);
        }
    }

    Ok(true)
}

/// Estimate gas burns for a mission, given PDE state, risk scalars, and host coefficients.
pub fn estimate_gas_for_mission(
    pde_state: &PdeDoseState,
    risk: &RiskScalars,
    coeffs: &GasCoeffs,
) -> GasBurnVector {
    let blood = coeffs.alpha_for(TokenKind::Blood) * pde_state.blood_phys_cost
        + coeffs.beta_for(TokenKind::Blood) * risk.blood_risk;
    let protein = coeffs.alpha_for(TokenKind::Protein) * pde_state.protein_phys_cost
        + coeffs.beta_for(TokenKind::Protein) * risk.protein_risk;
    let sugar = coeffs.alpha_for(TokenKind::NeuromodEnergy) * pde_state.sugar_phys_cost
        + coeffs.beta_for(TokenKind::NeuromodEnergy) * risk.sugar_risk;
    let lifeforce = coeffs.alpha_for(TokenKind::Lifeforce) * pde_state.lifeforce_phys_cost
        + coeffs.beta_for(TokenKind::Lifeforce) * risk.lifeforce_risk;
    let oxygen = coeffs.alpha_for(TokenKind::Oxygen) * pde_state.oxygen_phys_cost
        + coeffs.beta_for(TokenKind::Oxygen) * risk.oxygen_risk;

    GasBurnVector {
        blood: blood.max(0.0),
        protein: protein.max(0.0),
        sugar: sugar.max(0.0),
        lifeforce: lifeforce.max(0.0),
        oxygen: oxygen.max(0.0),
    }
}

/// Apply gas burns to the BiophysicalEnergyLedger as token debits.
pub fn apply_gas_burns_to_ledger(
    ledger: &mut BiophysicalEnergyLedger,
    burns: &GasBurnVector,
    jurisdiction: Option<&str>,
) -> Result<(), GasError> {
    ledger.validate_binding()?;

    let jm = jurisdiction.map(|s| s.to_string());

    let map = burns.to_map();
    for (kind, amount) in map.into_iter() {
        if amount <= 0.0 {
            continue;
        }
        ledger.debit(kind, amount, jm.as_deref())?;
    }
    Ok(())
}
