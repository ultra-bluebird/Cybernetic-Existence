// mk-bluebird/nanorobotics/crates/mcp-nanoswarm-gas-tools/src/lib.rs
//
// MCP tools for nanoswarm gas budgeting and estimation.
// This crate is strictly read-only and non-actuating.

#![forbid(unsafe_code)]
#![deny(warnings)]

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

use nanoswarm_gas_core::{
    NanoswarmGasBudget2026v1,
    NanoswarmGasBurn2026v1,
    PdeDoseState,
    RiskScalars,
    GasCoeffs,
    GasBurnVector,
    check_daily_budget,
    estimate_gas_for_mission,
};
use cybernetic_energy_objects::{BiophysicalEnergyLedger, TokenKind};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NanoswarmGasCheckRequest {
    pub hostdid: String,
    pub bostrom_address: String,
    pub date: String,
    pub planned_burns: HashMap<String, f32>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NanoswarmGasCheckResponse {
    pub within_budget: bool,
    pub ceilings: HashMap<String, f32>,
    pub remaining: HashMap<String, f32>,
    pub roh_estimate: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NanoswarmGasEstimateRequest {
    pub pde_state: PdeDoseState,
    pub risk_scalars: RiskScalars,
    pub coeffs: GasCoeffs,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NanoswarmGasEstimateResponse {
    pub gas_burn_vector: GasBurnVector,
    pub roh_after: f32,
}

pub fn nanoswarm_gas_check(
    req: NanoswarmGasCheckRequest,
    budget: &NanoswarmGasBudget2026v1,
    ledger_snapshot: &BiophysicalEnergyLedger,
    roh_estimate: f32,
) -> NanoswarmGasCheckResponse {
    let mut burns_map: HashMap<TokenKind, f32> = HashMap::new();
    for (k, v) in req.planned_burns.iter() {
        let kind = match k.as_str() {
            "BLOOD" => TokenKind::Blood,
            "PROTEIN" => TokenKind::Protein,
            "SUGAR" => TokenKind::NeuromodEnergy,
            "LIFEFORCE" => TokenKind::Lifeforce,
            "OXYGEN" => TokenKind::Oxygen,
            _ => continue,
        };
        burns_map.insert(kind, (*v).max(0.0));
    }

    let burn_entry =
        NanoswarmGasBurn2026v1::new("mcp-preview", burns_map).expect("valid burn entry");
    let within = check_daily_budget(budget, &[burn_entry], ledger_snapshot).unwrap_or(false);

    let mut ceilings_out = HashMap::new();
    let mut remaining_out = HashMap::new();
    for kind in [
        TokenKind::Blood,
        TokenKind::Protein,
        TokenKind::NeuromodEnergy,
        TokenKind::Lifeforce,
        TokenKind::Oxygen,
    ] {
        let name = match kind {
            TokenKind::Blood => "BLOOD",
            TokenKind::Protein => "PROTEIN",
            TokenKind::NeuromodEnergy => "SUGAR",
            TokenKind::Lifeforce => "LIFEFORCE",
            TokenKind::Oxygen => "OXYGEN",
            _ => continue,
        };
        ceilings_out.insert(name.to_string(), budget.ceiling_for_daily(kind));
        if let Ok(rem) = ledger_snapshot.remaining(kind, None) {
            remaining_out.insert(name.to_string(), rem);
        }
    }

    NanoswarmGasCheckResponse {
        within_budget: within,
        ceilings: ceilings_out,
        remaining: remaining_out,
        roh_estimate,
    }
}

pub fn nanoswarm_gas_estimate(
    req: NanoswarmGasEstimateRequest,
    roh_after: f32,
) -> NanoswarmGasEstimateResponse {
    let burns = estimate_gas_for_mission(&req.pde_state, &req.risk_scalars, &req.coeffs);
    NanoswarmGasEstimateResponse {
        gas_burn_vector: burns,
        roh_after,
    }
}
